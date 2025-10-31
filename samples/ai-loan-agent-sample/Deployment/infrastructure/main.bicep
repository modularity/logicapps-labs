targetScope = 'resourceGroup'

@minLength(3)
@maxLength(15)
@description('Project name used for resource naming (alphanumeric and hyphens only)')
param projectName string

@allowed([
  // US Regions
  'eastus'
  'eastus2'
  'northcentralus'
  'southcentralus'
  'westus'
  'westus3'
  // Europe
  'francecentral'
  'germanywestcentral'
  'norwayeast'
  'swedencentral'
  'switzerlandnorth'
  'uksouth'
  'westeurope'
  // Canada
  'canadacentral'
  'canadaeast'
  // South America
  'brazilsouth'
  // Asia Pacific
  'australiaeast'
  'japaneast'
  'koreacentral'
  'southeastasia'
  // Africa
  'southafricanorth'
])
@description('Azure region for resources. Must support OpenAI GPT-4o, Logic Apps Standard, and Storage Accounts.')
param location string = 'eastus2'

@description('Tags to apply to all resources')
param tags object = {}

// Generate consistent unique identifiers
var subscriptionHash = uniqueString(subscription().subscriptionId, resourceGroup().id)
var uniqueId4 = substring(subscriptionHash, 0, 4)
var uniqueId8 = substring(subscriptionHash, 0, 8)

// Resource names with deterministic uniqueness
var logicAppName = '${projectName}-logicapp-${uniqueId4}'
var openAIAccountName = '${projectName}-openai-${uniqueId4}'
var storageAccountName = toLower(take('${replace(projectName, '-', '')}storage${uniqueId8}', 24))

// Deploy modules
module logicappIdentity 'modules/logicapp-identity.bicep' = {
  name: 'loan-agent-sample-logicapp-identity-deployment'
  params: {
    identityName: '${logicAppName}-identity'
    location: location
    tags: tags
  }
}

module storage 'modules/logicapp-storage.bicep' = {
  name: 'loan-agent-sample-storage-deployment'
  params: {
    storageAccountName: storageAccountName
    location: location
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
    logicAppPrincipalId: logicappIdentity.outputs.principalId
  }
}

module connections 'modules/connections.bicep' = {
  name: 'connections-deployment'
  params: {
    location: location
  }
}

// Outputs for deploy script to configure Logic App settings
output logicAppName string = logicApp.outputs.name
output logicAppPrincipalId string = logicappIdentity.outputs.principalId
output openAIEndpoint string = openai.outputs.endpoint
output openAIResourceId string = openai.outputs.resourceId
output blobStorageAccountName string = storage.outputs.name
output microsoftFormsConnectionId string = connections.outputs.microsoftFormsConnectionId
output outlookConnectionId string = connections.outputs.outlookConnectionId
