#!/usr/bin/env powershell

<#
.SYNOPSIS
    Instructions for setting up the database via Azure Portal
.DESCRIPTION
    This script provides instructions for running the database-setup.sql script
    via Azure Portal Query Editor when command line access is not available
#>

Write-Host "=== Database Setup Instructions ===" -ForegroundColor Magenta
Write-Host ""
Write-Host "Since sqlcmd authentication is not working, please use Azure Portal:" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. Open Azure Portal in your browser" -ForegroundColor Cyan
Write-Host "2. Navigate to Resource Groups → [YOUR-RESOURCE-GROUP]" -ForegroundColor Cyan
Write-Host "3. Click on '[YOUR-SQL-SERVER]'" -ForegroundColor Cyan
Write-Host "4. Select 'Databases' → '[YOUR-DATABASE]'" -ForegroundColor Cyan
Write-Host "5. Click on 'Query editor (preview)' in the left menu" -ForegroundColor Cyan
Write-Host "6. Authenticate using Microsoft Entra ID (your-user@microsoft.com)" -ForegroundColor Cyan
Write-Host "7. Copy and paste the contents of database-setup.sql" -ForegroundColor Cyan
Write-Host "8. Click 'Run' to execute the script" -ForegroundColor Cyan
Write-Host ""
Write-Host "Alternative method using Azure Data Studio:" -ForegroundColor Yellow
Write-Host "1. Download Azure Data Studio if not installed" -ForegroundColor Cyan
Write-Host "2. Connect to: [YOUR-SQL-SERVER].database.windows.net" -ForegroundColor Cyan
Write-Host "3. Use Microsoft Entra ID authentication" -ForegroundColor Cyan
Write-Host "4. Open database-setup.sql file" -ForegroundColor Cyan
Write-Host "5. Execute the script" -ForegroundColor Cyan
Write-Host ""
Write-Host "The database-setup.sql script contains:" -ForegroundColor Green
Write-Host "- CustomersBankHistory table with SAMPLE-DATA.md aligned customer records" -ForegroundColor White
Write-Host "- SpecialVehicles table with luxury vehicle definitions" -ForegroundColor White
Write-Host "- Sample data for all 6 test scenarios (SSN patterns: 555-12-3456, etc.)" -ForegroundColor White
Write-Host ""
Write-Host "After setup, verify tables exist with:" -ForegroundColor Green
Write-Host "SELECT COUNT(*) FROM CustomersBankHistory; -- Should return 6 records" -ForegroundColor White
Write-Host "SELECT COUNT(*) FROM SpecialVehicles; -- Should return 9+ records" -ForegroundColor White
Write-Host ""

# Read the database setup file content to show what will be executed
if (Test-Path "database-setup.sql") {
    Write-Host "=== Database Setup Script Preview ===" -ForegroundColor Magenta
    Write-Host ""
    $content = Get-Content "database-setup.sql" -Raw
    # Show first 20 lines to give user preview
    $lines = $content -split "`n"
    $preview = $lines[0..19] -join "`n"
    Write-Host $preview -ForegroundColor Gray
    Write-Host ""
    Write-Host "... [$(($lines.Length - 20)) more lines] ..." -ForegroundColor Gray
    Write-Host ""
    Write-Host "Total lines in database-setup.sql: $($lines.Length)" -ForegroundColor Green
} else {
    Write-Host "⚠️  database-setup.sql file not found in current directory" -ForegroundColor Red
}

Write-Host ""
Write-Host "=== Expected Customer Records ===" -ForegroundColor Magenta
Write-Host "1. Sarah Johnson (555-12-3456) - Auto-approve scenario" -ForegroundColor Green
Write-Host "2. Michael Chen (555-98-7654) - High-end vehicle scenario" -ForegroundColor Yellow  
Write-Host "3. Jennifer Martinez (555-11-2233) - High risk scenario" -ForegroundColor Red
Write-Host "4. David Wilson (555-44-5566) - Luxury vehicle scenario" -ForegroundColor Yellow
Write-Host "5. Robert Thompson (555-77-8899) - Senior applicant scenario" -ForegroundColor Green
Write-Host "6. Alex Rodriguez (555-33-4455) - Young professional scenario" -ForegroundColor Green
Write-Host ""
Write-Host "Press any key when database setup is complete..." -ForegroundColor Cyan
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
Write-Host ""
Write-Host "✓ Database setup marked as complete" -ForegroundColor Green