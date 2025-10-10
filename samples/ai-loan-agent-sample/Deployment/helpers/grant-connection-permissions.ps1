#Requires -Version 7.0

<#
.SYNOPSIS
    Grants Logic App managed identity permissions to use API connections.

.DESCRIPTION
    This script grants the Logic App's system-assigned managed identity the necessary
    permissions to invoke the API connections (Microsoft Forms, Teams, Outlook).
    
    This is Layer 2 authentication:
    - Layer 1: Connection → API (OAuth token) - Done via "Edit API Connection → Authorize"
    - Layer 2: Logic App → Connection (RBAC) - This script
    
    Without Layer 2, the Logic App cannot use the connections even though they are authorized.

.PARAMETER LogicAppName
    The name of the Logic App.

.PARAMETER ResourceGroup
    The resource group containing the Logic App and connections.

.PARAMETER ConnectionNames
    Array of connection names to grant permissions for.
    Defaults to: formsConnection, teamsConnection, outlookConnection

.EXAMPLE
    .\grant-connection-permissions.ps1 -LogicAppName "ld-test-loan-agent-logicapp-817c" -ResourceGroup "ld-test-ai-loan-agent-rg"

.NOTES
    Requires: 
    - Azure CLI with sufficient permissions to assign roles
    Role needed: Owner or User Access Administrator on the Resource Group
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$LogicAppName,
    
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroup,
    
    [Parameter(Mandatory = $false)]
    [string[]]$ConnectionNames = @("formsConnection", "teamsConnection", "outlookConnection")
)

$ErrorActionPreference = "Stop"

Write-Host "🔐 Granting Logic App Managed Identity Permissions to API Connections" -ForegroundColor Cyan
Write-Host "=" * 70
Write-Host ""

# Step 1: Get Logic App Managed Identity Principal ID
Write-Host "📋 Step 1: Getting Logic App managed identity..." -ForegroundColor Yellow
try {
    $principalId = az logicapp show `
        --name $LogicAppName `
        --resource-group $ResourceGroup `
        --query "identity.principalId" `
        --output tsv
    
    if ([string]::IsNullOrWhiteSpace($principalId) -or $principalId -eq "null") {
        Write-Host "   ❌ Logic App does not have system-assigned managed identity enabled" -ForegroundColor Red
        Write-Host "   💡 Enable it in Azure Portal → Logic App → Identity → System assigned → On" -ForegroundColor Yellow
        exit 1
    }
    
    Write-Host "   ✅ Found Principal ID: $principalId" -ForegroundColor Green
}
catch {
    Write-Host "   ❌ Failed to get Logic App identity: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Step 2: Get Logic App display name for verification
Write-Host ""
Write-Host "📋 Step 2: Verifying Logic App details..." -ForegroundColor Yellow
try {
    $logicAppDetails = az logicapp show `
        --name $LogicAppName `
        --resource-group $ResourceGroup `
        --query "{name:name, state:state, identity:identity.type}" `
        --output json | ConvertFrom-Json
    
    Write-Host "   ✅ Logic App: $($logicAppDetails.name)" -ForegroundColor Green
    Write-Host "   ✅ State: $($logicAppDetails.state)" -ForegroundColor Green
    Write-Host "   ✅ Identity Type: $($logicAppDetails.identity)" -ForegroundColor Green
}
catch {
    Write-Host "   ⚠️  Could not verify Logic App details" -ForegroundColor Yellow
}

# Step 3: Grant permissions on each connection
Write-Host ""
Write-Host "🔐 Step 3: Granting permissions on API connections..." -ForegroundColor Yellow
Write-Host ""

$successCount = 0
$skipCount = 0
$errorCount = 0

foreach ($connectionName in $ConnectionNames) {
    Write-Host "   Processing: $connectionName" -ForegroundColor Cyan
    
    try {
        # Get connection resource ID
        $connectionId = az resource show `
            --resource-group $ResourceGroup `
            --resource-type "Microsoft.Web/connections" `
            --name $connectionName `
            --query "id" `
            --output tsv
        
        if ([string]::IsNullOrWhiteSpace($connectionId)) {
            Write-Host "      ⚠️  Connection not found: $connectionName" -ForegroundColor Yellow
            $errorCount++
            continue
        }
        
        Write-Host "      📍 Connection ID: $connectionId" -ForegroundColor Gray
        
        # Check if role assignment already exists
        $existingAssignment = az role assignment list `
            --assignee $principalId `
            --scope $connectionId `
            --role "Contributor" `
            --query "[0].id" `
            --output tsv 2>$null
        
        if (-not [string]::IsNullOrWhiteSpace($existingAssignment)) {
            Write-Host "      ℹ️  Permission already exists (skipping)" -ForegroundColor Cyan
            $skipCount++
            continue
        }
        
        # Grant Contributor role to Logic App managed identity on connection
        Write-Host "      🔄 Granting Contributor role..." -ForegroundColor Gray
        az role assignment create `
            --assignee $principalId `
            --role "Contributor" `
            --scope $connectionId `
            --output none
        
        Write-Host "      ✅ Permission granted successfully" -ForegroundColor Green
        $successCount++
    }
    catch {
        Write-Host "      ❌ Failed to grant permission: $($_.Exception.Message)" -ForegroundColor Red
        $errorCount++
    }
    
    Write-Host ""
}

# Step 4: Summary
Write-Host ""
Write-Host "📊 Summary" -ForegroundColor Cyan
Write-Host "=" * 30
Write-Host "✅ Permissions granted: $successCount" -ForegroundColor Green
Write-Host "ℹ️  Already existing: $skipCount" -ForegroundColor Cyan
Write-Host "❌ Errors: $errorCount" -ForegroundColor Red
Write-Host ""

if ($successCount -gt 0) {
    Write-Host "🎉 Connection permissions setup completed!" -ForegroundColor Green
    Write-Host ""
    Write-Host "📋 Next Steps:" -ForegroundColor Yellow
    Write-Host "   1. Wait 1-2 minutes for permissions to propagate" -ForegroundColor White
    Write-Host "   2. If using Teams, manually add Logic App to team (see README)" -ForegroundColor White
    Write-Host "   3. Save/redeploy your Logic App workflow" -ForegroundColor White
    Write-Host "   4. Webhook subscription should now succeed" -ForegroundColor White
    Write-Host ""
} elseif ($skipCount -gt 0 -and $errorCount -eq 0) {
    Write-Host "✅ All connection permissions already configured - no action needed" -ForegroundColor Green
    Write-Host ""
    Write-Host "📋 Next Steps:" -ForegroundColor Yellow
    Write-Host "   1. If using Teams, manually add Logic App to team (see README)" -ForegroundColor White
    Write-Host "   2. Save/redeploy your Logic App workflow" -ForegroundColor White
    Write-Host ""
} else {
    Write-Host "⚠️  Some errors occurred - review output above" -ForegroundColor Yellow
    Write-Host ""
}

# Step 5: Verification
Write-Host ""
Write-Host "🔍 Verification" -ForegroundColor Cyan
Write-Host "=" * 30
Write-Host "You can verify permissions in Azure Portal:" -ForegroundColor White
Write-Host "1. Navigate to Resource Group → Connection (e.g., formsConnection)" -ForegroundColor White
Write-Host "2. Click 'Access control (IAM)' → 'Role assignments'" -ForegroundColor White
Write-Host "3. Look for: $LogicAppName with Contributor role" -ForegroundColor White
Write-Host ""
Write-Host "Or use CLI:" -ForegroundColor White
Write-Host "az role assignment list --assignee $principalId --scope <connection-id>" -ForegroundColor Gray
Write-Host ""
Write-Host "For Teams integration, see README.md for manual membership steps." -ForegroundColor White
Write-Host "Logic App Principal ID: $principalId" -ForegroundColor Gray
Write-Host ""
