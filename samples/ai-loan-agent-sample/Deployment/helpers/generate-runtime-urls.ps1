#!/usr/bin/env powershell

<#
.SYNOPSIS
    Generate Logic Apps Standard connection runtime URLs
.DESCRIPTION
    This script generates the correct runtime URLs based on Azure connection IDs
    for Logic Apps Standard connections.
.PARAMETER SubscriptionId
    Azure subscription ID where resources are deployed
.PARAMETER ResourceGroup
    Name of the resource group containing the Logic Apps connections
.EXAMPLE
    .\generate-runtime-urls.ps1 -SubscriptionId "12345678-abcd-efgh-ijkl-123456789012" -ResourceGroup "ai-loan-agent-rg"
.EXAMPLE
    .\generate-runtime-urls.ps1
#>

param(
    [Parameter()]
    [string]$SubscriptionId = "12345678-abcd-efgh-ijkl-123456789012",
    
    [Parameter()]
    [string]$ResourceGroup = "ai-loan-agent-rg"
)

# Extract Connection Runtime URLs for Logic Apps Standard
# This script generates the correct runtime URLs based on Azure connection IDs

Write-Host "🔗 Generating Logic Apps Standard Connection Runtime URLs" -ForegroundColor Cyan
Write-Host "=======================================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "📋 Using Configuration:" -ForegroundColor Yellow
Write-Host "  Subscription ID: $SubscriptionId" -ForegroundColor Cyan
Write-Host "  Resource Group: $ResourceGroup" -ForegroundColor Cyan
Write-Host ""

# For Logic Apps Standard, connection runtime URLs follow this pattern:
# https://management.azure.com/subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/providers/Microsoft.Web/connections/{connectionName}

Write-Host "📝 Generating Runtime URLs..." -ForegroundColor Yellow
Write-Host ""

# Microsoft Forms Connection
$formsRuntimeUrl = "https://management.azure.com/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.Web/connections/formsConnection"
Write-Host "Microsoft Forms:" -ForegroundColor Green
Write-Host "  Connection: formsConnection" -ForegroundColor Cyan
Write-Host "  Runtime URL: $formsRuntimeUrl" -ForegroundColor Yellow
Write-Host ""

# Microsoft Teams Connection
$teamsRuntimeUrl = "https://management.azure.com/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.Web/connections/teamsConnection"
Write-Host "Microsoft Teams:" -ForegroundColor Green
Write-Host "  Connection: teamsConnection" -ForegroundColor Cyan
Write-Host "  Runtime URL: $teamsRuntimeUrl" -ForegroundColor Yellow
Write-Host ""

# Office 365 Connection
$outlookRuntimeUrl = "https://management.azure.com/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.Web/connections/outlookConnection"
Write-Host "Office 365 Outlook:" -ForegroundColor Green
Write-Host "  Connection: outlookConnection" -ForegroundColor Cyan
Write-Host "  Runtime URL: $outlookRuntimeUrl" -ForegroundColor Yellow
Write-Host ""

Write-Host "📋 local.settings.json Updates" -ForegroundColor Green
Write-Host "===============================" -ForegroundColor Green
Write-Host ""
Write-Host "Copy these values to your local.settings.json:" -ForegroundColor Cyan
Write-Host ""

Write-Host "`"formsConnection-ConnectionRuntimeUrl`": `"$formsRuntimeUrl`"," -ForegroundColor Yellow
Write-Host "`"teamsConnection-ConnectionRuntimeUrl`": `"$teamsRuntimeUrl`"," -ForegroundColor Yellow
Write-Host "`"outlookConnection-ConnectionRuntimeUrl`": `"$outlookRuntimeUrl`"," -ForegroundColor Yellow

Write-Host ""
Write-Host "🔑 Connection Keys Information" -ForegroundColor Yellow
Write-Host "==============================" -ForegroundColor Yellow
Write-Host ""
Write-Host "For Logic Apps Standard with managed API connections," -ForegroundColor White
Write-Host "connection keys are handled automatically by the platform." -ForegroundColor White
Write-Host "You can set the connection key values to:" -ForegroundColor White
Write-Host ""
Write-Host "`"formsConnection-connectionKey`": `"@connectionKey('formsConnection')`"," -ForegroundColor Yellow
Write-Host "`"teamsConnection-connectionKey`": `"@connectionKey('teamsConnection')`"," -ForegroundColor Yellow
Write-Host "`"outlookConnection-connectionKey`": `"@connectionKey('outlookConnection')`"," -ForegroundColor Yellow

Write-Host ""
Write-Host "🎯 Critical Workflow Settings" -ForegroundColor Magenta
Write-Host "==============================" -ForegroundColor Magenta
Write-Host ""
Write-Host "Ensure these critical settings are in your configuration:" -ForegroundColor White
Write-Host ""
Write-Host "`"PolicyDocumentURL`": `"<Your-Policy-Document-SAS-URL>`"," -ForegroundColor Yellow
Write-Host "`"PolicyDocumentURI`": `"<Your-Policy-Document-SAS-URL>`"," -ForegroundColor Yellow
Write-Host "`"TeamsGroupId`": `"<Your-Teams-Group-ID>`"," -ForegroundColor Yellow
Write-Host "`"TeamsChannelId`": `"<Your-Teams-Channel-ID>`"," -ForegroundColor Yellow

Write-Host ""
Write-Host "✅ Runtime URLs generated successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "📝 Next Steps:" -ForegroundColor Cyan
Write-Host "1. Update local.settings.json with the runtime URLs above" -ForegroundColor White
Write-Host "2. Update connection keys with the @connectionKey expressions" -ForegroundColor White
Write-Host "3. Test the Logic Apps workflow" -ForegroundColor White