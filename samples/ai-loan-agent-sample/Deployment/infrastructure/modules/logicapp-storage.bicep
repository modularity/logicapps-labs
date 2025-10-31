// Storage account for Logic Apps runtime
@description('Storage account name')
param storageAccountName string

@description('Location for the storage account')
param location string

@description('Tags to apply to resources')
param tags object = {}

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
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
        file: {
          enabled: true
        }
      }
      keySource: 'Microsoft.Storage'
    }
  }
}

output name string = storageAccount.name
output id string = storageAccount.id
output primaryEndpoints object = storageAccount.properties.primaryEndpoints
output blobUri string = storageAccount.properties.primaryEndpoints.blob
output queueUri string = storageAccount.properties.primaryEndpoints.queue
output tableUri string = storageAccount.properties.primaryEndpoints.table
