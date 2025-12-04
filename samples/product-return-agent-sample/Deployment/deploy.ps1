#!/usr/bin/env powershell
<#
.SYNOPSIS
    Deploy AI Product Return Agent infrastructure to Azure

.DESCRIPTION
    Deploys all Azure resources for the Product Return Agent sample including:
    - Logic Apps Standard
    - Azure OpenAI with GPT-4o-mini
    - Storage Account
    - Managed Identities
    - RBAC role assignments

.PARAMETER ResourceGroupName
    Name of the Azure resource group (will be created if it doesn't exist)

.PARAMETER Location
    Azure region for deployment (default: eastus2)

.PARAMETER BaseName
    Base name for Azure resources (default: productreturn)

.EXAMPLE
    .\deploy.ps1 -ResourceGroupName "rg-productreturn" -Location "eastus2" -BaseName "productreturn"

.NOTES
    Requirements:
    - Azure CLI installed and authenticated
    - Bicep CLI installed
    - Contributor access to Azure subscription
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory=$false)]
    [string]$Location = "eastus2",

    [Parameter(Mandatory=$false)]
    [string]$BaseName = "productreturn"
)

$ErrorActionPreference = "Stop"

Write-Host "`n=== AI Product Return Agent Deployment ===" -ForegroundColor Cyan

# Check Azure CLI
$azAvailable = $null -ne (Get-Command az -ErrorAction SilentlyContinue)
if (-not $azAvailable) {
    Write-Host "✗ Azure CLI not found. Please install it first." -ForegroundColor Red
    Write-Host "Install: https://learn.microsoft.com/cli/azure/install-azure-cli" -ForegroundColor Yellow
    exit 1
}

# Check login status
Write-Host "`nChecking Azure login status..."
$accountInfo = az account show 2>$null | ConvertFrom-Json
if (-not $accountInfo) {
    Write-Host "✗ Not logged in to Azure. Please run 'az login' first." -ForegroundColor Red
    exit 1
}

Write-Host "✓ Logged in as: $($accountInfo.user.name)" -ForegroundColor Green
Write-Host "✓ Subscription: $($accountInfo.name) ($($accountInfo.id))" -ForegroundColor Green

# Create resource group if it doesn't exist
Write-Host "`nCreating resource group '$ResourceGroupName' in '$Location'..."
az group create --name $ResourceGroupName --location $Location --output none

if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ Resource group ready" -ForegroundColor Green
} else {
    Write-Host "✗ Failed to create resource group" -ForegroundColor Red
    exit 1
}

# Deploy Bicep template
Write-Host "`nDeploying infrastructure..."
$bicepPath = Join-Path $PSScriptRoot "infrastructure\main.bicep"

$deploymentName = "productreturn-$(Get-Date -Format 'yyyyMMddHHmmss')"

az deployment group create `
    --resource-group $ResourceGroupName `
    --template-file $bicepPath `
    --parameters BaseName=$BaseName `
    --name $deploymentName `
    --output json | ConvertFrom-Json | Tee-Object -Variable deployment

if ($LASTEXITCODE -eq 0) {
    Write-Host "`n✓ Deployment completed successfully!" -ForegroundColor Green
    
    # Display outputs
    Write-Host "`n=== Deployment Outputs ===" -ForegroundColor Cyan
    Write-Host "Logic App Name: $($deployment.properties.outputs.logicAppName.value)" -ForegroundColor Yellow
    Write-Host "OpenAI Endpoint: $($deployment.properties.outputs.openAIEndpoint.value)" -ForegroundColor Yellow
    
    Write-Host "`nTo test the agent, navigate to:" -ForegroundColor Cyan
    Write-Host "Azure Portal > Resource Groups > $ResourceGroupName > $($deployment.properties.outputs.logicAppName.value)-logicapp > Workflows > ProductReturnAgent > Run history" -ForegroundColor Gray
    
} else {
    Write-Host "`n✗ Deployment failed. Check the error messages above." -ForegroundColor Red
    Write-Host "View deployment logs: Azure Portal > Resource Groups > $ResourceGroupName > Deployments > $deploymentName" -ForegroundColor Yellow
    exit 1
}

Write-Host "`n=== Deployment Complete ===" -ForegroundColor Cyan
