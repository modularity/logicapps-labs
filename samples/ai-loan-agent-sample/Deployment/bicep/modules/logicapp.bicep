@description('Logic App name')
param logicAppName string

@description('Location')
param location string

@description('Storage connection string')
@secure()
param storageConnectionString string

resource appServicePlan 'Microsoft.Web/serverfarms@2023-01-01' = {
  name: '${logicAppName}-plan'
  location: location
  sku: {
    name: 'WS1'
    tier: 'WorkflowStandard'
  }
  kind: 'elastic'
}

resource logicApp 'Microsoft.Web/sites@2023-01-01' = {
  name: logicAppName
  location: location
  kind: 'functionapp,workflowapp'
  identity: {
    type: 'SystemAssigned'  // ✅ Try to create in Bicep
  }
  properties: {
    serverFarmId: appServicePlan.id
    siteConfig: {
      netFrameworkVersion: 'v8.0'
      functionsRuntimeScaleMonitoringEnabled: false
      appSettings: [
        { name: 'FUNCTIONS_WORKER_RUNTIME', value: 'dotnet' }
        { name: 'FUNCTIONS_EXTENSION_VERSION', value: '~4' }
        { name: 'AzureWebJobsStorage', value: storageConnectionString }
        // Other settings added post-deployment
      ]
    }
  }
}

output name string = logicApp.name
output principalId string = logicApp.identity.principalId  // ✅ Output for RBAC
output id string = logicApp.id
