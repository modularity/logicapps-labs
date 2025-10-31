#!/usr/bin/env powershell

<#
.SYNOPSIS
    Deploy AI Loan Agent using Bicep
.DESCRIPTION
    Deploys Azure infrastructure for the AI Loan Agent sample.
.PARAMETER ProjectName
    Project name (3-15 characters, alphanumeric and hyphens only)
.PARAMETER Location
    Azure region for deployment (default: eastus2)
.PARAMETER Tags
    Optional tags as hashtable (e.g., @{Environment='Dev'; Owner='YourName'})
.EXAMPLE
    .\deploy.ps1 -ProjectName "my-loan-agent"
.EXAMPLE
    .\deploy.ps1 -ProjectName "my-loan-agent" -Location "eastus" -Tags @{Environment='Dev'}
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [ValidateLength(3,15)]
    [ValidatePattern('^[a-zA-Z0-9-]+$')]
    [string]$ProjectName,

    [Parameter(Mandatory=$false)]
    [ValidateSet('australiaeast', 'brazilsouth', 'canadacentral', 'canadaeast', 'eastus', 'eastus2', 
                 'francecentral', 'germanywestcentral', 'japaneast', 'koreacentral', 'northcentralus', 
                 'norwayeast', 'southafricanorth', 'southcentralus', 'southeastasia', 'swedencentral', 
                 'switzerlandnorth', 'uksouth', 'westeurope', 'westus', 'westus3')]
    [string]$Location = 'eastus2',

    [Parameter(Mandatory=$false)]
    [hashtable]$Tags = @{}
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Color helpers
function Write-Status($msg) { Write-Host "✓ $msg" -ForegroundColor Green }
function Write-Info($msg) { Write-Host "ℹ $msg" -ForegroundColor Cyan }
function Write-Warning($msg) { Write-Host "⚠ $msg" -ForegroundColor Yellow }
function Write-Header($msg) { Write-Host "`n=== $msg ===" -ForegroundColor Magenta }

Write-Header "AI Loan Agent - Bicep Deployment"

# ============================================================================
# Validate Prerequisites
# ============================================================================
Write-Header "Validating Prerequisites"

# Check Azure PowerShell
try {
    $context = Get-AzContext -ErrorAction Stop
    if (-not $context) {
        Write-Error "Not logged into Azure. Run: Connect-AzAccount"
        exit 1
    }
    Write-Status "Azure PowerShell authenticated"
} catch {
    Write-Error "Azure PowerShell not found or not authenticated"
    Write-Info "Install: Install-Module -Name Az -AllowClobber -Scope CurrentUser"
    Write-Info "Login: Connect-AzAccount"
    exit 1
}

$subscriptionId = $context.Subscription.Id
$resourceGroup = "rg-$ProjectName"

Write-Info "Project: $ProjectName"
Write-Info "Resource Group: $resourceGroup"
Write-Info "Location: $Location"

# ============================================================================
# Create Resource Group
# ============================================================================
Write-Header "Creating Resource Group"

$rg = Get-AzResourceGroup -Name $resourceGroup -ErrorAction SilentlyContinue
if (-not $rg) {
    if ($Tags.Count -gt 0) {
        New-AzResourceGroup -Name $resourceGroup -Location $Location -Tag $Tags | Out-Null
        Write-Status "Resource group created with tags"
    } else {
        New-AzResourceGroup -Name $resourceGroup -Location $Location | Out-Null
        Write-Status "Resource group created"
    }
} else {
    Write-Status "Resource group already exists"
}

# ============================================================================
# Deploy Bicep Infrastructure
# ============================================================================
Write-Header "Deploying Bicep Infrastructure"

Write-Info "This will take 5-10 minutes..."

$deploymentName = "ai-loan-agent-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
$bicepFile = "$PSScriptRoot/../infrastructure/main.bicep"

if (-not (Test-Path $bicepFile)) {
    Write-Error "Bicep file not found: $bicepFile"
    exit 1
}

try {
    # Deploy using Azure PowerShell (automatically compiles Bicep)
    $deployment = New-AzResourceGroupDeployment `
        -Name $deploymentName `
        -ResourceGroupName $resourceGroup `
        -TemplateFile $bicepFile `
        -projectName $ProjectName `
        -location $Location `
        -tags $Tags
    
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
# Retrieve Deployment Outputs
# ============================================================================
Write-Info "Retrieving deployment outputs..."

try {
    $outputs = $deployment.Outputs
    
    Write-Status "Deployment outputs retrieved successfully"
    
    # Extract all outputs to variables
    $logicAppName = $outputs['logicAppName'].Value
    $openAIEndpoint = $outputs['openAIEndpoint'].Value
    $openAIResourceId = $outputs['openAIResourceId'].Value
    
    # Handle optional blobStorageAccountName output
    if ($outputs.ContainsKey('blobStorageAccountName')) {
        $blobStorageAccountName = $outputs['blobStorageAccountName'].Value
    } else {
        Write-Warning "blobStorageAccountName output not found in deployment. You may need to update main.bicep."
        $blobStorageAccountName = "<UPDATE_REQUIRED>"
    }
} catch {
    Write-Error "Failed to retrieve deployment outputs: $($_.Exception.Message)"
    exit 1
}

# ============================================================================
# Generate local.settings.json
# ============================================================================
Write-Header "Generating local.settings.json"

$localSettings = [ordered]@{
    IsEncrypted = $false
    Values = [ordered]@{
        # USER CONFIGURATION - Update these values
        "ProjectDirectoryPath" = "<UPDATE_WITH_LOCAL_PROJECT_PATH>"
        
        # AZURE CONFIGURATION - Auto-populated
        "AzureWebJobsStorage" = "UseDevelopmentStorage=true"
        "FUNCTIONS_WORKER_RUNTIME" = "dotnet"
        "FUNCTIONS_INPROC_NET8_ENABLED" = "1"
        "APP_KIND" = "workflowApp"
        "WORKFLOWS_SUBSCRIPTION_ID" = $subscriptionId
        "WORKFLOWS_RESOURCE_GROUP_NAME" = $resourceGroup
        "WORKFLOWS_LOCATION_NAME" = $location
        "agent_openAIEndpoint" = $openAIEndpoint
        "agent_ResourceID" = $openAIResourceId
        "azureblob_storageAccountName" = $blobStorageAccountName
    }
}

$localSettingsPath = "$PSScriptRoot/../../LogicApps/local.settings.json"
$localSettings | ConvertTo-Json -Depth 10 | Out-File $localSettingsPath -Encoding UTF8

Write-Status "local.settings.json generated at: $localSettingsPath"

# ============================================================================
# Deployment Summary
# ============================================================================
Write-Header "Deployment Complete"

Write-Info "Resources deployed:"
Write-Info "  Logic App: $logicAppName"
Write-Info "  OpenAI Account: $($openAIResourceId.Split('/')[-1])"
Write-Info "  Blob Storage: $blobStorageAccountName"
Write-Info ""
Write-Info "Next steps:"
Write-Info "  1. Review local.settings.json and update ProjectDirectoryPath"
Write-Info "  2. Authorize OAuth connections in Azure Portal (Outlook)"
Write-Info "  3. Deploy workflows from VS Code (LogicApps folder)"
Write-Info "  4. Test your Logic App workflows"