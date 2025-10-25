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

# Check Azure CLI authentication
$subscriptionId = az account show --query id --output tsv 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Error "Not logged into Azure. Run: az login"
    exit 1
}
Write-Status "Azure CLI authenticated: $subscriptionId"

# Get current user for SQL admin
$currentUser = az account show --query user.name --output tsv
$currentUserId = az ad signed-in-user show --query id --output tsv
Write-Status "Current user: $currentUser ($currentUserId)"

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

$rgExists = az group exists --name $resourceGroup --output tsv
if ($rgExists -eq "false") {
    az group create --name $resourceGroup --location $location --output none
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
    
    Write-Status "Infrastructure deployed successfully"
    
    # Extract outputs to variables (in memory only)
    $logicAppName = $outputs.logicAppName.Value
    $logicAppPrincipalId = $outputs.logicAppPrincipalId.Value
    $sqlServerName = $outputs.sqlServerName.Value
    $sqlDatabaseName = $outputs.sqlDatabaseName.Value
    $openAIEndpoint = $outputs.openAIEndpoint.Value
    $openAIKey = $outputs.openAIKey.Value
    $openAIResourceId = $outputs.openAIResourceId.Value
    $apimServiceName = $outputs.apimServiceName.Value
    $apimBaseUrl = $outputs.apimBaseUrl.Value
    $apimKeys = $outputs.apimSubscriptionKeys.Value
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
    
    az sql server firewall-rule create `
        --resource-group $resourceGroup `
        --server $sqlServerName `
        --name "ClientIP-$currentIP" `
        --start-ip-address $currentIP `
        --end-ip-address $currentIP `
        --output none 2>$null
    
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

# Try automated execution with Azure CLI access token (no MFA prompt)
Write-Info "Attempting automated SQL setup using Azure CLI authentication..."

try {
    # Get access token for Azure SQL Database (uses existing az login session)
    $tokenResponse = az account get-access-token --resource https://database.windows.net --query accessToken -o tsv 2>&1
    
    if ($LASTEXITCODE -eq 0 -and $tokenResponse) {
        Write-Info "✓ Retrieved Azure SQL access token from Azure CLI session"
        
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
                      -ErrorAction Stop
        
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

# Upload to blob storage
az storage blob upload `
    --account-name $blobStorageAccountName `
    --container-name policies `
    --name loan-policy.txt `
    --file $policyDocPath `
    --auth-mode login `
    --overwrite `
    --output none

Write-Status "Policy document uploaded to blob storage"

# Generate SAS URL (expires in 1 year)
$expiryDate = (Get-Date).AddYears(1).ToString("yyyy-MM-ddTHH:mm:ssZ")
$policySasUrl = az storage blob generate-sas `
    --account-name $blobStorageAccountName `
    --container-name policies `
    --name loan-policy.txt `
    --permissions r `
    --expiry $expiryDate `
    --full-uri `
    --auth-mode key `
    --output tsv

Write-Status "SAS URL generated (expires: $expiryDate)"

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
        
        # Policy Document
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
Write-Info "  1. Deploy workflows using VS Code (connection authorization handled automatically)"
Write-Info "  2. Create Microsoft Form and update FormsFormId in local.settings.json"
Write-Info "  3. Configure Teams Group/Channel IDs in local.settings.json"
Write-Info "  4. Run update-form-field-mappings.ps1 after first form submission"
Write-Info ""
Write-Info "See README.md for detailed post-deployment instructions"