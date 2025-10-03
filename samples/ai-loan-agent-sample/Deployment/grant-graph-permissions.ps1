#Requires -Modules Microsoft.Graph.Authentication, Microsoft.Graph.Applications

<#
.SYNOPSIS
    Grants Microsoft Graph API permissions to AI Loan Agent Logic Apps managed identity.

.DESCRIPTION
    This script automates the process of granting required Microsoft Graph permissions
    to the Logic Apps managed identity for Microsoft Forms, Teams, and Outlook integration.
    
    Required permissions:
    - Group.ReadWrite.All, Channel.ReadBasic.All (Microsoft Teams)
    - Mail.Send, Mail.ReadWrite (Microsoft Outlook)
    - User.Read.All (Core Authentication)
    
    Note: You must have Global Administrator or Privileged Role Administrator 
    permissions in Microsoft Entra ID to run this script.

.PARAMETER ManagedIdentityPrincipalId
    The Principal ID of the Logic Apps managed identity. 
    You can find this in Azure Portal → Logic App → Identity → System assigned → Object (principal) ID
    If not provided, the script will attempt to find it automatically using LogicAppName and ResourceGroup.

.PARAMETER LogicAppName
    The name of the Logic App. Used to automatically extract the Principal ID if ManagedIdentityPrincipalId is not provided.

.PARAMETER ResourceGroup
    The resource group containing the Logic App. Used with LogicAppName to automatically extract the Principal ID.

.PARAMETER TenantId
    The Microsoft Entra ID tenant ID. If not provided, uses current tenant.

.PARAMETER DryRun
    If specified, shows what permissions would be granted without actually granting them.

.EXAMPLE
    .\grant-graph-permissions.ps1 -ManagedIdentityPrincipalId "12345678-1234-1234-1234-123456789012"
    
.EXAMPLE
    .\grant-graph-permissions.ps1 -ManagedIdentityPrincipalId "12345678-1234-1234-1234-123456789012" -DryRun

.NOTES
    Author: AI Loan Agent Deployment Script
    Requires: Global Administrator or Privileged Role Administrator permissions in Microsoft Entra ID
    Dependencies: Microsoft.Graph PowerShell modules
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ManagedIdentityPrincipalId,
    
    [Parameter(Mandatory = $false)]
    [string]$LogicAppName,
    
    [Parameter(Mandatory = $false)]
    [string]$ResourceGroup,
    
    [Parameter(Mandatory = $false)]
    [string]$TenantId,
    
    [Parameter(Mandatory = $false)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory = $false)]
    [switch]$DryRun
)

# Set error action preference
$ErrorActionPreference = "Stop"

# Required Graph permissions for AI Loan Agent
# Note: Forms permissions (Forms.Read.All, Forms.ReadWrite.All) are often not available in enterprise tenants
# Microsoft Forms connector uses connection-level OAuth authentication instead of Graph permissions
$RequiredPermissions = @(
    @{
        Permission = "Group.ReadWrite.All"
        Description = "Read and write all groups (Microsoft Teams integration)"
        Service = "Microsoft Teams"
    },
    @{
        Permission = "Channel.ReadBasic.All"
        Description = "Read basic channel properties (Microsoft Teams integration)"
        Service = "Microsoft Teams"
    },
    @{
        Permission = "Mail.Send"
        Description = "Send mail as any user (Microsoft Outlook integration)"
        Service = "Microsoft Outlook"
    },
    @{
        Permission = "Mail.ReadWrite"
        Description = "Read and write mail (Microsoft Outlook integration)"
        Service = "Microsoft Outlook"
    },
    @{
        Permission = "User.Read.All"
        Description = "Read all users' basic profiles (Core Authentication)"
        Service = "Core Authentication"
    }
)

# Microsoft Graph App ID (constant)
$GraphAppId = "00000003-0000-0000-c000-000000000000"

Write-Host "🚀 AI Loan Agent - Microsoft Graph Permissions Setup" -ForegroundColor Cyan
Write-Host "=" * 60

# Function to extract Logic App managed identity Principal ID
function Get-LogicAppPrincipalId {
    param(
        [string]$LogicAppName,
        [string]$ResourceGroup
    )
    
    Write-Host "🔍 Extracting Logic App managed identity Principal ID..." -ForegroundColor Yellow
    Write-Host "   Logic App: $LogicAppName"
    Write-Host "   Resource Group: $ResourceGroup"
    
    try {
        # Get the Logic App and extract its system-assigned managed identity Principal ID
        $principalId = az logicapp show --name $LogicAppName --resource-group $ResourceGroup --query identity.principalId --output tsv
        
        if ([string]::IsNullOrWhiteSpace($principalId) -or $principalId -eq "null") {
            Write-Host "   ❌ Logic App not found or managed identity not enabled" -ForegroundColor Red
            Write-Host "   💡 Ensure the Logic App exists and has system-assigned managed identity enabled" -ForegroundColor Yellow
            return $null
        }
        
        Write-Host "   ✅ Found Principal ID: $principalId" -ForegroundColor Green
        return $principalId.Trim()
    }
    catch {
        Write-Host "   ❌ Failed to extract Principal ID: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

# Function to check if required modules are installed
function Test-RequiredModules {
    Write-Host "📦 Checking required PowerShell modules..." -ForegroundColor Yellow
    
    $requiredModules = @(
        "Microsoft.Graph.Authentication",
        "Microsoft.Graph.Applications"
    )
    
    $missingModules = @()
    
    foreach ($module in $requiredModules) {
        if (-not (Get-Module -ListAvailable -Name $module)) {
            $missingModules += $module
        } else {
            Write-Host "   ✅ $module" -ForegroundColor Green
        }
    }
    
    if ($missingModules.Count -gt 0) {
        Write-Host "❌ Missing required modules:" -ForegroundColor Red
        $missingModules | ForEach-Object { Write-Host "   - $_" -ForegroundColor Red }
        Write-Host ""
        Write-Host "Install missing modules with:" -ForegroundColor Yellow
        Write-Host "Install-Module -Name Microsoft.Graph -Scope CurrentUser -Force" -ForegroundColor White
        return $false
    }
    
    return $true
}

# Function to set correct Azure context
function Set-AzureContext {
    param([string]$SubscriptionId)
    
    Write-Host "🔄 Setting Azure context..." -ForegroundColor Yellow
    Write-Host "   Target subscription: $SubscriptionId"
    
    try {
        # Check if we're connected to Azure
        $currentContext = Get-AzContext -ErrorAction SilentlyContinue
        if (-not $currentContext) {
            Write-Host "   🔐 Connecting to Azure..." -ForegroundColor Yellow
            Connect-AzAccount -Subscription $SubscriptionId | Out-Null
        } else {
            # Switch to correct subscription if needed
            if ($currentContext.Subscription.Id -ne $SubscriptionId) {
                Write-Host "   🔄 Switching to correct subscription..." -ForegroundColor Yellow
                Set-AzContext -SubscriptionId $SubscriptionId | Out-Null
            }
        }
        
        $newContext = Get-AzContext
        Write-Host "   ✅ Connected to: $($newContext.Subscription.Name)" -ForegroundColor Green
        Write-Host "   🏢 Tenant: $($newContext.Tenant.Id)" -ForegroundColor Green
        
        return $newContext.Tenant.Id
    }
    catch {
        Write-Host "   ❌ Failed to set Azure context: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

# Function to connect to Microsoft Graph
function Connect-ToGraph {
    Write-Host "🔐 Connecting to Microsoft Graph..." -ForegroundColor Yellow
    
    $scopes = @(
        "Application.ReadWrite.All",
        "AppRoleAssignment.ReadWrite.All"
    )
    
    try {
        if ($TenantId) {
            Connect-MgGraph -Scopes $scopes -TenantId $TenantId -NoWelcome
        } else {
            Connect-MgGraph -Scopes $scopes -NoWelcome
        }
        
        $context = Get-MgContext
        Write-Host "   ✅ Connected to tenant: $($context.TenantId)" -ForegroundColor Green
        Write-Host "   👤 Signed in as: $($context.Account)" -ForegroundColor Green
        
        return $true
    }
    catch {
        Write-Host "   ❌ Failed to connect: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Function to get managed identity
function Get-LogicAppManagedIdentity {
    param([string]$PrincipalId)
    
    Write-Host "🔍 Looking up Logic Apps managed identity..." -ForegroundColor Yellow
    Write-Host "   Principal ID: $PrincipalId"
    
    try {
        $managedIdentity = Get-MgServicePrincipal -ServicePrincipalId $PrincipalId -ErrorAction Stop
        Write-Host "   ✅ Found: $($managedIdentity.DisplayName)" -ForegroundColor Green
        Write-Host "   📱 App ID: $($managedIdentity.AppId)" -ForegroundColor Gray
        
        return $managedIdentity
    }
    catch {
        Write-Host "   ❌ Managed identity not found: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "   💡 Verify the Principal ID is correct (Azure Portal → Logic App → Identity → System assigned)" -ForegroundColor Yellow
        return $null
    }
}

# Function to get Microsoft Graph service principal
function Get-GraphServicePrincipal {
    Write-Host "🔍 Looking up Microsoft Graph service principal..." -ForegroundColor Yellow
    
    try {
        $graphSP = Get-MgServicePrincipal -Filter "AppId eq '$GraphAppId'" -ErrorAction Stop
        Write-Host "   ✅ Found: $($graphSP.DisplayName)" -ForegroundColor Green
        
        return $graphSP
    }
    catch {
        Write-Host "   ❌ Microsoft Graph service principal not found: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

# Function to check existing permissions
function Get-ExistingPermissions {
    param(
        [object]$ManagedIdentity,
        [object]$GraphServicePrincipal
    )
    
    Write-Host "📋 Checking existing permissions..." -ForegroundColor Yellow
    
    try {
        $assignments = Get-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $ManagedIdentity.Id
        $graphAssignments = $assignments | Where-Object { $_.ResourceId -eq $GraphServicePrincipal.Id }
        
        $existingPermissions = @()
        foreach ($assignment in $graphAssignments) {
            $appRole = $GraphServicePrincipal.AppRoles | Where-Object { $_.Id -eq $assignment.AppRoleId }
            if ($appRole) {
                $existingPermissions += $appRole.Value
                Write-Host "   ✅ Already granted: $($appRole.Value)" -ForegroundColor Green
            }
        }
        
        return $existingPermissions
    }
    catch {
        Write-Host "   ⚠️  Could not check existing permissions: $($_.Exception.Message)" -ForegroundColor Yellow
        return @()
    }
}

# Function to grant permissions
function Grant-GraphPermissions {
    param(
        [object]$ManagedIdentity,
        [object]$GraphServicePrincipal,
        [array]$ExistingPermissions
    )
    
    Write-Host "🔐 Granting Microsoft Graph permissions..." -ForegroundColor Yellow
    
    $grantedCount = 0
    $skippedCount = 0
    $errorCount = 0
    
    foreach ($permissionInfo in $RequiredPermissions) {
        $permission = $permissionInfo.Permission
        $description = $permissionInfo.Description
        $service = $permissionInfo.Service
        
        Write-Host "   Processing: $permission ($service)" -ForegroundColor Gray
        
        # Check if permission already exists
        if ($ExistingPermissions -contains $permission) {
            Write-Host "     ℹ️  Already granted: $permission" -ForegroundColor Cyan
            $skippedCount++
            continue
        }
        
        # Find the app role
        $appRole = $GraphServicePrincipal.AppRoles | Where-Object { $_.Value -eq $permission }
        if (-not $appRole) {
            Write-Host "     ❌ Permission not found: $permission" -ForegroundColor Red
            $errorCount++
            continue
        }
        
        if ($DryRun) {
            Write-Host "     🏃 [DRY RUN] Would grant: $permission" -ForegroundColor Yellow
            $grantedCount++
            continue
        }
        
        try {
            # Grant the permission
            New-MgServicePrincipalAppRoleAssignment `
                -ServicePrincipalId $ManagedIdentity.Id `
                -PrincipalId $ManagedIdentity.Id `
                -ResourceId $GraphServicePrincipal.Id `
                -AppRoleId $appRole.Id | Out-Null
            
            Write-Host "     ✅ Granted: $permission" -ForegroundColor Green
            $grantedCount++
        }
        catch {
            Write-Host "     ❌ Failed to grant: $permission - $($_.Exception.Message)" -ForegroundColor Red
            $errorCount++
        }
    }
    
    return @{
        Granted = $grantedCount
        Skipped = $skippedCount
        Errors = $errorCount
    }
}

# Function to display summary
function Show-Summary {
    param([hashtable]$Results)
    
    Write-Host ""
    Write-Host "📊 Summary" -ForegroundColor Cyan
    Write-Host "=" * 30
    Write-Host "✅ Permissions granted: $($Results.Granted)" -ForegroundColor Green
    Write-Host "ℹ️  Already existing: $($Results.Skipped)" -ForegroundColor Cyan
    Write-Host "❌ Errors: $($Results.Errors)" -ForegroundColor Red
    Write-Host ""
    
    if ($DryRun) {
        Write-Host "🏃 This was a DRY RUN - no actual changes were made" -ForegroundColor Yellow
        Write-Host "   Run without -DryRun to apply changes" -ForegroundColor Yellow
    } elseif ($Results.Granted -gt 0 -or $Results.Errors -eq 0) {
        Write-Host "🎉 Microsoft Graph permissions setup completed!" -ForegroundColor Green
        Write-Host ""
        Write-Host "📋 Next Steps:" -ForegroundColor Yellow
        Write-Host "   1. Wait 5-10 minutes for permissions to propagate"
        Write-Host "   2. Navigate to Azure Portal → Resource Groups → [your-resource-group]"
        Write-Host "   3. Authorize API connections: formsConnection, teamsConnection, outlookConnection"
        Write-Host "   4. Test connections in Logic Apps Designer"
        Write-Host ""
        Write-Host "🔗 Connection Authorization Guide:"
        Write-Host "   Portal → Resource Group → Connection → Edit API Connection → Authorize"
    }
}

# Main execution
try {
    # Validate required parameters
    if (-not $ManagedIdentityPrincipalId -and (-not $LogicAppName -or -not $ResourceGroup)) {
        Write-Host "❌ Missing required parameters" -ForegroundColor Red
        Write-Host "   Either provide:" -ForegroundColor Yellow
        Write-Host "   - ManagedIdentityPrincipalId (find in Azure Portal → Logic App → Identity → System assigned → Object ID)" -ForegroundColor Yellow
        Write-Host "   - OR LogicAppName and ResourceGroup (script will extract Principal ID automatically)" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "   Examples:" -ForegroundColor Cyan
        Write-Host "   .\grant-graph-permissions.ps1 -ManagedIdentityPrincipalId '12345678-1234-1234-1234-123456789012'" -ForegroundColor White
        Write-Host "   .\grant-graph-permissions.ps1 -LogicAppName 'my-logicapp' -ResourceGroup 'my-rg'" -ForegroundColor White
        exit 1
    }
    
    # Extract Principal ID if not provided
    if (-not $ManagedIdentityPrincipalId) {
        $ManagedIdentityPrincipalId = Get-LogicAppPrincipalId -LogicAppName $LogicAppName -ResourceGroup $ResourceGroup
        if (-not $ManagedIdentityPrincipalId) {
            exit 1
        }
    }
    
    # Check required modules
    if (-not (Test-RequiredModules)) {
        exit 1
    }
    
    # Set correct Azure context and get tenant ID (if subscription specified)
    if ($SubscriptionId) {
        $detectedTenantId = Set-AzureContext -SubscriptionId $SubscriptionId
        if (-not $detectedTenantId) {
            exit 1
        }
        
        # Use detected tenant ID if not specified
        if (-not $TenantId) {
            $TenantId = $detectedTenantId
            Write-Host "   ℹ️  Using detected tenant ID: $TenantId" -ForegroundColor Cyan
        }
    }
    
    # Connect to Microsoft Graph
    if (-not (Connect-ToGraph)) {
        exit 1
    }
    
    # Get managed identity
    $managedIdentity = Get-LogicAppManagedIdentity -PrincipalId $ManagedIdentityPrincipalId
    if (-not $managedIdentity) {
        exit 1
    }
    
    # Get Microsoft Graph service principal
    $graphServicePrincipal = Get-GraphServicePrincipal
    if (-not $graphServicePrincipal) {
        exit 1
    }
    
    # Check existing permissions
    $existingPermissions = Get-ExistingPermissions -ManagedIdentity $managedIdentity -GraphServicePrincipal $graphServicePrincipal
    
    # Grant permissions
    $results = Grant-GraphPermissions -ManagedIdentity $managedIdentity -GraphServicePrincipal $graphServicePrincipal -ExistingPermissions $existingPermissions
    
    # Show summary
    Show-Summary -Results $results
    
}
catch {
    Write-Host ""
    Write-Host "💥 Script execution failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "   Line: $($_.InvocationInfo.ScriptLineNumber)" -ForegroundColor Gray
    exit 1
}
finally {
    # Disconnect from Microsoft Graph
    try {
        Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
    }
    catch {
        # Ignore disconnect errors
    }
}