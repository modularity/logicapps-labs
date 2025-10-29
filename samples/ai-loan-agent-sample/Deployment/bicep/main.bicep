targetScope = 'resourceGroup'

@minLength(3)
@maxLength(15)
@description('Project name used for resource naming (alphanumeric and hyphens only)')
param projectName string

@allowed([
  // US Regions
  'eastus'
  'eastus2'
  'southcentralus'
  // Europe
  'swedencentral'
  'francecentral'
  'switzerlandnorth'
  'uksouth'
  'northeurope'
  'westeurope'
  // Asia Pacific
  'australiaeast'
  'japaneast'
  'eastasia'
  // Canada
  'canadaeast'
  // Middle East
  'uaenorth'
])
@description('Azure region for resources. Must support both OpenAI GPT-4 Turbo and Logic Apps Standard.')
param location string = 'eastus2'

@description('Current user Object ID for SQL Server Entra admin')
param sqlAdminObjectId string

@description('Current user email/UPN for SQL Server Entra admin')
param sqlAdminUsername string

@description('Current user Object ID for blob storage access (for policy document upload)')
param deployerObjectId string = ''

@description('Optional: Name of existing APIM service to reuse')
param existingApimName string = ''

@description('Optional: Client IP address for SQL firewall rule')
param clientIpAddress string = ''

@description('Tags to apply to all resources')
param tags object = {}

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
module logicappIdentity 'modules/logicapp-identity.bicep' = {
  name: 'loan-agent-sample-logicapp-identity-deployment'
  params: {
    identityName: '${logicAppName}-identity'
    location: location
    tags: tags
  }
}

module storage 'modules/storage.bicep' = {
  name: 'loan-agent-sample-storage-deployment'
  params: {
    storageAccountName: storageAccountName
    location: location
    tags: tags
  }
}

module blobStorage 'modules/blobstorage.bicep' = {
  name: 'loan-agent-sample-blobstorage-deployment'
  params: {
    blobStorageAccountName: blobStorageAccountName
    location: location
    tags: tags
  }
}

module sql 'modules/sql.bicep' = {
  name: 'loan-agent-sample-sql-deployment'
  params: {
    sqlServerName: sqlServerName
    sqlDatabaseName: sqlDatabaseName
    location: location
    sqlAdminObjectId: sqlAdminObjectId
    sqlAdminUsername: sqlAdminUsername
    clientIpAddress: clientIpAddress
    tags: tags
  }
}

module openai 'modules/openai.bicep' = {
  name: 'loan-agent-sample-openai-deployment'
  params: {
    openAIAccountName: openAIAccountName
    location: location
    tags: tags
  }
}

module apim 'modules/apim.bicep' = {
  name: 'loan-agent-sample-apim-deployment'
  params: {
    apimServiceName: apimServiceName
    location: location
    createNew: empty(existingApimName)
    tags: tags
  }
}

module apimApis 'modules/apim-apis.bicep' = {
  name: 'loan-agent-sample-apim-apis-deployment'
  params: {
    apimServiceName: apim.outputs.serviceName
  }
}

module logicApp 'modules/logicapp.bicep' = {
  name: 'loan-agent-sample-logicapp-deployment'
  params: {
    logicAppName: logicAppName
    location: location
    logicAppRuntimeStorageIdentityId: logicappIdentity.outputs.id
    storageBlobUri: storage.outputs.blobUri
    storageQueueUri: storage.outputs.queueUri
    storageTableUri: storage.outputs.tableUri
    tags: tags
  }
}

// Grant Logic App managed identity access to OpenAI
module openaiRbac 'modules/openai-rbac.bicep' = {
  name: 'loan-agent-sample-openai-rbac-deployment'
  params: {
    openAIAccountName: openai.outputs.accountName
    logicAppPrincipalId: logicappIdentity.outputs.principalId
  }
}

// Grant Logic App managed identity access to storage accounts
module storageRbac 'modules/storage-rbac.bicep' = {
  name: 'loan-agent-sample-storage-rbac-deployment'
  params: {
    storageAccountName: storage.outputs.name
    blobStorageAccountName: blobStorage.outputs.name
    logicAppPrincipalId: logicappIdentity.outputs.principalId
    deployerObjectId: deployerObjectId
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
output logicAppPrincipalId string = logicappIdentity.outputs.principalId
output sqlServerName string = sql.outputs.serverName
output sqlDatabaseName string = sql.outputs.databaseName
output openAIEndpoint string = openai.outputs.endpoint
output openAIResourceId string = openai.outputs.resourceId
output apimServiceName string = apim.outputs.serviceName
output apimBaseUrl string = apim.outputs.gatewayUrl
output storageAccountName string = storage.outputs.name
output blobStorageAccountName string = blobStorage.outputs.name
output policyDocumentUrl string = 'https://${blobStorage.outputs.name}.blob.${environment().suffixes.storage}/policies/loan-policy.txt'
// output formsConnectionId string = connections.outputs.formsConnectionId
// output formsConnectionRuntimeUrl string = connections.outputs.formsRuntimeUrl
// output teamsConnectionId string = connections.outputs.teamsConnectionId
// output teamsConnectionRuntimeUrl string = connections.outputs.teamsRuntimeUrl
// output outlookConnectionId string = connections.outputs.outlookConnectionId
// output outlookConnectionRuntimeUrl string = connections.outputs.outlookRuntimeUrl
