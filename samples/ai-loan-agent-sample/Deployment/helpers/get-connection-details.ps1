#!/usr/bin/env powershell

<#
.SYNOPSIS
    Extract Microsoft 365 connection details for AI Loan Agent Logic Apps
.DESCRIPTION
    This script extracts connection details and runtime URLs for Microsoft 365 
    connections used by the AI Loan Agent Logic Apps workflows.
.PARAMETER SubscriptionId
    Azure subscription ID where resources are deployed
.PARAMETER ResourceGroup
    Name of the resource group containing the Logic Apps connections
.EXAMPLE
    .\get-connection-details.ps1 -SubscriptionId "12345678-abcd-efgh-ijkl-123456789012" -ResourceGroup "ai-loan-agent-rg"
.EXAMPLE
    .\get-connection-details.ps1
#>

param(
    [Parameter()]
    [string]$SubscriptionId = "12345678-abcd-efgh-ijkl-123456789012",
    
    [Parameter()]
    [string]$ResourceGroup = "ai-loan-agent-rg"
)

# Azure CLI Script to Extract Microsoft 365 Connection Details
# for AI Loan Agent Logic Apps

Write-Host "🔑 Extracting Microsoft 365 Connection Details" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "📋 Using Configuration:" -ForegroundColor Yellow
Write-Host "  Subscription ID: $SubscriptionId" -ForegroundColor Cyan
Write-Host "  Resource Group: $ResourceGroup" -ForegroundColor Cyan
Write-Host ""

# Login and set subscription
Write-Host "🔐 Logging into Azure..." -ForegroundColor Yellow
az login --only-show-errors

Write-Host "📋 Setting subscription..." -ForegroundColor Yellow
az account set --subscription $SubscriptionId

Write-Host ""
Write-Host "🔍 Looking for Microsoft 365 connections..." -ForegroundColor Yellow

# Get all connections in the resource group
$connections = az resource list --resource-group $ResourceGroup --resource-type "Microsoft.Web/connections" --query "[].{name:name, type:type}" --output json | ConvertFrom-Json

Write-Host "Found $($connections.Count) connection(s):" -ForegroundColor Green
foreach ($conn in $connections) {
    Write-Host "  - $($conn.name)" -ForegroundColor Cyan
}

Write-Host ""

# Function to get connection details
function Get-ConnectionDetails {
    param($connectionName)
    
    Write-Host "📡 Getting details for connection: $connectionName" -ForegroundColor Yellow
    
    try {
        $connectionDetails = az resource show --resource-group $ResourceGroup --name $connectionName --resource-type "Microsoft.Web/connections" --query "properties" --output json | ConvertFrom-Json
        
        if ($connectionDetails) {
            $runtimeUrl = $connectionDetails.connectionRuntimeUrl
            $displayName = $connectionDetails.displayName
            
            Write-Host "  ✅ Connection Name: $displayName" -ForegroundColor Green
            Write-Host "  🔗 Runtime URL: $runtimeUrl" -ForegroundColor Cyan
            
            # Try to get authentication details
            if ($connectionDetails.parameterValues) {
                Write-Host "  🔑 Authentication: Parameter-based" -ForegroundColor Cyan
            } elseif ($connectionDetails.authenticatedUser) {
                Write-Host "  🔑 Authenticated User: $($connectionDetails.authenticatedUser.name)" -ForegroundColor Cyan
            }
            
            return @{
                Name = $connectionName
                RuntimeUrl = $runtimeUrl
                DisplayName = $displayName
            }
        }
    } catch {
        Write-Host "  ❌ Failed to get details for $connectionName" -ForegroundColor Red
    }
    
    return $null
}

# Extract Microsoft Forms connection details
Write-Host "📝 Microsoft Forms Connection" -ForegroundColor Green
Write-Host "==============================" -ForegroundColor Green
$formsConnection = Get-ConnectionDetails "formsConnection"

Write-Host ""

# Extract Teams connection details
Write-Host "👥 Microsoft Teams Connection" -ForegroundColor Green
Write-Host "==============================" -ForegroundColor Green
$teamsConnection = Get-ConnectionDetails "teamsConnection"

Write-Host ""

# Extract Outlook connection details
Write-Host "📧 Microsoft Outlook Connection" -ForegroundColor Green
Write-Host "================================" -ForegroundColor Green
$outlookConnection = Get-ConnectionDetails "outlookConnection"

Write-Host ""

# Generate local.settings.json updates
Write-Host "📋 local.settings.json Updates" -ForegroundColor Green
Write-Host "===============================" -ForegroundColor Green
Write-Host ""

if ($formsConnection) {
    Write-Host "Microsoft Forms:" -ForegroundColor Cyan
    Write-Host "`"formsConnection-ConnectionRuntimeUrl`": `"$($formsConnection.RuntimeUrl)`"," -ForegroundColor Yellow
    Write-Host "`"formsConnection-connectionKey`": `"@connectionKey('formsConnection')`"," -ForegroundColor Yellow
} else {
    Write-Host "❌ Microsoft Forms connection not found. Please create it in VS Code first." -ForegroundColor Red
}

Write-Host ""

if ($teamsConnection) {
    Write-Host "Microsoft Teams:" -ForegroundColor Cyan
    Write-Host "`"teamsConnection-ConnectionRuntimeUrl`": `"$($teamsConnection.RuntimeUrl)`"," -ForegroundColor Yellow
    Write-Host "`"teamsConnection-connectionKey`": `"@connectionKey('teamsConnection')`"," -ForegroundColor Yellow
} else {
    Write-Host "❌ Microsoft Teams connection not found. Please create it in VS Code first." -ForegroundColor Red
}

Write-Host ""

if ($outlookConnection) {
    Write-Host "Microsoft Outlook:" -ForegroundColor Cyan
    Write-Host "`"outlookConnection-ConnectionRuntimeUrl`": `"$($outlookConnection.RuntimeUrl)`"," -ForegroundColor Yellow
    Write-Host "`"outlookConnection-connectionKey`": `"@connectionKey('outlookConnection')`"," -ForegroundColor Yellow
} else {
    Write-Host "❌ Microsoft Outlook connection not found. Please create it in VS Code first." -ForegroundColor Red
}

Write-Host ""

# Check if connections exist
$formsExists = $connections | Where-Object { $_.name -eq "formsConnection" }
$teamsExists = $connections | Where-Object { $_.name -eq "teamsConnection" }
$outlookExists = $connections | Where-Object { $_.name -eq "outlookConnection" }

if (-not $formsExists -and -not $teamsExists -and -not $outlookExists) {
    Write-Host "⚠️  No Microsoft 365 connections found!" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Next Steps:" -ForegroundColor Cyan
    Write-Host "1. Open VS Code with the LogicApps folder" -ForegroundColor White
    Write-Host "2. Open LoanApprovalAgent workflow in designer" -ForegroundColor White
    Write-Host "3. Create Microsoft Forms and Teams connections" -ForegroundColor White
    Write-Host "4. Run this script again to get connection details" -ForegroundColor White
} else {
    Write-Host "✅ Connection extraction complete!" -ForegroundColor Green
    Write-Host ""
    Write-Host "📝 Next Steps:" -ForegroundColor Cyan
    Write-Host "1. Copy the runtime URLs above to local.settings.json" -ForegroundColor White
    Write-Host "2. Get connection keys from Logic Apps Designer or Azure Portal" -ForegroundColor White
    Write-Host "3. Update local.settings.json with all connection details" -ForegroundColor White
}

Write-Host ""