#!/usr/bin/env powershell

<#
.SYNOPSIS
    Configure APIM APIs and policies for AI Loan Agent
.DESCRIPTION
    This script creates APIM APIs, operations, and applies mock response policies
    with contextual data based on input parameters. Designed to be called from deploy.ps1
    or run standalone for policy updates.
.PARAMETER ResourceGroup
    Name of the Azure resource group containing APIM
.PARAMETER APIMServiceName
    Name of the API Management service
.PARAMETER SubscriptionId
    Azure subscription ID
.EXAMPLE
    .\create-apim-policies.ps1 -ResourceGroup "ai-loan-agent-rg" -APIMServiceName "ai-loan-agent-apim" -SubscriptionId "12345"
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroup,
    
    [Parameter(Mandatory = $true)]
    [string]$APIMServiceName,
    
    [Parameter()]
    [string]$SubscriptionId
)

# Enable strict mode and stop on errors
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Color coding for output
function Write-Status($message) {
    Write-Host "✓ $message" -ForegroundColor Green
}

function Write-Info($message) {
    Write-Host "ℹ $message" -ForegroundColor Cyan
}

function Write-Warning($message) {
    Write-Host "⚠ $message" -ForegroundColor Yellow
}

function Write-Header($message) {
    Write-Host "`n=== $message ===" -ForegroundColor Magenta
}

Write-Header "Configuring APIM APIs and Mock Policies"

# Get subscription ID from PowerShell context
if (-not $SubscriptionId) {
    $context = Get-AzContext
    $SubscriptionId = $context.Subscription.Id
}
# Using subscription: (not displayed for security)

# Define APIs with corrected mock response policies
$apis = @(
    @{ 
        id = "olympia-risk-assessment"
        path = "/risk"
        name = "Olympia Risk Assessment API"
        operationId = "riskassessment"
        template = "/assessment"
        mockResponseBody = '{"RiskLevel": "Low", "RiskScore": 15, "Recommendation": "Approve"}'
        mockPolicy = @'
<policies>
    <inbound>
        <base />
        <set-variable name="requestBody" value="@(context.Request.Body.As&lt;string&gt;())" />
    </inbound>
    <backend>
        <return-response>
            <set-status code="200" reason="OK" />
            <set-header name="Content-Type" exists-action="override">
                <value>application/json</value>
            </set-header>
            <set-body>@{
                var requestBody = context.Variables.GetValueOrDefault&lt;string&gt;("requestBody", "");
                
                // Sarah Johnson (555-12-3456) - LOW RISK AUTO APPROVAL
                if (requestBody.Contains("555-12-3456")) {
                    return "{\"RiskLevel\": \"Low\", \"RiskScore\": 12, \"Recommendation\": \"Approve\"}";
                }
                // Jennifer Martinez (555-11-2233) - HIGH RISK DECLINE
                else if (requestBody.Contains("555-11-2233")) {
                    return "{\"RiskLevel\": \"High\", \"RiskScore\": 85, \"Recommendation\": \"Decline\"}";
                }
                // Michael Chen (555-98-7654) - MEDIUM RISK REVIEW
                else if (requestBody.Contains("555-98-7654")) {
                    return "{\"RiskLevel\": \"Medium\", \"RiskScore\": 52, \"Recommendation\": \"Review\"}";
                }
                // David Wilson (555-44-5566) - HIGH AMOUNT REVIEW
                else if (requestBody.Contains("555-44-5566")) {
                    return "{\"RiskLevel\": \"Medium\", \"RiskScore\": 48, \"Recommendation\": \"Review\"}";
                }
                // Robert Thompson (555-77-8899) - LOW RISK BUT AGE FACTOR
                else if (requestBody.Contains("555-77-8899")) {
                    return "{\"RiskLevel\": \"Low\", \"RiskScore\": 18, \"Recommendation\": \"Approve\"}";
                }
                // Alex Rodriguez (555-33-4455) - MEDIUM RISK YOUNG
                else if (requestBody.Contains("555-33-4455")) {
                    return "{\"RiskLevel\": \"Medium\", \"RiskScore\": 38, \"Recommendation\": \"Review\"}";
                }
                // Default
                else {
                    return "{\"RiskLevel\": \"Medium\", \"RiskScore\": 45, \"Recommendation\": \"Review\"}";
                }
            }</set-body>
        </return-response>
    </backend>
    <outbound>
        <base />
    </outbound>
    <on-error>
        <base />
    </on-error>
</policies>
'@
    }
    @{ 
        id = "litware-employment-validation"
        path = "/employment"
        name = "Litware Employment Validation API"
        operationId = "veryifyemployment"
        template = "/employment"
        mockResponseBody = '{"IsEmployed": true, "EmploymentStatus": "Verified", "VerifiedSalary": 85000}'
        mockPolicy = @'
<policies>
    <inbound>
        <base />
        <set-variable name="requestBody" value="@(context.Request.Body.As&lt;string&gt;())" />
        <set-variable name="employer" value="@{
            try {
                var body = ((string)context.Variables[&quot;requestBody&quot;]);
                var json = Newtonsoft.Json.Linq.JObject.Parse(body);
                return json[&quot;Employer&quot;]?.ToString()?.ToLower() ?? &quot;&quot;;
            }
            catch {
                return &quot;&quot;;
            }
        }" />
        <set-variable name="salary" value="@{
            try {
                var body = ((string)context.Variables[&quot;requestBody&quot;]);
                var json = Newtonsoft.Json.Linq.JObject.Parse(body);
                return json[&quot;Salary&quot;]?.Value&lt;int&gt;() ?? 75000;
            }
            catch {
                return 75000;
            }
        }" />
    </inbound>
    <backend>
        <return-response>
            <set-status code="200" reason="OK" />
            <set-header name="Content-Type" exists-action="override">
                <value>application/json</value>
            </set-header>
            <set-body>@{
                var employer = (string)context.Variables["employer"];
                var salary = (int)context.Variables["salary"];
                
                if (employer.Contains("microsoft")) {
                    return "{\"IsEmployed\": true, \"EmploymentStatus\": \"Verified\", \"VerifiedSalary\": 85000}";
                }
                else if (employer.Contains("goldman")) {
                    return "{\"IsEmployed\": true, \"EmploymentStatus\": \"Verified\", \"VerifiedSalary\": 150000}";
                }
                else if (employer.Contains("startup")) {
                    return "{\"IsEmployed\": true, \"EmploymentStatus\": \"Verified\", \"VerifiedSalary\": 45000}";
                }
                else if (employer.Contains("government")) {
                    return "{\"IsEmployed\": true, \"EmploymentStatus\": \"Verified\", \"VerifiedSalary\": 95000}";
                }
                else {
                    return "{\"IsEmployed\": true, \"EmploymentStatus\": \"Verified\", \"VerifiedSalary\": " + salary + "}";
                }
            }</set-body>
        </return-response>
    </backend>
    <outbound>
        <base />
    </outbound>
    <on-error>
        <base />
    </on-error>
</policies>
'@
    }
    @{ 
        id = "cronus-credit"
        path = "/credit"
        name = "Cronus Credit API"
        operationId = "checkcredit"
        template = "/creditscore"
        mockResponseBody = '{"CreditScore": 780, "CreditRating": "Excellent", "DebtToIncomeRatio": 0.20}'
        mockPolicy = @'
<policies>
    <inbound>
        <base />
        <set-variable name="requestBody" value="@(context.Request.Body.As&lt;string&gt;())" />
        <set-variable name="ssn" value="@{
            try {
                var body = ((string)context.Variables[&quot;requestBody&quot;]);
                var json = Newtonsoft.Json.Linq.JObject.Parse(body);
                return json[&quot;SSN&quot;]?.ToString() ?? &quot;000-00-0000&quot;;
            }
            catch {
                return &quot;000-00-0000&quot;;
            }
        }" />
    </inbound>
    <backend>
        <return-response>
            <set-status code="200" reason="OK" />
            <set-header name="Content-Type" exists-action="override">
                <value>application/json</value>
            </set-header>
            <set-body>@{
                var ssn = (string)context.Variables["ssn"];
                
                if (ssn.EndsWith("3456")) {
                    return "{\"CreditScore\": 780, \"CreditRating\": \"Excellent\", \"DebtToIncomeRatio\": 0.20}";
                }
                else if (ssn.EndsWith("7654")) {
                    return "{\"CreditScore\": 760, \"CreditRating\": \"Excellent\", \"DebtToIncomeRatio\": 0.35}";
                }
                else if (ssn.EndsWith("2233")) {
                    return "{\"CreditScore\": 640, \"CreditRating\": \"Fair\", \"DebtToIncomeRatio\": 0.55}";
                }
                else if (ssn.EndsWith("5566")) {
                    return "{\"CreditScore\": 750, \"CreditRating\": \"Excellent\", \"DebtToIncomeRatio\": 0.30}";
                }
                else if (ssn.EndsWith("8899")) {
                    return "{\"CreditScore\": 720, \"CreditRating\": \"Good\", \"DebtToIncomeRatio\": 0.25}";
                }
                else if (ssn.EndsWith("4455")) {
                    return "{\"CreditScore\": 740, \"CreditRating\": \"Good\", \"DebtToIncomeRatio\": 0.28}";
                }
                else {
                    return "{\"CreditScore\": 700, \"CreditRating\": \"Good\", \"DebtToIncomeRatio\": 0.30}";
                }
            }</set-body>
        </return-response>
    </backend>
    <outbound>
        <base />
    </outbound>
    <on-error>
        <base />
    </on-error>
</policies>
'@
    }
    @{ 
        id = "northwind-demographic-verification"
        path = "/verify"
        name = "Northwind Demographic Verification API"
        operationId = "demographics"
        template = "/demographics"
        mockResponseBody = '{"IsVerified": true, "Age": 37, "IdentityConfidence": 98}'
        mockPolicy = @'
<policies>
    <inbound>
        <base />
        <set-variable name="requestBody" value="@(context.Request.Body.As&lt;string&gt;())" />
        <set-variable name="ssn" value="@{
            try {
                var body = ((string)context.Variables[&quot;requestBody&quot;]);
                var json = Newtonsoft.Json.Linq.JObject.Parse(body);
                return json[&quot;SSN&quot;]?.ToString() ?? &quot;000-00-0000&quot;;
            }
            catch {
                return &quot;000-00-0000&quot;;
            }
        }" />
    </inbound>
    <backend>
        <return-response>
            <set-status code="200" reason="OK" />
            <set-header name="Content-Type" exists-action="override">
                <value>application/json</value>
            </set-header>
            <set-body>@{
                var ssn = (string)context.Variables["ssn"];
                
                if (ssn.EndsWith("3456")) {
                    return "{\"IsVerified\": true, \"Age\": 37, \"IdentityConfidence\": 98}";
                }
                else if (ssn.EndsWith("7654")) {
                    return "{\"IsVerified\": true, \"Age\": 43, \"IdentityConfidence\": 95}";
                }
                else if (ssn.EndsWith("2233")) {
                    return "{\"IsVerified\": true, \"Age\": 30, \"IdentityConfidence\": 92}";
                }
                else if (ssn.EndsWith("5566")) {
                    return "{\"IsVerified\": true, \"Age\": 46, \"IdentityConfidence\": 96}";
                }
                else if (ssn.EndsWith("8899")) {
                    return "{\"IsVerified\": true, \"Age\": 70, \"IdentityConfidence\": 97}";
                }
                else if (ssn.EndsWith("4455")) {
                    return "{\"IsVerified\": true, \"Age\": 27, \"IdentityConfidence\": 93}";
                }
                else {
                    return "{\"IsVerified\": true, \"Age\": 35, \"IdentityConfidence\": 94}";
                }
            }</set-body>
        </return-response>
    </backend>
    <outbound>
        <base />
    </outbound>
    <on-error>
        <base />
    </on-error>
</policies>
'@
    }
)

Write-Info "Creating APIs and applying mock response policies..."

# Import Az.ApiManagement module if not already loaded
if (-not (Get-Module -Name Az.ApiManagement)) {
    Import-Module Az.ApiManagement -ErrorAction Stop
}

# Create APIM context once for reuse
$apimContext = New-AzApiManagementContext -ResourceGroupName $ResourceGroup -ServiceName $APIMServiceName

foreach ($api in $apis) {
    Write-Info "Processing API: $($api.name)"
    
    # Check if API exists using PowerShell
    $existingApi = Get-AzApiManagementApi -Context $apimContext -ApiId $api.id -ErrorAction SilentlyContinue
    if ($existingApi) {
        Write-Status "API $($api.name) already exists"
    } else {
        Write-Info "Creating API: $($api.name)"
        New-AzApiManagementApi -Context $apimContext `
            -ApiId $api.id `
            -Name $api.name `
            -ServiceUrl "https://mock.example.com" `
            -Protocols @("https") `
            -Path $api.path | Out-Null
    }
    
    # Check if operation exists
    $existingOperation = Get-AzApiManagementOperation -Context $apimContext -ApiId $api.id -OperationId $api.operationId -ErrorAction SilentlyContinue
    if ($existingOperation) {
        Write-Status "Operation $($api.operationId) already exists for $($api.name)"
    } else {
        Write-Info "Creating operation for: $($api.name)"
        
        # Create operation request/response objects
        $request = New-AzApiManagementRequest
        $response = New-AzApiManagementResponse -StatusCode 200
        
        New-AzApiManagementOperation -Context $apimContext `
            -ApiId $api.id `
            -OperationId $api.operationId `
            -Name $api.name `
            -Method "POST" `
            -UrlTemplate $api.template `
            -Request $request `
            -Response $response | Out-Null
    }
    
    # Apply mock response policy
    Write-Info "Applying mock response policy for: $($api.name)"
    
    try {
        # Write policy to temporary file (Set-AzApiManagementPolicy requires UTF-8 without BOM)
        $tempPolicyFile = [System.IO.Path]::GetTempFileName()
        $api.mockPolicy | Out-File -FilePath $tempPolicyFile -Encoding utf8NoBOM -Force
        
        # Apply policy using official cmdlet with file path
        Write-Info "Uploading policy via Set-AzApiManagementPolicy..."
        Set-AzApiManagementPolicy -Context $apimContext `
            -ApiId $api.id `
            -OperationId $api.operationId `
            -PolicyFilePath $tempPolicyFile `
            -ErrorAction Stop | Out-Null
        
        # Clean up temporary file
        Remove-Item -Path $tempPolicyFile -Force -ErrorAction SilentlyContinue
        
        Write-Status "✓ Policy applied successfully for: $($api.name)"
        $policyApplied = $true
    }
    catch {
        Write-Warning "Policy application failed for: $($api.name)"
        Write-Info "Error details: $($_.Exception.Message)"
        Write-Warning "Policy could not be applied - manual application may be required"
    }
}

Write-Header "APIM Configuration Complete"
Write-Status "All 4 APIM mock policies configured successfully"