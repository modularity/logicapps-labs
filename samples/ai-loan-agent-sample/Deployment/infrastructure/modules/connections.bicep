@description('Location')
param location string

// Create OAuth-based connections 
// Note: These connectors use user delegation (OAuth) 
// Access policies are not needed - authorization happens via OAuth consent flow
resource microsoftFormsConnection 'Microsoft.Web/connections@2016-06-01' = {
  name: 'microsoftFormsConnection'
  location: location
  properties: {
    displayName: 'Microsoft Forms'
    api: {
      id: subscriptionResourceId('Microsoft.Web/locations/managedApis', location, 'microsoftforms')
    }
  }
}

// Outlook Connection
resource outlookConnection 'Microsoft.Web/connections@2016-06-01' = {
  name: 'outlookConnection'
  location: location
  properties: {
    displayName: 'Office 365 Outlook'
    api: {
      id: subscriptionResourceId('Microsoft.Web/locations/managedApis', location, 'office365')
    }
  }
}

// Output connection details
output microsoftFormsConnectionId string = microsoftFormsConnection.id
output microsoftFormsConnectionName string = microsoftFormsConnection.name

output outlookConnectionId string = outlookConnection.id
output outlookConnectionName string = outlookConnection.name

// ⚠️ User must authorize OAuth in portal after deployment (Edit API connection > Authorize)
// ⚠️ connectionRuntimeUrl is only available after OAuth authorization
