// RBAC for OpenAI - Grant Logic App Managed Identity access
@description('OpenAI account name')
param openAIAccountName string

@description('Logic App principal ID (managed identity)')
param logicAppPrincipalId string

resource openAIAccount 'Microsoft.CognitiveServices/accounts@2023-05-01' existing = {
  name: openAIAccountName
}

// Grant Cognitive Services OpenAI User role to Logic App
resource openAIUserRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(openAIAccount.id, logicAppPrincipalId, '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd')
  scope: openAIAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd') // Cognitive Services OpenAI User
    principalId: logicAppPrincipalId
    principalType: 'ServicePrincipal'
  }
}

output roleAssignmentId string = openAIUserRole.id
