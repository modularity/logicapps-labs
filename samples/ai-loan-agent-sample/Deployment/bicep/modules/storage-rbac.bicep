// RBAC role assignments for Logic App managed identity to access storage accounts

@description('Runtime storage account name')
param storageAccountName string

@description('Policy document blob storage account name')
param blobStorageAccountName string

@description('Logic App managed identity principal ID')
param logicAppPrincipalId string

@description('Deployer user Object ID for blob storage write access (optional)')
param deployerObjectId string = ''

// Reference to runtime storage account
resource runtimeStorage 'Microsoft.Storage/storageAccounts@2023-01-01' existing = {
  name: storageAccountName
}

// Reference to policy document blob storage
resource policyBlobStorage 'Microsoft.Storage/storageAccounts@2023-01-01' existing = {
  name: blobStorageAccountName
}

// Grant Logic App "Storage Blob Data Contributor" on runtime storage (for workflow state)
resource runtimeBlobContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(runtimeStorage.id, logicAppPrincipalId, 'BlobDataContributor')
  scope: runtimeStorage
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 
      'ba92f5b4-2d11-453d-a403-e96b0029c9fe') // Storage Blob Data Contributor
    principalId: logicAppPrincipalId
    principalType: 'ServicePrincipal'
  }
}

// Grant Logic App "Storage Queue Data Contributor" on runtime storage (for workflow triggers/actions)
resource runtimeQueueContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(runtimeStorage.id, logicAppPrincipalId, 'QueueDataContributor')
  scope: runtimeStorage
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions',
      '974c5e8b-45b9-4653-ba55-5f855dd0fb88') // Storage Queue Data Contributor
    principalId: logicAppPrincipalId
    principalType: 'ServicePrincipal'
  }
}

// Grant Logic App "Storage Table Data Contributor" on runtime storage (for workflow metadata)
resource runtimeTableContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(runtimeStorage.id, logicAppPrincipalId, 'TableDataContributor')
  scope: runtimeStorage
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions',
      '0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3') // Storage Table Data Contributor
    principalId: logicAppPrincipalId
    principalType: 'ServicePrincipal'
  }
}

// Grant Logic App "Storage Blob Data Reader" on policy document storage
resource policyBlobReader 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(policyBlobStorage.id, logicAppPrincipalId, 'BlobDataReader')
  scope: policyBlobStorage
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions',
      '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1') // Storage Blob Data Reader
    principalId: logicAppPrincipalId
    principalType: 'ServicePrincipal'
  }
}

// Grant deployer user "Storage Blob Data Contributor" on policy document storage (for upload)
resource deployerBlobContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(deployerObjectId)) {
  name: guid(policyBlobStorage.id, deployerObjectId, 'DeployerBlobDataContributor')
  scope: policyBlobStorage
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions',
      'ba92f5b4-2d11-453d-a403-e96b0029c9fe') // Storage Blob Data Contributor
    principalId: deployerObjectId
    principalType: 'User'
  }
}

output runtimeStorageRoleAssignments array = [
  runtimeBlobContributor.id
  runtimeQueueContributor.id
  runtimeTableContributor.id
]

output policyStorageRoleAssignment string = policyBlobReader.id
