@description('Logic App name')
param logicAppName string

@description('Location')
param location string

@description('User-assigned managed identity resource ID for Logic App runtime storage (AzureWebJobsStorage)')
param logicAppRuntimeStorageIdentityId string

@description('Storage account blob service URI')
param storageBlobUri string

@description('Storage account queue service URI')
param storageQueueUri string

@description('Storage account table service URI')
param storageTableUri string

@description('Tags to apply to resources')
param tags object = {}

@description('Azure AD tenant ID for Easy Auth')
param easyAuthTenantId string = tenant().tenantId

@description('Azure AD client ID for Easy Auth (optional)')
param easyAuthClientId string = ''

resource appServicePlan 'Microsoft.Web/serverfarms@2023-01-01' = {
  name: '${logicAppName}-plan'
  location: location
  tags: tags
  sku: {
    name: 'WS1'
    tier: 'WorkflowStandard'
  }
  kind: 'elastic'
}

resource logicApp 'Microsoft.Web/sites@2023-01-01' = {
  name: logicAppName
  location: location
  tags: tags
  kind: 'functionapp,workflowapp'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${logicAppRuntimeStorageIdentityId}': {}
    }
  }
  properties: {
    serverFarmId: appServicePlan.id
    siteConfig: {
      netFrameworkVersion: 'v8.0'
      functionsRuntimeScaleMonitoringEnabled: true  // ✅ Required for managed identity storage
      appSettings: [
        { name: 'FUNCTIONS_WORKER_RUNTIME', value: 'dotnet' }
        { name: 'FUNCTIONS_EXTENSION_VERSION', value: '~4' }
        // ✅ Official managed identity storage pattern from Microsoft docs
        { name: 'AzureWebJobsStorage__managedIdentityResourceId', value: logicAppRuntimeStorageIdentityId }
        { name: 'AzureWebJobsStorage__blobServiceUri', value: storageBlobUri }
        { name: 'AzureWebJobsStorage__queueServiceUri', value: storageQueueUri }
        { name: 'AzureWebJobsStorage__tableServiceUri', value: storageTableUri }
        { name: 'AzureWebJobsStorage__credential', value: 'managedIdentity' }
        { name: 'APP_KIND', value: 'workflowApp' }
      ]
    }
  }
}

// --- Easy Auth (V2) configured as *child* resource of the site ---
resource easyAuth 'Microsoft.Web/sites/config@2022-03-01' = {
  parent: logicApp
  name: 'authsettingsV2'
  properties: {
    platform: {
      enabled: true
      // optional: runtimeVersion: '~1'
    }
    httpSettings: {
      requireHttps: true
    }
    globalValidation: {
      // Redirect or Return403 depending on your caller model
      unauthenticatedClientAction: 'RedirectToLoginPage'
    }
    identityProviders: {
      azureActiveDirectory: {
        enabled: true
        // Registration: pin to tenant; pass clientId from pipeline
        registration: union(
          { openIdIssuer: '${environment().authentication.loginEndpoint}${easyAuthTenantId}/v2.0' },
          empty(easyAuthClientId) ? {} : { clientId: easyAuthClientId }
        )
        // Built-in authorization checks (least-privilege pattern)
        validation: {
          defaultAuthorizationPolicy: {
            // Only allow specific client applications (optional but recommended)
            // e.g., an APIM-managed client app, A2A chat app, etc.
            allowedApplications: empty(easyAuthClientId) ? [] : [
              easyAuthClientId
            ]
          }
        }
        login: {
          loginParameters: [
            'response_type=code'
            'scope=openid profile email'
          ]
        }
      }
    }
  }
}

output name string = logicApp.name
output id string = logicApp.id
