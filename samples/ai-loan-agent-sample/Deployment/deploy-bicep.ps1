#!/usr/bin/env powershell

<#
.SYNOPSIS
    Deploy AI Loan Agent using Bicep
.DESCRIPTION
    Deploys Azure infrastructure using Bicep templates with parameters from main.bicepparam.
    All deployment parameters (projectName, location, sqlAdminObjectId, etc.) are configured
    in the bicep/main.bicepparam file.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Color helpers
function Write-Status($msg) { Write-Host "✓ $msg" -ForegroundColor Green }
function Write-Info($msg) { Write-Host "ℹ $msg" -ForegroundColor Cyan }
function Write-Warning($msg) { Write-Host "⚠ $msg" -ForegroundColor Yellow }
function Write-Header($msg) { Write-Host "`n=== $msg ===" -ForegroundColor Magenta }

Write-Header "AI Loan Agent - Bicep Deployment"

# ============================================================================
# Step 1: Prerequisites
# ============================================================================
Write-Header "Validating Prerequisites"

# Check Azure PowerShell authentication
try {
    $context = Get-AzContext -ErrorAction Stop
    if (-not $context) {
        Write-Error "Not logged into Azure. Run: Connect-AzAccount"
        exit 1
    }
    $subscriptionId = $context.Subscription.Id
    Write-Status "Azure PowerShell authenticated: $subscriptionId"
    
    # Get current user for SQL admin
    $currentUser = $context.Account.Id
    $currentUserId = $null
    
    # Try Get-AzADUser first
    try {
        $adUser = Get-AzADUser -UserPrincipalName $currentUser -ErrorAction Stop
        if ($adUser) {
            $currentUserId = $adUser.Id
        }
    } catch {
        Write-Info "Could not retrieve user from Get-AzADUser, trying token method..."
    }
    
    # Fallback: Extract OID from access token
    if (-not $currentUserId) {
        try {
            # Get token - will be SecureString in Az 14.0.0+, but we need plain string for JWT parsing
            $graphToken = Get-AzAccessToken -ResourceUrl "https://graph.microsoft.com" -ErrorAction Stop
            
            # Handle both current string and future SecureString token formats
            if ($graphToken.Token -is [System.Security.SecureString]) {
                # Future Az version - convert SecureString to plain text for JWT parsing
                $token = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
                    [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($graphToken.Token))
            } else {
                # Current Az version - token is already a string
                $token = $graphToken.Token
            }
            
            $tokenParts = $token.Split('.')
            if ($tokenParts.Count -ge 2) {
                # Decode JWT payload (add padding if needed)
                $payload = $tokenParts[1]
                $paddingNeeded = 4 - ($payload.Length % 4)
                if ($paddingNeeded -lt 4) {
                    $payload += "=" * $paddingNeeded
                }
                $tokenPayload = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($payload))
                $tokenJson = $tokenPayload | ConvertFrom-Json
                $currentUserId = $tokenJson.oid
            }
        } catch {
            Write-Warning "Could not extract user ID from token: $($_.Exception.Message)"
        }
    }
    
    if ($currentUserId) {
        Write-Status "Current user: $currentUser ($currentUserId)"
    } else {
        Write-Error "Could not determine current user ID. Please ensure you have proper Azure AD permissions."
        exit 1
    }
} catch {
    Write-Error "Azure PowerShell authentication failed: $($_.Exception.Message)"
    Write-Info "Run: Connect-AzAccount"
    exit 1
}

# ============================================================================
# Step 2: Read Parameters from .bicepparam
# ============================================================================
Write-Header "Reading Deployment Parameters"

$bicepParamPath = "$PSScriptRoot/bicep/main.bicepparam"
if (-not (Test-Path $bicepParamPath)) {
    Write-Error "Bicep parameter file not found: $bicepParamPath"
    exit 1
}

# Parse bicepparam file to extract resource group and location
$paramContent = Get-Content $bicepParamPath -Raw
if ($paramContent -match "param\s+projectName\s*=\s*'([^']+)'") {
    $projectName = $Matches[1]
    $resourceGroup = "rg-$projectName"
} else {
    Write-Error "Could not find projectName in bicepparam file"
    exit 1
}

if ($paramContent -match "param\s+location\s*=\s*'([^']+)'") {
    $location = $Matches[1]
} else {
    Write-Error "Could not find location in bicepparam file"
    exit 1
}

Write-Status "Project: $projectName"
Write-Status "Resource Group: $resourceGroup"
Write-Status "Location: $location"

# ============================================================================
# Step 3: Create Resource Group
# ============================================================================
Write-Header "Creating Resource Group"

$rg = Get-AzResourceGroup -Name $resourceGroup -ErrorAction SilentlyContinue
if (-not $rg) {
    New-AzResourceGroup -Name $resourceGroup -Location $location | Out-Null
    Write-Status "Resource group created: $resourceGroup"
} else {
    Write-Status "Resource group exists: $resourceGroup"
}

# ============================================================================
# Step 4: Deploy Bicep Infrastructure
# ============================================================================
Write-Header "Deploying Bicep Infrastructure"

Write-Info "This will take 5-10 minutes (or 30-45 if creating new APIM)..."
Write-Info "Using parameters from: main.bicepparam"

$deploymentName = "ai-loan-agent-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

# Use PowerShell Az module instead of Azure CLI to avoid streaming bug
Write-Info "Using PowerShell Az.Resources module for deployment..."

try {
    # Parse bicepparam file to get parameters
    $paramContent = Get-Content $bicepParamPath -Raw
    $params = @{}
    
    if ($paramContent -match "param\s+projectName\s*=\s*'([^']+)'") { $params['projectName'] = $Matches[1] }
    if ($paramContent -match "param\s+location\s*=\s*'([^']+)'") { $params['location'] = $Matches[1] }
    if ($paramContent -match "param\s+sqlAdminObjectId\s*=\s*'([^']+)'") { $params['sqlAdminObjectId'] = $Matches[1] }
    if ($paramContent -match "param\s+sqlAdminUsername\s*=\s*'([^']+)'") { $params['sqlAdminUsername'] = $Matches[1] }
    if ($paramContent -match "param\s+existingApimName\s*=\s*'([^']*)'") { $params['existingApimName'] = $Matches[1] }
    
    # Deploy using PowerShell Az module
    $deployment = New-AzResourceGroupDeployment `
        -Name $deploymentName `
        -ResourceGroupName $resourceGroup `
        -TemplateFile "$PSScriptRoot/bicep/main.bicep" `
        -TemplateParameterObject $params `
        -Verbose
    
    if ($deployment.ProvisioningState -eq "Succeeded") {
        Write-Status "Bicep deployment completed successfully"
    } else {
        Write-Error "Bicep deployment failed with state: $($deployment.ProvisioningState)"
        exit 1
    }
} catch {
    Write-Error "Bicep deployment failed: $($_.Exception.Message)"
    exit 1
}

# ============================================================================
# Step 5: Retrieve Deployment Outputs
# ============================================================================
Write-Info "Retrieving deployment outputs..."

try {
    $outputs = $deployment.Outputs
    
    Write-Status "Deployment outputs retrieved successfully"
    
    # Extract all outputs to variables
    $logicAppName = $outputs.logicAppName.Value
    $logicAppPrincipalId = $outputs.logicAppPrincipalId.Value
    $sqlServerName = $outputs.sqlServerName.Value
    $sqlDatabaseName = $outputs.sqlDatabaseName.Value
    $openAIEndpoint = $outputs.openAIEndpoint.Value
    $openAIKey = $outputs.openAIKey.Value
    $openAIResourceId = $outputs.openAIResourceId.Value
    $apimServiceName = $outputs.apimServiceName.Value
    $apimBaseUrl = $outputs.apimBaseUrl.Value
    # Convert JObject to PowerShell object
    $apimKeysJson = $outputs.apimSubscriptionKeys.Value.ToString()
    $apimKeys = $apimKeysJson | ConvertFrom-Json
    $storageAccountName = $outputs.storageAccountName.Value
    $blobStorageAccountName = $outputs.blobStorageAccountName.Value
} catch {
    Write-Error "Failed to retrieve deployment outputs: $($_.Exception.Message)"
    exit 1
}

# Connection runtime URLs - commented out as VS Code handles connections automatically
# Uncomment for CI/CD scenarios where connections are pre-created
# $formsRuntimeUrl = $outputs.formsConnectionRuntimeUrl.value
# $teamsRuntimeUrl = $outputs.teamsConnectionRuntimeUrl.value
# $outlookRuntimeUrl = $outputs.outlookConnectionRuntimeUrl.value

# ============================================================================
# Step 6: Grant Connection Permissions (Layer 2) - OPTIONAL FOR CI/CD
# ============================================================================
# Commented out - VS Code handles connection creation and authorization automatically
# Uncomment this section if using pre-created connections in CI/CD pipelines

# Write-Header "Granting Connection Permissions"
# 
# try {
#     & "$PSScriptRoot/helpers/grant-connection-permissions.ps1" `
#         -LogicAppName $logicAppName `
#         -ResourceGroup $resourceGroup
#     Write-Status "Connection permissions granted"
# } catch {
#     Write-Warning "Failed to grant connection permissions: $($_.Exception.Message)"
#     Write-Info "You can run manually later: .\helpers\grant-connection-permissions.ps1"
# }

# ============================================================================
# Step 7: Add User IP to SQL Firewall
# ============================================================================
Write-Header "Configuring SQL Server Firewall"

try {
    $currentIP = (Invoke-RestMethod -Uri "https://api.ipify.org" -ErrorAction Stop).Trim()
    Write-Info "Your IP address: $currentIP"
    
    $firewallRule = Get-AzSqlServerFirewallRule -ResourceGroupName $resourceGroup -ServerName $sqlServerName -FirewallRuleName "ClientIP-$currentIP" -ErrorAction SilentlyContinue
    if (-not $firewallRule) {
        New-AzSqlServerFirewallRule -ResourceGroupName $resourceGroup `
            -ServerName $sqlServerName `
            -FirewallRuleName "ClientIP-$currentIP" `
            -StartIpAddress $currentIP `
            -EndIpAddress $currentIP | Out-Null
    }
    
    Write-Status "SQL firewall rule added for your IP"
} catch {
    Write-Warning "Could not detect your IP address"
    Write-Info "Add your IP manually: Azure Portal → SQL Server → Networking"
}

# ============================================================================
# Step 8: Setup SQL Database (Automated with Access Token)
# ============================================================================
Write-Header "Setting Up SQL Database"

$sqlScriptPath = "$PSScriptRoot/complete-database-setup.sql"
$sqlContent = Get-Content $sqlScriptPath -Raw
$sqlContent = $sqlContent.Replace('your-logic-app-name', $logicAppName)

# Try automated execution with Azure PowerShell access token (no MFA prompt)
Write-Info "Attempting automated SQL setup using Azure PowerShell authentication..."

try {
    # Get access token for Azure SQL Database (uses existing PowerShell session)
    # Handle both current string and future SecureString token formats
    $sqlToken = Get-AzAccessToken -ResourceUrl "https://database.windows.net" -ErrorAction Stop
    
    if ($sqlToken.Token -is [System.Security.SecureString]) {
        # Future Az version - convert SecureString to plain text for SQL authentication
        $tokenResponse = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
            [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($sqlToken.Token))
    } else {
        # Current Az version - token is already a string
        $tokenResponse = $sqlToken.Token
    }
    
    if ($tokenResponse) {
        Write-Info "✓ Retrieved Azure SQL access token from PowerShell session"
        
        # Check if SqlServer module is available (provides Invoke-Sqlcmd)
        if (-not (Get-Module -ListAvailable -Name SqlServer)) {
            Write-Info "Installing SqlServer PowerShell module..."
            Install-Module -Name SqlServer -Force -AllowClobber -Scope CurrentUser -Repository PSGallery
        }
        Import-Module SqlServer -ErrorAction Stop
        
        # Execute SQL script using access token (no MFA required!)
        Write-Info "Executing SQL setup script..."
        Invoke-Sqlcmd -ServerInstance "$sqlServerName.database.windows.net" `
                      -Database $sqlDatabaseName `
                      -AccessToken $tokenResponse `
                      -Query $sqlContent `
                      -ErrorAction Stop `
                      -OutputSqlErrors $true
        
        Write-Status "✓ Database setup completed successfully (automated)"
        $sqlSetupSucceeded = $true
        
    } else {
        throw "Failed to retrieve access token"
    }
    
} catch {
    Write-Warning "Automated SQL setup failed: $($_.Exception.Message)"
    Write-Info "Falling back to alternative methods..."
    $sqlSetupSucceeded = $false
    
    # Fallback 1: Try sqlcmd with interactive auth (will prompt for MFA)
    $tempSqlFile = [System.IO.Path]::GetTempFileName() + ".sql"
    $sqlContent | Out-File $tempSqlFile -Encoding UTF8
    
    if (Get-Command sqlcmd -ErrorAction SilentlyContinue) {
        Write-Info "Trying sqlcmd with Entra ID authentication (may prompt for MFA)..."
        sqlcmd -S "$sqlServerName.database.windows.net" `
               -d $sqlDatabaseName `
               -G `
               -i $tempSqlFile 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-Status "✓ Database setup completed via sqlcmd"
            $sqlSetupSucceeded = $true
        }
        Remove-Item $tempSqlFile -ErrorAction SilentlyContinue
    }
    
    # Fallback 2: Provide manual instructions
    if (-not $sqlSetupSucceeded) {
        Write-Warning "Automated SQL setup not available"
        Write-Info ""
        Write-Info "📋 Manual Setup Required:"
        Write-Info "1. Go to Azure Portal → SQL Database → Query editor"
        Write-Info "2. Authenticate with Microsoft Entra ID"
        Write-Info "3. Copy and execute this SQL script:"
        Write-Info ""
        Write-Info "--- SQL Script Start ---"
        Write-Host $sqlContent -ForegroundColor Cyan
        Write-Info "--- SQL Script End ---"
        Write-Info ""
        Write-Info "Or run: Get-Content '$PSScriptRoot/complete-database-setup.sql' | Where-Object { `$_ -replace 'your-logic-app-name','$logicAppName' }"
    }
}

# ============================================================================
# Step 9: Upload Policy Document & Generate SAS
# ============================================================================
Write-Header "Uploading Policy Document"

$policyDocPath = "$PSScriptRoot/loan-policy.txt"

if (-not (Test-Path $policyDocPath)) {
    Write-Error "Policy document not found: $policyDocPath"
    exit 1
}

# Get storage context
$storageAccount = Get-AzStorageAccount -ResourceGroupName $resourceGroup -Name $blobStorageAccountName -ErrorAction Stop
$storageContext = $storageAccount.Context

# Upload to blob storage
try {
    Set-AzStorageBlobContent `
        -File $policyDocPath `
        -Container "policies" `
        -Blob "loan-policy.txt" `
        -Context $storageContext `
        -Force `
        -ErrorAction Stop | Out-Null
    
    Write-Status "✓ Policy document uploaded to blob storage"
} catch {
    Write-Error "Policy document upload failed: $($_.Exception.Message)"
    exit 1
}

# Generate SAS URL (expires in 1 year)
$expiryDate = (Get-Date).AddYears(1).ToUniversalTime()
try {
    $policySasToken = New-AzStorageBlobSASToken `
        -Container "policies" `
        -Blob "loan-policy.txt" `
        -Permission r `
        -ExpiryTime $expiryDate `
        -Context $storageContext `
        -ErrorAction Stop
    
    $policySasUrl = "https://$blobStorageAccountName.blob.core.windows.net/policies/loan-policy.txt$policySasToken"
    Write-Status "✓ SAS URL generated (expires: $($expiryDate.ToString('yyyy-MM-ddTHH:mm:ssZ')))"
} catch {
    Write-Error "SAS URL generation failed"
    exit 1
}
 
# ============================================================================
# Step 10: Configure APIM Policies
# ============================================================================
Write-Header "Configuring APIM Policies"

& "$PSScriptRoot/create-apim-policies.ps1" `
    -ResourceGroup $resourceGroup `
    -APIMServiceName $apimServiceName `
    -SubscriptionId $subscriptionId

Write-Status "APIM policies configured"

# ============================================================================
# Step 11: Generate local.settings.json
# ============================================================================
Write-Header "Generating local.settings.json"

$localSettings = @{
    IsEncrypted = $false
    Values = @{
        # Azure Functions settings
        "AzureWebJobsStorage" = "UseDevelopmentStorage=true"
        "FUNCTIONS_WORKER_RUNTIME" = "dotnet"
        "FUNCTIONS_INPROC_NET8_ENABLED" = "1"
        "APP_KIND" = "workflowApp"
        
        # Workflow metadata
        "WORKFLOWS_SUBSCRIPTION_ID" = $subscriptionId
        "WORKFLOWS_RESOURCE_GROUP_NAME" = $resourceGroup
        "WORKFLOWS_LOCATION_NAME" = $location
        
        # SQL Database (Managed Identity)
        "sql_connectionString" = "Server=tcp:$sqlServerName.database.windows.net,1433;Initial Catalog=$sqlDatabaseName;Authentication=Active Directory Managed Identity;Encrypt=True;"
        
        # Azure OpenAI
        "agent_openAIEndpoint" = $openAIEndpoint
        "agent_openAIKey" = $openAIKey
        "agent_ResourceID" = $openAIResourceId
        
        # API Management
        "ApiManagementServiceName" = $apimServiceName
        "ApiManagementBaseUrl" = $apimBaseUrl
        "ApiManagementCreditUrl" = "$apimBaseUrl/credit"
        "ApiManagementEmploymentUrl" = "$apimBaseUrl/employment"
        "ApiManagementVerifyUrl" = "$apimBaseUrl/verify"
        "riskAssessmentAPI_SubscriptionKey" = $apimKeys.riskAssessment
        "employmentValidationAPI_SubscriptionKey" = $apimKeys.employment
        "creditCheckAPI_SubscriptionKey" = $apimKeys.creditCheck
        "demographicVerificationAPI_SubscriptionKey" = $apimKeys.demographics
        
        # Policy Document URLs
        "PolicyDocumentURL" = $policySasUrl
        "PolicyDocumentURI" = $policySasUrl
        "LoanPolicyDocumentUrl" = $policySasUrl
        "approvalAgent-policyDocument-URI" = $policySasUrl
        
        # Connection Runtime URLs - commented out for VS Code workflow
        # Uncomment for CI/CD scenarios with pre-created connections
        # "formsConnection-connectionKey" = "@connectionKey('formsConnection')"
        # "formsConnection-ConnectionRuntimeUrl" = $formsRuntimeUrl
        # "teamsConnection-connectionKey" = "@connectionKey('teamsConnection')"
        # "teamsConnection-ConnectionRuntimeUrl" = $teamsRuntimeUrl
        # "outlookConnection-connectionKey" = "@connectionKey('outlookConnection')"
        # "outlookConnection-ConnectionRuntimeUrl" = $outlookRuntimeUrl
        
        # Placeholders for user configuration
        "TeamsGroupId" = "<UPDATE_WITH_YOUR_TEAMS_GROUP_ID>"
        "TeamsChannelId" = "<UPDATE_WITH_YOUR_TEAMS_CHANNEL_ID>"
        "DemoUserEmail" = "<UPDATE_WITH_YOUR_EMAIL>"
        "ProjectDirectoryPath" = "<UPDATE_WITH_LOCAL_PROJECT_PATH>"
        "FormsFormId" = "<UPDATE_WITH_YOUR_FORM_ID>"
        
        # Form field IDs (updated via helper script after first submission)
        "FormFieldId_SSN" = "<UPDATE_AFTER_FORM_SUBMISSION>"
        "FormFieldId_Name" = "<UPDATE_AFTER_FORM_SUBMISSION>"
        "FormFieldId_DateOfBirth" = "<UPDATE_AFTER_FORM_SUBMISSION>"
        "FormFieldId_Employer" = "<UPDATE_AFTER_FORM_SUBMISSION>"
        "FormFieldId_YearsWorked" = "<UPDATE_AFTER_FORM_SUBMISSION>"
        "FormFieldId_Salary" = "<UPDATE_AFTER_FORM_SUBMISSION>"
        "FormFieldId_LoanAmount" = "<UPDATE_AFTER_FORM_SUBMISSION>"
        "FormFieldId_VehicleMake" = "<UPDATE_AFTER_FORM_SUBMISSION>"
    }
}

$localSettingsPath = "$PSScriptRoot/../LogicApps/local.settings.json"
$localSettings | ConvertTo-Json -Depth 10 | Out-File $localSettingsPath -Encoding UTF8

Write-Status "local.settings.json generated at: $localSettingsPath"

# ============================================================================
# Step 12: Deployment Summary
# ============================================================================
Write-Header "Deployment Complete"

Write-Info "Resources deployed:"
Write-Info "  Logic App: $logicAppName"
Write-Info "  SQL Server: $sqlServerName"
Write-Info "  OpenAI: $openAIResourceId"
Write-Info "  APIM: $apimServiceName"
Write-Info ""
Write-Info "Next steps:"
Write-Info "  1. Create Microsoft Form and get Form ID from URL"
Write-Info "  2. Update local.settings.json with FormsFormId, Teams Group/Channel IDs, and DemoUserEmail"
Write-Info "  3. Deploy workflows from VS Code (LogicApps folder) - authorize connections when prompted"
Write-Info "  4. Submit test form to get field IDs"
Write-Info "  5. Run update-form-field-mappings.ps1 to populate FormFieldId_* values"
Write-Info "  6. Validate end-to-end test scenarios"
Write-Info ""
Write-Info "See README.md for detailed post-deployment instructions"