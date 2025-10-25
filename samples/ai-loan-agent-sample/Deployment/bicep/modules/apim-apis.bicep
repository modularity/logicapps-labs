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

#disable-next-line outputs-should-not-contain-secrets
output creditCheckSubscriptionKey string = creditSubscription.listSecrets().primaryKey
#disable-next-line outputs-should-not-contain-secrets
output employmentSubscriptionKey string = employmentSubscription.listSecrets().primaryKey
#disable-next-line outputs-should-not-contain-secrets
output demographicsSubscriptionKey string = demographicsSubscription.listSecrets().primaryKey
#disable-next-line outputs-should-not-contain-secrets
output riskAssessmentSubscriptionKey string = riskSubscription.listSecrets().primaryKey
