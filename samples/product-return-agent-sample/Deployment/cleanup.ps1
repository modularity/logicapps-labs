#!/usr/bin/env powershell
<#
.SYNOPSIS
    Clean up AI Product Return Agent resources from Azure

.DESCRIPTION
    Deletes the resource group and all associated resources for the Product Return Agent sample.
    Use with caution - this action cannot be undone.

.PARAMETER ResourceGroupName
    Name of the Azure resource group to delete

.PARAMETER Force
    Skip confirmation prompt

.EXAMPLE
    .\cleanup.ps1 -ResourceGroupName "rg-productreturn"

.EXAMPLE
    .\cleanup.ps1 -ResourceGroupName "rg-productreturn" -Force

.NOTES
    Requirements:
    - Azure CLI installed and authenticated
    - Appropriate permissions to delete resource groups
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory=$false)]
    [switch]$Force
)

$ErrorActionPreference = "Stop"

Write-Host "`n=== AI Product Return Agent Cleanup ===" -ForegroundColor Cyan

# Check Azure CLI
$azAvailable = $null -ne (Get-Command az -ErrorAction SilentlyContinue)
if (-not $azAvailable) {
    Write-Host "✗ Azure CLI not found. Please install it first." -ForegroundColor Red
    exit 1
}

# Check if resource group exists
Write-Host "`nChecking if resource group '$ResourceGroupName' exists..."
$rgExists = az group exists --name $ResourceGroupName

if ($rgExists -eq "false") {
    Write-Host "✓ Resource group '$ResourceGroupName' does not exist. Nothing to clean up." -ForegroundColor Green
    exit 0
}

# Confirm deletion
if (-not $Force) {
    Write-Host "`nWARNING: This will delete the resource group '$ResourceGroupName' and ALL resources within it." -ForegroundColor Yellow
    Write-Host "This action CANNOT be undone.`n" -ForegroundColor Yellow
    
    $confirmation = Read-Host "Type the resource group name to confirm deletion"
    
    if ($confirmation -ne $ResourceGroupName) {
        Write-Host "`n✗ Confirmation failed. Resource group name did not match. Aborting." -ForegroundColor Red
        exit 1
    }
}

# Delete resource group
Write-Host "`nDeleting resource group '$ResourceGroupName'..."
Write-Host "This may take several minutes..." -ForegroundColor Gray

az group delete --name $ResourceGroupName --yes --no-wait

if ($LASTEXITCODE -eq 0) {
    Write-Host "`n✓ Resource group deletion initiated successfully!" -ForegroundColor Green
    Write-Host "Deletion is running in the background and may take 5-10 minutes to complete." -ForegroundColor Gray
    Write-Host "`nTo check deletion status:" -ForegroundColor Cyan
    Write-Host "  az group show --name $ResourceGroupName" -ForegroundColor Gray
} else {
    Write-Host "`n✗ Failed to delete resource group" -ForegroundColor Red
    exit 1
}

Write-Host "`n=== Cleanup Complete ===" -ForegroundColor Cyan
