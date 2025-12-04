#!/usr/bin/env powershell
<#
.SYNOPSIS
    Test the AI Product Return Agent with sample scenarios

.DESCRIPTION
    Sends test requests to the ProductReturnAgent workflow and displays results.
    Run this after deploying the sample to verify it's working correctly.

.PARAMETER LogicAppName
    Name of the deployed Logic App (without -logicapp suffix)

.PARAMETER ResourceGroupName
    Name of the resource group containing the Logic App

.EXAMPLE
    .\test-agent.ps1 -LogicAppName "productreturnxyz123" -ResourceGroupName "rg-productreturn"

.NOTES
    Requirements:
    - Azure CLI installed and authenticated
    - Logic App deployed and workflows registered
    - Access to invoke the workflow
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$LogicAppName,

    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName
)

$ErrorActionPreference = "Stop"

Write-Host "`n=== Testing AI Product Return Agent ===" -ForegroundColor Cyan

# Get workflow callback URL
Write-Host "`nRetrieving workflow callback URL..."
$callbackUrl = az rest `
    --method post `
    --uri "https://management.azure.com/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$ResourceGroupName/providers/Microsoft.Web/sites/$LogicAppName-logicapp/hostruntime/runtime/webhooks/workflow/api/management/workflows/ProductReturnAgent/triggers/When_a_HTTP_request_is_received/listCallbackUrl?api-version=2022-05-01" `
    --query value -o tsv

if (-not $callbackUrl) {
    Write-Host "✗ Failed to retrieve callback URL. Ensure the Logic App is deployed and workflows are registered." -ForegroundColor Red
    exit 1
}

Write-Host "✓ Callback URL retrieved" -ForegroundColor Green

# Test scenarios
$scenarios = @(
    @{
        Name = "Scenario 1: Defective item - Auto-approval"
        Payload = @{
            orderId = "ORD001"
            customerId = "CUST001"
            reason = "defective"
            description = "Coffee maker stopped working after 10 days"
        }
        Expected = "APPROVED with full $150 refund"
    },
    @{
        Name = "Scenario 2: Opened perishable - Auto-rejection"
        Payload = @{
            orderId = "ORD002"
            customerId = "CUST002"
            reason = "changed_mind"
            description = "Don't like the flavor"
        }
        Expected = "REJECTED - perishable items cannot be returned once opened"
    },
    @{
        Name = "Scenario 3: VIP edge case - Escalation"
        Payload = @{
            orderId = "ORD003"
            customerId = "CUST003"
            reason = "changed_mind"
            description = "Decided to get a different model"
        }
        Expected = "ESCALATE - VIP customer with expensive item"
    },
    @{
        Name = "Scenario 4: Opened electronics - Approved with fee"
        Payload = @{
            orderId = "ORD001"
            customerId = "CUST001"
            reason = "changed_mind"
            description = "Found a better price elsewhere"
        }
        Expected = "APPROVED with $120 refund (20% restocking fee)"
    }
)

foreach ($scenario in $scenarios) {
    Write-Host "`n=== $($scenario.Name) ===" -ForegroundColor Yellow
    Write-Host "Expected: $($scenario.Expected)" -ForegroundColor Gray
    
    $body = $scenario.Payload | ConvertTo-Json -Compress
    Write-Host "Sending request..." -ForegroundColor Gray
    
    try {
        $response = Invoke-RestMethod -Uri $callbackUrl -Method Post -Body $body -ContentType "application/json"
        
        Write-Host "✓ Request completed successfully" -ForegroundColor Green
        Write-Host "`nResponse:" -ForegroundColor Cyan
        $response | ConvertTo-Json -Depth 10 | Write-Host
        
    } catch {
        Write-Host "✗ Request failed: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Write-Host "`nWaiting 3 seconds before next test..." -ForegroundColor Gray
    Start-Sleep -Seconds 3
}

Write-Host "`n=== All Tests Complete ===" -ForegroundColor Cyan
Write-Host "`nView detailed run history in Azure Portal:" -ForegroundColor Cyan
Write-Host "Resource Groups > $ResourceGroupName > $LogicAppName-logicapp > Workflows > ProductReturnAgent > Run history" -ForegroundColor Gray
