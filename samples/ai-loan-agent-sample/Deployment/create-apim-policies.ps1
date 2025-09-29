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

# Get subscription ID if not provided
if (-not $SubscriptionId) {
    $SubscriptionId = az account show --query id --output tsv
}
Write-Info "Using subscription: $SubscriptionId"

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
        <set-variable name="requestBody" value="@(context.Request.Body.As<string>())" />
    </inbound>
    <backend>
        <return-response>
            <set-status code="200" reason="OK" />
            <set-header name="Content-Type" exists-action="override">
                <value>application/json</value>
            </set-header>
            <set-body>@{
                var requestBody = context.Variables.GetValueOrDefault<string>("requestBody", "");
                
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
        <set-variable name="requestBody" value="@(context.Request.Body.As<string>())" />
        <set-variable name="employer" value="@{
            try {
                var body = ((string)context.Variables["requestBody"]);
                var json = Newtonsoft.Json.Linq.JObject.Parse(body);
                return json["Employer"]?.ToString()?.ToLower() ?? "";
            }
            catch {
                return "";
            }
        }" />
        <set-variable name="salary" value="@{
            try {
                var body = ((string)context.Variables["requestBody"]);
                var json = Newtonsoft.Json.Linq.JObject.Parse(body);
                return json["Salary"]?.Value<int>() ?? 75000;
            }
            catch {
                return 75000;
            }
        }" />
        <choose>
            <when condition="@(((string)context.Variables["employer"]).Contains("microsoft"))">
                <mock-response status-code="200" content-type="application/json">
                    <set-body>{
                        "IsEmployed": true,
                        "EmploymentStatus": "Verified",
                        "VerifiedSalary": 85000
                    }</set-body>
                </mock-response>
            </when>
            <when condition="@(((string)context.Variables["employer"]).Contains("goldman"))">
                <mock-response status-code="200" content-type="application/json">
                    <set-body>{
                        "IsEmployed": true,
                        "EmploymentStatus": "Verified",
                        "VerifiedSalary": 150000
                    }</set-body>
                </mock-response>
            </when>
            <when condition="@(((string)context.Variables["employer"]).Contains("startup"))">
                <mock-response status-code="200" content-type="application/json">
                    <set-body>{
                        "IsEmployed": true,
                        "EmploymentStatus": "Verified",
                        "VerifiedSalary": 45000
                    }</set-body>
                </mock-response>
            </when>
            <when condition="@(((string)context.Variables["employer"]).Contains("government"))">
                <mock-response status-code="200" content-type="application/json">
                    <set-body>{
                        "IsEmployed": true,
                        "EmploymentStatus": "Verified",
                        "VerifiedSalary": 95000
                    }</set-body>
                </mock-response>
            </when>
            <otherwise>
                <mock-response status-code="200" content-type="application/json">
                    <set-body>@{
                        return "{" +
                            "\"IsEmployed\": true," +
                            "\"EmploymentStatus\": \"Verified\"," +
                            "\"VerifiedSalary\": " + context.Variables["salary"] +
                        "}";
                    }</set-body>
                </mock-response>
            </otherwise>
        </choose>
    </inbound>
    <backend>
        <base />
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
        <set-variable name="requestBody" value="@(context.Request.Body.As<string>())" />
        <set-variable name="ssn" value="@{
            try {
                var body = ((string)context.Variables["requestBody"]);
                var json = Newtonsoft.Json.Linq.JObject.Parse(body);
                return json["SSN"]?.ToString() ?? "000-00-0000";
            }
            catch {
                return "000-00-0000";
            }
        }" />
        <set-variable name="salary" value="@{
            try {
                var body = ((string)context.Variables["requestBody"]);
                var json = Newtonsoft.Json.Linq.JObject.Parse(body);
                return json["Salary"]?.Value<int>() ?? 50000;
            }
            catch {
                return 50000;
            }
        }" />
        <choose>
            <when condition="@(((string)context.Variables["ssn"]).EndsWith("3456"))">
                <mock-response status-code="200" content-type="application/json">
                    <set-body>{
                        "CreditScore": 780,
                        "CreditRating": "Excellent",
                        "DebtToIncomeRatio": 0.20
                    }</set-body>
                </mock-response>
            </when>
            <when condition="@(((string)context.Variables["ssn"]).EndsWith("7654"))">
                <mock-response status-code="200" content-type="application/json">
                    <set-body>{
                        "CreditScore": 760,
                        "CreditRating": "Excellent", 
                        "DebtToIncomeRatio": 0.35
                    }</set-body>
                </mock-response>
            </when>
            <when condition="@(((string)context.Variables["ssn"]).EndsWith("2233"))">
                <mock-response status-code="200" content-type="application/json">
                    <set-body>{
                        "CreditScore": 640,
                        "CreditRating": "Fair",
                        "DebtToIncomeRatio": 0.55
                    }</set-body>
                </mock-response>
            </when>
            <when condition="@(((string)context.Variables["ssn"]).EndsWith("5566"))">
                <mock-response status-code="200" content-type="application/json">
                    <set-body>{
                        "CreditScore": 750,
                        "CreditRating": "Excellent",
                        "DebtToIncomeRatio": 0.30
                    }</set-body>
                </mock-response>
            </when>
            <when condition="@(((string)context.Variables["ssn"]).EndsWith("8899"))">
                <mock-response status-code="200" content-type="application/json">
                    <set-body>{
                        "CreditScore": 720,
                        "CreditRating": "Good",
                        "DebtToIncomeRatio": 0.25
                    }</set-body>
                </mock-response>
            </when>
            <when condition="@(((string)context.Variables["ssn"]).EndsWith("4455"))">
                <mock-response status-code="200" content-type="application/json">
                    <set-body>{
                        "CreditScore": 740,
                        "CreditRating": "Good",
                        "DebtToIncomeRatio": 0.28
                    }</set-body>
                </mock-response>
            </when>
            <otherwise>
                <mock-response status-code="200" content-type="application/json">
                    <set-body>{
                        "CreditScore": 700,
                        "CreditRating": "Good",
                        "DebtToIncomeRatio": 0.30
                    }</set-body>
                </mock-response>
            </otherwise>
        </choose>
    </inbound>
    <backend>
        <base />
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
        <set-variable name="requestBody" value="@(context.Request.Body.As<string>())" />
        <set-variable name="ssn" value="@{
            try {
                var body = ((string)context.Variables["requestBody"]);
                var json = Newtonsoft.Json.Linq.JObject.Parse(body);
                return json["SSN"]?.ToString() ?? "000-00-0000";
            }
            catch {
                return "000-00-0000";
            }
        }" />
        <set-variable name="dateOfBirth" value="@{
            try {
                var body = ((string)context.Variables["requestBody"]);
                var json = Newtonsoft.Json.Linq.JObject.Parse(body);
                var dobString = json["DateOfBirth"]?.ToString() ?? "01/01/1988";
                var dob = DateTime.Parse(dobString);
                var age = DateTime.Now.Year - dob.Year;
                if (DateTime.Now.DayOfYear < dob.DayOfYear) age--;
                return age;
            }
            catch {
                return 35;
            }
        }" />
        <choose>
            <when condition="@(((string)context.Variables["ssn"]).EndsWith("3456"))">
                <mock-response status-code="200" content-type="application/json">
                    <set-body>{
                        "IsVerified": true,
                        "Age": 37,
                        "IdentityConfidence": 98
                    }</set-body>
                </mock-response>
            </when>
            <when condition="@(((string)context.Variables["ssn"]).EndsWith("7654"))">
                <mock-response status-code="200" content-type="application/json">
                    <set-body>{
                        "IsVerified": true,
                        "Age": 43,
                        "IdentityConfidence": 95
                    }</set-body>
                </mock-response>
            </when>
            <when condition="@(((string)context.Variables["ssn"]).EndsWith("2233"))">
                <mock-response status-code="200" content-type="application/json">
                    <set-body>{
                        "IsVerified": true,
                        "Age": 30,
                        "IdentityConfidence": 92
                    }</set-body>
                </mock-response>
            </when>
            <when condition="@(((string)context.Variables["ssn"]).EndsWith("5566"))">
                <mock-response status-code="200" content-type="application/json">
                    <set-body>{
                        "IsVerified": true,
                        "Age": 46,
                        "IdentityConfidence": 96
                    }</set-body>
                </mock-response>
            </when>
            <when condition="@(((string)context.Variables["ssn"]).EndsWith("8899"))">
                <mock-response status-code="200" content-type="application/json">
                    <set-body>{
                        "IsVerified": true,
                        "Age": 70,
                        "IdentityConfidence": 97
                    }</set-body>
                </mock-response>
            </when>
            <when condition="@(((string)context.Variables["ssn"]).EndsWith("4455"))">
                <mock-response status-code="200" content-type="application/json">
                    <set-body>{
                        "IsVerified": true,
                        "Age": 27,
                        "IdentityConfidence": 93
                    }</set-body>
                </mock-response>
            </when>
            <otherwise>
                <mock-response status-code="200" content-type="application/json">
                    <set-body>@{
                        return "{" +
                            "\"IsVerified\": true," +
                            "\"Age\": " + context.Variables["dateOfBirth"] + "," +
                            "\"IdentityConfidence\": 94" +
                        "}";
                    }</set-body>
                </mock-response>
            </otherwise>
        </choose>
    </inbound>
    <backend>
        <base />
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

foreach ($api in $apis) {
    Write-Info "Processing API: $($api.name)"
    
    # Check if API exists
    $apiExists = az apim api show --service-name $APIMServiceName --resource-group $ResourceGroup --api-id $api.id --query "name" --output tsv 2>$null
    if ($apiExists) {
        Write-Status "API $($api.name) already exists"
    } else {
        Write-Info "Creating API: $($api.name)"
        az apim api create `
            --service-name $APIMServiceName `
            --resource-group $ResourceGroup `
            --api-id $api.id `
            --path $api.path `
            --display-name $api.name `
            --protocols https
        
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Failed to create API: $($api.name)"
            continue
        }
    }
    
    # Check if operation exists
    $operationExists = az apim api operation show --service-name $APIMServiceName --resource-group $ResourceGroup --api-id $api.id --operation-id $api.operationId --query "name" --output tsv 2>$null
    if ($operationExists) {
        Write-Status "Operation $($api.operationId) already exists for $($api.name)"
    } else {
        Write-Info "Creating operation for: $($api.name)"
        az apim api operation create `
            --service-name $APIMServiceName `
            --resource-group $ResourceGroup `
            --api-id $api.id `
            --operation-id $api.operationId `
            --url-template $api.template `
            --method POST `
            --display-name $api.name
            
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Failed to create operation for: $($api.name)"
            continue
        }
    }
    
    # Apply mock response policy using Azure CLI REST API (WORKING METHOD)
    Write-Info "Applying mock response policy for: $($api.name)"
    
    try {
        # Use the enhanced policy with SSN-based dynamic responses
        # This provides realistic scenario diversity for testing
        $correctedPolicy = $api.mockPolicy
        
        # Create temporary policy file with proper encoding to avoid UTF-8 BOM issues
        $policyFile = "temp-policy-$($api.id).xml"
        [System.IO.File]::WriteAllText($policyFile, $correctedPolicy, [System.Text.UTF8Encoding]::new($false))
        
        # Use Azure CLI REST API with direct XML upload (PROVEN WORKING METHOD)
        $policyUri = "https://management.azure.com/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.ApiManagement/service/$APIMServiceName/apis/$($api.id)/operations/$($api.operationId)/policies/policy?api-version=2022-08-01"
        
        Write-Info "Uploading policy via Azure CLI REST API..."
        $result = az rest --method PUT --uri $policyUri --body "@$policyFile" --headers "Content-Type=application/vnd.ms-azure-apim.policy+xml" 2>&1
        
        # Check if the operation was successful
        if ($LASTEXITCODE -eq 0 -and -not ($result -match "Bad Request|error|Error|ERROR")) {
            Write-Status "✓ Policy applied successfully for: $($api.name)"
            $policyApplied = $true
        }
        else {
            Write-Warning "Policy application failed for: $($api.name)"
            if ($result) {
                Write-Info "Error details: $($result -join ' ')"
            }
            
            # Create policy file for manual application if needed
            $manualPolicyFile = "policies/policy-$($api.id).xml" 
            $correctedPolicy | Out-File -FilePath $manualPolicyFile -Encoding UTF8 -NoNewline
            Write-Info "📋 Policy file created for manual application: $manualPolicyFile"
        }
        
        # Clean up temporary file
        Remove-Item -Path $policyFile -ErrorAction SilentlyContinue
    }
    catch {
        Write-Warning "Error applying policy for $($api.name): $($_.Exception.Message)"
        
        # Create policy file as fallback
        $policyFile = "policies/policy-$($api.id).xml"
        $api.mockPolicy | Out-File -FilePath $policyFile -Encoding UTF8 -NoNewline
        Write-Info "📋 Policy file created for manual application: $policyFile"
    }
}

Write-Header "Testing API Endpoints"

# Test each API endpoint with realistic data
$testCases = @{
    "olympia-risk-assessment" = @{
        path = "/risk/assessment"
        data = '{"SSN": "555-12-3456"}'
        expected = "RiskLevel"
    }
    "litware-employment-validation" = @{
        path = "/employment/employment" 
        data = '{"Employer": "Microsoft Corporation", "Salary": 85000, "YearsWorked": 5}'
        expected = "EmploymentStatus"
    }
    "cronus-credit" = @{
        path = "/credit/creditscore"
        data = '{"SSN": "555-12-3456", "Salary": 85000, "YearsInRole": 5}'
        expected = "CreditScore"
    }
    "northwind-demographic-verification" = @{
        path = "/verify/demographics"
        data = '{"Name": "Sarah Johnson", "DateOfBirth": "05/15/1988", "SSN": "555-12-3456"}'
        expected = "IsVerified"
    }
}

# Get subscription key for testing
try {
    $subscriptions = az rest --method GET --uri "https://management.azure.com/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.ApiManagement/service/$APIMServiceName/subscriptions?api-version=2021-08-01" --query "value[0].name" --output tsv 2>$null
    
    if ($subscriptions) {
        $subscriptionKey = az rest --method POST --uri "https://management.azure.com/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.ApiManagement/service/$APIMServiceName/subscriptions/$subscriptions/listSecrets?api-version=2021-08-01" --query "primaryKey" --output tsv 2>$null
        
        if ($subscriptionKey) {
            foreach ($apiId in $testCases.Keys) {
                $testCase = $testCases[$apiId]
                Write-Info "Testing $apiId..."
                
                try {
                    $response = Invoke-RestMethod -Uri "https://$APIMServiceName.azure-api.net$($testCase.path)" -Method POST -Body $testCase.data -ContentType "application/json" -Headers @{"Ocp-Apim-Subscription-Key" = $subscriptionKey} -ErrorAction SilentlyContinue
                    
                    if ($response -and $response.PSObject.Properties.Name -contains $testCase.expected) {
                        Write-Status "$apiId is returning structured data"
                        Write-Info "Sample response: $($response | ConvertTo-Json -Compress)"
                    } else {
                        Write-Warning "$apiId may still be returning echo responses"
                        if ($response) {
                            Write-Info "Actual response: $($response | ConvertTo-Json -Compress)"
                        }
                    }
                }
                catch {
                    Write-Warning "Error testing $apiId`: $($_.Exception.Message)"
                }
            }
        } else {
            Write-Warning "Could not retrieve subscription key for testing"
        }
    } else {
        Write-Warning "No APIM subscriptions found for testing"
    }
}
catch {
    Write-Warning "Error during API testing: $($_.Exception.Message)"
}

Write-Header "APIM Configuration Complete"
Write-Status "APIs and mock policies have been configured successfully"
Write-Info "APIs should now return contextual structured data based on input parameters"
Write-Info "Credit scores, employment status, and risk assessments will vary based on SSN patterns from SAMPLE-DATA.md"

# Output expected responses for reference
Write-Header "Expected Responses by SSN Pattern"
Write-Info "SSN ending in 3456 (Sarah Johnson): High credit score (780), Low risk (15), Age 37"
Write-Info "SSN ending in 7654 (Michael Chen): High credit score (760), Medium risk (45), Age 43" 
Write-Info "SSN ending in 2233 (Jennifer Martinez): Low credit score (640), High risk (75), Age 30"
Write-Info "SSN ending in 5566 (David Wilson): Good credit score (750), Medium risk (55), Age 46"
Write-Info "SSN ending in 8899 (Robert Thompson): Good credit score (720), Low risk (20), Age 70"
Write-Info "SSN ending in 4455 (Alex Rodriguez): Good credit score (740), Medium risk (40), Age 27"

return @{
    Success = $true
    Message = "APIM policies configured successfully"
    APIMServiceName = $APIMServiceName
    ResourceGroup = $ResourceGroup
}