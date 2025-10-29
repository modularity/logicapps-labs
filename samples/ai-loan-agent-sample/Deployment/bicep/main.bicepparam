using './main.bicep'

// Set your deployment parameters here
// IMPORTANT: Update these values before deployment
param projectName = 'my-loan-agent'  // Change to your unique project name (3-15 chars, alphanumeric and hyphens)
param location = 'eastus2'  // Supported region for both Logic Apps Standard + OpenAI GPT-4
param sqlAdminObjectId = ''  // Auto-detected if empty. Or get via: (Get-AzADUser -UserPrincipalName (Get-AzContext).Account.Id).Id
param sqlAdminUsername = ''  // Auto-detected if empty. Or specify your Azure AD email/UPN
param deployerObjectId = ''  // Auto-detected if empty. Used for blob storage upload permissions
param existingApimName = ''  // Optional: name of existing APIM to reuse (leave empty to create new)

param tags = {
  Project: 'Logic-Apps-Loan-Agent-Sample'
  Environment: 'Development'
}
