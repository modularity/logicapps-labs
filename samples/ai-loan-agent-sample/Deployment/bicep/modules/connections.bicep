@description('Location')
param location string

@description('Logic App name')
param logicAppName string

@description('Logic App principal ID')
param logicAppPrincipalId string

// Create V2 connections
resource formsConnection 'Microsoft.Web/connections@2016-06-01' = {
  name: 'formsConnection'
  location: location
  properties: {
    displayName: 'Microsoft Forms'
    api: {
      id: subscriptionResourceId('Microsoft.Web/locations/managedApis', location, 'microsoftforms')
    }
  }
}

// Grant Logic App access (Layer 2)
resource formsAccessPolicy 'Microsoft.Web/connections/accessPolicies@2016-06-01' = {
  parent: formsConnection
  name: logicAppName
  properties: {
    principal: {
      type: 'ActiveDirectory'
      identity: {
        tenantId: subscription().tenantId
        objectId: logicAppPrincipalId  // ✅ From Logic App output
      }
    }
  }
}

// Teams Connection
resource teamsConnection 'Microsoft.Web/connections@2016-06-01' = {
  name: 'teamsConnection'
  location: location
  properties: {
    displayName: 'Microsoft Teams'
    api: {
      id: subscriptionResourceId('Microsoft.Web/locations/managedApis', location, 'teams')
    }
  }
}

resource teamsAccessPolicy 'Microsoft.Web/connections/accessPolicies@2016-06-01' = {
  parent: teamsConnection
  name: logicAppName
  properties: {
    principal: {
      type: 'ActiveDirectory'
      identity: {
        tenantId: subscription().tenantId
        objectId: logicAppPrincipalId
      }
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

resource outlookAccessPolicy 'Microsoft.Web/connections/accessPolicies@2016-06-01' = {
  parent: outlookConnection
  name: logicAppName
  properties: {
    principal: {
      type: 'ActiveDirectory'
      identity: {
        tenantId: subscription().tenantId
        objectId: logicAppPrincipalId
      }
    }
  }
}

// Output connection details  
// Note: connectionRuntimeUrl is available in the ARM resource but not in Bicep type definitions
// Using reference() function as workaround
output formsConnectionId string = formsConnection.id
#disable-next-line use-resource-symbol-reference
output formsRuntimeUrl string = reference(formsConnection.id, '2016-06-01', 'Full').properties.connectionRuntimeUrl
output teamsConnectionId string = teamsConnection.id
#disable-next-line use-resource-symbol-reference
output teamsRuntimeUrl string = reference(teamsConnection.id, '2016-06-01', 'Full').properties.connectionRuntimeUrl
output outlookConnectionId string = outlookConnection.id
#disable-next-line use-resource-symbol-reference
output outlookRuntimeUrl string = reference(outlookConnection.id, '2016-06-01', 'Full').properties.connectionRuntimeUrl
// ⚠️ User still needs to authorize OAuth (Layer 1) in portal after deployment
