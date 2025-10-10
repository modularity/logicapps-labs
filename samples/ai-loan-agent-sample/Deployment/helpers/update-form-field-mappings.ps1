#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Updates Microsoft Forms field IDs in the LoanApprovalAgent workflow based on actual form response.

.DESCRIPTION
    This script extracts form field IDs from a test workflow run and automatically updates
    all references in the workflow.json file. This solves the problem where each Microsoft Form
    has unique field IDs that must be mapped correctly.

.PARAMETER LogicAppName
    The name of the Logic App resource

.PARAMETER ResourceGroup
    The resource group containing the Logic App

.PARAMETER Interactive
    If specified, prompts for manual field mapping instead of auto-detection

.EXAMPLE
    .\update-form-field-mappings.ps1 -LogicAppName "my-loan-agent" -ResourceGroup "my-rg"

.EXAMPLE
    .\update-form-field-mappings.ps1 -LogicAppName "my-loan-agent" -ResourceGroup "my-rg" -Interactive

.NOTES
    Prerequisites:
    1. Submit at least ONE test form response before running this script
    2. Ensure you're logged into Azure CLI (az login)
    3. The workflow must have run at least once successfully or partially
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$LogicAppName,
    
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroup,
    
    [Parameter(Mandatory=$false)]
    [switch]$Interactive
)

$ErrorActionPreference = "Stop"

Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║   Microsoft Forms Field ID Mapper for Logic Apps Standard     ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Step 1: Verify Azure CLI is logged in
Write-Host "[1/6] Verifying Azure CLI authentication..." -ForegroundColor Yellow
try {
    $account = az account show 2>$null | ConvertFrom-Json
    if (-not $account) {
        Write-Host "❌ Not logged into Azure CLI. Please run 'az login' first." -ForegroundColor Red
        exit 1
    }
    Write-Host "✅ Logged in as: $($account.user.name)" -ForegroundColor Green
    Write-Host "   Subscription: $($account.name)" -ForegroundColor Gray
} catch {
    Write-Host "❌ Azure CLI not found or not logged in." -ForegroundColor Red
    exit 1
}

# Step 2: Get the latest workflow run
Write-Host ""
Write-Host "[2/6] Fetching latest workflow run..." -ForegroundColor Yellow
try {
    $subscriptionId = $account.id
    $uri = "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.Web/sites/$LogicAppName/hostruntime/runtime/webhooks/workflow/api/management/workflows/LoanApprovalAgent/runs?api-version=2018-11-01&`$top=1"
    
    $runsJson = az rest --method GET --uri $uri 2>$null
    $runs = $runsJson | ConvertFrom-Json
    
    if (-not $runs.value -or $runs.value.Count -eq 0) {
        Write-Host "❌ No workflow runs found. Please submit a test form first." -ForegroundColor Red
        Write-Host "   Go to your Microsoft Form and submit a test response, then run this script again." -ForegroundColor Yellow
        exit 1
    }
    
    $latestRun = $runs.value[0]
    $runName = $latestRun.name
    Write-Host "✅ Found run: $runName" -ForegroundColor Green
    Write-Host "   Status: $($latestRun.properties.status)" -ForegroundColor Gray
    Write-Host "   Start Time: $($latestRun.properties.startTime)" -ForegroundColor Gray
} catch {
    Write-Host "❌ Failed to fetch workflow runs: $_" -ForegroundColor Red
    exit 1
}

# Step 3: Get the Get_response_details action output
Write-Host ""
Write-Host "[3/6] Extracting form field IDs from run..." -ForegroundColor Yellow
try {
    $actionUri = "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.Web/sites/$LogicAppName/hostruntime/runtime/webhooks/workflow/api/management/workflows/LoanApprovalAgent/runs/$runName/actions/Get_response_details?api-version=2018-11-01"
    
    $actionJson = az rest --method GET --uri $actionUri 2>$null
    $action = $actionJson | ConvertFrom-Json
    
    if ($action.properties.status -ne "Succeeded") {
        Write-Host "⚠️  Get_response_details action status: $($action.properties.status)" -ForegroundColor Yellow
        Write-Host "   The workflow may have failed. Attempting to extract field IDs anyway..." -ForegroundColor Yellow
    }
    
    # Get the outputs
    $outputsUri = $action.properties.outputsLink.uri
    $outputsJson = Invoke-RestMethod -Uri $outputsUri -Method Get
    
    Write-Host "✅ Retrieved form response data" -ForegroundColor Green
    
    # Extract form body (field data is in body property)
    $formData = $outputsJson.body
    
    if (-not $formData) {
        Write-Host "❌ No form data found in action outputs. The response structure may have changed." -ForegroundColor Red
        exit 1
    }
    
    # Extract all field IDs
    $allFields = $formData | Get-Member -MemberType NoteProperty | Where-Object { $_.Name -like 'r*' }
    
    Write-Host "   Found $($allFields.Count) form fields with IDs:" -ForegroundColor Gray
    foreach ($field in $allFields) {
        $fieldId = $field.Name
        $value = $formData.$fieldId
        Write-Host "     • $fieldId = $value" -ForegroundColor DarkGray
    }
    
} catch {
    Write-Host "❌ Failed to extract form field data: $_" -ForegroundColor Red
    Write-Host "   Make sure the workflow run includes the Get_response_details action." -ForegroundColor Yellow
    exit 1
}

# Step 4: Map fields to expected schema
Write-Host ""
Write-Host "[4/6] Mapping form fields to expected schema..." -ForegroundColor Yellow

$fieldMapping = @{}

if ($Interactive) {
    Write-Host "   📝 Interactive mode: Please enter the field ID for each required field" -ForegroundColor Cyan
    Write-Host ""
    
    foreach ($field in $allFields) {
        $fieldId = $field.Name
        $value = $formData.$fieldId
        Write-Host "   Field ID: $fieldId" -ForegroundColor White
        Write-Host "   Value: $value" -ForegroundColor Gray
        Write-Host ""
    }
    
    Write-Host "   Required field mappings:" -ForegroundColor Yellow
    $fieldMapping['SSN'] = Read-Host "     Enter field ID for SSN (Social Security Number)"
    $fieldMapping['LoanAmount'] = Read-Host "     Enter field ID for Loan Amount"
    $fieldMapping['VehicleMake'] = Read-Host "     Enter field ID for Vehicle Make"
    $fieldMapping['Salary'] = Read-Host "     Enter field ID for Salary"
    $fieldMapping['Name'] = Read-Host "     Enter field ID for Full Name"
    $fieldMapping['DateOfBirth'] = Read-Host "     Enter field ID for Date of Birth"
    $fieldMapping['Employer'] = Read-Host "     Enter field ID for Employer"
    $fieldMapping['YearsWorked'] = Read-Host "     Enter field ID for Years Worked"
    
} else {
    # Auto-detect based on common patterns and values
    Write-Host "   🔍 Auto-detecting field mappings..." -ForegroundColor Cyan
    
    $detectedFields = @()
    
    foreach ($field in $allFields) {
        $fieldId = $field.Name
        $value = $formData.$fieldId
        
        # Try to guess field type based on value patterns
        $fieldType = "Unknown"
        
        if ($value -match '^\d{3}-\d{2}-\d{4}$' -or $value -match '^\d{9}$') {
            $fieldType = "SSN"
        }
        elseif ($value -match '^\d+\.?\d*$' -and [decimal]$value -gt 10000) {
            if ([decimal]$value -gt 100000) {
                $fieldType = "Salary"
            } else {
                $fieldType = "LoanAmount"
            }
        }
        elseif ($value -match '\d{1,2}/\d{1,2}/\d{4}') {
            $fieldType = "DateOfBirth"
        }
        elseif ($value -match '^\d+$' -and [int]$value -lt 100) {
            $fieldType = "YearsWorked"
        }
        elseif ($value -match '^[A-Za-z\s\.]+$' -and $value.Length -lt 100) {
            if ($value -match '(Toyota|Honda|Ford|Chevrolet|BMW|Mercedes|Audi|Tesla|Nissan|Mazda|Volkswagen|Hyundai|Kia|Subaru|Jeep|Ram|GMC|Cadillac|Lexus|Acura|Infiniti|Porsche|Ferrari|Lamborghini|Bentley|Rolls-Royce|Maserati|Jaguar|Land Rover|Volvo|Peugeot|Renault|Fiat|Alfa Romeo|Mini|Smart|Mitsubishi|Suzuki|Isuzu|Dodge|Buick|Lincoln|Chrysler)') {
                $fieldType = "VehicleMake"
            } elseif (-not $fieldMapping.ContainsKey('Name')) {
                $fieldType = "Name"
            } elseif (-not $fieldMapping.ContainsKey('Employer')) {
                $fieldType = "Employer"
            }
        }
        
        $detectedFields += [PSCustomObject]@{
            FieldId = $fieldId
            Value = $value
            DetectedType = $fieldType
        }
        
        if ($fieldType -ne "Unknown" -and -not $fieldMapping.ContainsKey($fieldType)) {
            $fieldMapping[$fieldType] = $fieldId
        }
    }
    
    # Display detected mappings
    Write-Host ""
    Write-Host "   Detected field mappings:" -ForegroundColor Green
    foreach ($key in $fieldMapping.Keys | Sort-Object) {
        $fieldId = $fieldMapping[$key]
        $value = $formData.$fieldId
        Write-Host "     ✓ $key → $fieldId" -ForegroundColor Green
        Write-Host "       Value: $value" -ForegroundColor DarkGray
    }
    
    # Check for missing required fields
    $requiredFields = @('SSN', 'LoanAmount', 'VehicleMake', 'Salary', 'Name', 'DateOfBirth', 'Employer', 'YearsWorked')
    $missingFields = $requiredFields | Where-Object { -not $fieldMapping.ContainsKey($_) }
    
    if ($missingFields.Count -gt 0) {
        Write-Host ""
        Write-Host "   ⚠️  Could not auto-detect the following fields:" -ForegroundColor Yellow
        foreach ($field in $missingFields) {
            Write-Host "      • $field" -ForegroundColor Yellow
        }
        Write-Host ""
        Write-Host "   Available unmatched fields:" -ForegroundColor Cyan
        $unmatchedFields = $detectedFields | Where-Object { $_.DetectedType -eq "Unknown" }
        foreach ($field in $unmatchedFields) {
            Write-Host "      • $($field.FieldId) = $($field.Value)" -ForegroundColor Gray
        }
        Write-Host ""
        $continue = Read-Host "   Would you like to manually map the missing fields? (y/n)"
        if ($continue -eq 'y') {
            foreach ($field in $missingFields) {
                $fieldMapping[$field] = Read-Host "     Enter field ID for $field"
            }
        } else {
            Write-Host "   ⚠️  Proceeding with partial mapping. Some workflow actions may fail." -ForegroundColor Yellow
        }
    }
}

# Step 5: Update local.settings.json
Write-Host ""
Write-Host "[5/6] Updating local.settings.json..." -ForegroundColor Yellow

$settingsPath = Join-Path $PSScriptRoot "..\..\LogicApps\local.settings.json"
Write-Host "   Reading: $settingsPath" -ForegroundColor Gray

if (-not (Test-Path $settingsPath)) {
    Write-Host "❌ local.settings.json not found at: $settingsPath" -ForegroundColor Red
    exit 1
}

$settingsContent = Get-Content $settingsPath -Raw
$settings = $settingsContent | ConvertFrom-Json

# Update the form field ID values in local.settings.json
$updatesApplied = 0

if ($fieldMapping.ContainsKey('SSN')) {
    $settings.Values.FormFieldId_SSN = $fieldMapping['SSN']
    $updatesApplied++
    Write-Host "     Updated FormFieldId_SSN" -ForegroundColor Gray
}

if ($fieldMapping.ContainsKey('Name')) {
    $settings.Values.FormFieldId_Name = $fieldMapping['Name']
    $updatesApplied++
    Write-Host "     Updated FormFieldId_Name" -ForegroundColor Gray
}

if ($fieldMapping.ContainsKey('DateOfBirth')) {
    $settings.Values.FormFieldId_DateOfBirth = $fieldMapping['DateOfBirth']
    $updatesApplied++
    Write-Host "     Updated FormFieldId_DateOfBirth" -ForegroundColor Gray
}

if ($fieldMapping.ContainsKey('Employer')) {
    $settings.Values.FormFieldId_Employer = $fieldMapping['Employer']
    $updatesApplied++
    Write-Host "     Updated FormFieldId_Employer" -ForegroundColor Gray
}

if ($fieldMapping.ContainsKey('YearsWorked')) {
    $settings.Values.FormFieldId_YearsWorked = $fieldMapping['YearsWorked']
    $updatesApplied++
    Write-Host "     Updated FormFieldId_YearsWorked" -ForegroundColor Gray
}

if ($fieldMapping.ContainsKey('Salary')) {
    $settings.Values.FormFieldId_Salary = $fieldMapping['Salary']
    $updatesApplied++
    Write-Host "     Updated FormFieldId_Salary" -ForegroundColor Gray
}

if ($fieldMapping.ContainsKey('LoanAmount')) {
    $settings.Values.FormFieldId_LoanAmount = $fieldMapping['LoanAmount']
    $updatesApplied++
    Write-Host "     Updated FormFieldId_LoanAmount" -ForegroundColor Gray
}

if ($fieldMapping.ContainsKey('VehicleMake')) {
    $settings.Values.FormFieldId_VehicleMake = $fieldMapping['VehicleMake']
    $updatesApplied++
    Write-Host "     Updated FormFieldId_VehicleMake" -ForegroundColor Gray
}

# Save updated settings
$settings | ConvertTo-Json -Depth 10 | Set-Content $settingsPath

Write-Host "✅ Updated $updatesApplied form field parameters in local.settings.json" -ForegroundColor Green

# Step 5b: Push settings to Azure
Write-Host ""
Write-Host "   Pushing form field parameters to Azure..." -ForegroundColor Gray

# Push each form field parameter to Azure app settings
$azureUpdates = 0

foreach ($fieldName in $fieldMapping.Keys) {
    $settingName = "FormFieldId_$fieldName"
    $settingValue = $fieldMapping[$fieldName]
    
    try {
        az functionapp config appsettings set `
            --name $LogicAppName `
            --resource-group $ResourceGroup `
            --settings "$settingName=$settingValue" `
            --output none
        $azureUpdates++
    } catch {
        Write-Host "     ⚠️ Failed to update $settingName in Azure" -ForegroundColor Yellow
    }
}

Write-Host "✅ Pushed $azureUpdates form field parameters to Azure app settings" -ForegroundColor Green

# Step 5c: Restart Logic App to pick up new settings
Write-Host ""
Write-Host "   Restarting Logic App to apply new settings..." -ForegroundColor Gray

try {
    az functionapp restart `
        --name $LogicAppName `
        --resource-group $ResourceGroup `
        --output none
    Write-Host "✅ Logic App restarted successfully" -ForegroundColor Green
    Write-Host "   ⏱️  Waiting 10 seconds for restart to complete..." -ForegroundColor Gray
    Start-Sleep -Seconds 10
} catch {
    Write-Host "     ⚠️ Failed to restart Logic App - you may need to restart manually" -ForegroundColor Yellow
}

# Step 6: Deploy updated workflow
Write-Host ""
Write-Host "[6/6] Next steps..." -ForegroundColor Yellow
Write-Host "   1. Review the updated local.settings.json file" -ForegroundColor White
Write-Host "   2. Redeploy the Logic App to apply the new form field mappings:" -ForegroundColor White
Write-Host "      cd ../../LogicApps" -ForegroundColor Gray
Write-Host "      func azure functionapp publish $LogicAppName" -ForegroundColor Gray
Write-Host "   3. Submit another test form to verify the mapping works" -ForegroundColor White
Write-Host ""

$deploy = Read-Host "Would you like to deploy now? (y/n)"
if ($deploy -eq 'y') {
    Write-Host ""
    Write-Host "Deploying to Azure..." -ForegroundColor Cyan
    Push-Location
    Set-Location (Join-Path $PSScriptRoot "..\..\LogicApps")
    & func azure functionapp publish $LogicAppName
    Pop-Location
    Write-Host ""
    Write-Host "✅ Deployment complete!" -ForegroundColor Green
}

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║                  Form Field Mapping Complete!                 ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
