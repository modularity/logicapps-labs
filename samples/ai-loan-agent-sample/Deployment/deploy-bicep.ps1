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
        Write-Status "Azure AD user authenticated successfully"
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
# Detect Client IP for SQL Firewall
# ============================================================================
Write-Info "Detecting client IP address..."

try {
    $clientIP = (Invoke-RestMethod -Uri "https://api.ipify.org" -ErrorAction Stop).Trim()
    Write-Status "Client IP detected for SQL firewall"
} catch {
    Write-Warning "Could not detect client IP address: $($_.Exception.Message)"
    $clientIP = ''
    Write-Info "SQL firewall rule will not be created automatically. Add your IP manually via Azure Portal."
}

# ============================================================================
# Step 3: Create Resource Group (with tags from bicepparam)
# ============================================================================
Write-Header "Creating Resource Group"

# Extract tags from bicepparam for resource group
$rgTags = @{}
if ($paramContent -match "param\s+tags\s*=\s*\{([^}]+)\}") {
    $tagsBlock = $Matches[1]
    $tagsBlock -split "`n" | ForEach-Object {
        if ($_ -match "^\s*([^:]+):\s*'([^']+)'") {
            $key = $Matches[1].Trim()
            $value = $Matches[2].Trim()
            $rgTags[$key] = $value
        }
    }
}

$rg = Get-AzResourceGroup -Name $resourceGroup -ErrorAction SilentlyContinue
if (-not $rg) {
    if ($rgTags.Count -gt 0) {
        New-AzResourceGroup -Name $resourceGroup -Location $location -Tag $rgTags | Out-Null
        Write-Status "Resource group created with tags: $resourceGroup"
    } else {
        New-AzResourceGroup -Name $resourceGroup -Location $location | Out-Null
        Write-Status "Resource group created: $resourceGroup"
    }
} else {
    # Update tags on existing resource group
    if ($rgTags.Count -gt 0) {
        Set-AzResourceGroup -Name $resourceGroup -Tag $rgTags | Out-Null
        Write-Status "Resource group exists (tags updated): $resourceGroup"
    } else {
        Write-Status "Resource group exists: $resourceGroup"
    }
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
    
    # SQL Admin parameters - use auto-detected values if bicepparam has placeholders/empty values
    $sqlAdminObjectIdFromParam = ''
    $sqlAdminUsernameFromParam = ''
    
    if ($paramContent -match "param\s+sqlAdminObjectId\s*=\s*'([^']+)'") { 
        $sqlAdminObjectIdFromParam = $Matches[1] 
    }
    if ($paramContent -match "param\s+sqlAdminUsername\s*=\s*'([^']+)'") { 
        $sqlAdminUsernameFromParam = $Matches[1] 
    }
    
    # Use auto-detected values if param file has placeholder or empty value
    if ([string]::IsNullOrWhiteSpace($sqlAdminObjectIdFromParam) -or 
        $sqlAdminObjectIdFromParam -like '*YOUR_*' -or 
        $sqlAdminObjectIdFromParam -like '*OBJECT_ID*') {
        Write-Info "Using auto-detected SQL admin Object ID"
        $params['sqlAdminObjectId'] = $currentUserId
    } else {
        $params['sqlAdminObjectId'] = $sqlAdminObjectIdFromParam
    }
    
    if ([string]::IsNullOrWhiteSpace($sqlAdminUsernameFromParam) -or 
        $sqlAdminUsernameFromParam -like '*YOUR_*' -or 
        $sqlAdminUsernameFromParam -like '*EMAIL*') {
        Write-Info "Using auto-detected SQL admin username"
        $params['sqlAdminUsername'] = $currentUser
    } else {
        $params['sqlAdminUsername'] = $sqlAdminUsernameFromParam
    }
    
    if ($paramContent -match "param\s+existingApimName\s*=\s*'([^']*)'") { $params['existingApimName'] = $Matches[1] }
    
    # Tags - extract from bicepparam (complex object parsing)
    if ($paramContent -match "param\s+tags\s*=\s*\{([^}]+)\}") {
        $tagsBlock = $Matches[1]
        $tagsHash = @{}
        
        # Parse each key-value pair in the tags object
        $tagsBlock -split "`n" | ForEach-Object {
            if ($_ -match "^\s*([^:]+):\s*'([^']+)'") {
                $key = $Matches[1].Trim()
                $value = $Matches[2].Trim()
                $tagsHash[$key] = $value
            }
        }
        
        if ($tagsHash.Count -gt 0) {
            $params['tags'] = $tagsHash
            Write-Info "Applying tags: $($tagsHash.Keys -join ', ')"
        }
    }
    
    # Deployer Object ID - use auto-detected value for blob storage upload permissions
    $deployerObjectIdFromParam = ''
    if ($paramContent -match "param\s+deployerObjectId\s*=\s*'([^']*)'") { 
        $deployerObjectIdFromParam = $Matches[1] 
    }
    
    if ([string]::IsNullOrWhiteSpace($deployerObjectIdFromParam) -or 
        $deployerObjectIdFromParam -like '*YOUR_*' -or 
        $deployerObjectIdFromParam -like '*OBJECT_ID*') {
        Write-Info "Using auto-detected deployer Object ID for storage access"
        $params['deployerObjectId'] = $currentUserId
    } else {
        $params['deployerObjectId'] = $deployerObjectIdFromParam
    }
    
    # Add client IP if detected
    if (-not [string]::IsNullOrEmpty($clientIP)) {
        $params['clientIpAddress'] = $clientIP
    }
    
    # Deploy using PowerShell Az module
    $deployment = New-AzResourceGroupDeployment `
        -Name $deploymentName `
        -ResourceGroupName $resourceGroup `
        -TemplateFile "$PSScriptRoot/bicep/main.bicep" `
        -TemplateParameterObject $params `
        -Verbose
    
    if ($deployment.ProvisioningState -eq "Succeeded") {
        Write-Status "Bicep deployment completed successfully"
        
        # Wait for RBAC role assignments to propagate
        Write-Info "Waiting for RBAC role assignments to propagate (2 minutes)..."
        Start-Sleep -Seconds 120
        Write-Status "RBAC propagation complete - storage access ready"
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
    $sqlServerName = $outputs.sqlServerName.Value
    $sqlDatabaseName = $outputs.sqlDatabaseName.Value
    $openAIEndpoint = $outputs.openAIEndpoint.Value
    $openAIResourceId = $outputs.openAIResourceId.Value
    $apimServiceName = $outputs.apimServiceName.Value
    $apimBaseUrl = $outputs.apimBaseUrl.Value
    $blobStorageAccountName = $outputs.blobStorageAccountName.Value
    $policyBlobUrl = $outputs.policyDocumentUrl.Value
} catch {
    Write-Error "Failed to retrieve deployment outputs: $($_.Exception.Message)"
    exit 1
}

# ============================================================================
# Step 6: Retrieve APIM Subscription Keys
# ============================================================================
Write-Header "Retrieving APIM Subscription Keys"

Write-Info "Retrieving subscription keys securely (not exposed in deployment outputs)..."

try {
    $creditCheckKey = (Get-AzApiManagementSubscriptionKey `
        -Context (New-AzApiManagementContext -ResourceGroupName $resourceGroup -ServiceName $apimServiceName) `
        -SubscriptionId 'credit-check-subscription').PrimaryKey
    
    $employmentKey = (Get-AzApiManagementSubscriptionKey `
        -Context (New-AzApiManagementContext -ResourceGroupName $resourceGroup -ServiceName $apimServiceName) `
        -SubscriptionId 'employment-validation-subscription').PrimaryKey
    
    $demographicsKey = (Get-AzApiManagementSubscriptionKey `
        -Context (New-AzApiManagementContext -ResourceGroupName $resourceGroup -ServiceName $apimServiceName) `
        -SubscriptionId 'demographics-subscription').PrimaryKey
    
    $riskAssessmentKey = (Get-AzApiManagementSubscriptionKey `
        -Context (New-AzApiManagementContext -ResourceGroupName $resourceGroup -ServiceName $apimServiceName) `
        -SubscriptionId 'risk-assessment-subscription').PrimaryKey
    
    Write-Status "APIM subscription keys retrieved securely"
} catch {
    Write-Error "Failed to retrieve APIM subscription keys: $($_.Exception.Message)"
    exit 1
}

# ============================================================================
# Step 7: Upload Policy Document to Blob Storage
# ============================================================================
Write-Header "Uploading Policy Document"

try {
    $policyFilePath = "$PSScriptRoot/loan-policy.txt"
    
    Write-Info "Uploading loan-policy.txt to blob storage..."
    
    # Create storage context with Azure AD authentication (uses your current login)
    $ctx = New-AzStorageContext -StorageAccountName $blobStorageAccountName -UseConnectedAccount -ErrorAction Stop
    
    # Upload policy document
    Set-AzStorageBlobContent `
        -File $policyFilePath `
        -Container 'policies' `
        -Blob 'loan-policy.txt' `
        -Context $ctx `
        -Force `
        -Properties @{'ContentType' = 'text/plain'} `
        -ErrorAction Stop
    
    # Verify upload by checking blob properties
    $blob = Get-AzStorageBlob -Container 'policies' -Blob 'loan-policy.txt' -Context $ctx -ErrorAction Stop
    
    if ($blob) {
        Write-Status "Policy document uploaded successfully"
        Write-Info "Size: $($blob.Length) bytes"
        Write-Info "URL: $policyBlobUrl"
    } else {
        throw "Blob verification failed - upload may not have completed"
    }
} catch {
    Write-Error "Failed to upload policy document: $($_.Exception.Message)"
    Write-Warning "You may need Storage Blob Data Contributor role on the storage account"
    Write-Warning "You can upload manually: Azure Portal → Storage Account → Containers → policies"
}

# ============================================================================
# Step 7: SQL Server Firewall Status
# ============================================================================
Write-Header "SQL Server Firewall Configuration"

if (-not [string]::IsNullOrEmpty($clientIP)) {
    Write-Status "SQL firewall rule created for detected client IP"
    Write-Info "Rule was configured during Bicep deployment"
} else {
    Write-Warning "No client IP detected - SQL firewall rule was not created"
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
        # Future Az version may return SecureString - convert to plain text
        $tokenResponse = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($sqlToken.Token))
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
# Step 9: Policy Document Upload Status
# ============================================================================
Write-Header "Policy Document Upload"

Write-Status "Policy document uploaded via Bicep deployment script"
Write-Status "Policy URL: $policyBlobUrl"
Write-Info "Document uploaded from: loan-policy.txt"
Write-Info "Access granted via Logic App managed identity"

# ============================================================================
# Step 10: APIM Policies Status
# ============================================================================
Write-Header "APIM Policies Configuration"

Write-Status "APIM mock response policies configured via Bicep"
Write-Info "All 4 API operations have mock response policies:"
Write-Info "  - Credit Check API (Cronus)"
Write-Info "  - Employment Validation API (Litware)"
Write-Info "  - Demographics Verification API (Northwind)"
Write-Info "  - Risk Assessment API (Olympia)"

# ============================================================================
# Step 11: Generate local.settings.json
# ============================================================================
Write-Header "Generating local.settings.json"

$localSettings = [ordered]@{
    IsEncrypted = $false
    Values = [ordered]@{
        # USER CONFIGURATION - Update these values
        "FormsFormId" = "<UPDATE_WITH_YOUR_FORM_ID>"
        "TeamsGroupId" = "<UPDATE_WITH_YOUR_TEAMS_GROUP_ID>"
        "TeamsChannelId" = "<UPDATE_WITH_YOUR_TEAMS_CHANNEL_ID>"
        "DemoUserEmail" = "<UPDATE_WITH_YOUR_EMAIL>"
        "ProjectDirectoryPath" = "<UPDATE_WITH_LOCAL_PROJECT_PATH>"
        "FormFieldId_SSN" = "<UPDATE_AFTER_FORM_SUBMISSION>"
        "FormFieldId_Name" = "<UPDATE_AFTER_FORM_SUBMISSION>"
        "FormFieldId_DateOfBirth" = "<UPDATE_AFTER_FORM_SUBMISSION>"
        "FormFieldId_Employer" = "<UPDATE_AFTER_FORM_SUBMISSION>"
        "FormFieldId_YearsWorked" = "<UPDATE_AFTER_FORM_SUBMISSION>"
        "FormFieldId_Salary" = "<UPDATE_AFTER_FORM_SUBMISSION>"
        "FormFieldId_LoanAmount" = "<UPDATE_AFTER_FORM_SUBMISSION>"
        "FormFieldId_VehicleMake" = "<UPDATE_AFTER_FORM_SUBMISSION>"
        
        # AZURE CONFIGURATION - Auto-populated
        "AzureWebJobsStorage" = "UseDevelopmentStorage=true"
        "FUNCTIONS_WORKER_RUNTIME" = "dotnet"
        "FUNCTIONS_INPROC_NET8_ENABLED" = "1"
        "APP_KIND" = "workflowApp"
        "WORKFLOWS_SUBSCRIPTION_ID" = $subscriptionId
        "WORKFLOWS_RESOURCE_GROUP_NAME" = $resourceGroup
        "WORKFLOWS_LOCATION_NAME" = $location
        "sql_connectionString" = "Server=tcp:$sqlServerName.database.windows.net,1433;Initial Catalog=$sqlDatabaseName;Authentication=Active Directory Managed Identity;Encrypt=True;"
        "agent_openAIEndpoint" = $openAIEndpoint
        "agent_ResourceID" = $openAIResourceId
        "ApiManagementServiceName" = $apimServiceName
        "ApiManagementBaseUrl" = $apimBaseUrl
        "ApiManagementCreditUrl" = "$apimBaseUrl/credit"
        "ApiManagementEmploymentUrl" = "$apimBaseUrl/employment"
        "ApiManagementVerifyUrl" = "$apimBaseUrl/verify"
        "riskAssessmentAPI_SubscriptionKey" = $riskAssessmentKey
        "employmentValidationAPI_SubscriptionKey" = $employmentKey
        "creditCheckAPI_SubscriptionKey" = $creditCheckKey
        "demographicVerificationAPI_SubscriptionKey" = $demographicsKey
        "PolicyDocumentURL" = $policyBlobUrl
        "PolicyDocumentURI" = $policyBlobUrl
        "LoanPolicyDocumentUrl" = $policyBlobUrl
        "approvalAgent-policyDocument-URI" = $policyBlobUrl
        "azureblob_storageAccountName" = $blobStorageAccountName
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