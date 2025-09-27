# Teams Integration Setup Guide

This comprehensive guide explains how to configure Microsoft Teams integration for the Loan Approval Agent workflow.

## 🎯 Overview

The AI Loan Approval Agent uses Microsoft Teams adaptive cards for human-in-the-loop approval processes. When the AI agent determines that human review is required, it posts an interactive card to a Teams channel where approvers can:

- Review loan application details
- See AI recommendation and reasoning  
- Approve or reject with comments
- Track approval history

## 📋 Required Configuration

You need to configure two essential identifiers:
1. **Teams Group ID** - The Microsoft 365 Group associated with your Teams team
2. **Teams Channel ID** - The specific channel where approval requests will be posted

## ✅ Current Configuration Status

**Example Teams integration configuration:**
- 📝 **Group ID**: `a1b2c3d4-e5f6-7890-abcd-ef1234567890` (Replace with your Teams Group ID)
- 📝 **Channel ID**: `19:example1234567890example1234567890@thread.tacv2` (Replace with your Channel ID)

**Files Updated:**
- ✅ `cloud.settings.json` - Ready for Azure deployment
- ✅ `local.settings.json` - Configuration for local development

## How to Get Teams Group ID

### Method 1: Using Teams Web/Desktop App
1. Go to your Teams team in the Teams app
2. Click on any channel in the team
3. Click the **three dots (...)** menu → **Get link to channel**
4. Copy the link - it will look like:
   ```
   https://teams.microsoft.com/l/channel/19%3a[CHANNEL_ID]%40thread.tacv2/[CHANNEL_NAME]?groupId=[GROUP_ID]&tenantId=[TENANT_ID]
   ```
5. Extract the `GROUP_ID` value from the URL (it's a GUID format like `12345678-1234-1234-1234-123456789012`)

### Method 2: Using PowerShell with Microsoft Graph
```powershell
# Install Microsoft Graph module if not already installed
Install-Module Microsoft.Graph -Scope CurrentUser

# Connect to Microsoft Graph
Connect-MgGraph -Scopes "Group.Read.All"

# Get all teams (this will show Group IDs)
Get-MgGroup -Filter "resourceProvisioningOptions/Any(x:x eq 'Team')" | Select-Object DisplayName, Id

# Find your team by name and get the ID
```

## How to Get Teams Channel ID

### Method 1: From Channel Link (Same as Group ID method)
1. Get the channel link as described above
2. The Channel ID is the part after `19%3a` and before `%40thread.tacv2`
3. URL decode it (replace `%3a` with `:`, `%40` with `@`)
4. The final format should look like: `19:abcd1234567890abcd1234567890abcd@thread.tacv2`

### Method 2: Using PowerShell with Microsoft Graph
```powershell
# Connect to Microsoft Graph (if not already connected)
Connect-MgGraph -Scopes "Channel.Read.All"

# Replace [GROUP_ID] with your actual Group ID
$groupId = "12345678-1234-1234-1234-123456789012"
Get-MgTeamChannel -TeamId $groupId | Select-Object DisplayName, Id
```

## 🚀 Deployment Steps

Since your configuration is already complete, you can proceed directly to deployment:

### 1. Deploy to Azure Logic Apps
```powershell
# From the LogicApps directory
func azure functionapp publish ai-loan-agent-logicapp --force
```

### 2. For Local Development (Optional)
```powershell
# Copy template to create local settings
# local.settings.json is already created by deploy.ps1
# Just update the Teams IDs in the existing file

# Update only the ProjectDirectoryPath to your local path:
# "ProjectDirectoryPath": "<Add local path to your LogicApps project directory>"
```

## 🔧 Configuration Details

### Why Multiple Teams Settings Exist
Logic Apps uses different naming conventions in different contexts:

```json
{
  "TeamsGroupId": "12345678-1234-1234-1234-123456789012",     // Used by parameters.json
  "TeamsChannelId": "19:abcd1234567890abcd1234567890abcd@thread.tacv2",
  "teams-GroupId": "12345678-1234-1234-1234-123456789012",   // Used by connections.json  
  "teams-ChannelId": "19:abcd1234567890abcd1234567890abcd@thread.tacv2"
}
```

**Both sets are required** and have the same values.

## 🧪 Testing the Integration

### 1. Deploy and Test Workflow
```powershell
# Deploy the Logic App
func azure functionapp publish ai-loan-agent-logicapp --force

# Monitor the deployment
az logicapp show --name ai-loan-agent-logicapp --resource-group ai-loan-agent-rg
```

### 2. Trigger a Test Approval
1. Submit a loan application via Microsoft Forms
2. The workflow will process the application
3. If human approval is required, check your Teams channel
4. You should see an adaptive card with:
   - Loan application details
   - AI recommendation and reasoning
   - Approve/Reject buttons

### 3. Test the Approval Process
1. Click **Approve** or **Reject** on the adaptive card
2. Add comments if required
3. Verify the workflow continues processing
4. Check that the applicant receives email notification

## ⚠️ Teams App Registration & Permissions

The Teams integration uses the existing `teams-1` connection which should already be configured with proper authentication. If you encounter permission errors:

### Verify Teams Connection
1. **Azure Portal** → **Logic Apps** → **ai-loan-agent-logicapp**
2. **API connections** → **teams-1**  
3. Verify the connection status is **Connected**
4. Re-authenticate if needed

### Required Permissions
The Teams connection needs these permissions:
- **Channel.ReadWrite.All** - To post messages to channels
- **Team.ReadBasic.All** - To access team information
- **TeamsActivity.Send** - To send notifications

### Managed Identity Configuration
If using managed identity for Teams authentication:
```powershell
# Assign Teams permissions to Logic Apps managed identity
az role assignment create --role "Teams Communications Administrator" \
  --assignee-object-id $(az logicapp identity show --name ai-loan-agent-logicapp --resource-group ai-loan-agent-rg --query principalId -o tsv) \
  --scope /subscriptions/$(az account show --query id -o tsv)
```

## 🔍 Troubleshooting Guide

### Common Issues and Solutions

| Error | Cause | Solution |
|-------|-------|----------|
| **404 Not Found** | Incorrect Group/Channel ID | Verify IDs are correct and channel exists |
| **403 Forbidden** | Permission issues | Re-authenticate Teams connection |
| **No adaptive card appears** | Connection authentication failure | Check connection status in Azure Portal |
| **Card appears but buttons don't work** | Callback URL issues | Verify Logic App is publicly accessible |
| **Timeout errors** | Teams API limits | Implement retry logic or reduce frequency |

### Verification Steps
```powershell
# Check Logic Apps logs
az logicapp log tail --name ai-loan-agent-logicapp --resource-group ai-loan-agent-rg

# Test Teams API connectivity
Invoke-RestMethod -Uri "https://graph.microsoft.com/v1.0/teams/12345678-1234-1234-1234-123456789012" -Headers @{Authorization="Bearer $token"}
```

### Debug Teams Integration
1. **Enable diagnostic logging** in Logic Apps
2. **Monitor workflow runs** in Azure Portal
3. **Check Teams activity logs** for message delivery
4. **Verify adaptive card JSON** is valid

## 🔒 Security Best Practices

### Authentication & Authorization
- ✅ **Use managed identities** when possible
- ✅ **Implement least privilege** access
- ✅ **Regular permission audits** for Teams connections
- ✅ **Monitor approval activities** via audit logs

### Data Protection
- ✅ **Encrypt sensitive data** in transit and at rest
- ✅ **Sanitize PII** in Teams messages
- ✅ **Implement data retention** policies
- ✅ **Regular security reviews** of workflow logic

### Access Control
- ✅ **Restrict approver access** to authorized personnel only
- ✅ **Implement approval hierarchies** for different loan amounts
- ✅ **Log all approval decisions** for audit trails
- ✅ **Regular access reviews** of Teams membership

## 📚 Additional Resources

### Microsoft Documentation
- [Teams Connectors for Logic Apps](https://docs.microsoft.com/en-us/connectors/teams/)
- [Adaptive Cards Documentation](https://adaptivecards.io/)
- [Microsoft Graph Teams API](https://docs.microsoft.com/en-us/graph/api/resources/teams-api-overview)

### Sample Adaptive Cards
- [Approval Card Templates](https://adaptivecards.io/samples/ActivityUpdate.html)
- [Input Forms](https://adaptivecards.io/samples/InputForm.html)
- [Card Actions](https://adaptivecards.io/explorer/Action.Submit.html)

---

## 🎉 Ready to Go!

Your Teams integration is fully configured and ready for deployment. The workflow will now:

1. ✅ **Post approval requests** to your Teams channel
2. ✅ **Handle human responses** via adaptive cards  
3. ✅ **Continue workflow processing** based on approval decisions
4. ✅ **Send notifications** to all stakeholders

Deploy and test your loan approval agent! 🚀