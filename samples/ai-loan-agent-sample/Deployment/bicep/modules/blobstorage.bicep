// Blob storage for policy documents
@description('Blob storage account name')
param blobStorageAccountName string

@description('Location for the storage account')
param location string

@description('Tags to apply to resources')
param tags object = {}

resource blobStorageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: blobStorageAccountName
  location: location
  tags: tags
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false
    encryption: {
      services: {
        blob: {
          enabled: true
        }
      }
      keySource: 'Microsoft.Storage'
    }
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  parent: blobStorageAccount
  name: 'default'
}

resource policiesContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  parent: blobService
  name: 'policies'
  properties: {
    publicAccess: 'None'
  }
}

output name string = blobStorageAccount.name
output id string = blobStorageAccount.id
output containerName string = policiesContainer.name
output primaryBlobEndpoint string = blobStorageAccount.properties.primaryEndpoints.blob
