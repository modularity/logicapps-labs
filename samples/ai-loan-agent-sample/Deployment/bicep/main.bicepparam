using './main.bicep'

// Set your deployment parameters here
// IMPORTANT: Update these values before deployment
param projectName = 'my-loan-agent'  // Change to your unique project name (3-15 chars, alphanumeric and hyphens)
param location = 'eastus2'  // Must be an OpenAI-supported region
param sqlAdminObjectId = '<YOUR_ENTRA_ID_OBJECT_ID>'  // Run: az ad signed-in-user show --query id -o tsv
param sqlAdminUsername = '<YOUR_EMAIL>'  // Your Azure AD email/UPN
param existingApimName = ''  // Optional: name of existing APIM to reuse (leave empty to create new)
