# AI Loan Agent - Connection Setup Guide

This guide provides step-by-step instructions for setting up all connections required for the AI Loan Agent Logic Apps sample after running the main deployment script.

## 📋 Overview

The AI Loan Agent sample requires two types of connections:

1. **Azure Infrastructure** (✅ Automated by `deploy.ps1`)
2. **Microsoft 365 Connections** (⚠️ Manual setup required)

## 🚀 Quick Start

1. **Run the main deployment**: `.\deploy.ps1`
2. **Follow this guide** to set up Microsoft 365 connections
3. **Update Teams configuration** with your actual IDs
4. **Test the complete workflow**

## ✅ Configuration Fixes Applied

The deployment scripts have been updated to automatically fix common configuration issues:

### HTTP Action URI Configuration ✅ FIXED
- ✅ **PolicyDocumentURL** app setting is now automatically configured in Azure
- ✅ **PolicyDocumentURI** is added for consistency
- ✅ HTTP action will successfully retrieve the policy document from blob storage

### Teams Integration Configuration ✅ READY
- ✅ **TeamsGroupId** and **TeamsChannelId** app settings are configured
- ⚠️ **Update required**: Replace placeholder values with your actual Teams IDs
- ✅ Teams adaptive cards will post to your specified channel

**All deployment scripts now include these fixes automatically.**

---

## ✅ What `deploy.ps1` Creates Automatically

The main deployment script creates all Azure infrastructure:

### Azure Resources (Fully Automated)
- **Resource Group**: `ai-loan-agent-rg`
- **Storage Account**: Blob storage for policies and documents
- **SQL Server & Database**: For loan application data
- **OpenAI Service**: GPT-4 deployment for AI processing
- **API Management**: Mock APIs for credit check, employment verification, etc.
- **Configuration**: All connection strings and API keys

### Settings Configured Automatically
- ✅ `sql_connectionString`
- ✅ `agent_openAIKey` & `agent_openAIEndpoint`
- ✅ `apiManagementOperation_*_SubscriptionKey` (all API keys)
- ✅ `approvalAgent-policyDocument-URI`
- ✅ Azure subscription and resource group settings

---

## ⚠️ Manual Setup Required: Microsoft 365 Connections

After running `deploy.ps1`, you must manually configure Microsoft 365 connections for:

### 1. Microsoft Forms (Loan Application Entry)
**Purpose**: Customer loan application submission
**Manual Steps Required**: Create form, configure connection

### 2. Microsoft Teams (Human Escalation)
**Purpose**: Loan officer notifications and approvals  
**Manual Steps Required**: Create team/channel, get IDs, configure connection

### 3. Microsoft Outlook (Email Notifications)
**Purpose**: Customer and internal email communications
**Manual Steps Required**: Configure primary and secondary email connections

---

## 📝 Step-by-Step Setup Process

### Phase 1: Microsoft Forms Setup
**Time Required**: ~10 minutes

1. **Create Loan Application Form**
   ```
   - Go to https://forms.microsoft.com
   - Create "Vehicle Loan Application" form
   - Add required fields (see form-fields-template.md)
   - Configure form settings (require sign-in)
   - Note the Form ID
   ```

### Phase 2: Microsoft Teams Setup  
**Time Required**: ~5 minutes

1. **Create Teams Workspace**
   ```
   - Create team: "Loan Processing Team"
   - Add channel: "Loan Approvals" 
   - Add team members (loan officers)
   ```

2. **Get Teams IDs**
   ```
   - Use browser method to get Team Group ID and Channel ID
   - Update local.settings.json with IDs
   ```

### Phase 3: Azure API Connections
**Time Required**: ~10 minutes

1. **Run Connection Creation Script**
   ```powershell
   .\create-connections.ps1
   ```
   This creates Azure API connections for:
   - microsoftforms-1
   - teams  
   - outlook-1 (primary)
   - outlook-2 (secondary)

2. **Authenticate Connections in Azure Portal**
   ```
   - Go to Azure Portal → Resource Group: ai-loan-agent-rg
   - For each connection: Click → Edit API Connection → Authorize
   - Sign in with Microsoft 365 account
   ```

### Phase 4: Update Configuration
**Time Required**: ~5 minutes

1. **Extract Connection Details**
   ```powershell
   .\helpers\get-connection-details.ps1
   ```

2. **Update local.settings.json**
   - All connection runtime URLs and keys
   - Teams Group ID and Channel ID
   - Form ID reference

---

## 🛠️ Available Scripts

All scripts are located in the `Deployment/` folder:

### Automated Scripts
- **`deploy.ps1`** - Main Azure infrastructure deployment
- **`create-connections.ps1`** - Creates Microsoft 365 API connections in Azure
- **`helpers/get-connection-details.ps1`** - Extracts connection details after authentication
- **`helpers/generate-runtime-urls.ps1`** - Generates connection runtime URLs

### Manual Process Helpers
- **`get-teams-ids-browser.md`** - Browser-based method to get Teams IDs
- **`form-fields-template.md`** - Required fields for Microsoft Forms

---

## 📋 Configuration Checklist

### ✅ Azure Infrastructure (Automated)
- [ ] Resource group created
- [ ] Storage account deployed
- [ ] SQL Server and database created
- [ ] OpenAI service configured
- [ ] API Management deployed
- [ ] All Azure settings populated in local.settings.json

### ⚠️ Microsoft 365 Connections (Manual)
- [ ] Microsoft Forms created with required fields
- [ ] Form ID documented
- [ ] Teams workspace created ("Loan Processing Team")
- [ ] Teams channel created ("Loan Approvals")  
- [ ] Teams Group ID extracted
- [ ] Teams Channel ID extracted
- [ ] Azure API connections created (4 total)
- [ ] All connections authenticated in Azure Portal
- [ ] Connection runtime URLs extracted
- [ ] Connection keys configured
- [ ] local.settings.json fully populated

### 🧪 Testing
- [ ] Form submission triggers workflow
- [ ] AI processing completes
- [ ] Teams notifications sent
- [ ] Email notifications sent
- [ ] Database records created

---

## 🔧 Troubleshooting

### Common Issues

**Connection Authentication Failures**
- Clear browser cache
- Use incognito mode for authentication
- Verify Microsoft 365 permissions

**Teams IDs Not Found**
- Ensure you're a member of the Teams workspace
- Use browser URL method as fallback
- Check channel permissions

**Form Not Triggering Workflow**
- Verify Form ID is correct
- Ensure form requires sign-in
- Check connection authentication status

### Getting Help

1. **Check Azure Portal**: Monitor deployment and connection status
2. **Review Logs**: Logic Apps run history for detailed error information
3. **Validate Settings**: Use provided scripts to verify configuration

---

## 📚 Documentation References

- **`database-setup.sql`** - Database schema and setup

---

## 🎯 Success Criteria

Your setup is complete when:

1. ✅ All Azure resources deployed successfully
2. ✅ All 10 Microsoft 365 connection settings configured in local.settings.json
3. ✅ Form submission triggers the Logic Apps workflow
4. ✅ Teams notifications sent for escalation scenarios
5. ✅ Email notifications sent for approvals/rejections
6. ✅ Database contains loan application records

**Estimated Total Setup Time**: 30-45 minutes after Azure deployment

---

*This guide ensures a smooth setup experience for all users deploying the AI Loan Agent sample.*