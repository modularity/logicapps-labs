// APIM APIs, Operations, and Subscriptions (Policies added via PowerShell)
@description('APIM service name')
param apimServiceName string

resource apimService 'Microsoft.ApiManagement/service@2022-08-01' existing = {
  name: apimServiceName
}

// Credit Check API
resource creditCheckAPI 'Microsoft.ApiManagement/service/apis@2022-08-01' = {
  parent: apimService
  name: 'cronus-credit'
  properties: {
    displayName: 'Cronus Credit API'
    path: '/credit'
    protocols: ['https']
  }
}

resource creditCheckOperation 'Microsoft.ApiManagement/service/apis/operations@2022-08-01' = {
  parent: creditCheckAPI
  name: 'checkcredit'
  properties: {
    displayName: 'Check Credit'
    method: 'POST'
    urlTemplate: '/creditscore'
  }
}

// ❌ NO policy resource here - will be added via PowerShell

// Create subscription for Logic App
resource creditSubscription 'Microsoft.ApiManagement/service/subscriptions@2022-08-01' = {
  parent: apimService
  name: 'credit-check-subscription'
  properties: {
    scope: creditCheckAPI.id
    displayName: 'Credit Check Subscription'
    state: 'active'
  }
}

// Employment Validation API
resource employmentAPI 'Microsoft.ApiManagement/service/apis@2022-08-01' = {
  parent: apimService
  name: 'litware-employment-validation'
  properties: {
    displayName: 'Litware Employment Validation API'
    path: '/employment'
    protocols: ['https']
  }
}

resource employmentOperation 'Microsoft.ApiManagement/service/apis/operations@2022-08-01' = {
  parent: employmentAPI
  name: 'veryifyemployment'
  properties: {
    displayName: 'Verify Employment'
    method: 'POST'
    urlTemplate: '/employment'
  }
}

resource employmentSubscription 'Microsoft.ApiManagement/service/subscriptions@2022-08-01' = {
  parent: apimService
  name: 'employment-validation-subscription'
  properties: {
    scope: employmentAPI.id
    displayName: 'Employment Validation Subscription'
    state: 'active'
  }
}

// Demographics API
resource demographicsAPI 'Microsoft.ApiManagement/service/apis@2022-08-01' = {
  parent: apimService
  name: 'northwind-demographic-verification'
  properties: {
    displayName: 'Northwind Demographic Verification API'
    path: '/verify'
    protocols: ['https']
  }
}

resource demographicsOperation 'Microsoft.ApiManagement/service/apis/operations@2022-08-01' = {
  parent: demographicsAPI
  name: 'demographics'
  properties: {
    displayName: 'Verify Demographics'
    method: 'POST'
    urlTemplate: '/demographics'
  }
}

resource demographicsSubscription 'Microsoft.ApiManagement/service/subscriptions@2022-08-01' = {
  parent: apimService
  name: 'demographics-subscription'
  properties: {
    scope: demographicsAPI.id
    displayName: 'Demographics Subscription'
    state: 'active'
  }
}

// Risk Assessment API
resource riskAPI 'Microsoft.ApiManagement/service/apis@2022-08-01' = {
  parent: apimService
  name: 'olympia-risk-assessment'
  properties: {
    displayName: 'Olympia Risk Assessment API'
    path: '/risk'
    protocols: ['https']
  }
}

resource riskOperation 'Microsoft.ApiManagement/service/apis/operations@2022-08-01' = {
  parent: riskAPI
  name: 'riskassessment'
  properties: {
    displayName: 'Risk Assessment'
    method: 'POST'
    urlTemplate: '/assessment'
  }
}

resource riskSubscription 'Microsoft.ApiManagement/service/subscriptions@2022-08-01' = {
  parent: apimService
  name: 'risk-assessment-subscription'
  properties: {
    scope: riskAPI.id
    displayName: 'Risk Assessment Subscription'
    state: 'active'
  }
}

// ============================================================================
// APIM POLICIES - Mock Response Logic
// ============================================================================

resource creditCheckPolicy 'Microsoft.ApiManagement/service/apis/operations/policies@2022-08-01' = {
  parent: creditCheckOperation
  name: 'policy'
  properties: {
    format: 'rawxml'
    value: '''<policies>
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
</policies>'''
  }
}

resource employmentPolicy 'Microsoft.ApiManagement/service/apis/operations/policies@2022-08-01' = {
  parent: employmentOperation
  name: 'policy'
  properties: {
    format: 'rawxml'
    value: '''<policies>
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
</policies>'''
  }
}

resource demographicsPolicy 'Microsoft.ApiManagement/service/apis/operations/policies@2022-08-01' = {
  parent: demographicsOperation
  name: 'policy'
  properties: {
    format: 'rawxml'
    value: '''<policies>
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
</policies>'''
  }
}

resource riskAssessmentPolicy 'Microsoft.ApiManagement/service/apis/operations/policies@2022-08-01' = {
  parent: riskOperation
  name: 'policy'
  properties: {
    format: 'rawxml'
    value: '''<policies>
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
</policies>'''
  }
}
