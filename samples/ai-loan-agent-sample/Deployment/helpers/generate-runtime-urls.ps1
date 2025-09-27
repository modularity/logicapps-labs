# Extract Connection Runtime URLs for Logic Apps Standard
# This script generates the correct runtime URLs based on Azure connection IDs

Write-Host "🔗 Generating Logic Apps Standard Connection Runtime URLs" -ForegroundColor Cyan
Write-Host "=======================================================" -ForegroundColor Cyan
Write-Host ""

# Variables - UPDATE THESE VALUES FOR YOUR DEPLOYMENT
$subscriptionId = "12345678-abcd-efgh-ijkl-123456789012"  # Replace with your subscription ID
$resourceGroup = "my-loan-agent-rg"                    # Replace with your resource group name
$location = "eastus2"

# For Logic Apps Standard, connection runtime URLs follow this pattern:
# https://management.azure.com/subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/providers/Microsoft.Web/connections/{connectionName}

Write-Host "📝 Generating Runtime URLs..." -ForegroundColor Yellow
Write-Host ""

# Microsoft Forms Connection
$formsRuntimeUrl = "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.Web/connections/microsoftforms-2"
Write-Host "Microsoft Forms:" -ForegroundColor Green
Write-Host "  Connection: microsoftforms-2" -ForegroundColor Cyan
Write-Host "  Runtime URL: $formsRuntimeUrl" -ForegroundColor Yellow
Write-Host ""

# Microsoft Teams Connection
$teamsRuntimeUrl = "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.Web/connections/teams-1"
Write-Host "Microsoft Teams:" -ForegroundColor Green
Write-Host "  Connection: teams-1" -ForegroundColor Cyan
Write-Host "  Runtime URL: $teamsRuntimeUrl" -ForegroundColor Yellow
Write-Host ""

# Office 365 Connection
$outlookRuntimeUrl = "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.Web/connections/office365"
Write-Host "Office 365 Outlook:" -ForegroundColor Green
Write-Host "  Connection: office365" -ForegroundColor Cyan
Write-Host "  Runtime URL: $outlookRuntimeUrl" -ForegroundColor Yellow
Write-Host ""

Write-Host "📋 local.settings.json Updates" -ForegroundColor Green
Write-Host "===============================" -ForegroundColor Green
Write-Host ""
Write-Host "Copy these values to your local.settings.json:" -ForegroundColor Cyan
Write-Host ""

Write-Host "`"microsoftforms-2-ConnectionRuntimeUrl`": `"$formsRuntimeUrl`"," -ForegroundColor Yellow
Write-Host "`"teams-1-ConnectionRuntimeUrl`": `"$teamsRuntimeUrl`"," -ForegroundColor Yellow
Write-Host "`"office365-ConnectionRuntimeUrl`": `"$outlookRuntimeUrl`"," -ForegroundColor Yellow

Write-Host ""
Write-Host "🔑 Connection Keys Information" -ForegroundColor Yellow
Write-Host "==============================" -ForegroundColor Yellow
Write-Host ""
Write-Host "For Logic Apps Standard with managed API connections," -ForegroundColor White
Write-Host "connection keys are handled automatically by the platform." -ForegroundColor White
Write-Host "You can set the connection key values to:" -ForegroundColor White
Write-Host ""
Write-Host "`"microsoftforms-2-connectionKey`": `"@connectionKey('microsoftforms-2')`"," -ForegroundColor Yellow
Write-Host "`"teams-1-connectionKey`": `"@connectionKey('teams-1')`"," -ForegroundColor Yellow
Write-Host "`"office365-connectionKey`": `"@connectionKey('office365')`"," -ForegroundColor Yellow

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