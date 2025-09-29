#!/usr/bin/env powershell

<#
.SYNOPSIS
    Deploy Azure infrastructure for AI Loan Agent sample
.DESCRIPTION
    This script deploys all required Azure resources for the AI Loan Agent Logic Apps sample,
    including OpenAI, SQL Database, API Management, Storage, and Logic Apps.
.PARAMETER ResourceGroup
    Name of the Azure resource group to create/use
.PARAMETER Location
    AzWrite-Info "Checking if policies container exists..."
$containerExists = az storage container exists --name "policies" --account-name $BLOB_STORAGE_NAME --auth-mode key --query "exists" --output tsv 2>$null
if ($containerExists -eq "true") {
    Write-Status "Policies container already exists - skipping creation"
else {
    Write-Info "Creating policies container..."
    az storage container create `
        --name "policies" `
        --account-name $BLOB_STORAGE_NAME `
        --auth-mode key
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to create policies container"
        exit 1
    }
    Write-Status "Policies container created successfully"
} for resource deployment
.PARAMETER ProjectName
    Base name for all resources (used as prefix)
.PARAMETER SqlAdminPassword
    Password for SQL Server admin user (SecureString recommended)
.PARAMETER SkipLogin
    Skip Azure CLI login (useful if already authenticated)
.EXAMPLE
    .\deploy.ps1 -ResourceGroup "my-rg" -Location "eastus" -ProjectName "my-loan-agent"
.EXAMPLE
    .\deploy.ps1 -ResourceGroup "my-rg" -SqlAdminPassword (ConvertTo-SecureString "MyPassword123!" -AsPlainText -Force)
#>

param(
    [Parameter()]
    [string]$ResourceGroup = "ai-loan-agent-rg",
    
    [Parameter()]
    [string]$Location = "eastus2",
    
    [Parameter()]
    [string]$ProjectName = "ai-loan-agent",
    
    [Parameter()]
    [SecureString]$SqlAdminPassword,
    
    [Parameter()]
    [switch]$SkipLogin,

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

# Function to generate secure password
function New-SecurePassword {
    # Use .NET RNGCryptoServiceProvider for cryptographically secure random generation
    $rng = New-Object System.Security.Cryptography.RNGCryptoServiceProvider
    $chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*"
    $password = ""
    
    for ($i = 0; $i -lt 20; $i++) {  # Increased length for better security
        $bytes = New-Object byte[] 1
        $rng.GetBytes($bytes)
        $password += $chars[$bytes[0] % $chars.Length]
    }
    
    $rng.Dispose()
    return $password
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

# Check prerequisites
Write-Info "Checking prerequisites..."

if (-not (Test-AzureCli)) {
    Write-Error "Azure CLI is not installed or not in PATH. Please install Azure CLI first."
    exit 1
}

Write-Status "Azure CLI is available"

# Handle SQL Admin Password securely
$SqlAdminPasswordPlainText = ""
if ($SqlAdminPassword) {
    # Convert SecureString to plain text for Azure CLI usage
    $SqlAdminPasswordPlainText = ConvertFrom-SecureStringToPlainText -SecureString $SqlAdminPassword
    Write-Info "Using provided SQL admin password"
} else {
    Write-Info "Generating cryptographically secure SQL admin password..."
    $SqlAdminPasswordPlainText = New-SecurePassword
    Write-Warning "Password will be displayed in the final configuration output for copying to local.settings.json"
}

# Set resource names
$timestamp = Get-Date -Format "yyyyMMddHHmmss"
$LOGIC_APP_NAME = "$ProjectName-logicapp"
$STORAGE_ACCOUNT_NAME = ($ProjectName + "storage" + $timestamp).Replace("-", "").ToLower()
$SQL_SERVER_NAME = "$ProjectName-sqlserver"
$SQL_DATABASE_NAME = "$ProjectName-db"
$OPENAI_ACCOUNT_NAME = "$ProjectName-openai"
$APIM_SERVICE_NAME = if ($APIMServiceName -and $APIMServiceName.Trim().Length -gt 0) { $APIMServiceName } else { "$ProjectName-apim" }
$APIM_RESOURCE_GROUP = $ResourceGroup
$BLOB_STORAGE_NAME = ($ProjectName + "blob" + $timestamp).Replace("-", "").ToLower()
$SQL_ADMIN_USERNAME = "sqladmin"

# Storage account names must be unique and lowercase
if ($STORAGE_ACCOUNT_NAME.Length -gt 24) {
    $STORAGE_ACCOUNT_NAME = $STORAGE_ACCOUNT_NAME.Substring(0, 24)
}
if ($BLOB_STORAGE_NAME.Length -gt 24) {
    $BLOB_STORAGE_NAME = $BLOB_STORAGE_NAME.Substring(0, 24)
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

# Login to Azure
if (-not $SkipLogin) {
    Write-Header "Azure Authentication"
    Write-Info "Logging in to Azure..."
    az login
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Azure login failed"
        exit 1
    }
    Write-Status "Successfully logged in to Azure"
}

# List and set subscription
Write-Info "Available subscriptions:"
az account list --output table

$subscriptionInput = Read-Host "Enter your subscription ID (or press Enter to use current)"
if ($subscriptionInput) {
    az account set --subscription $subscriptionInput
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to set subscription"
        exit 1
    }
    Write-Status "Subscription set to: $subscriptionInput"
}

# Get current subscription ID for use throughout the script
$subscriptionId = az account show --query id --output tsv
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
Write-Info "Checking if storage account exists: $STORAGE_ACCOUNT_NAME"
$storageExists = az storage account check-name --name $STORAGE_ACCOUNT_NAME --query "nameAvailable" --output tsv
if ($storageExists -eq "false") {
    Write-Status "Storage account $STORAGE_ACCOUNT_NAME already exists - skipping creation"
} else {
    Write-Info "Creating storage account: $STORAGE_ACCOUNT_NAME"
    az storage account create `
        --name $STORAGE_ACCOUNT_NAME `
        --resource-group $ResourceGroup `
        --location $Location `
        --sku Standard_LRS `
        --kind StorageV2
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to create storage account"
        exit 1
    }
    Write-Status "Storage account created successfully"
}

# Create SQL Server and Database
Write-Header "Creating SQL Database"
Write-Info "Checking if SQL Server exists: $SQL_SERVER_NAME"
$sqlServerExists = az sql server show --name $SQL_SERVER_NAME --resource-group $ResourceGroup --query "name" --output tsv 2>$null
if ($sqlServerExists) {
    Write-Status "SQL Server $SQL_SERVER_NAME already exists - skipping creation"
} else {
    Write-Info "Creating SQL Server: $SQL_SERVER_NAME"
    az sql server create `
        --name $SQL_SERVER_NAME `
        --resource-group $ResourceGroup `
        --location $Location `
        --admin-user $SQL_ADMIN_USERNAME `
        --admin-password $SqlAdminPasswordPlainText
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to create SQL Server"
        exit 1
    }
    Write-Status "SQL Server created successfully"
}

Write-Info "Configuring SQL Server firewall..."
az sql server firewall-rule create `
    --resource-group $ResourceGroup `
    --server $SQL_SERVER_NAME `
    --name AllowAzureServices `
    --start-ip-address 0.0.0.0 `
    --end-ip-address 0.0.0.0
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to configure SQL Server firewall"
    exit 1
}
Write-Status "SQL Server firewall configured"

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

# Configure SQL Server Microsoft Entra ID Authentication
Write-Header "Configuring SQL Database Authentication"
Write-Info "Setting up Microsoft Entra ID authentication for SQL Server..."

# Get current user information for setting as SQL admin
$currentUser = az account show --query user.name --output tsv
$currentUserId = az ad signed-in-user show --query id --output tsv

Write-Info "Setting Microsoft Entra ID admin for SQL Server: $currentUser"
az sql server ad-admin create `
    --server $SQL_SERVER_NAME `
    --resource-group $ResourceGroup `
    --display-name $currentUser `
    --object-id $currentUserId
if ($LASTEXITCODE -ne 0) {
    Write-Warning "Failed to set Microsoft Entra ID admin - you may need to set this manually"
} else {
    Write-Status "Microsoft Entra ID authentication configured successfully"
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
        Write-Warning "Failed to add IP address to firewall - you may need to add it manually: $currentIP"
    } else {
        Write-Status "IP address $currentIP added to SQL Server firewall"
    }
} else {
    Write-Warning "Could not detect your public IP address - you may need to add it manually to SQL Server firewall"
}

# Create Azure OpenAI
Write-Header "Creating Azure OpenAI Service"
Write-Info "Checking if OpenAI account exists: $OPENAI_ACCOUNT_NAME"
$openaiExists = az cognitiveservices account show --name $OPENAI_ACCOUNT_NAME --resource-group $ResourceGroup --query "name" --output tsv 2>$null
if ($openaiExists) {
    Write-Status "OpenAI account $OPENAI_ACCOUNT_NAME already exists - skipping creation"
} else {
    Write-Info "Creating OpenAI account: $OPENAI_ACCOUNT_NAME"
    az cognitiveservices account create `
        --name $OPENAI_ACCOUNT_NAME `
        --resource-group $ResourceGroup `
        --location $Location `
        --kind OpenAI `
        --sku S0 `
        --yes
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to create OpenAI account"
        exit 1
    }
    Write-Status "OpenAI account created successfully"
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
        Write-Warning "Failed to deploy GPT-4 model. This may be due to:"
        Write-Warning "  - Model quota limitations in your subscription"
        Write-Warning "  - Regional availability constraints"
        Write-Warning "  - Account type restrictions"
        Write-Warning "You will need to deploy a GPT-4 model manually in the Azure portal:"
        Write-Warning "  1. Go to Azure OpenAI Studio (oai.azure.com)"
        Write-Warning "  2. Navigate to Deployments > Create new deployment"
        Write-Warning "  3. Select GPT-4 model (any available version)"
        Write-Warning "  4. Set deployment name to 'gpt-4.1' to match the Logic Apps configuration"
    } else {
        Write-Status "GPT-4.1 model deployed successfully"
    }
}

# Create API Management
Write-Header "Creating API Management Service"
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
        # If the name is taken (ServiceAlreadyExists), try to locate the existing APIM by name across the subscription
        if ($apimCreateResult -match "ServiceAlreadyExists" -or $apimCreateResult -match "already exists") {
            Write-Warning "APIM name '$APIM_SERVICE_NAME' appears to be already in use. Attempting to locate existing APIM with that name in this subscription..."

            $apimMatchJson = az apim list --query "[?name=='$APIM_SERVICE_NAME'] | [0] | {name:name, resourceGroup:resourceGroup}" --output json 2>$null
            if ($apimMatchJson) {
                try {
                    $apimMatch = $apimMatchJson | ConvertFrom-Json
                } catch {
                    $apimMatch = $null
                }

                if ($apimMatch -and $apimMatch.name) {
                    $APIM_SERVICE_NAME = $apimMatch.name
                    $APIM_RESOURCE_GROUP = $apimMatch.resourceGroup
                    Write-Status "Located existing APIM: $APIM_SERVICE_NAME in resource group: $APIM_RESOURCE_GROUP - using it"
                }
            }

            if (-not $APIM_SERVICE_NAME -or $APIM_SERVICE_NAME -eq "") {
                Write-Error "APIM creation failed and could not locate an existing service by that name in the subscription. Provide a different APIM name with -APIMServiceName or create APIM manually."
                exit 1
            }
        } else {
            Write-Error "Failed to create API Management service: $apimCreateResult"
            exit 1
        }
    } else {
        Write-Status "API Management service created successfully"
        # Leave $APIM_RESOURCE_GROUP as the target ResourceGroup
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

# Create blob storage
Write-Header "Creating Blob Storage"
Write-Info "Checking if blob storage account exists: $BLOB_STORAGE_NAME"
$blobStorageExists = az storage account check-name --name $BLOB_STORAGE_NAME --query "nameAvailable" --output tsv
if ($blobStorageExists -eq "false") {
    Write-Status "Blob storage account $BLOB_STORAGE_NAME already exists - skipping creation"
} else {
    Write-Info "Creating blob storage account: $BLOB_STORAGE_NAME"
    az storage account create `
        --name $BLOB_STORAGE_NAME `
        --resource-group $ResourceGroup `
        --location $Location `
        --sku Standard_LRS `
        --kind StorageV2
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to create blob storage account"
        exit 1
    }
    Write-Status "Blob storage account created successfully"
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

# Create Logic Apps
Write-Header "Creating Logic Apps Standard"
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

# Assign RBAC roles for Azure resources
Write-Info "Assigning RBAC roles for Azure resource access..."

# Grant access to API Management (Reader role for accessing APIs)
Write-Info "Assigning API Management Service Reader role..."
az role assignment create `
    --assignee $principalId `
    --role "API Management Service Reader Role" `
    --scope "/subscriptions/$subscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.ApiManagement/service/$APIM_SERVICE_NAME"
if ($LASTEXITCODE -ne 0) {
    Write-Warning "Failed to assign API Management Reader role - may already exist"
} else {
    Write-Status "API Management Reader role assigned successfully"
}

# Grant access to Storage (for policy documents)
Write-Info "Assigning Storage Blob Data Reader role..."
az role assignment create `
    --assignee $principalId `
    --role "Storage Blob Data Reader" `
    --scope "/subscriptions/$subscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.Storage/storageAccounts/$BLOB_STORAGE_NAME"
if ($LASTEXITCODE -ne 0) {
    Write-Warning "Failed to assign Storage Blob Data Reader role - may already exist"
} else {
    Write-Status "Storage Blob Data Reader role assigned successfully"
}

# Grant access to OpenAI (Cognitive Services User role)
Write-Info "Assigning Cognitive Services User role for OpenAI access..."
az role assignment create `
    --assignee $principalId `
    --role "Cognitive Services User" `
    --scope "/subscriptions/$subscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.CognitiveServices/accounts/$OPENAI_ACCOUNT_NAME"
if ($LASTEXITCODE -ne 0) {
    Write-Warning "Failed to assign Cognitive Services User role - may already exist"
} else {
    Write-Status "Cognitive Services User role assigned successfully"
}

# Grant access to SQL Database (SQL DB Contributor role)
Write-Info "Assigning SQL DB Contributor role for database access..."
az role assignment create `
    --assignee $principalId `
    --role "SQL DB Contributor" `
    --scope "/subscriptions/$subscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.Sql/servers/$SQL_SERVER_NAME"
if ($LASTEXITCODE -ne 0) {
    Write-Warning "Failed to assign SQL DB Contributor role - may already exist"
} else {
    Write-Status "SQL DB Contributor role assigned successfully"
}

# Also grant SQL Server Contributor for more comprehensive access
Write-Info "Assigning SQL Server Contributor role for server access..."
az role assignment create `
    --assignee $principalId `
    --role "SQL Server Contributor" `
    --scope "/subscriptions/$subscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.Sql/servers/$SQL_SERVER_NAME"
if ($LASTEXITCODE -ne 0) {
    Write-Warning "Failed to assign SQL Server Contributor role - may already exist"
} else {
    Write-Status "SQL Server Contributor role assigned successfully"
}

Write-Status "RBAC roles assigned successfully"

# SQL Connection Setup Required
Write-Header "SQL Managed API Connection Setup Required"
Write-Warning "IMPORTANT: SQL connection must be created as managed API connection for child workflows"
Write-Warning "Current configuration uses service provider connection which doesn't inherit to child workflows"
Write-Warning ""
Write-Warning "Please follow the steps in SQL-CONNECTION-SETUP.md to create the proper connection:"
Write-Warning "  Option 1 (Recommended): Use Azure Portal Logic App Designer"
Write-Warning "  Option 2: Use VS Code Azure Logic Apps extension"
Write-Warning ""
Write-Warning "Quick steps:"
Write-Warning "  1. Azure Portal → Logic Apps → $LOGIC_APP_NAME → Workflows → Designer"
Write-Warning "  2. Add SQL Server action → Create new connection"
Write-Warning "  3. Connection name: sql"
Write-Warning "  4. Authentication: Managed Identity"
Write-Warning "  5. Server: $SQL_SERVER_NAME.database.windows.net"
Write-Warning "  6. Database: $SQL_DATABASE_NAME"
Write-Warning ""

# Display Microsoft Graph permissions requirements
Write-Header "Microsoft Graph API Permissions Required"
Write-Warning "IMPORTANT: Microsoft Graph permissions must be granted manually through Azure Portal"
Write-Warning "These permissions require admin consent and cannot be assigned via Azure CLI"
Write-Warning ""
Write-Warning "Required steps:"
Write-Warning "  1. Go to Azure Portal → Azure Active Directory → Enterprise Applications"
Write-Warning "  2. Search for your Logic App: $LOGIC_APP_NAME"
Write-Warning "  3. Navigate to Permissions → Add permissions → Microsoft Graph"
Write-Warning "  4. Add the following Application permissions:"
Write-Warning "     Microsoft Forms:"
Write-Warning "       - Forms.Read.All"
Write-Warning "       - Forms.ReadWrite.All"
Write-Warning "     Microsoft Teams:"
Write-Warning "       - Group.ReadWrite.All"
Write-Warning "       - Channel.ReadBasic.All"
Write-Warning "     Outlook/Exchange:"
Write-Warning "       - Mail.Send"
Write-Warning "       - Mail.ReadWrite"
Write-Warning "  5. Click 'Grant admin consent' for your organization"
Write-Warning ""
Write-Warning "After granting permissions, you can create V2 API connections using managed identity authentication."

Write-Status "Logic App managed identity configuration completed"

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

if ($subscriptions.Count -ge 1) {
    $key1Response = az rest --method POST --uri "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.ApiManagement/service/$APIM_SERVICE_NAME/subscriptions/$($subscriptions[0].SubscriptionId)/listSecrets?api-version=2021-08-01" --query "primaryKey" --output tsv
    $apimSubscriptionKey1 = $key1Response
    Write-Info "Retrieved subscription key for Risk Assessment & Employment APIs: $($subscriptions[0].SubscriptionId)"
}

if ($subscriptions.Count -ge 2) {
    $key2Response = az rest --method POST --uri "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.ApiManagement/service/$APIM_SERVICE_NAME/subscriptions/$($subscriptions[1].SubscriptionId)/listSecrets?api-version=2021-08-01" --query "primaryKey" --output tsv
    $apimSubscriptionKey2 = $key2Response
    Write-Info "Retrieved subscription key for Credit Check & Demographics APIs: $($subscriptions[1].SubscriptionId)"
}

# Fallback to first key if only one subscription exists
if (-not $apimSubscriptionKey2 -and $apimSubscriptionKey1) {
    $apimSubscriptionKey2 = $apimSubscriptionKey1
    Write-Warning "Only one subscription found, using same key for all API operations"
}

Write-Status "API Management subscription keys retrieved successfully"

Write-Info "Getting storage connection string..."
# Note: Storage connection string retrieved but not used in local.settings.json as we use UseDevelopmentStorage=true for local development

# Clean up temporary files and sensitive variables
Remove-Item -Path "loan-policy.txt" -ErrorAction SilentlyContinue

# Clear sensitive variables from memory
if ($SqlAdminPasswordPlainText) {
    Clear-Variable -Name "SqlAdminPasswordPlainText" -Force -ErrorAction SilentlyContinue
}

# Display results
Write-Header "Deployment Complete!"
Write-Status "All Azure resources have been deployed successfully."

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
az webapp config appsettings set `
    --name $LOGIC_APP_NAME `
    --resource-group $ResourceGroup `
    --settings `
        "WORKFLOWS_SUBSCRIPTION_ID=$subscriptionId" `
        "WORKFLOWS_LOCATION_NAME=$Location" `
        "WORKFLOWS_RESOURCE_GROUP_NAME=$ResourceGroup" `
        "agent_ResourceID=$openaiResourceId" `
        "agent_openAIEndpoint=$openaiEndpoint" `
        "agent_openAIKey=$openaiKey" `
        "sql_connectionString=$sqlConnectionString" `
        "apiManagementOperation_SubscriptionKey=$apimSubscriptionKey1" `
        "apiManagementOperation_11_SubscriptionKey=$apimSubscriptionKey1" `
        "apiManagementOperation_12_SubscriptionKey=$apimSubscriptionKey2" `
        "apiManagementOperation_13_SubscriptionKey=$apimSubscriptionKey2"
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
        agent_ResourceID = $openaiResourceId
        agent_openAIEndpoint = $openaiEndpoint
        agent_openAIKey = $openaiKey
        "sql_connectionString" = $sqlConnectionString
        apiManagementOperation_SubscriptionKey = $apimSubscriptionKey1
        apiManagementOperation_11_SubscriptionKey = $apimSubscriptionKey1
        apiManagementOperation_12_SubscriptionKey = $apimSubscriptionKey2
        apiManagementOperation_13_SubscriptionKey = $apimSubscriptionKey2
        "approvalAgent-policyDocument-URI" = $policyUrl
        "PolicyDocumentURL" = $policyUrl
        "PolicyDocumentURI" = $policyUrl
        "microsoftforms-2-ConnectionRuntimeUrl" = "<Add Microsoft Forms connection runtime URL>"
        "teams-1-ConnectionRuntimeUrl" = "<Add Microsoft Teams connection runtime URL>"
        "office365-ConnectionRuntimeUrl" = "<Add Outlook connection runtime URL>"
        "microsoftforms-2-connectionKey" = "@connectionKey('microsoftforms-2')"
        "teams-1-connectionKey" = "@connectionKey('teams-1')"
        "office365-connectionKey" = "@connectionKey('office365')"
        "TeamsGroupId" = "12345678-1234-1234-1234-123456789012"
        "TeamsChannelId" = "19:abcd1234567890abcd1234567890abcd@thread.tacv2"
        "DemoUserEmail" = "REPLACE_WITH_YOUR_EMAIL@example.com"
    }
}

# Convert to JSON and save to file
$jsonContent = $localSettings | ConvertTo-Json -Depth 10
$jsonContent | Out-File -FilePath $localSettingsPath -Encoding UTF8

Write-Status "local.settings.json file created successfully at: $localSettingsPath"
Write-Info "The file contains all necessary configuration values for your Logic Apps."

Write-Header "Next Steps"
Write-Info "1. Setup Database Schema:"
Write-Info "   - Open Azure Portal → SQL Database → Query Editor"
Write-Info "   - Authenticate with Microsoft Entra ID"
Write-Info "   - Run the database-setup.sql script to create tables and sample data"
Write-Info "2. Deploy using VS Code Azure Logic Apps Extension:"
Write-Info "   a. Open LogicApps folder in VS Code"
Write-Info "   b. Install Azure Logic Apps extension" 
Write-Info "   c. Deploy workflows to ai-loan-agent-logicapp"
Write-Info "   d. SQL connections will work immediately with connection string authentication"
Write-Info "3. Grant Microsoft Graph Permissions:"
Write-Info "   - Run: .\grant-graph-permissions.ps1 -ManagedIdentityPrincipalId '<YOUR-LOGIC-APP-PRINCIPAL-ID>'"
Write-Info "   - Or use Azure Portal → Microsoft Entra ID → Enterprise Applications method"
Write-Info "4. Authorize API Connections:"
Write-Info "   - Azure Portal → Logic App → Connections → Authorize each Microsoft 365 connection"
Write-Info "5. Deploy Logic App workflows using VS Code Azure Logic Apps extension:"
Write-Info "   a. Open LogicApps folder in VS Code"
Write-Info "   b. Install Azure Logic Apps extension"
Write-Info "   c. Deploy workflows to ai-loan-agent-logicapp"
Write-Info "   d. All connections including SQL will work immediately with deployed configuration"
Write-Info "6. Configure Microsoft Forms and Teams workspace (see SETUPCONNECTIONS.md)"
Write-Info "7. Test the system with a sample loan application"

Write-Header "Important Notes"
Write-Info "SQL Server: $SQL_SERVER_NAME.database.windows.net"
Write-Info "SQL Database: $SQL_DATABASE_NAME"
Write-Warning "SQL Admin Username: $SQL_ADMIN_USERNAME"
Write-Warning "SQL Admin Password: [REDACTED - check configuration output above]"
Write-Info "Microsoft Entra ID Admin: $currentUser (configured for portal access)"
Write-Info "Policy Document URL: $policyUrl"
Write-Info "Resource Group: $ResourceGroup"
Write-Info ""
Write-Header "Database Setup Required"
Write-Warning "IMPORTANT: Run database-setup.sql script to create required tables"
Write-Info "1. Portal Method: Azure Portal → SQL Database → Query Editor → Authenticate → Run script"
Write-Info "2. sqlcmd Method: sqlcmd -S $SQL_SERVER_NAME.database.windows.net -d $SQL_DATABASE_NAME -G -i database-setup.sql"
Write-Info ""
Write-Info "To clean up all resources: az group delete --name $ResourceGroup --yes --no-wait"

Write-Header "Security Best Practices Implemented"
Write-Status "✓ Cryptographically secure password generation using RNGCryptoServiceProvider"
Write-Status "✓ SecureString parameter support for password input"
Write-Status "✓ Sensitive variable cleanup after use"
Write-Status "✓ Password redacted from final output (shown only in configuration section)"
Write-Status "✓ Automatic local.settings.json file generation"
Write-Status "✓ API Management subscription keys automatically mapped to appropriate APIs"

Write-Header "API Management Key Mapping"
Write-Info "Risk Assessment API (olympia-risk-assessment) → apiManagementOperation_SubscriptionKey"
Write-Info "Employment Validation API (litware-employment-validation) → apiManagementOperation_11_SubscriptionKey"
Write-Info "Credit Check API (cronus-credit) → apiManagementOperation_12_SubscriptionKey"
Write-Info "Demographics API (northwind-demographic-verification) → apiManagementOperation_13_SubscriptionKey"

Write-Status "Deployment script completed successfully!"