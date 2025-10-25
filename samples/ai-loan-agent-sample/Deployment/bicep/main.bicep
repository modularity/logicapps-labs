targetScope = 'resourceGroup'

@minLength(3)
@maxLength(15)
@description('Project name used for resource naming (alphanumeric and hyphens only)')
param projectName string

@allowed([
  'eastus2'
  'swedencentral'
  'australiaeast'
  'westus'
  'northeurope'
])
@description('Azure region for resources. Must support OpenAI.')
param location string = 'eastus2'

@description('Current user Object ID for SQL Server Entra admin')
param sqlAdminObjectId string

@description('Current user email/UPN for SQL Server Entra admin')
param sqlAdminUsername string

@description('Optional: Name of existing APIM service to reuse')
param existingApimName string = ''

// Generate consistent unique identifiers
var subscriptionHash = uniqueString(subscription().subscriptionId, resourceGroup().id)
var uniqueId4 = substring(subscriptionHash, 0, 4)
var uniqueId8 = substring(subscriptionHash, 0, 8)

// Resource names with deterministic uniqueness
var logicAppName = '${projectName}-logicapp-${uniqueId4}'
var sqlServerName = '${projectName}-sqlserver-${uniqueId4}'
var openAIAccountName = '${projectName}-openai-${uniqueId4}'
var apimServiceName = empty(existingApimName) ? '${projectName}-apim-${uniqueId4}' : existingApimName
var storageAccountName = toLower(take('${replace(projectName, '-', '')}storage${uniqueId8}', 24))
var blobStorageAccountName = toLower(take('${replace(projectName, '-', '')}blob${uniqueId8}', 24))
var sqlDatabaseName = '${projectName}-db'

// Deploy modules
module storage 'modules/storage.bicep' = {
  name: 'storage-deployment'
  params: {
    storageAccountName: storageAccountName
    location: location
  }
}

module blobStorage 'modules/blobstorage.bicep' = {
  name: 'blobstorage-deployment'
  params: {
    blobStorageAccountName: blobStorageAccountName
    location: location
  }
}

module sql 'modules/sql.bicep' = {
  name: 'sql-deployment'
  params: {
    sqlServerName: sqlServerName
    sqlDatabaseName: sqlDatabaseName
    location: location
    sqlAdminObjectId: sqlAdminObjectId
    sqlAdminUsername: sqlAdminUsername
  }
}

module openai 'modules/openai.bicep' = {
  name: 'openai-deployment'
  params: {
    openAIAccountName: openAIAccountName
    location: location
  }
}

module apim 'modules/apim.bicep' = {
  name: 'apim-deployment'
  params: {
    apimServiceName: apimServiceName
    location: location
    createNew: empty(existingApimName)
  }
}

module apimApis 'modules/apim-apis.bicep' = {
  name: 'apim-apis-deployment'
  params: {
    apimServiceName: apim.outputs.serviceName
  }
}

module logicApp 'modules/logicapp.bicep' = {
  name: 'logicapp-deployment'
  params: {
    logicAppName: logicAppName
    location: location
    storageConnectionString: storage.outputs.connectionString
  }
}

// module connections 'modules/connections.bicep' = {
//   name: 'connections-deployment'
//   params: {
//     location: location
//     logicAppName: logicApp.outputs.name
//     logicAppPrincipalId: logicApp.outputs.principalId
//   }
// }

// Outputs for PowerShell consumption
output logicAppName string = logicApp.outputs.name
output logicAppPrincipalId string = logicApp.outputs.principalId
output sqlServerName string = sql.outputs.serverName
output sqlDatabaseName string = sql.outputs.databaseName
output openAIEndpoint string = openai.outputs.endpoint
output openAIKey string = openai.outputs.key
output openAIResourceId string = openai.outputs.resourceId
output apimServiceName string = apim.outputs.serviceName
output apimBaseUrl string = apim.outputs.gatewayUrl
output apimSubscriptionKeys object = {
  creditCheck: apimApis.outputs.creditCheckSubscriptionKey
  employment: apimApis.outputs.employmentSubscriptionKey
  demographics: apimApis.outputs.demographicsSubscriptionKey
  riskAssessment: apimApis.outputs.riskAssessmentSubscriptionKey
}
output storageAccountName string = storage.outputs.name
output blobStorageAccountName string = blobStorage.outputs.name
// output formsConnectionId string = connections.outputs.formsConnectionId
// output formsConnectionRuntimeUrl string = connections.outputs.formsRuntimeUrl
// output teamsConnectionId string = connections.outputs.teamsConnectionId
// output teamsConnectionRuntimeUrl string = connections.outputs.teamsRuntimeUrl
// output outlookConnectionId string = connections.outputs.outlookConnectionId
// output outlookConnectionRuntimeUrl string = connections.outputs.outlookRuntimeUrl
