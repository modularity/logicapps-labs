// Blob storage for policy documents
@description('Blob storage account name')
param blobStorageAccountName string

@description('Location for the storage account')
param location string

resource blobStorageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: blobStorageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
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
