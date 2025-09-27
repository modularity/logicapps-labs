#!/usr/bin/env powershell

<#
.SYNOPSIS
    Update local.settings.json to fix configuration issues and update email settings
.DESCRIPTION
    This script reads the current local.settings.json and updates the outlook-1-ConnectionRuntimeUrl 
    to point to the policy document URL instead of a connection URL, which is what the workflow expects.
    It also allows updating the DemoUserEmail setting for proper email delivery in demonstrations.
.PARAMETER DemoUserEmail
    Email address to use for demo notifications (optional - will prompt if not provided and current value is placeholder)
.EXAMPLE
    .\update-local-settings.ps1
.EXAMPLE
    .\update-local-settings.ps1 -DemoUserEmail "presenter@company.com"
#>

param(
    [Parameter()]
    [string]$DemoUserEmail
)

# Enable strict mode and stop on errors
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Status($message) {
    Write-Host "✓ $message" -ForegroundColor Green
}

function Write-Info($message) {
    Write-Host "ℹ $message" -ForegroundColor Cyan
}

function Write-Error($message) {
    Write-Host "✗ $message" -ForegroundColor Red
}

Write-Info "Updating local.settings.json to fix outlook-1-ConnectionRuntimeUrl..."

$logicAppsPath = Join-Path $PSScriptRoot "..\LogicApps"
$localSettingsPath = Join-Path $logicAppsPath "local.settings.json"

if (-not (Test-Path $localSettingsPath)) {
    Write-Error "local.settings.json not found at: $localSettingsPath"
    Write-Error "Please run deploy.ps1 first to create the initial configuration."
    exit 1
}

# Read current settings
$localSettings = Get-Content $localSettingsPath | ConvertFrom-Json

# Get the policy document URL from the current settings
$policyUrl = $localSettings.Values.'approvalAgent-policyDocument-URI'

if (-not $policyUrl) {
    Write-Error "Policy document URL not found in local.settings.json"
    Write-Error "Please ensure deploy.ps1 has been run successfully."
    exit 1
}

# Update the outlook-1-ConnectionRuntimeUrl to point to the policy document
$localSettings.Values.'outlook-1-ConnectionRuntimeUrl' = $policyUrl

# Ensure critical app settings are present for workflow execution
if (-not $localSettings.Values.PolicyDocumentURL) {
    $localSettings.Values.PolicyDocumentURL = $policyUrl
    Write-Status "Added PolicyDocumentURL for workflow compatibility"
}

if (-not $localSettings.Values.PolicyDocumentURI) {
    $localSettings.Values.PolicyDocumentURI = $policyUrl
    Write-Status "Added PolicyDocumentURI for consistency"
}

# Ensure Teams settings are present (use placeholder values if not configured)
if (-not $localSettings.Values.TeamsGroupId) {
    $localSettings.Values.TeamsGroupId = "12345678-1234-1234-1234-123456789012"
    Write-Info "Added TeamsGroupId placeholder - update with your actual Teams Group ID"
}

if (-not $localSettings.Values.TeamsChannelId) {
    $localSettings.Values.TeamsChannelId = "19:abcd1234567890abcd1234567890abcd@thread.tacv2"
    Write-Info "Added TeamsChannelId placeholder - update with your actual Teams Channel ID"
}

# Handle demo email configuration for email notifications
if ($DemoUserEmail) {
    # Validate email format
    if ($DemoUserEmail -notmatch "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$") {
        Write-Error "Invalid email format: $DemoUserEmail"
        exit 1
    }
    $localSettings.Values.DemoUserEmail = $DemoUserEmail
    Write-Status "Updated DemoUserEmail to: $DemoUserEmail"
} elseif (-not $localSettings.Values.DemoUserEmail -or $localSettings.Values.DemoUserEmail -eq "REPLACE_WITH_YOUR_EMAIL@example.com") {
    # Current email is placeholder, prompt for real email
    Write-Warning "Current DemoUserEmail is placeholder: $($localSettings.Values.DemoUserEmail)"
    Write-Info "Email notifications will fail with placeholder email address."
    Write-Info "To fix email delivery, run: .\update-local-settings.ps1 -DemoUserEmail 'your-email@company.com'"
    Write-Info "Or update the Azure app setting in the portal manually."
    
    if (-not $localSettings.Values.DemoUserEmail) {
        $localSettings.Values.DemoUserEmail = "REPLACE_WITH_YOUR_EMAIL@example.com"
        Write-Info "Added DemoUserEmail placeholder"
    }
} else {
    Write-Status "DemoUserEmail already configured: $($localSettings.Values.DemoUserEmail)"
}

# Save the updated settings
$jsonContent = $localSettings | ConvertTo-Json -Depth 10
$jsonContent | Out-File -FilePath $localSettingsPath -Encoding UTF8

Write-Status "Updated outlook-1-ConnectionRuntimeUrl to point to policy document"
Write-Status "Added missing PolicyDocumentURL and Teams settings"
Write-Info "Policy URL: $policyUrl"

# If DemoUserEmail was provided and updated, also try to update Azure app setting
if ($DemoUserEmail) {
    Write-Info "Attempting to update Azure app setting for DemoUserEmail..."
    
    # Check if Logic App exists by trying to find it
    $logicApps = az webapp list --query "[?kind=='functionapp,workflowapp'].{name:name, resourceGroup:resourceGroup}" | ConvertFrom-Json 2>$null
    $logicApp = $logicApps | Where-Object { $_.name -like "*loan*agent*" -or $_.name -like "*ai*loan*" }
    
    if ($logicApp) {
        Write-Info "Found Logic App: $($logicApp.name) in resource group: $($logicApp.resourceGroup)"
        try {
            az webapp config appsettings set `
                --name $logicApp.name `
                --resource-group $logicApp.resourceGroup `
                --settings "DemoUserEmail=$DemoUserEmail" `
                --output none
            Write-Status "Successfully updated Azure app setting DemoUserEmail"
        } catch {
            Write-Warning "Failed to update Azure app setting: $($_.Exception.Message)"
            Write-Info "You can manually update it in Azure Portal: Logic Apps → Configuration → Application Settings"
        }
    } else {
        Write-Info "Logic App not found or not deployed yet. Azure app setting will be set during deployment."
    }
}

Write-Status "local.settings.json updated successfully"