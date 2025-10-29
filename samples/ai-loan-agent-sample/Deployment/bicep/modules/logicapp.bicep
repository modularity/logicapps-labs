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

output name string = logicApp.name
output id string = logicApp.id
