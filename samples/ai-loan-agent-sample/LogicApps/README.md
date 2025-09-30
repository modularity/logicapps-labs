# Local Development Setup

This guide provides step-by-step instructions for setting up local development environment for this Logic Apps Standard project.

> 🎥 **New to this sample?** [Watch the demo video](https://youtu.be/rR1QjQTfCCg) to see the complete AI Loan Agent workflow in action before setting up your development environment.

## Overview

**End-to-End Setup Summary:**
1. Run `deploy.ps1` to create Azure infrastructure
2. Configure Microsoft 365 (Forms, Teams, authorize API connections) - *during deployment*
3. Setup database schema and managed identity access
4. Configure local development environment (`local.settings.json`)
5. Deploy workflows to Azure using VS Code
6. Test the complete loan approval flow

This guide focuses on **Step 4** - local development configuration. Complete this setup AFTER running `deploy.ps1`, configuring Microsoft 365, and setting up the database schema (Steps 1-3).

The `local.settings.json` file contains configuration settings required for local development. This file should **never** be committed to source control as it contains sensitive connection strings and local-specific paths.

## Quick Setup Steps

### 1. Create local.settings.json
```powershell
# Navigate to the LogicApps folder
cd LogicApps

# Copy the template file
Copy-Item cloud.settings.json local.settings.json
```

### 2. Configure Required Settings

Update the following values in your `local.settings.json` file:

| Setting Key | Description | Where to Find | Example |
|-------------|-------------|---------------|---------|
| `ProjectDirectoryPath` | Local path to LogicApps folder | Your local file system | `C:\\projects\\ai-loan-agent\\LogicApps` |
| `WORKFLOWS_SUBSCRIPTION_ID` | Azure subscription ID | Azure Portal → Subscriptions | `12345678-1234-1234-1234-123456789012` |
| `WORKFLOWS_RESOURCE_GROUP_NAME` | Target resource group name | Azure Portal → Resource groups | `ai-loan-agent-rg` |
| `agent_openAIEndpoint` | Azure OpenAI service endpoint | Azure Portal → OpenAI → Keys and Endpoint | `https://myopenai.openai.azure.com/` |
| `agent_openAIKey` | Azure OpenAI access key | Azure Portal → OpenAI → Keys and Endpoint | `abc123def456...` |
| `agent_ResourceID` | Azure OpenAI resource ID | Azure Portal → OpenAI → Properties | `/subscriptions/.../resourceGroups/.../providers/Microsoft.CognitiveServices/accounts/myopenai` |
| `sql_connectionString` | SQL Database connection string | Azure Portal → SQL Database → Connection strings | `Server=tcp:myserver.database.windows.net,1433;...` |
| `riskAssessmentAPI_SubscriptionKey` | Risk assessment API key | Azure Portal → API Management → Subscriptions | `abc123...` |
| `employmentValidationAPI_SubscriptionKey` | Employment validation API key | Azure Portal → API Management → Subscriptions | `def456...` |
| `creditCheckAPI_SubscriptionKey` | Credit check API key | Azure Portal → API Management → Subscriptions | `ghi789...` |
| `demographicVerificationAPI_SubscriptionKey` | Demographics API key | Azure Portal → API Management → Subscriptions | `jkl012...` |
| `PolicyDocumentURL` | Policy document SAS URL | Azure Storage → Generate SAS | `https://mystorage.blob.core.windows.net/...` |
| `teams-GroupId` | Microsoft Teams group ID | Teams channel URL | `a1b2c3d4-e5f6-7890-abcd-ef1234567890` |
| `teams-ChannelId` | Microsoft Teams channel ID | Teams channel URL | `19:example1234567890@thread.tacv2` |
| `DemoUserEmail` | Demo email for notifications | Your email address | `demo@yourcompany.com` |

### 3. Pre-configured Values (Do Not Modify)

These values are already set correctly and should remain unchanged:
- `AzureWebJobsStorage`: `"UseDevelopmentStorage=true"`
- `APP_KIND`: `"workflowApp"`
- `FUNCTIONS_WORKER_RUNTIME`: `"dotnet"`
- `FUNCTIONS_INPROC_NET8_ENABLED`: `"1"`

## Detailed Configuration Guide

### Azure OpenAI Configuration

1. Navigate to Azure Portal → Azure OpenAI Service
2. Select your OpenAI resource
3. Go to "Keys and Endpoint" section
4. Copy the endpoint URL and access key
5. For the resource ID, go to Properties and copy the full resource path

### SQL Database Configuration

The SQL connection string should use managed identity authentication:
```
Server=tcp:[servername].database.windows.net,1433;Initial Catalog=[database];Authentication=Active Directory Managed Identity;Encrypt=True;
```

### API Management Configuration

1. Navigate to Azure Portal → API Management
2. Go to Subscriptions section
3. Copy subscription keys for each API:
   - Risk Assessment API (olympia-risk-assessment)
   - Employment Validation API (litware-employment-validation)  
   - Credit Check API (cronus-credit)
   - Demographics API (northwind-demographic-verification)

### Microsoft 365 Connections

The deployment script automatically creates Microsoft 365 API connections in Azure, but they require manual authorization:

1. **Connections Created by deploy.ps1**:
   - `formsConnection` - Microsoft Forms connector
   - `teamsConnection` - Microsoft Teams connector  
   - `outlookConnection` - Outlook connector

2. **Manual Authorization Required**:
   - Azure Portal → Resource Groups → [your-resource-group]
   - Click each connection → "Edit API Connection" → "Authorize"
   - Sign in with your Microsoft 365 account when prompted

3. **Connection Configuration**:
   - Runtime URLs are auto-generated after authorization
   - Connection keys use `@connectionKey('connection-name')` format
   - No manual configuration needed for these values in local.settings.json

### Teams Configuration

Extract Team Group ID and Channel ID from Teams channel URL:
1. Open Teams channel in browser
2. Copy URL and extract IDs from the path
3. Update both `teams-GroupId` and `TeamsGroupId` with the same value
4. Update both `teams-ChannelId` and `TeamsChannelId` with the same value

## Next Steps: Deploy to Azure

After completing local.settings.json configuration:

1. **Open in VS Code**: Open the LogicApps folder in VS Code
2. **Install Extension**: Ensure Azure Logic Apps extension is installed
3. **Deploy Workflows**: Right-click LogicApps folder → "Deploy to Logic App in Azure"
4. **Select Target**: Choose your deployed Logic App resource
5. **Test Deployment**: Verify workflows appear in Azure Portal

## Sample Configuration

Your completed `local.settings.json` should look similar to this:

```json
{
  "IsEncrypted": false,
  "Values": {
    "AzureWebJobsStorage": "UseDevelopmentStorage=true",
    "APP_KIND": "workflowApp",
    "FUNCTIONS_WORKER_RUNTIME": "dotnet",
    "FUNCTIONS_INPROC_NET8_ENABLED": "1",
    "ProjectDirectoryPath": "C:\\\\projects\\\\ai-loan-agent\\\\LogicApps",
    "WORKFLOWS_SUBSCRIPTION_ID": "12345678-1234-1234-1234-123456789012",
    "WORKFLOWS_LOCATION_NAME": "eastus2",
    "WORKFLOWS_RESOURCE_GROUP_NAME": "ai-loan-agent-rg",
    "agent_openAIEndpoint": "https://myopenai.openai.azure.com/",
    "agent_openAIKey": "your-actual-openai-key",
    "agent_ResourceID": "/subscriptions/12345678-1234-1234-1234-123456789012/resourceGroups/ai-loan-agent-rg/providers/Microsoft.CognitiveServices/accounts/myopenai",
    "sql_connectionString": "Server=tcp:myserver.database.windows.net,1433;Initial Catalog=ai-loan-agent-db;Authentication=Active Directory Managed Identity;Encrypt=True;",
    "riskAssessmentAPI_SubscriptionKey": "risk-assessment-key",
    "employmentValidationAPI_SubscriptionKey": "employment-validation-key",
    "creditCheckAPI_SubscriptionKey": "credit-check-key",
    "demographicVerificationAPI_SubscriptionKey": "demographics-key",
    "PolicyDocumentURL": "https://mystorage.blob.core.windows.net/policies/policy.pdf?sp=r&st=...",
    "teams-GroupId": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
    "teams-ChannelId": "19:example1234567890@thread.tacv2",
    "DemoUserEmail": "demo@yourcompany.com"
  }
}
```

## Next Steps: Deploy to Azure

After completing local.settings.json configuration:

1. **Open in VS Code**: Open the LogicApps folder in VS Code
2. **Install Extension**: Ensure Azure Logic Apps extension is installed
3. **Deploy Workflows**: Right-click LogicApps folder → "Deploy to Logic App in Azure"
4. **Select Target**: Choose your deployed Logic App resource
5. **Test Deployment**: Verify workflows appear in Azure Portal

> 💡 **Tip**: This corresponds to **Step 5** in the main deployment guide. After deployment, proceed to **Step 6: End-to-End Testing**.

## Verification Steps

1. **Test Local Run**: Use VS Code Azure Logic Apps extension to start the local runtime
2. **Check Connections**: Verify all connections are working in the Logic Apps Designer
3. **Test Workflows**: Run a simple test of each workflow to ensure proper configuration

## Important Security Notes

- ⚠️ **Never commit `local.settings.json` to source control**
- 🔐 **Use proper Azure RBAC permissions instead of connection strings when possible**
- 🔄 **Rotate keys regularly and update local settings accordingly**
- 🔒 **Microsoft 365 connections use OAuth - no passwords stored locally**
- 🛡️ **Managed identity used for SQL authentication - no connection string passwords**

## Troubleshooting

### Common Issues

**File Path Issues (Windows):**
- Ensure paths use double backslashes (`\\\\`) or forward slashes (`/`)
- Example: `C:\\\\projects\\\\myapp` or `C:/projects/myapp`

**Connection Failures:**
- Verify connection strings are complete and unmodified
- Check firewall settings for local development
- Ensure Azure resources allow access from your IP

**Microsoft 365 Connection Issues:**
- **Unauthorized errors**: Re-authorize connections in Azure Portal → "Edit API Connection"
- **Connection not found**: Verify deploy.ps1 completed successfully
- **Authentication failures**: Ensure you have appropriate Microsoft 365 permissions
- **Teams/Forms access**: Check your account has access to the target workspace/form

**SQL Authentication Issues:**
- Verify managed identity user created in database
- Check connection string includes `Authentication=Active Directory Managed Identity`
- Ensure Logic App has database permissions
- Run `create-managed-identity-user.sql` if access denied

**Azure OpenAI Issues:**
- Verify GPT-4.1 model deployment exists
- Check OpenAI resource has sufficient quota
- Ensure endpoint URL format is correct
- Validate API key is not expired

**Teams Integration Issues:**
- Verify Group ID and Channel ID are correct format
- Check that Teams workspace allows external apps
- Ensure Microsoft Graph permissions granted to Logic App

**Runtime Issues:**
- Verify .NET and Azure Functions Core Tools are installed
- Check VS Code Azure Logic Apps extension is up to date
- Review terminal output for specific error messages

### Getting Help

- Check Azure Logic Apps runtime logs in VS Code terminal
- Review connection test results in Logic Apps Designer
- Monitor Azure resource health in Azure Portal
- Use Azure Application Insights for detailed telemetry
