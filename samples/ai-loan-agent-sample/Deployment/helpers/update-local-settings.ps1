#!/usr/bin/env powershell

<#
.SYNOPSIS
    Update local.settings.json to fix configuration issues and setup SQL connection for managed identity
.DESCRIPTION
    This script reads the current local.settings.json and updates the SQL connection string to use 
    managed identity authentication, fixes the outlook-1-ConnectionRuntimeUrl to point to the policy 
    document URL, and allows updating email settings for proper demo functionality.
.PARAMETER DemoUserEmail
    Email address to use for demo notifications (optional - will prompt if not provided and current value is placeholder)
.PARAMETER SqlServerName
    SQL Server name (optional - will auto-detect from Azure resources if not provided)
.PARAMETER SqlDatabaseName
    SQL Database name (optional - will auto-detect from Azure resources if not provided)
.EXAMPLE
    .\update-local-settings.ps1
.EXAMPLE
    .\update-local-settings.ps1 -DemoUserEmail "presenter@company.com"
.EXAMPLE
    .\update-local-settings.ps1 -SqlServerName "my-sql-server" -SqlDatabaseName "my-database"
#>

param(
    [Parameter()]
    [string]$DemoUserEmail,
    
    [Parameter()]
    [string]$SqlServerName,
    
    [Parameter()]
    [string]$SqlDatabaseName
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

Write-Info "Updating local.settings.json to fix configuration issues and setup SQL connection..."

$logicAppsPath = Join-Path $PSScriptRoot "..\..\LogicApps"
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
if ($localSettings.Values | Get-Member -Name 'outlook-1-ConnectionRuntimeUrl' -MemberType NoteProperty) {
    $localSettings.Values.'outlook-1-ConnectionRuntimeUrl' = $policyUrl
} else {
    $localSettings.Values | Add-Member -MemberType NoteProperty -Name 'outlook-1-ConnectionRuntimeUrl' -Value $policyUrl
}
Write-Status "Updated outlook-1-ConnectionRuntimeUrl to policy document"

# Configure SQL connection string for managed identity authentication
Write-Info "Configuring SQL connection string for managed identity..."

# Auto-detect SQL server and database if not provided
if (-not $SqlServerName -or -not $SqlDatabaseName) {
    Write-Info "Auto-detecting SQL resources from Azure..."
    
    # Try to find SQL resources by common naming patterns
    try {
        $sqlServers = az sql server list --query "[?contains(name, 'loan') || contains(name, 'ai')].{name:name, resourceGroup:resourceGroup}" | ConvertFrom-Json 2>$null
        if ($sqlServers -and $sqlServers.Count -gt 0) {
            $sqlServer = $sqlServers[0]
            if (-not $SqlServerName) {
                $SqlServerName = $sqlServer.name
                Write-Info "Auto-detected SQL Server: $SqlServerName"
            }
            
            # Get databases for this server
            $databases = az sql db list --server $sqlServer.name --resource-group $sqlServer.resourceGroup --query "[?name != 'master'].name" --output tsv 2>$null
            if ($databases -and -not $SqlDatabaseName) {
                $SqlDatabaseName = $databases.Split("`n")[0].Trim()
                Write-Info "Auto-detected SQL Database: $SqlDatabaseName"
            }
        }
    } catch {
        Write-Warning "Could not auto-detect SQL resources: $($_.Exception.Message)"
    }
}

# Use default values if still not found
if (-not $SqlServerName) {
    $SqlServerName = "ai-loan-agent-sqlserver"
    Write-Info "Using default SQL Server name: $SqlServerName"
}

if (-not $SqlDatabaseName) {
    $SqlDatabaseName = "ai-loan-agent-db"
    Write-Info "Using default SQL Database name: $SqlDatabaseName"
}

# Create the managed identity connection string
$sqlConnectionString = "Server=tcp:$SqlServerName.database.windows.net,1433;Initial Catalog=$SqlDatabaseName;Authentication=Active Directory Managed Identity;Encrypt=True;"

# Update or add the SQL connection string
if ($localSettings.Values | Get-Member -Name 'sql_connectionString' -MemberType NoteProperty) {
    $localSettings.Values.'sql_connectionString' = $sqlConnectionString
} else {
    $localSettings.Values | Add-Member -MemberType NoteProperty -Name 'sql_connectionString' -Value $sqlConnectionString
}
Write-Status "Updated SQL connection string for managed identity authentication"
Write-Info "SQL Server: $SqlServerName"
Write-Info "SQL Database: $SqlDatabaseName"

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
Write-Status "Configured SQL connection string for managed identity authentication"
Write-Status "Added missing PolicyDocumentURL and Teams settings"
Write-Info "Policy URL: $policyUrl"
Write-Info "SQL Connection: $SqlServerName.database.windows.net → $SqlDatabaseName (Managed Identity)"

# If DemoUserEmail was provided and updated, also try to update Azure app setting
if ($DemoUserEmail -or $sqlConnectionString) {
    Write-Info "Attempting to update Azure app settings..."
    
    # Check if Logic App exists by trying to find it
    $logicApps = az webapp list --query "[?kind=='functionapp,workflowapp'].{name:name, resourceGroup:resourceGroup}" | ConvertFrom-Json 2>$null
    $logicApp = $logicApps | Where-Object { $_.name -like "*loan*agent*" -or $_.name -like "*ai*loan*" }
    
    if ($logicApp) {
        Write-Info "Found Logic App: $($logicApp.name) in resource group: $($logicApp.resourceGroup)"
        
        # Update SQL connection string in Azure
        if ($sqlConnectionString) {
            try {
                az webapp config appsettings set `
                    --name $logicApp.name `
                    --resource-group $logicApp.resourceGroup `
                    --settings "sql_connectionString=$sqlConnectionString" `
                    --output none
                Write-Status "Successfully updated Azure app setting sql_connectionString"
            } catch {
                Write-Warning "Failed to update Azure SQL app setting: $($_.Exception.Message)"
                Write-Info "You can manually update it in Azure Portal: Logic Apps → Configuration → Application Settings"
            }
        }
        
        # Update demo email if provided
        if ($DemoUserEmail) {
            try {
                az webapp config appsettings set `
                    --name $logicApp.name `
                    --resource-group $logicApp.resourceGroup `
                    --settings "DemoUserEmail=$DemoUserEmail" `
                    --output none
                Write-Status "Successfully updated Azure app setting DemoUserEmail"
            } catch {
                Write-Warning "Failed to update Azure email app setting: $($_.Exception.Message)"
                Write-Info "You can manually update it in Azure Portal: Logic Apps → Configuration → Application Settings"
            }
        }
    } else {
        Write-Info "Logic App not found or not deployed yet. Azure app settings will be set during deployment."
    }
}

Write-Status "local.settings.json updated successfully"

Write-Info ""
Write-Info "🔧 Important: SQL connection uses managed identity authentication."
Write-Info "   Make sure the Logic App's managed identity has been granted database access."
Write-Info "   Run this SQL script in Azure Portal Query Editor if not already done:"
Write-Info "   📄 ../create-managed-identity-user.sql"
Write-Info ""
Write-Info "📖 Next steps:"
Write-Info "   1. Deploy workflows using VS Code Azure Logic Apps extension"
Write-Info "   2. Test the SpecialVehicles workflow to verify SQL connection"
Write-Info "   3. Test the complete LoanApprovalAgent flow end-to-end"