# AI Loan Agent Deployment Prerequisites

Before running the deployment script, ensure you have the following installed and configured.

## Required Tools

### 1. PowerShell
- **Version**: PowerShell 5.1+ (Windows) or PowerShell 7.0+ (cross-platform)
- **Installation**: 
  - Windows: Included with Windows, or [install PowerShell 7+](https://learn.microsoft.com/powershell/scripting/install/installing-powershell-on-windows)
  - macOS: [Install PowerShell](https://learn.microsoft.com/powershell/scripting/install/installing-powershell-on-macos)
  - Linux: [Install PowerShell](https://learn.microsoft.com/powershell/scripting/install/installing-powershell-on-linux)

### 2. Azure PowerShell Module
- **Module**: Az
- **Installation**:
  ```powershell
  Install-Module -Name Az -AllowClobber -Scope CurrentUser
  ```
- **Verification**:
  ```powershell
  Get-Module -ListAvailable Az
  ```
- **Documentation**: [Install Azure PowerShell](https://learn.microsoft.com/powershell/azure/install-azure-powershell)

> **Note**: Azure PowerShell includes built-in Bicep support - no separate Bicep CLI installation needed!

## Azure Requirements

### 1. Azure Subscription
- Active Azure subscription with appropriate permissions
- Contributor or Owner role at the subscription or resource group level

### 2. Azure Authentication
- Login to Azure before running the deployment:
  ```powershell
  Connect-AzAccount
  ```
- Select the correct subscription if you have multiple:
  ```powershell
  Set-AzContext -SubscriptionId "<your-subscription-id>"
  ```

### 3. Azure OpenAI Access
- Access to Azure OpenAI service in your subscription
- The deployment will create OpenAI resources automatically

## Running the Deployment

### Basic Usage
```powershell
.\deploy.ps1 -ProjectName "my-loan-agent"
```

### With Target Region
```powershell
.\deploy.ps1 -ProjectName "my-loan-agent" -Location "eastus"
```

### With Tags
```powershell
.\deploy.ps1 `
    -ProjectName "my-loan-agent" `
    -Location "eastus" `
    -Tags @{
        Environment = 'Production'
        Owner = 'YourName'
        CostCenter = 'IT-1234'
        Project = 'AI-Loan-Agent'
        Department = 'Engineering'
    }
```

### Parameters

- **ProjectName** (required): Unique project name (3-15 characters, alphanumeric and hyphens)
- **Location** (optional): Azure region (default: `eastus2`)
  - Supported: `eastus`, `eastus2`, `southcentralus`, `swedencentral`, `francecentral`, `switzerlandnorth`, `uksouth`, `northeurope`, `westeurope`, `australiaeast`, `japaneast`, `eastasia`, `canadaeast`, `uaenorth`
- **Tags** (optional): Hashtable of resource tags

## Pre-Deployment Checklist

- [ ] PowerShell 5.1+ installed
- [ ] Azure PowerShell module (Az) installed
- [ ] Logged into Azure (`Connect-AzAccount`)
- [ ] Correct subscription selected
- [ ] Choose a unique project name (3-15 chars)
- [ ] Appropriate Azure permissions (Contributor or Owner)

## Quick Validation

Run these commands to verify your setup:

```powershell
# Check PowerShell version
$PSVersionTable.PSVersion

# Check Azure PowerShell
Get-Module -ListAvailable Az

# Check Azure login
Get-AzContext

# Check subscription
Get-AzSubscription
```

## Troubleshooting

### "Azure PowerShell not found"
- Run `Install-Module -Name Az -AllowClobber -Scope CurrentUser`
- Restart your terminal after installation

### "Not logged into Azure"
- Run `Connect-AzAccount`
- Verify with `Get-AzContext`

### "Insufficient permissions"
- Contact your Azure subscription administrator
- Requires Contributor or Owner role on the target resource group or subscription

### "Project name validation error"
- Must be 3-15 characters
- Only alphanumeric and hyphens allowed
- Example: `my-loan-agent`, `loan-demo-01`

## Additional Resources

- [Azure PowerShell Documentation](https://learn.microsoft.com/powershell/azure/)
- [Bicep in Azure PowerShell](https://learn.microsoft.com/azure/azure-resource-manager/bicep/deploy-powershell)
- [Azure Logic Apps Documentation](https://learn.microsoft.com/azure/logic-apps/)
- [Azure OpenAI Service Documentation](https://learn.microsoft.com/azure/ai-services/openai/)
