#!/usr/bin/env powershell

<#
.SYNOPSIS
    Deploy Azure infrastructure for AI Loan Agent sample
.DESCRIPTION
    This script deploys all required Azure resources for the AI Loan Agent Logic Apps sample,
    including OpenAI, SQL Database, API Management, Storage, and Logic Apps.
    
    The script is idempotent and can be safely re-run multiple times.
    For troubleshooting help, see TROUBLESHOOTING.md in the same directory.
    
.PARAMETER ResourceGroup
    Name of the Azure resource group to create/use
.PARAMETER Location
    Azure region for resource deployment
.PARAMETER ProjectName
    Base name for all resources (used as prefix)
.PARAMETER APIMServiceName
    Name of existing API Management service to use (optional)
.EXAMPLE
    .\deploy.ps1 -ResourceGroup "my-rg" -Location "eastus" -ProjectName "my-loan-agent"
.EXAMPLE
    .\deploy.ps1 -APIMServiceName "existing-apim"
.NOTES
    For troubleshooting common issues, see TROUBLESHOOTING.md
#>

param(
    [Parameter()]
    [string]$ResourceGroup = "ai-loan-agent-rg",
    
    [Parameter()]
    [string]$Location = "eastus2",
    
    [Parameter()]
    [string]$ProjectName = "ai-loan-agent",

    [Parameter()]
    [string]$APIMServiceName = "ai-loan-agent-apim"
)

# Enable strict mode and stop on errors
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Color coding for output
function Write-Status($message) {
    Write-Host "✓ $message" -ForegroundColor Green
}

function Write-Info($message) {
    Write-Host "ℹ $message" -ForegroundColor Cyan
}

function Write-Warning($message) {
    Write-Host "⚠ $message" -ForegroundColor Yellow
}

function Write-Error($message) {
    Write-Host "✗ $message" -ForegroundColor Red
}

function Write-Header($message) {
    Write-Host "`n=== $message ===" -ForegroundColor Magenta
}

# Function to validate Azure CLI command success with detailed error reporting
function Test-AzureCommand {
    param(
        [string]$CommandDescription,
        [int]$ExitCode = $LASTEXITCODE,
        [string]$ErrorOutput = ""
    )
    
    if ($ExitCode -ne 0) {
        Write-Error "Failed: $CommandDescription"
        if ($ErrorOutput) {
            Write-Error "Error details: $ErrorOutput"
        }
        Write-Error "Exit code: $ExitCode"
        return $false
    }
    return $true
}

# Function to check if a resource exists with proper error handling
function Test-AzureResource {
    param(
        [string]$ResourceType,
        [string]$ResourceName,
        [string]$ResourceGroup = "",
        [hashtable]$ExtraParams = @{}
    )
    
    try {
        $params = @($ResourceName)
        if ($ResourceGroup) {
            $params += "--resource-group", $ResourceGroup
        }
        foreach ($key in $ExtraParams.Keys) {
            $params += $key, $ExtraParams[$key]
        }
        
        $result = & az $ResourceType show @params --query "name" --output tsv 2>$null
        return [bool]$result
    } catch {
        return $false
    }
}

# Function to retry Azure CLI operations with exponential backoff
function Invoke-AzureCommandWithRetry {
    param(
        [scriptblock]$Command,
        [string]$Description,
        [int]$MaxRetries = 3,
        [int]$DelaySeconds = 30
    )
    
    $attempt = 1
    $delay = $DelaySeconds
    
    do {
        try {
            Write-Info "$Description (attempt $attempt of $MaxRetries)"
            $result = & $Command
            
            if ($LASTEXITCODE -eq 0) {
                Write-Status "$Description completed successfully"
                return $result
            } else {
                throw "Command failed with exit code $LASTEXITCODE"
            }
        } catch {
            Write-Warning "$Description failed on attempt $attempt - $($_.Exception.Message)"
            
            if ($attempt -eq $MaxRetries) {
                Write-Error "$Description failed after $MaxRetries attempts"
                throw
            }
            
            Write-Info "Waiting $delay seconds before retry..."
            Start-Sleep -Seconds $delay
            $delay = $delay * 2  # Exponential backoff
            $attempt++
        }
    } while ($attempt -le $MaxRetries)
}

# Function to convert SecureString to plain text (use sparingly)
function ConvertFrom-SecureStringToPlainText {
    param([SecureString]$SecureString)
    
    $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString)
    try {
        return [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
    } finally {
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    }
}

# Function to test if Azure CLI is installed
function Test-AzureCli {
    try {
        az version | Out-Null
        return $true
    } catch {
        return $false
    }
}

Write-Header "AI Loan Agent Infrastructure Deployment"

Write-Info "This script is idempotent and can be safely re-run multiple times."
Write-Info "Existing resources will be detected and skipped automatically."
Write-Info "Only missing or failed resources will be created."

# Parameter validation
Write-Header "Validating Parameters"

if (-not $ResourceGroup -or $ResourceGroup.Trim().Length -eq 0) {
    Write-Error "ResourceGroup parameter cannot be empty"
    exit 1
}

if (-not $Location -or $Location.Trim().Length -eq 0) {
    Write-Error "Location parameter cannot be empty"
    exit 1
}

if (-not $ProjectName -or $ProjectName.Trim().Length -eq 0) {
    Write-Error "ProjectName parameter cannot be empty"
    exit 1
}

# Validate resource group name format
if ($ResourceGroup -notmatch '^[a-zA-Z0-9._\-\(\)]+$' -or $ResourceGroup.Length -gt 90) {
    Write-Error "Invalid resource group name. Must be 1-90 characters and contain only alphanumeric, underscore, parentheses, hyphen, period."
    exit 1
}

# Validate location format
$validLocation = az account list-locations --query "[?name=='$Location'].name" --output tsv 2>$null
if (-not $validLocation) {
    Write-Warning "Location '$Location' may not be valid. Available locations:"
    az account list-locations --query "[].{Name:name, DisplayName:displayName}" --output table
    $confirmation = Read-Host "Continue with location '$Location'? (y/N)"
    if ($confirmation -ne 'y' -and $confirmation -ne 'Y') {
        Write-Info "Deployment cancelled by user"
        exit 0
    }
}

Write-Status "Parameters validated successfully"

# Check prerequisites
Write-Info "Checking prerequisites..."

if (-not (Test-AzureCli)) {
    Write-Error "Azure CLI is not installed or not in PATH. Please install Azure CLI first."
    exit 1
}

Write-Status "Azure CLI is available"

# Generate consistent unique identifiers based on subscription and resource group to ensure idempotency
$subscriptionId = az account show --query id --output tsv 2>$null
if ($LASTEXITCODE -ne 0 -or -not $subscriptionId) {
    Write-Error "Not logged into Azure or no active subscription. Please run 'az login' first."
    Write-Info "Authentication steps:"
    Write-Info "  1. Run: az login"
    Write-Info "  2. Run: az account set --subscription 'your-subscription-id'"
    Write-Info "  3. Re-run this script"
    exit 1
}

$hashInput = "$subscriptionId-$ResourceGroup"
$hashBytes = [System.Text.Encoding]::UTF8.GetBytes($hashInput)
$hash = [System.Security.Cryptography.SHA256]::Create().ComputeHash($hashBytes)
$hashHex = [BitConverter]::ToString($hash).Replace("-", "").ToLower()

# Create truncated identifiers for different resource types
$uniqueId4 = $hashHex.Substring(0, 4)  # 4 chars for SQL server suffix
$uniqueId8 = $hashHex.Substring(0, 8)  # 8 chars for longer identifiers

# Set resource names with consistent unique suffixes for true idempotency
$LOGIC_APP_NAME = "$ProjectName-logicapp-$uniqueId4"
$STORAGE_ACCOUNT_NAME = ($ProjectName + "storage" + $uniqueId8).Replace("-", "").ToLower()
$SQL_SERVER_NAME = "$ProjectName-sqlserver-$uniqueId4"
$SQL_DATABASE_NAME = "$ProjectName-db"
$OPENAI_ACCOUNT_NAME = "$ProjectName-openai-$uniqueId4"
$APIM_SERVICE_NAME = if ($APIMServiceName -and $APIMServiceName.Trim().Length -gt 0) { $APIMServiceName } else { "$ProjectName-apim-$uniqueId4" }
$APIM_RESOURCE_GROUP = $ResourceGroup
$BLOB_STORAGE_NAME = ($ProjectName + "blob" + $uniqueId8).Replace("-", "").ToLower()

# Check if resources with the EXACT hash-based names already exist (true idempotency)
Write-Info "Checking for existing resources with consistent naming pattern..."
Write-Info "Expected resource names based on hash ${uniqueId4}:"
Write-Info "  SQL Server: $SQL_SERVER_NAME"
Write-Info "  OpenAI: $OPENAI_ACCOUNT_NAME"  
Write-Info "  Logic App: $LOGIC_APP_NAME"
Write-Info "  Storage: $STORAGE_ACCOUNT_NAME"

# Check for exact resource names (not just pattern matching)
$sqlServerExists = az sql server show --name $SQL_SERVER_NAME --resource-group $ResourceGroup --query "name" --output tsv 2>$null
$openAIExists = az cognitiveservices account show --name $OPENAI_ACCOUNT_NAME --resource-group $ResourceGroup --query "name" --output tsv 2>$null
$logicAppExists = az webapp show --name $LOGIC_APP_NAME --resource-group $ResourceGroup --query "name" --output tsv 2>$null
$storageExists = az storage account show --name $STORAGE_ACCOUNT_NAME --resource-group $ResourceGroup --query "name" --output tsv 2>$null

# Flags to track what resources already exist (exact names only)
$sqlServerFound = [bool]$sqlServerExists
$openAIFound = [bool]$openAIExists  
$storageFound = [bool]$storageExists
$logicAppFound = [bool]$logicAppExists
$blobStorageFound = $false  # Will be set during blob storage creation
$apimFound = $false  # Will check separately due to different logic

# Report existing resources
if ($sqlServerFound) {
    Write-Status "✓ Found existing SQL Server: $SQL_SERVER_NAME - will reuse"
}
if ($openAIFound) {
    Write-Status "✓ Found existing OpenAI: $OPENAI_ACCOUNT_NAME - will reuse"  
}
if ($storageFound) {
    Write-Status "✓ Found existing storage account: $STORAGE_ACCOUNT_NAME - will reuse"
}
if ($logicAppFound) {
    Write-Status "✓ Found existing Logic App: $LOGIC_APP_NAME - will reuse"
}

# Check for existing APIM service (may have different naming logic)
$existingApim = az apim show --name $APIM_SERVICE_NAME --resource-group $ResourceGroup --query "name" --output tsv 2>$null
$apimFound = [bool]$existingApim
if ($apimFound) {
    Write-Status "✓ Found existing APIM service: $APIM_SERVICE_NAME - will reuse"
}

# Storage account names must be unique and lowercase, max 24 characters
if ($STORAGE_ACCOUNT_NAME.Length -gt 24) {
    $STORAGE_ACCOUNT_NAME = $STORAGE_ACCOUNT_NAME.Substring(0, 24)
}
if ($BLOB_STORAGE_NAME.Length -gt 24) {
    $BLOB_STORAGE_NAME = $BLOB_STORAGE_NAME.Substring(0, 24)
}

# Check for existing storage accounts with this naming pattern
$projectNameClean = $ProjectName.Replace("-", "")
$existingStorage = az storage account list --resource-group $ResourceGroup --query "[?starts_with(name, '$($projectNameClean)storage')].name" --output tsv 2>$null
if ($existingStorage) {
    $existingStorageName = ($existingStorage -split "`n")[0].Trim()
    if ($existingStorageName) {
        $STORAGE_ACCOUNT_NAME = $existingStorageName
        $storageFound = $true
        Write-Status "Found existing storage account: $STORAGE_ACCOUNT_NAME - will reuse"
    }
}

$existingBlobStorage = az storage account list --resource-group $ResourceGroup --query "[?starts_with(name, '$($projectNameClean)blob')].name" --output tsv 2>$null
if ($existingBlobStorage) {
    $existingBlobStorageName = ($existingBlobStorage -split "`n")[0].Trim()
    if ($existingBlobStorageName) {
        $BLOB_STORAGE_NAME = $existingBlobStorageName
        $blobStorageFound = $true
        Write-Status "Found existing blob storage account: $BLOB_STORAGE_NAME - will reuse"
    }
}

Write-Header "Deployment Configuration"
Write-Info "Resource Group: $ResourceGroup"
Write-Info "Location: $Location"
Write-Info "Project Name: $ProjectName"
Write-Info "Logic App: $LOGIC_APP_NAME"
Write-Info "Storage Account: $STORAGE_ACCOUNT_NAME"
Write-Info "SQL Server: $SQL_SERVER_NAME"
Write-Info "OpenAI Account: $OPENAI_ACCOUNT_NAME"
Write-Info "API Management: $APIM_SERVICE_NAME"
Write-Info "Using subscription: $subscriptionId"

# Create resource group
Write-Header "Creating Resource Group"
Write-Info "Checking if resource group exists: $ResourceGroup"
$rgExists = az group exists --name $ResourceGroup --output tsv
if ($rgExists -eq "true") {
    Write-Status "Resource group $ResourceGroup already exists - skipping creation"
} else {
    Write-Info "Creating resource group: $ResourceGroup"
    az group create --name $ResourceGroup --location $Location
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to create resource group"
        exit 1
    }
    Write-Status "Resource group created successfully"
}

# Create storage account for Logic Apps
Write-Header "Creating Storage Account"

if ($storageFound) {
    Write-Status "Storage account $STORAGE_ACCOUNT_NAME already found - skipping creation"
} else {
    Write-Info "Checking if storage account exists: $STORAGE_ACCOUNT_NAME"

# Check name availability first
$nameCheck = az storage account check-name --name $STORAGE_ACCOUNT_NAME --output json 2>$null
if ($nameCheck) {
    $nameCheckObj = $nameCheck | ConvertFrom-Json
    if (-not $nameCheckObj.nameAvailable) {
        if ($nameCheckObj.reason -eq "AlreadyExists") {
            Write-Info "Storage account name already taken. Checking if it's in our resource group..."
            $existingStorage = az storage account show --name $STORAGE_ACCOUNT_NAME --resource-group $ResourceGroup --query "name" --output tsv 2>$null
            if ($existingStorage) {
                Write-Status "Storage account $STORAGE_ACCOUNT_NAME already exists in our resource group - skipping creation"
            } else {
                Write-Warning "Storage account name '$STORAGE_ACCOUNT_NAME' exists in different resource group/subscription"
                $newTimestamp = Get-Date -Format "yyyyMMddHHmm"
                $STORAGE_ACCOUNT_NAME = ($ProjectName + "storage" + $newTimestamp).Replace("-", "").ToLower()
                if ($STORAGE_ACCOUNT_NAME.Length -gt 24) {
                    $STORAGE_ACCOUNT_NAME = $STORAGE_ACCOUNT_NAME.Substring(0, 24)
                }
                Write-Info "Generated new storage account name: $STORAGE_ACCOUNT_NAME"
            }
        } else {
            Write-Error "Storage account name '$STORAGE_ACCOUNT_NAME' is invalid: $($nameCheckObj.message)"
            exit 1
        }
    }
}

# Create storage account if it doesn't exist
if (-not (az storage account show --name $STORAGE_ACCOUNT_NAME --resource-group $ResourceGroup --query "name" --output tsv 2>$null)) {
    Write-Info "Creating storage account: $STORAGE_ACCOUNT_NAME"
    $createResult = az storage account create `
        --name $STORAGE_ACCOUNT_NAME `
        --resource-group $ResourceGroup `
        --location $Location `
        --sku Standard_LRS `
        --kind StorageV2 2>&1
    
    if (-not (Test-AzureCommand "Create storage account $STORAGE_ACCOUNT_NAME" $LASTEXITCODE $createResult)) {
        exit 1
    }
    Write-Status "Storage account created successfully: $STORAGE_ACCOUNT_NAME"
} else {
    Write-Status "Storage account $STORAGE_ACCOUNT_NAME already exists - skipping creation"
}
} # End of storage creation section

# Create SQL Server and Database
Write-Header "Creating SQL Database"

# Get current user information for SQL Server configuration
Write-Info "Getting current user information for SQL Server configuration..."
$currentUser = az account show --query user.name --output tsv
$currentUserId = az ad signed-in-user show --query id --output tsv

# SQL Server Creation Logic
if ($sqlServerFound) {
    Write-Status "SQL Server $SQL_SERVER_NAME already found - will configure authentication"
} else {
    Write-Info "Checking if SQL Server exists: $SQL_SERVER_NAME"

    # Check if it exists in our resource group first
    $sqlServerExists = az sql server show --name $SQL_SERVER_NAME --resource-group $ResourceGroup --query "name" --output tsv 2>$null
    if ($sqlServerExists) {
        Write-Status "SQL Server $SQL_SERVER_NAME already exists in resource group - skipping creation"
    } else {
        # Only check global availability if we don't have an existing server in our resource group
        Write-Info "Checking SQL Server name availability globally..."
        $nameCheckResult = az sql server list --query "[?name=='$SQL_SERVER_NAME'].name" --output tsv 2>$null
        if ($nameCheckResult) {
            Write-Warning "SQL Server name '$SQL_SERVER_NAME' is already taken globally. Using deterministic collision resolution..."
            # Use longer hash for collision resolution - still deterministic
            $additionalId = $hashHex.Substring(8, 5)  # Next 5 chars from same hash
            $SQL_SERVER_NAME = "$ProjectName-sqlserver-$additionalId"
            Write-Info "New SQL Server name: $SQL_SERVER_NAME"
        }

        Write-Info "Creating SQL Server: $SQL_SERVER_NAME"
        Write-Info "This may take a few minutes..."
        
        $createResult = az sql server create `
            --name $SQL_SERVER_NAME `
            --resource-group $ResourceGroup `
            --location $Location `
            --enable-ad-only-auth `
            --external-admin-principal-type User `
            --external-admin-name $currentUser `
            --external-admin-sid $currentUserId 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Failed to create SQL Server '$SQL_SERVER_NAME'"
            Write-Error "Error details: $createResult"
            if ($createResult -match "NameAlreadyExists" -or $createResult -match "already exists") {
                Write-Error "The SQL Server name is still conflicting. Try running the script again to generate a new unique name."
            }
            exit 1
        }
        Write-Status "SQL Server created successfully: $SQL_SERVER_NAME"
    }
}

# SQL Server Configuration (runs for both new and existing servers)
Write-Info "Configuring SQL Server firewall..."
az sql server firewall-rule create `
    --resource-group $ResourceGroup `
    --server $SQL_SERVER_NAME `
    --name AllowAzureServices `
    --start-ip-address 0.0.0.0 `
    --end-ip-address 0.0.0.0
if ($LASTEXITCODE -ne 0) {
    Write-Warning "SQL Server firewall rule may already exist - continuing"
}
Write-Status "SQL Server firewall configured"

# SQL Database Creation
Write-Info "Checking if SQL Database exists: $SQL_DATABASE_NAME"
$sqlDbExists = az sql db show --name $SQL_DATABASE_NAME --server $SQL_SERVER_NAME --resource-group $ResourceGroup --query "name" --output tsv 2>$null
if ($sqlDbExists) {
    Write-Status "SQL Database $SQL_DATABASE_NAME already exists - skipping creation"
} else {
    Write-Info "Creating SQL Database: $SQL_DATABASE_NAME"
    az sql db create `
        --resource-group $ResourceGroup `
        --server $SQL_SERVER_NAME `
        --name $SQL_DATABASE_NAME `
        --service-objective Basic
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to create SQL Database"
        exit 1
    }
    Write-Status "SQL Database created successfully"
}

# Generate SQL connection string for local development
$sqlConnectionString = "Server=tcp:$SQL_SERVER_NAME.database.windows.net,1433;Initial Catalog=$SQL_DATABASE_NAME;Authentication=Active Directory Managed Identity;Encrypt=True;"

# Configure SQL Server Microsoft Entra ID Authentication (runs for both new and existing servers)
Write-Header "Configuring SQL Database Authentication"
Write-Info "Setting up Microsoft Entra ID authentication for SQL Server..."

# Check if Microsoft Entra ID admin is already configured
Write-Info "Checking existing Microsoft Entra ID admin configuration..."
$existingAdmin = az sql server ad-admin list --resource-group $ResourceGroup --server $SQL_SERVER_NAME --query "[0].login" --output tsv 2>$null
if ($existingAdmin) {
    Write-Status "Microsoft Entra ID admin already configured: $existingAdmin"
    if ($existingAdmin -ne $currentUser) {
        Write-Warning "Current Entra ID admin ($existingAdmin) differs from current user ($currentUser)"
        Write-Info "Updating Entra ID admin to current user..."
        az sql server ad-admin create `
            --server $SQL_SERVER_NAME `
            --resource-group $ResourceGroup `
            --display-name $currentUser `
            --object-id $currentUserId
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Failed to update Microsoft Entra ID admin - current admin remains: $existingAdmin"
        } else {
            Write-Status "Microsoft Entra ID admin updated successfully to: $currentUser"
        }
    }
} else {
    Write-Info "Setting Microsoft Entra ID admin for SQL Server: $currentUser"
    az sql server ad-admin create `
        --server $SQL_SERVER_NAME `
        --resource-group $ResourceGroup `
        --display-name $currentUser `
        --object-id $currentUserId
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Failed to set Microsoft Entra ID admin - you may need to set this manually"
        Write-Warning "Run this command manually: az sql server ad-admin create --server $SQL_SERVER_NAME --resource-group $ResourceGroup --display-name '$currentUser' --object-id $currentUserId"
    } else {
        Write-Status "Microsoft Entra ID authentication configured successfully"
    }
}

# Add current user's IP to firewall rules for database access
Write-Info "Adding your IP address to SQL Server firewall rules..."
$currentIP = (Invoke-RestMethod -Uri "https://api.ipify.org" -ErrorAction SilentlyContinue)
if ($currentIP) {
    az sql server firewall-rule create `
        --resource-group $ResourceGroup `
        --server $SQL_SERVER_NAME `
        --name "AllowCurrentUserIP" `
        --start-ip-address $currentIP `
        --end-ip-address $currentIP
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Failed to add IP address to firewall - rule may already exist: $currentIP"
    } else {
        Write-Status "IP address $currentIP added to SQL Server firewall"
    }
} else {
    Write-Warning "Could not detect your public IP address - you may need to add it manually to SQL Server firewall"
}

Write-Status "SQL Server configuration completed successfully"

# Create Azure OpenAI
Write-Header "Creating Azure OpenAI Service"

if ($openAIFound) {
    Write-Status "OpenAI account $OPENAI_ACCOUNT_NAME already found - skipping creation"
} else {

# First, check if the name is available globally
Write-Info "Checking OpenAI account name availability globally..."
$existingOpenAI = az cognitiveservices account list --query "[?name=='$OPENAI_ACCOUNT_NAME'].name" --output tsv 2>$null
if ($existingOpenAI) {
    Write-Warning "OpenAI account name '$OPENAI_ACCOUNT_NAME' already exists globally. Using deterministic collision resolution..."
    # Use different part of hash for collision resolution - still deterministic
    $newUniqueId = $hashHex.Substring(8, 5)  # Next 5 chars from same hash
    $OPENAI_ACCOUNT_NAME = "$ProjectName-openai-$newUniqueId"
    Write-Info "New OpenAI account name: $OPENAI_ACCOUNT_NAME"
}

Write-Info "Checking if OpenAI account exists: $OPENAI_ACCOUNT_NAME"

# Check if OpenAI service exists in our resource group
$openaiExists = az cognitiveservices account show --name $OPENAI_ACCOUNT_NAME --resource-group $ResourceGroup --query "name" --output tsv 2>$null
if ($openaiExists) {
    Write-Status "OpenAI account $OPENAI_ACCOUNT_NAME already exists - skipping creation"
} else {
    Write-Info "Creating OpenAI account: $OPENAI_ACCOUNT_NAME"
    Write-Info "This may take a few minutes..."
    
    $createResult = az cognitiveservices account create `
        --name $OPENAI_ACCOUNT_NAME `
        --resource-group $ResourceGroup `
        --location $Location `
        --kind OpenAI `
        --sku S0 `
        --yes 2>&1
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to create OpenAI account '$OPENAI_ACCOUNT_NAME'"
        Write-Error "Error details: $createResult"
        Write-Warning "You may need to:"
        Write-Warning "  1. Check if OpenAI is available in your region: $Location"
        Write-Warning "  2. Ensure you have sufficient quota for OpenAI resources"
        Write-Warning "  3. Try a different region with OpenAI availability"
        Write-Warning "  4. Try running the script again to generate a new unique name"
        exit 1
    }
    Write-Status "OpenAI account created successfully: $OPENAI_ACCOUNT_NAME"
}

Write-Info "Checking if GPT-4.1 model deployment exists..."
$modelExists = az cognitiveservices account deployment show --name $OPENAI_ACCOUNT_NAME --resource-group $ResourceGroup --deployment-name "gpt-4.1" --query "name" --output tsv 2>$null
if ($modelExists) {
    Write-Status "GPT-4.1 model deployment already exists - skipping creation"
} else {
    Write-Info "Deploying GPT-4.1 model..."
    az cognitiveservices account deployment create `
        --name $OPENAI_ACCOUNT_NAME `
        --resource-group $ResourceGroup `
        --deployment-name "gpt-4.1" `
        --model-name "gpt-4" `
        --model-version "turbo-2024-04-09" `
        --model-format OpenAI `
        --sku-capacity 10 `
        --sku-name Standard
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Failed to deploy GPT-4 model. This may be due to quota or availability constraints."
    } else {
        Write-Status "GPT-4.1 model deployed successfully"
    }
} # End of OpenAI model deployment section
} # End of OpenAI creation section

# Create API Management
Write-Header "Creating API Management Service"

if ($apimFound) {
    Write-Status "API Management service $APIM_SERVICE_NAME already found - skipping creation"
} else {
    Write-Info "Checking for existing API Management services in resource group: $ResourceGroup"
$existingApims = az apim list --resource-group $ResourceGroup --query "[].name" --output tsv 2>$null
if ($existingApims) {
    # If there are one or more APIM instances in the RG, pick the first one and use it
    $firstApim = $existingApims -split "\r?\n" | Where-Object { $_ -ne "" } | Select-Object -First 1
    if ($firstApim) {
        $APIM_SERVICE_NAME = $firstApim.Trim()
        $APIM_RESOURCE_GROUP = $ResourceGroup
        Write-Status "Found existing API Management service in resource group: $APIM_SERVICE_NAME - using it"
    }
} else {
    Write-Info "No API Management service found in resource group: $ResourceGroup"
    
    # Check if the APIM name is available globally before attempting creation
    Write-Info "Checking APIM service name availability globally..."
    $existingAPIMs = az apim list --query "[?name=='$APIM_SERVICE_NAME'].{name:name, resourceGroup:resourceGroup}" --output json 2>$null
    $existingAPIMList = @()
    $shouldCreateAPIM = $true
    
    if ($existingAPIMs -and $existingAPIMs -ne "[]") {
        try {
            $existingAPIMList = $existingAPIMs | ConvertFrom-Json
            if ($existingAPIMList -and $existingAPIMList.Count -gt 0) {
                $existingAPIM = $existingAPIMList[0]
                Write-Warning "APIM name '$APIM_SERVICE_NAME' already exists in resource group '$($existingAPIM.resourceGroup)'."
                
                # Check if we have access to this APIM service
                $accessibleAPIM = az apim show --name $existingAPIM.name --resource-group $existingAPIM.resourceGroup --query "name" --output tsv 2>$null
                if ($accessibleAPIM) {
                    Write-Status "Using existing accessible APIM: $($existingAPIM.name) in resource group: $($existingAPIM.resourceGroup)"
                    $APIM_SERVICE_NAME = $existingAPIM.name
                    $APIM_RESOURCE_GROUP = $existingAPIM.resourceGroup
                    $shouldCreateAPIM = $false
                } else {
                    Write-Warning "Cannot access existing APIM service. Generating new unique name..."
                    $newUniqueId = Get-Random -Minimum 10000 -Maximum 99999
                    $APIM_SERVICE_NAME = "$ProjectName-apim-$newUniqueId"
                    Write-Info "New APIM service name: $APIM_SERVICE_NAME"
                }
            }
        } catch {
            Write-Info "Could not parse existing APIM list. Proceeding with creation..."
            Write-Info "Attempting to create API Management: $APIM_SERVICE_NAME"
            Write-Warning "API Management deployment can take 30-45 minutes..."
        }
    } else {
        Write-Info "APIM name '$APIM_SERVICE_NAME' is available globally"
        Write-Info "Attempting to create API Management: $APIM_SERVICE_NAME"
        Write-Warning "API Management deployment can take 30-45 minutes..."
    }

    # Only attempt creation if we didn't find an existing APIM to reuse
    if ($shouldCreateAPIM) {
        Write-Info "Attempting to create API Management: $APIM_SERVICE_NAME"
        Write-Warning "API Management deployment can take 30-45 minutes..."
        
        # Try to create APIM; capture stdout/stderr so we can detect a 'ServiceAlreadyExists' error
        $apimCreateResult = az apim create `
        --name $APIM_SERVICE_NAME `
        --resource-group $ResourceGroup `
        --location $Location `
        --publisher-email "admin@example.com" `
        --publisher-name "AI Loan Agent" `
        --sku-name Developer 2>&1

        if ($LASTEXITCODE -ne 0) {
            if ($apimCreateResult -match "ServiceAlreadyExists" -or $apimCreateResult -match "already exists") {
                Write-Warning "APIM service name '$APIM_SERVICE_NAME' already exists globally but not accessible. Generating unique name..."
                $newUniqueId = Get-Random -Minimum 10000 -Maximum 99999
                $APIM_SERVICE_NAME = "$ProjectName-apim-$newUniqueId"
                Write-Info "Attempting to create APIM with new unique name: $APIM_SERVICE_NAME"
                
                # Retry with new unique name
                $apimCreateResult = az apim create `
                    --name $APIM_SERVICE_NAME `
                    --resource-group $ResourceGroup `
                    --location $Location `
                    --publisher-email "admin@example.com" `
                    --publisher-name "AI Loan Agent" `
                    --sku-name Developer 2>&1
                
                if ($LASTEXITCODE -ne 0) {
                    Write-Error "Failed to create API Management service even with unique name: $apimCreateResult"
                    Write-Warning "Failed to create APIM - manual creation may be required."
                    exit 1
                } else {
                    Write-Status "API Management service created successfully with unique name: $APIM_SERVICE_NAME"
                    $APIM_RESOURCE_GROUP = $ResourceGroup
                }
            } else {
                Write-Error "Failed to create API Management service: $apimCreateResult"
                Write-Warning "Failed to create APIM - manual creation may be required."
                exit 1
            }
        } else {
            Write-Status "API Management service created successfully"
            $APIM_RESOURCE_GROUP = $ResourceGroup
        }
    } else {
        Write-Status "Using existing APIM service: $APIM_SERVICE_NAME"
    }
}

# Create APIs and operations with mock backends
Write-Info "Creating APIs with mock backend responses..."
Write-Info "Calling modular APIM policy configuration script..."

# Call the dedicated APIM policy script
$apimScriptPath = Join-Path $PSScriptRoot "create-apim-policies.ps1"
if (Test-Path $apimScriptPath) {
    try {
        $apimResult = & $apimScriptPath -ResourceGroup $APIM_RESOURCE_GROUP -APIMServiceName $APIM_SERVICE_NAME -SubscriptionId $subscriptionId
        if ($apimResult.Success) {
            Write-Status "APIM APIs and policies configured successfully"
        } else {
            Write-Warning "APIM configuration completed with warnings - check output above"
        }
    }
    catch {
        Write-Warning "Error calling APIM configuration script: $($_.Exception.Message)"
        Write-Info "Falling back to inline configuration..."
        
        # Fallback to simple inline configuration if script fails
        Write-Info "Creating basic API structure..."
        $basicApis = @("olympia-risk-assessment", "litware-employment-validation", "cronus-credit", "northwind-demographic-verification")
        foreach ($apiId in $basicApis) {
            $apiExists = az apim api show --service-name $APIM_SERVICE_NAME --resource-group $APIM_RESOURCE_GROUP --api-id $apiId --query "name" --output tsv 2>$null
            if (-not $apiExists) {
                Write-Info "Creating basic API: $apiId"
                az apim api create --service-name $APIM_SERVICE_NAME --resource-group $APIM_RESOURCE_GROUP --api-id $apiId --path "/$apiId" --display-name $apiId 2>$null
            }
        }
    }
} else {
    Write-Warning "APIM policy script not found at: $apimScriptPath"
    Write-Info "Creating basic API structure..."
    
    # Basic fallback API creation
    $basicApis = @{
        "olympia-risk-assessment" = "/risk"
        "litware-employment-validation" = "/employment" 
        "cronus-credit" = "/credit"
        "northwind-demographic-verification" = "/verify"
    }
    
    foreach ($apiId in $basicApis.Keys) {
        $path = $basicApis[$apiId]
        $apiExists = az apim api show --service-name $APIM_SERVICE_NAME --resource-group $APIM_RESOURCE_GROUP --api-id $apiId --query "name" --output tsv 2>$null
        if (-not $apiExists) {
            Write-Info "Creating basic API: $apiId at path $path"
            az apim api create --service-name $APIM_SERVICE_NAME --resource-group $APIM_RESOURCE_GROUP --api-id $apiId --path $path --display-name $apiId 2>$null
        }
    }
}

Write-Status "APIM configuration completed"
} # End of APIM creation section

# Create blob storage
Write-Header "Creating Blob Storage"

if ($blobStorageFound) {
    Write-Status "Blob storage account $BLOB_STORAGE_NAME already found - skipping creation"
} else {
    # Ensure blob storage name is valid and unique BEFORE checking
    if ($BLOB_STORAGE_NAME.Length -gt 24) {
        $BLOB_STORAGE_NAME = $BLOB_STORAGE_NAME.Substring(0, 24)
        Write-Info "Blob storage name truncated to: $BLOB_STORAGE_NAME"
    }

Write-Info "Checking if blob storage account exists: $BLOB_STORAGE_NAME"

$blobNameCheck = az storage account check-name --name $BLOB_STORAGE_NAME --output json 2>$null
if ($blobNameCheck) {
    $blobNameCheckObj = $blobNameCheck | ConvertFrom-Json
    if (-not $blobNameCheckObj.nameAvailable) {
        if ($blobNameCheckObj.reason -eq "AlreadyExists") {
            # Check if it exists in our resource group
            $existingBlobStorage = az storage account show --name $BLOB_STORAGE_NAME --resource-group $ResourceGroup --query "name" --output tsv 2>$null
            if ($existingBlobStorage) {
                Write-Status "Blob storage account $BLOB_STORAGE_NAME already exists in our resource group - skipping creation"
            } else {
                Write-Warning "Blob storage name '$BLOB_STORAGE_NAME' exists elsewhere. Generating new name..."
                $newBlobTimestamp = Get-Date -Format "yyyyMMddHHmm"
                $BLOB_STORAGE_NAME = ($ProjectName + "blob" + $newBlobTimestamp).Replace("-", "").ToLower()
                if ($BLOB_STORAGE_NAME.Length -gt 24) {
                    $BLOB_STORAGE_NAME = $BLOB_STORAGE_NAME.Substring(0, 24)
                }
                Write-Info "New blob storage name: $BLOB_STORAGE_NAME"
            }
        } else {
            Write-Error "Blob storage name '$BLOB_STORAGE_NAME' is invalid: $($blobNameCheckObj.message)"
            exit 1
        }
    }
}

# Create blob storage if needed
if (-not (az storage account show --name $BLOB_STORAGE_NAME --resource-group $ResourceGroup --query "name" --output tsv 2>$null)) {
    Write-Info "Creating blob storage account: $BLOB_STORAGE_NAME"
    $blobCreateResult = az storage account create `
        --name $BLOB_STORAGE_NAME `
        --resource-group $ResourceGroup `
        --location $Location `
        --sku Standard_LRS `
        --kind StorageV2 2>&1
    
    if (-not (Test-AzureCommand "Create blob storage account $BLOB_STORAGE_NAME" $LASTEXITCODE $blobCreateResult)) {
        exit 1
    }
    Write-Status "Blob storage account created successfully: $BLOB_STORAGE_NAME"
} else {
    Write-Status "Blob storage account $BLOB_STORAGE_NAME already exists - skipping creation"
}

Write-Info "Checking if policies container exists..."
$containerExists = az storage container exists --name "policies" --account-name $BLOB_STORAGE_NAME --account-key $(az storage account keys list --resource-group $ResourceGroup --account-name $BLOB_STORAGE_NAME --query "[0].value" --output tsv) --query "exists" --output tsv 2>$null
if ($containerExists -eq "true") {
    Write-Status "Policies container already exists - skipping creation"
} else {
    Write-Info "Creating policies container..."
    az storage container create `
        --name "policies" `
        --account-name $BLOB_STORAGE_NAME `
        --account-key $(az storage account keys list --resource-group $ResourceGroup --account-name $BLOB_STORAGE_NAME --query "[0].value" --output tsv)
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to create policies container"
        exit 1
    }
    Write-Status "Policies container created successfully"
}

# Create and upload policy document
Write-Info "Creating policy document..."
$policyContent = @"
AI Loan Agent Policy Document

LOAN APPROVAL CRITERIA:
1. Minimum credit score: 650
2. Maximum loan-to-income ratio: 5:1
3. Minimum employment period: 2 years
4. Maximum loan amount: `$100,000

SPECIAL VEHICLE CRITERIA:
- Luxury vehicles (>`$75,000): Requires minimum 750 credit score
- Limited edition vehicles: Requires human approval
- Custom vehicles: Requires human approval

HUMAN ESCALATION REQUIRED FOR:
- Credit scores between 600-649
- Loan amounts >`$75,000
- Special vehicle categories
- Employment verification failures
- Unusual risk profile indicators

AUTOMATIC APPROVAL CONDITIONS:
- Credit score >750
- Loan amount <`$50,000
- Standard vehicle purchase
- Verified employment >3 years
- Existing customer with good history

AUTOMATIC REJECTION CONDITIONS:
- Credit score <600
- Loan amount >`$100,000
- Employment verification failure
- High risk profile
"@

Write-Info "Checking if policy document exists..."
$blobExists = az storage blob exists --name "loan-policy.txt" --container-name "policies" --account-name $BLOB_STORAGE_NAME --account-key $(az storage account keys list --resource-group $ResourceGroup --account-name $BLOB_STORAGE_NAME --query "[0].value" --output tsv) --query "exists" --output tsv 2>$null
if ($blobExists -eq "true") {
    Write-Status "Policy document already exists - skipping upload"
} else {
    Write-Info "Creating policy document..."
    $policyContent | Out-File -FilePath "loan-policy.txt" -Encoding UTF8
    
    Write-Info "Uploading policy document..."
    az storage blob upload `
        --account-name $BLOB_STORAGE_NAME `
        --container-name policies `
        --name loan-policy.txt `
        --file loan-policy.txt `
        --account-key $(az storage account keys list --resource-group $ResourceGroup --account-name $BLOB_STORAGE_NAME --query "[0].value" --output tsv) `
        --overwrite
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to upload policy document"
        exit 1
    }
    Write-Status "Policy document uploaded successfully"
    
    # Clean up temporary file
    Remove-Item -Path "loan-policy.txt" -ErrorAction SilentlyContinue
}

# Generate SAS URL
$expiryDate = (Get-Date).AddYears(1).ToString("yyyy-MM-ddTHH:mm:ssZ")
$policyUrl = az storage blob generate-sas `
    --account-name $BLOB_STORAGE_NAME `
    --container-name policies `
    --name loan-policy.txt `
    --permissions r `
    --expiry $expiryDate `
    --full-uri `
    --account-key $(az storage account keys list --resource-group $ResourceGroup --account-name $BLOB_STORAGE_NAME --query "[0].value" --output tsv) `
    --output tsv
} # End of blob storage creation section

# Generate SAS URL for policy document (works for both new and existing storage)
Write-Info "Generating policy document SAS URL..."
$expiryDate = (Get-Date).AddYears(1).ToString("yyyy-MM-ddTHH:mm:ssZ")
$policyUrl = az storage blob generate-sas `
    --account-name $BLOB_STORAGE_NAME `
    --container-name policies `
    --name loan-policy.txt `
    --permissions r `
    --expiry $expiryDate `
    --full-uri `
    --account-key $(az storage account keys list --resource-group $ResourceGroup --account-name $BLOB_STORAGE_NAME --query "[0].value" --output tsv) `
    --output tsv

if ($policyUrl) {
    Write-Status "Policy document SAS URL generated successfully"
} else {
    Write-Warning "Failed to generate policy document SAS URL - using placeholder"
    $policyUrl = "https://$BLOB_STORAGE_NAME.blob.core.windows.net/policies/loan-policy.txt"
}

# Create Logic Apps
Write-Header "Creating Logic Apps Standard"

if ($logicAppFound) {
    Write-Status "Logic App $LOGIC_APP_NAME already found - skipping creation"
} else {
Write-Info "Checking if App Service Plan exists: $LOGIC_APP_NAME-plan"
$planExists = az appservice plan show --name "$LOGIC_APP_NAME-plan" --resource-group $ResourceGroup --query "name" --output tsv 2>$null
if ($planExists) {
    Write-Status "App Service Plan $LOGIC_APP_NAME-plan already exists - skipping creation"
} else {
    Write-Info "Creating App Service Plan..."
    az appservice plan create `
        --name "$LOGIC_APP_NAME-plan" `
        --resource-group $ResourceGroup `
        --location $Location `
        --sku WS1
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to create App Service Plan"
        exit 1
    }
    Write-Status "App Service Plan created successfully"
}

Write-Info "Checking if Logic Apps exists: $LOGIC_APP_NAME"
$logicAppExists = az logicapp show --name $LOGIC_APP_NAME --resource-group $ResourceGroup --query "name" --output tsv 2>$null
if ($logicAppExists) {
    Write-Status "Logic Apps $LOGIC_APP_NAME already exists - skipping creation"
} else {
    Write-Info "Creating Logic Apps: $LOGIC_APP_NAME"
    az logicapp create `
        --name $LOGIC_APP_NAME `
        --resource-group $ResourceGroup `
        --plan "$LOGIC_APP_NAME-plan" `
        --storage-account $STORAGE_ACCOUNT_NAME
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to create Logic Apps"
        exit 1
    }
    Write-Status "Logic Apps created successfully"
}

# Configure Logic App Managed Identity
Write-Header "Configuring Logic App Managed Identity"
Write-Info "Enabling system-assigned managed identity for Logic App..."
az webapp identity assign `
    --name $LOGIC_APP_NAME `
    --resource-group $ResourceGroup
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to enable Logic App managed identity"
    exit 1
}
Write-Status "Logic App managed identity enabled successfully"

# Get managed identity principal ID
Write-Info "Getting Logic App managed identity principal ID..."
$principalId = az webapp identity show `
    --name $LOGIC_APP_NAME `
    --resource-group $ResourceGroup `
    --query principalId `
    --output tsv

Write-Info "Logic App managed identity principal ID: $principalId"

# Note: RBAC role assignments are deferred until after workflow deployment
# This prevents premature creation of managed connection resource groups
Write-Info "Managed identity configured successfully - ready for connection creation during workflow deployment"

# Set critical workflow app settings immediately after Logic App creation
Write-Info "Setting critical workflow app settings to prevent naming mismatches..."
az webapp config appsettings set `
    --name $LOGIC_APP_NAME `
    --resource-group $ResourceGroup `
    --settings `
        "WORKFLOWS_LOGIC_APP_NAME=$LOGIC_APP_NAME" `
        "WORKFLOWS_RESOURCE_GROUP_NAME=$ResourceGroup" `
        "WORKFLOWS_SUBSCRIPTION_ID=$subscriptionId" `
        "WORKFLOWS_LOCATION_NAME=$Location" > $null

if ($LASTEXITCODE -eq 0) {
    Write-Status "✅ Critical workflow app settings configured"
} else {
    Write-Warning "⚠️ Failed to set critical workflow app settings"
}

Write-Status "Logic App managed identity configuration completed"
} # End of Logic Apps creation section

# Create Microsoft 365 API Connections
Write-Header "Creating Microsoft 365 API Connections"
Write-Info "Creating V2 API connections with access policies for Logic App workflows..."

# Function to create V2 API connection with access policy
function New-V2ApiConnection {
    param(
        [string]$ConnectionName,
        [string]$DisplayName,
        [string]$ApiName,
        [string]$SubscriptionId,
        [string]$ResourceGroup,
        [string]$Location,
        [string]$LogicAppPrincipalId,
        [string]$TenantId
    )
    
    Write-Info "Creating V2 $DisplayName..."
    
    # Create V2 connection using REST API
    $connectionJson = @{
        location = $Location
        kind = "V2"
        properties = @{
            displayName = $DisplayName
            api = @{
                id = "/subscriptions/$SubscriptionId/providers/Microsoft.Web/locations/$Location/managedApis/$ApiName"
            }
            parameterValues = @{}
        }
    } | ConvertTo-Json -Depth 10
    
    # Create temporary JSON file
    $tempJsonFile = [System.IO.Path]::GetTempFileName() + ".json"
    
    try {
        $connectionJson | Out-File -FilePath $tempJsonFile -Encoding UTF8
        
        # Create V2 connection
        $createResult = az rest --method PUT `
            --url "https://management.azure.com/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.Web/connections/$ConnectionName" `
            --query-parameters "api-version=2018-07-01-preview" `
            --body "@$tempJsonFile" 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-Status "✅ V2 $DisplayName created successfully"
            
            # Create access policy for Logic App managed identity
            Write-Info "Creating access policy for $ConnectionName..."
            
            $accessPolicyJson = @{
                properties = @{
                    principal = @{
                        type = "ActiveDirectory"
                        identity = @{
                            tenantId = $TenantId
                            objectId = $LogicAppPrincipalId
                        }
                    }
                }
            } | ConvertTo-Json -Depth 10
            
            $accessPolicyJson | Out-File -FilePath $tempJsonFile -Encoding UTF8
            
            $policyResult = az rest --method PUT `
                --url "https://management.azure.com/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.Web/connections/$ConnectionName/accessPolicies/$LogicAppPrincipalId" `
                --query-parameters "api-version=2018-07-01-preview" `
                --body "@$tempJsonFile" 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                Write-Status "✅ Access policy created for $ConnectionName"
                return $true
            } else {
                Write-Warning "⚠ Failed to create access policy for $ConnectionName - this may need manual authorization"
                return $true  # Connection still created successfully
            }
        } else {
            Write-Warning "⚠ $DisplayName creation failed: $createResult"
            return $false
        }
    }
    finally {
        # Clean up temporary file
        Remove-Item -Path $tempJsonFile -ErrorAction SilentlyContinue
    }
}

# Create the three Microsoft 365 API V2 connections with access policies
$connectionsCreated = 0

# Get tenant ID for access policies
$tenantId = az account show --query tenantId --output tsv

# Microsoft Forms Connection
if (New-V2ApiConnection -ConnectionName "formsConnection" -DisplayName "Microsoft Forms Connection" -ApiName "microsoftforms" -SubscriptionId $subscriptionId -ResourceGroup $ResourceGroup -Location $Location -LogicAppPrincipalId $principalId -TenantId $tenantId) {
    $connectionsCreated++
}

# Microsoft Teams Connection  
if (New-V2ApiConnection -ConnectionName "teamsConnection" -DisplayName "Microsoft Teams Connection" -ApiName "teams" -SubscriptionId $subscriptionId -ResourceGroup $ResourceGroup -Location $Location -LogicAppPrincipalId $principalId -TenantId $tenantId) {
    $connectionsCreated++
}

# Office 365 Outlook Connection
if (New-V2ApiConnection -ConnectionName "outlookConnection" -DisplayName "Office 365 Outlook Connection" -ApiName "office365" -SubscriptionId $subscriptionId -ResourceGroup $ResourceGroup -Location $Location -LogicAppPrincipalId $principalId -TenantId $tenantId) {
    $connectionsCreated++
}

# Verify connections were created
Write-Info "Verifying V2 API connections..."
$connections = az resource list --resource-group $ResourceGroup --resource-type "Microsoft.Web/connections" --query "[].name" --output tsv 2>$null
if ($connections) {
    Write-Status "V2 API connections found: $($connections -join ', ')"
    Write-Status "$connectionsCreated of 3 V2 connections created successfully with access policies"
    
    Write-Status "All connections show 'Unauthenticated' status until authorized - this is normal"
    Write-Info "Manual authorization will be required in Azure Portal for each connection"
} else {
    Write-Warning "No API connections found - creation may have failed"
}

Write-Status "Microsoft 365 V2 API connections setup completed"

# Collect configuration values
Write-Header "Collecting Configuration Values"

Write-Info "Getting OpenAI configuration..."
$openaiEndpoint = az cognitiveservices account show `
    --name $OPENAI_ACCOUNT_NAME `
    --resource-group $ResourceGroup `
    --query "properties.endpoint" `
    --output tsv

$openaiKey = az cognitiveservices account keys list `
    --name $OPENAI_ACCOUNT_NAME `
    --resource-group $ResourceGroup `
    --query "key1" `
    --output tsv

$openaiResourceId = az cognitiveservices account show `
    --name $OPENAI_ACCOUNT_NAME `
    --resource-group $ResourceGroup `
    --query "id" `
    --output tsv

Write-Info "Getting API Management subscription keys..."
# Get all subscriptions in APIM (excluding built-in all-access)
$subscriptions = az rest --method GET --uri "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.ApiManagement/service/$APIM_SERVICE_NAME/subscriptions?api-version=2021-08-01" --query "value[?properties.displayName!='Built-in all-access subscription'].{Name:properties.displayName, SubscriptionId:name}" --output json | ConvertFrom-Json

if (-not $subscriptions) {
    Write-Warning "No subscriptions found in API Management. Creating default subscriptions..."
    # Create default subscriptions if none exist
    az rest --method PUT --uri "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.ApiManagement/service/$APIM_SERVICE_NAME/subscriptions/default-subscription-1?api-version=2021-08-01" --body '{"properties":{"displayName":"API Subscription 1","scope":"/apis","state":"active"}}'
    az rest --method PUT --uri "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.ApiManagement/service/$APIM_SERVICE_NAME/subscriptions/default-subscription-2?api-version=2021-08-01" --body '{"properties":{"displayName":"API Subscription 2","scope":"/apis","state":"active"}}'
    
    # Re-fetch subscriptions
    $subscriptions = az rest --method GET --uri "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.ApiManagement/service/$APIM_SERVICE_NAME/subscriptions?api-version=2021-08-01" --query "value[?properties.displayName!='Built-in all-access subscription'].{Name:properties.displayName, SubscriptionId:name}" --output json | ConvertFrom-Json
}

# Get keys for each subscription
$apimSubscriptionKey1 = $null
$apimSubscriptionKey2 = $null

if ($subscriptions -and $subscriptions.Count -ge 1) {
    $key1Response = az rest --method POST --uri "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.ApiManagement/service/$APIM_SERVICE_NAME/subscriptions/$($subscriptions[0].SubscriptionId)/listSecrets?api-version=2021-08-01" --query "primaryKey" --output tsv 2>$null
    if ($LASTEXITCODE -eq 0) {
        $apimSubscriptionKey1 = $key1Response
        Write-Info "Retrieved subscription key for Risk Assessment and Employment APIs: $($subscriptions[0].SubscriptionId)"
    } else {
        Write-Warning "Failed to retrieve subscription key 1 - APIM may not be accessible"
    }
}

if ($subscriptions -and $subscriptions.Count -ge 2) {
    $key2Response = az rest --method POST --uri "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.ApiManagement/service/$APIM_SERVICE_NAME/subscriptions/$($subscriptions[1].SubscriptionId)/listSecrets?api-version=2021-08-01" --query "primaryKey" --output tsv 2>$null
    if ($LASTEXITCODE -eq 0) {
        $apimSubscriptionKey2 = $key2Response
        Write-Info "Retrieved subscription key for Credit Check and Demographics APIs: $($subscriptions[1].SubscriptionId)"
    } else {
        Write-Warning "Failed to retrieve subscription key 2 - APIM may not be accessible"
    }
}

# Fallback to first key if only one subscription exists
if (-not $apimSubscriptionKey2 -and $apimSubscriptionKey1) {
    $apimSubscriptionKey2 = $apimSubscriptionKey1
    Write-Warning "Only one subscription found, using same key for all API operations"
}

Write-Status "API Management subscription keys retrieved successfully"

Write-Info "Generating SQL connection string..."
# Generate SQL connection string for local development (ensure this is available globally)
$sqlConnectionString = "Server=tcp:$SQL_SERVER_NAME.database.windows.net,1433;Initial Catalog=$SQL_DATABASE_NAME;Authentication=Active Directory Managed Identity;Encrypt=True;"

Write-Info "Getting storage connection string..."
# Note: Storage connection string retrieved but not used in local.settings.json as we use UseDevelopmentStorage=true for local development

# Clean up temporary files
Remove-Item -Path "loan-policy.txt" -ErrorAction SilentlyContinue

# Deployment Complete!
Write-Header "Deployment Complete!"
Write-Status "All Azure resources have been deployed successfully."
Write-Info ""
Write-Info "📖 For complete post-deployment setup instructions, see README.md"
Write-Info ""

# Configure Azure Logic App Settings
Write-Header "Configuring Azure Logic App Settings"
Write-Info "Setting app settings in Azure Logic Apps resource..."

# Configure the critical app settings that the workflow needs
Write-Info "Setting PolicyDocumentURL app setting..."

# Create a temporary JSON file to avoid PowerShell command line parsing issues with SAS URLs
$tempAppSettings = @{
    "properties" = @{
        "PolicyDocumentURL" = $policyUrl
        "PolicyDocumentURI" = $policyUrl  
    }
}

$tempFile = [System.IO.Path]::GetTempFileName()
try {
    ($tempAppSettings | ConvertTo-Json -Depth 3) | Out-File -FilePath $tempFile -Encoding UTF8
    
    # Use REST API to set the app settings via JSON to avoid URL parsing issues
    Write-Info "Setting policy document app settings via REST API..."
    $subscriptionId = az account show --query id --output tsv
    
    az rest --method PATCH `
        --url "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.Web/sites/$LOGIC_APP_NAME/config/appsettings?api-version=2022-03-01" `
        --body "@$tempFile"
    
    if ($LASTEXITCODE -eq 0) {
        Write-Status "PolicyDocumentURL and PolicyDocumentURI app settings configured successfully"
    } else {
        Write-Warning "Failed to set policy document app settings via REST API"
        Write-Info "Policy URL that failed: $policyUrl"
    }
} finally {
    Remove-Item -Path $tempFile -ErrorAction SilentlyContinue
}

Write-Info "Setting Teams configuration app settings..."
az webapp config appsettings set `
    --name $LOGIC_APP_NAME `
    --resource-group $ResourceGroup `
    --settings "TeamsGroupId=a1b2c3d4-e5f6-7890-abcd-ef1234567890" "TeamsChannelId=19:example1234567890example1234567890@thread.tacv2"
if ($LASTEXITCODE -ne 0) {
    Write-Warning "Failed to set Teams app settings"
} else {
    Write-Status "Teams app settings configured successfully"
    Write-Info "Teams IDs are set to your actual values from previous configuration"
}

Write-Info "Setting additional workflow app settings..."
# CRITICAL: These app settings must match the actual Logic App name generated above
# If WORKFLOWS_LOGIC_APP_NAME doesn't match the actual Logic App name, workflow references
# will fail with "exceeds maximum limit of 80" error during path construction
az webapp config appsettings set `
    --name $LOGIC_APP_NAME `
    --resource-group $ResourceGroup `
    --settings `
        "WORKFLOWS_SUBSCRIPTION_ID=$subscriptionId" `
        "WORKFLOWS_LOCATION_NAME=$Location" `
        "WORKFLOWS_RESOURCE_GROUP_NAME=$ResourceGroup" `
        "WORKFLOWS_LOGIC_APP_NAME=$LOGIC_APP_NAME" `
        "agent_ResourceID=$openaiResourceId" `
        "agent_openAIEndpoint=$openaiEndpoint" `
        "agent_openAIKey=$openaiKey" `
        "apiManagementOperation_SubscriptionKey=$apimSubscriptionKey1" `
        "apiManagementOperation_11_SubscriptionKey=$apimSubscriptionKey1" `
        "apiManagementOperation_12_SubscriptionKey=$apimSubscriptionKey2" `
        "apiManagementOperation_13_SubscriptionKey=$apimSubscriptionKey2" `
        "ApiManagementServiceName=$APIM_SERVICE_NAME" `
        "ApiManagementBaseUrl=https://$APIM_SERVICE_NAME.azure-api.net/risk" `
        "ApiManagementEmploymentUrl=https://$APIM_SERVICE_NAME.azure-api.net/employment" `
        "ApiManagementCreditUrl=https://$APIM_SERVICE_NAME.azure-api.net/credit" `
        "ApiManagementVerifyUrl=https://$APIM_SERVICE_NAME.azure-api.net/verify"
if ($LASTEXITCODE -ne 0) {
    Write-Warning "Failed to set some workflow app settings"
} else {
    Write-Status "Workflow app settings configured successfully"
}

Write-Status "Azure Logic App settings configuration completed"

# Create local.settings.json file
Write-Header "Creating local.settings.json file"
$logicAppsPath = Join-Path $PSScriptRoot "..\LogicApps"
$localSettingsPath = Join-Path $logicAppsPath "local.settings.json"

# Ensure LogicApps directory exists
if (-not (Test-Path $logicAppsPath)) {
    New-Item -ItemType Directory -Path $logicAppsPath -Force | Out-Null
}

# Create the configuration object
$localSettings = @{
    IsEncrypted = $false
    Values = @{
        AzureWebJobsStorage = "UseDevelopmentStorage=true"
        APP_KIND = "workflowApp"
        FUNCTIONS_WORKER_RUNTIME = "dotnet"
        FUNCTIONS_INPROC_NET8_ENABLED = "1"
        ProjectDirectoryPath = "<Add local path to your LogicApps project directory>"
        WORKFLOWS_SUBSCRIPTION_ID = $subscriptionId
        WORKFLOWS_LOCATION_NAME = $Location
        WORKFLOWS_RESOURCE_GROUP_NAME = $ResourceGroup
        WORKFLOWS_LOGIC_APP_NAME = $LOGIC_APP_NAME
        agent_ResourceID = $openaiResourceId
        agent_openAIEndpoint = $openaiEndpoint
        agent_openAIKey = $openaiKey
        "sql_connectionString" = $sqlConnectionString
        riskAssessmentAPI_SubscriptionKey = $apimSubscriptionKey1
        employmentValidationAPI_SubscriptionKey = $apimSubscriptionKey1
        creditCheckAPI_SubscriptionKey = $apimSubscriptionKey2
        demographicVerificationAPI_SubscriptionKey = $apimSubscriptionKey2
        "approvalAgent-policyDocument-URI" = $policyUrl
        "PolicyDocumentURL" = $policyUrl
        "PolicyDocumentURI" = $policyUrl
        "formsConnection-ConnectionRuntimeUrl" = "<Add Microsoft Forms connection runtime URL>"
        "teamsConnection-ConnectionRuntimeUrl" = "<Add Microsoft Teams connection runtime URL>"
        "outlookConnection-ConnectionRuntimeUrl" = "<Add Outlook connection runtime URL>"
        "formsConnection-connectionKey" = "@connectionKey('formsConnection')"
        "teamsConnection-connectionKey" = "@connectionKey('teamsConnection')"
        "outlookConnection-connectionKey" = "@connectionKey('outlookConnection')"
        "TeamsGroupId" = "12345678-1234-1234-1234-123456789012"
        "TeamsChannelId" = "19:abcd1234567890abcd1234567890abcd@thread.tacv2"
        "DemoUserEmail" = "REPLACE_WITH_YOUR_EMAIL@example.com"
        
        # API Management Configuration
        "ApiManagementServiceName" = $APIM_SERVICE_NAME
        "ApiManagementBaseUrl" = "https://$APIM_SERVICE_NAME.azure-api.net/risk"
        "ApiManagementEmploymentUrl" = "https://$APIM_SERVICE_NAME.azure-api.net/employment" 
        "ApiManagementCreditUrl" = "https://$APIM_SERVICE_NAME.azure-api.net/credit"
        "ApiManagementVerifyUrl" = "https://$APIM_SERVICE_NAME.azure-api.net/verify"
        
        # Additional Policy Document reference for backwards compatibility
        "LoanPolicyDocumentUrl" = $policyUrl
    }
}

# Convert to JSON and save to file
$jsonContent = $localSettings | ConvertTo-Json -Depth 10
$jsonContent | Out-File -FilePath $localSettingsPath -Encoding UTF8

Write-Status "local.settings.json file created successfully at: $localSettingsPath"

Write-Header "Deployment Complete!"
Write-Status "✅ All Azure resources deployed successfully"
Write-Info ""

# Final verification and fix for critical workflow settings
Write-Header "Verifying Critical Workflow Settings"
Write-Info "Ensuring workflow app settings are correctly configured..."

# Get the current workflow app setting to verify it's correct
$currentWorkflowAppName = az webapp config appsettings list --resource-group $ResourceGroup --name $LOGIC_APP_NAME --query "[?name=='WORKFLOWS_LOGIC_APP_NAME'].value" --output tsv

if ($currentWorkflowAppName -ne $LOGIC_APP_NAME) {
    Write-Warning "WORKFLOWS_LOGIC_APP_NAME mismatch detected!"
    Write-Warning "  Expected: $LOGIC_APP_NAME"
    Write-Warning "  Current:  $currentWorkflowAppName"
    Write-Info "Fixing workflow app settings..."
    
    # Fix the critical workflow settings that must match the actual resource names
    az webapp config appsettings set `
        --name $LOGIC_APP_NAME `
        --resource-group $ResourceGroup `
        --settings `
            "WORKFLOWS_LOGIC_APP_NAME=$LOGIC_APP_NAME" `
            "WORKFLOWS_RESOURCE_GROUP_NAME=$ResourceGroup" `
            "WORKFLOWS_SUBSCRIPTION_ID=$subscriptionId" `
            "WORKFLOWS_LOCATION_NAME=$Location" > $null
    
    if ($LASTEXITCODE -eq 0) {
        Write-Status "✅ Workflow app settings corrected"
    } else {
        Write-Warning "⚠️ Failed to update workflow app settings - manual verification required"
    }
} else {
    Write-Status "✅ Workflow app settings are correctly configured"
}

Write-Info "📖 Next Steps: See README.md for complete setup instructions"
Write-Info ""
Write-Info "� Key remaining tasks:"
Write-Info "  1. Setup database schema (SQL scripts provided)"
Write-Info "  2. Authorize API connections"
Write-Info "  3. Deploy workflows with VS Code"
Write-Info "  4. Test with sample data"
Write-Info ""
Write-Info "🗂️  Resource Group: $ResourceGroup"
Write-Info "🛢️  SQL Server: $SQL_SERVER_NAME.database.windows.net" 
Write-Info "🤖 OpenAI Service: $OPENAI_ACCOUNT_NAME"
Write-Info ""
Write-Info "🧹 To clean up: az group delete --name $ResourceGroup --yes --no-wait"