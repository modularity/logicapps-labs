// API Management Service
@description('APIM service name')
param apimServiceName string

@description('Location for APIM service')
param location string

@description('Publisher email for APIM')
param publisherEmail string = 'admin@contoso.com'

@description('Publisher name for APIM')
param publisherName string = 'Contoso'

@description('Create new APIM or use existing')
param createNew bool = true

// Create new APIM service
resource apimService 'Microsoft.ApiManagement/service@2022-08-01' = if (createNew) {
  name: apimServiceName
  location: location
  sku: {
    name: 'Developer'
    capacity: 1
  }
  properties: {
    publisherEmail: publisherEmail
    publisherName: publisherName
    notificationSenderEmail: 'apimgmt-noreply@mail.windowsazure.com'
    virtualNetworkType: 'None'
    disableGateway: false
    apiVersionConstraint: {}
    publicNetworkAccess: 'Enabled'
  }
  identity: {
    type: 'SystemAssigned'
  }
}

// Reference existing APIM service
resource existingApimService 'Microsoft.ApiManagement/service@2022-08-01' existing = if (!createNew) {
  name: apimServiceName
}

output serviceName string = createNew ? apimService.name : existingApimService.name
output serviceId string = createNew ? apimService.id : existingApimService.id
output gatewayUrl string = createNew ? apimService!.properties.gatewayUrl : existingApimService!.properties.gatewayUrl
// Note: gatewayUrl may be null during initial deployment, but will be populated once APIM is ready
