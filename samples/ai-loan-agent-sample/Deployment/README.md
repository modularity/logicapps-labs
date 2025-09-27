# AI Loan Agent - Infrastructure Deployment Guide

This guide provides automated deployment scripts for the prerequisite Azure infrastructure required by the AI Loan Agent sample.

## Overview

The AI Loan Agent is an AI-powered loan approval system that automates vehicle loan application evaluation using Azure Logic Apps Standard and Azure OpenAI. The system processes applications from Microsoft Forms, performs comprehensive risk assessments, and routes decisions through AI agents with human escalation when needed.

## Required Azure Services

- **Azure Logic Apps Standard** - Workflow orchestration platform
- **Azure OpenAI Service** - AI agent with GPT-4 deployment for loan decisions
- **Azure SQL Database** - Customer history and special vehicle data storage
- **Azure API Management** - Four APIs for risk assessment, credit check, employment verification, and demographics
- **Microsoft Forms** - Loan application submission interface
- **Microsoft Teams** - Human agent notification and approval workflow
- **Microsoft Outlook** - Email notifications and communications
- **Azure Storage Account** - Workflow runtime storage
- **Azure Blob Storage** - Policy document storage

## 🚀 Quick Start

### 1. Deploy Azure Infrastructure
```powershell
.\deploy.ps1
```
**What it creates**: Logic Apps, Azure OpenAI, SQL Database, API Management, Storage, Blob containers

### 2. Setup Database Schema and Data
**Method 1: Azure Portal (Recommended)**
1. Navigate to Azure Portal → Resource Groups → ai-loan-agent-rg → [your-sql-server] → [your-database]
2. Click **Query Editor (preview)** in the left menu
3. Authenticate with **Microsoft Entra ID** (configured automatically by deploy.ps1)
4. Copy and paste the entire contents of `database-setup.sql`
5. Click **Run** to execute the script

**Method 2: sqlcmd Command Line**
```powershell
# From the Deployment folder:
sqlcmd -S [your-sql-server].database.windows.net -d [your-database] -G -i database-setup.sql
```

**What it creates**: 
- CustomersBankHistory table with 8 sample customer records
- SpecialVehicles table with 27 special vehicle records (5 Custom, 9 Limited, 13 Luxury)
- Required for AI agent tools: customer lookup and special vehicle validation

**Expected Output**: Database statistics showing record counts by category

### 3. Grant Microsoft Graph Permissions
**Required for Microsoft 365 integrations (Forms, Teams, Outlook)**

#### Option A: PowerShell Script (Recommended)
```powershell
# Get your Logic App's Principal ID from Azure Portal:
# Logic App → Identity → System assigned → Object (principal) ID

.\grant-graph-permissions.ps1 -ManagedIdentityPrincipalId "YOUR-PRINCIPAL-ID"
```

#### Option B: Azure Portal Method
1. **Navigate to Microsoft Entra ID**
   ```
   Portal → Microsoft Entra ID → Enterprise applications
   → Application type: "Managed Identity"
   → Search: "ai-loan-agent-logicapp"
   ```

2. **Grant App Role Assignments**
   ```
   → Users and groups → Add user/group
   → Select "Microsoft Graph" as the application
   → Assign required roles:
     - Group.ReadWrite.All (Teams)
     - Channel.ReadBasic.All (Teams)
     - Mail.Send (Outlook)
     - Mail.ReadWrite (Outlook)
   ```

**Prerequisites**: Global Administrator or Privileged Role Administrator permissions in Microsoft Entra ID

### 4. Authorize API Connections
```
Azure Portal → Resource Groups → ai-loan-agent-rg
→ microsoftforms-1 → Edit API Connection → Authorize
→ teams → Edit API Connection → Authorize  
→ outlook → Edit API Connection → Authorize
```

### 5. Deploy Logic Apps to Azure
- Open VS Code with the LogicApps folder
- Use Azure Logic Apps extension to deploy workflows

### 6. Complete Microsoft 365 Setup
**Follow the comprehensive guide**: **[SETUPCONNECTIONS.md](SETUPCONNECTIONS.md)**
- Create Microsoft Forms with required fields
- Setup Teams workspace and get IDs  
- Configure Outlook for notifications

## 📚 Available Files

### Deployment Scripts
- **`deploy.ps1`** - 🔥 **Main Azure infrastructure deployment** (Run First)
- **`database-setup.sql`** - 📊 **Database schema and sample data** (Run Second)  
- **`grant-graph-permissions.ps1`** - 🔐 **Grant Microsoft Graph permissions** (Run Third)

### Logic Apps Support Scripts
- **`update-local-settings.ps1`** - Fix policy document URL mapping and ensure all settings are present

### Connection Setup Scripts
- **`SETUPCONNECTIONS.md`** - 📋 **Complete setup guide** (START HERE)
- **`create-connections.ps1`** - Automated connection creation script
- **`helpers/get-connection-details.ps1`** - Extract connection configuration
- **`helpers/generate-runtime-urls.ps1`** - Generate connection URLs

### Setup Helpers
- **`FORM-FIELDS-TEMPLATE.md`** - Microsoft Forms field requirements
- **`GET-TEAMS-IDS-BROWSER.md`** - Browser method for Teams IDs

### Validation & Troubleshooting
- **`database-setup.sql`** - Database schema setup
- **`SESSION-HANDOFF.md`** - Session documentation Any |

## Configuration Values

After deployment, the scripts will output all necessary configuration values for your `local.settings.json` file, including:

- Azure OpenAI endpoint and keys
- SQL connection strings
- API Management subscription keys
- Storage account connection strings
- Blob storage SAS URLs

## Microsoft 365 Setup

### Microsoft Forms
Create a form with these required fields:
- Name, Date of Birth, SSN, Email
- Employer, Salary, Years in Role
- Loan Amount, Vehicle Make

### Microsoft Teams
Configure a Teams channel for loan approval notifications and collect:
- Teams Group ID
- Teams Channel ID

### Outlook
Set up Outlook connections for customer email notifications.

## Security Considerations

- **Microsoft Graph Permissions**: Logic Apps managed identity requires specific Graph permissions for Microsoft 365 integrations
- **Microsoft Entra ID**: Requires Global Administrator or Privileged Role Administrator to grant Graph permissions
- **API Connection Authorization**: Each Microsoft 365 connection (Forms, Teams, Outlook) must be individually authorized
- SQL Database has firewall rules configured for Azure services only
- API Management includes subscription key authentication
- Storage accounts use managed identity where possible
- Consider using Azure Key Vault for production deployments

## Troubleshooting

### Common Issues
- **SQL Authentication Failed**: "Client IP not allowed" or "Login failed for token-identified principal"
  - **Solution**: Run deploy.ps1 which automatically configures Microsoft Entra ID authentication and firewall rules
  - **Manual Fix**: Azure Portal → SQL Server → Firewall → Add your IP address
- **Missing database tables**: "SQL query failed" - Run `database-setup.sql` script first using Query Editor
- **Microsoft Graph permissions**: "Access Policies are missing" - Run `grant-graph-permissions.ps1` or use portal method
- **API connection authorization**: "Unauthorized" errors - Authorize each connection in Azure Portal
- **Microsoft Entra ID permissions**: Ensure you have Global Admin or Privileged Role Admin permissions
- **API Management timeouts**: Deployment can take 30-45 minutes
- **SQL connection failures**: Verify firewall rules and Microsoft Entra ID admin is set
- **OpenAI quota limits**: Check deployment status and available quota
- **Logic App deployment**: Ensure storage account is accessible

### Getting Help
- Review deployment script output for specific errors
- Check Azure portal for resource deployment status
- Verify Azure CLI is properly authenticated
- Ensure sufficient permissions in target subscription

## Cleanup

To remove all deployed resources:

```powershell
az group delete --name "ai-loan-agent-rg" --yes --no-wait
```

## Next Steps

1. **Review deployment output** - Check configuration values from `deploy.ps1`
2. **Setup database** - Run `database-setup.sql` to create required tables and sample data
3. **Grant Microsoft Graph permissions** - Use `grant-graph-permissions.ps1` or portal method
4. **Authorize API connections** - Authorize Microsoft 365 services in Azure Portal
5. **Deploy Logic Apps** - Use VS Code Azure Logic Apps extension  
6. **Configure Microsoft 365** - Follow [SETUPCONNECTIONS.md](SETUPCONNECTIONS.md) for Forms/Teams setup
7. **Test end-to-end** - Submit a loan application through Microsoft Forms

---

**Note**: These deployment scripts create resources that incur Azure costs. Review pricing for each service and adjust SKUs based on your requirements.

---

**Note**: These deployment scripts create resources that incur Azure costs. Review pricing for each service and adjust SKUs based on your requirements.