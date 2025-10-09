# Azure Logic App Standard Template

A comprehensive Azure Bicep template for deploying Logic App Standard with all supporting infrastructure, following Azure best practices and naming conventions.

## Overview

This template deploys a complete Logic App Standard environment including:

- **Logic App Standard** - Serverless workflow platform
- **Storage Account** - Required for Logic App runtime with intelligent 24-character naming
- **User-Assigned Managed Identity** - Secure authentication across resources
- **Application Insights** - Application performance monitoring
- **Log Analytics Workspace** - Centralized logging (optional)
- **App Service Plan** - Hosting infrastructure (optional, WS1/WS2/WS3 SKUs)
- **Role Assignments** - Proper RBAC permissions for secure access

## Architecture

The template uses a modular architecture with the following structure:

```
bicep/
├── main.bicep                           # Main orchestration template
└── modules/
    ├── identity/
    │   └── managed-identity.bicep       # User-assigned managed identity
    ├── storage/
    │   └── storage-account.bicep        # Storage with secure connection strings
    ├── hosting/
    │   └── app-service-plan.bicep       # Optional App Service Plan
    ├── monitoring/
    │   ├── log-analytics.bicep          # Optional Log Analytics workspace
    │   └── application-insights.bicep   # Application Insights
    └── logic-app/
        ├── logic-app.bicep              # Logic App Standard configuration
        └── role-assignments.bicep       # RBAC permissions
```

## Features

- ✅ **Modular Architecture** - Reusable, maintainable components
- ✅ **Azure Naming Conventions** - Follows Microsoft recommended naming standards
- ✅ **Intelligent Storage Naming** - Automatic trimming for 24-character storage account limits
- ✅ **Conditional Deployment** - Optional App Service Plan and Log Analytics workspace
- ✅ **Secure by Default** - Managed identity authentication, proper RBAC
- ✅ **Professional Deployment Scripts** - PowerShell automation with comprehensive logging
- ✅ **ARM Template Support** - Bicep compilation to ARM JSON for legacy systems
- ✅ **Unique Deployment Names** - Trackable module deployments with descriptive suffixes

## Quick Deploy

### Deploy to Azure Portal

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FTheAlistairRoss%2FThe-Cloud-Brain-Dump%2Fmain%2FSOAR%2FLogicApp-Standard%2FTemplate%2Farm%2FazureDeploy.json)

### Required Parameters

| Parameter | Description | Example | Required |
|-----------|-------------|---------|----------|
| `baseName` | Base name for all resources | `my-logicapp` | ✅ |
| `location` | Azure region | `UK South` | ✅ |
| `environment` | Environment suffix | `test`, `dev`, `prod` | ✅ |

### Optional Parameters

| Parameter | Description | Default | Options |
|-----------|-------------|---------|---------|
| `hostingPlanId` | Existing App Service Plan ID | `""` (creates new) | Resource ID |
| `workflowSku` | Logic App SKU (if creating new plan) | `WS1` | `WS1`, `WS2`, `WS3` |
| `workspaceResourceId` | Existing Log Analytics workspace ID | `""` (creates new) | Resource ID |
| `tags` | Resource tags | `{}` | Key-value pairs |

## Deployment Options

### Option 1: PowerShell Script (Recommended)

#### Prerequisites
- PowerShell 7.0+
- Azure PowerShell module (`Az.Accounts`, `Az.Resources`)
- Azure CLI with Bicep extension OR standalone Bicep CLI

#### Basic Deployment
```powershell
# Clone the repository
git clone <repository-url>
cd SOAR\LogicApp-Standard\Template

# Deploy with default settings
.\..\..\Toolshed\Scripts\Deploy-BicepTemplate.ps1 `
    -SubscriptionId "your-subscription-id" `
    -ResourceGroupName "my-logicapp-rg" `
    -BicepFile "bicep\main.bicep" `
    -ParameterFile ".local\main.bicepparam"
```

#### Custom Deployment
```powershell
# Deploy with custom parameters
.\..\..\Toolshed\Scripts\Deploy-BicepTemplate.ps1 `
    -SubscriptionId "12345678-1234-1234-1234-123456789012" `
    -ResourceGroupName "production-logicapp-rg" `
    -BicepFile "bicep\main.bicep" `
    -DeploymentName "LogicApp-Production-$(Get-Date -Format 'yyyyMMdd-HHmmss')" `
    -Location "UK South" `
    -Tags @{
        Environment = "Production"
        Owner = "Platform Team"
        CostCenter = "IT-001"
    }
```

#### What-If Deployment (Preview Changes)
```powershell
# Preview changes without deploying
.\..\..\Toolshed\Scripts\Deploy-BicepTemplate.ps1 `
    -SubscriptionId "your-subscription-id" `
    -ResourceGroupName "my-logicapp-rg" `
    -BicepFile "bicep\main.bicep" `
    -ParameterFile ".local\main.bicepparam" `
    -WhatIf
```

### Option 2: Azure CLI

#### Prerequisites
- Azure CLI 2.20.0+
- Bicep extension: `az extension add --name bicep`

#### Basic Deployment
```bash
# Login to Azure
az login

# Set subscription
az account set --subscription "your-subscription-id"

# Create resource group
az group create --name "my-logicapp-rg" --location "UK South"

# Deploy template
az deployment group create \
    --resource-group "my-logicapp-rg" \
    --template-file "bicep/main.bicep" \
    --parameters "@.local/main.bicepparam"
```

#### Custom Parameters
```bash
# Deploy with inline parameters
az deployment group create \
    --resource-group "my-logicapp-rg" \
    --template-file "bicep/main.bicep" \
    --parameters \
        baseName="my-production-app" \
        environment="prod" \
        location="UK South" \
        workflowSku="WS2"
```

### Option 3: ARM Template Deployment

#### Build ARM Template
```powershell
# Generate ARM template from Bicep
.\..\..\Toolshed\Scripts\Build-ArmTemplates.ps1 -BicepFile "bicep\main.bicep"

# Deploy using ARM template
New-AzResourceGroupDeployment `
    -ResourceGroupName "my-logicapp-rg" `
    -TemplateFile "arm\azureDeploy.json" `
    -baseName "my-logicapp" `
    -environment "test" `
    -location "UK South"
```

## Parameter File Configuration

Create a parameter file (`.local/main.bicepparam`) for your environment:

```bicep
using './bicep/main.bicep'

// Required parameters
param baseName = 'my-logicapp'
param environment = 'test'
param location = 'UK South'

// Optional parameters
param workflowSku = 'WS1'
param tags = {
  Environment: 'Test'
  Owner: 'Development Team'
  Project: 'MyProject'
}

// Use existing resources (optional)
// param hostingPlanId = '/subscriptions/.../resourceGroups/.../providers/Microsoft.Web/serverfarms/existing-plan'
// param workspaceResourceId = '/subscriptions/.../resourceGroups/.../providers/Microsoft.OperationalInsights/workspaces/existing-workspace'
```

## Generated Resources

After deployment, you'll have the following resources:

| Resource Type | Naming Convention | Example |
|---------------|-------------------|---------|
| Logic App | `{baseName}-la-{env}` | `my-logicapp-la-test` |
| Storage Account | `{baseName}st{env}{uniqueString}` | `myappsttest7x8k2m9n` |
| Managed Identity | `{baseName}-mi-{env}` | `my-logicapp-mi-test` |
| App Service Plan | `{baseName}-asp-{env}` | `my-logicapp-asp-test` |
| Application Insights | `{baseName}-ai-{env}` | `my-logicapp-ai-test` |
| Log Analytics | `{baseName}-law-{env}` | `my-logicapp-law-test` |

## Outputs

The template provides the following outputs for integration with other systems:

```json
{
  "logicAppId": "/subscriptions/.../resourceGroups/.../providers/Microsoft.Web/sites/my-logicapp-la-test",
  "logicAppName": "my-logicapp-la-test",
  "logicAppHostname": "my-logicapp-la-test.azurewebsites.net",
  "storageAccountId": "/subscriptions/.../resourceGroups/.../providers/Microsoft.Storage/storageAccounts/...",
  "managedIdentityId": "/subscriptions/.../resourceGroups/.../providers/Microsoft.ManagedIdentity/userAssignedIdentities/...",
  "appInsightsId": "/subscriptions/.../resourceGroups/.../providers/Microsoft.Insights/components/...",
  "logAnalyticsWorkspaceId": "/subscriptions/.../resourceGroups/.../providers/Microsoft.OperationalInsights/workspaces/...",
  "hostingPlanId": "/subscriptions/.../resourceGroups/.../providers/Microsoft.Web/serverfarms/..."
}
```

## Security Features

- **Managed Identity Authentication** - No connection strings or passwords
- **RBAC Permissions** - Least privilege access to resources
- **Secure Storage** - Connection strings secured using Key Vault references
- **Network Security** - Optional VNET integration support
- **Monitoring** - Application Insights for security monitoring

## Monitoring and Observability

The template includes comprehensive monitoring:

- **Application Insights** - Performance monitoring, dependency tracking
- **Log Analytics** - Centralized logging and querying
- **Built-in Metrics** - Logic App execution metrics
- **Custom Dashboards** - Ready for Azure Monitor workbooks

## CI/CD Integration

### Azure DevOps
```yaml
- task: AzureResourceManagerTemplateDeployment@3
  inputs:
    deploymentScope: 'Resource Group'
    azureResourceManagerConnection: 'Azure-ServiceConnection'
    subscriptionId: '$(subscriptionId)'
    action: 'Create Or Update Resource Group'
    resourceGroupName: '$(resourceGroupName)'
    location: '$(location)'
    templateLocation: 'Linked artifact'
    csmFile: 'SOAR/LogicApp-Standard/Template/arm/azureDeploy.json'
    csmParametersFile: 'SOAR/LogicApp-Standard/Template/arm/azureDeploy.parameters.json'
    deploymentMode: 'Incremental'
```

### GitHub Actions
```yaml
- name: Deploy ARM Template
  uses: azure/arm-deploy@v1
  with:
    subscriptionId: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
    resourceGroupName: ${{ env.RESOURCE_GROUP_NAME }}
    template: SOAR/LogicApp-Standard/Template/arm/azureDeploy.json
    parameters: SOAR/LogicApp-Standard/Template/arm/azureDeploy.parameters.json
```

## Troubleshooting

### Common Issues

1. **Storage Account Name Conflicts**
   - The template uses intelligent naming with unique suffixes
   - Storage names are automatically trimmed to 24 characters

2. **Permission Errors**
   - Ensure your account has Owner or Contributor and User Access Administrator roles to the resource group
   - Check subscription limits for the chosen region

3. **Bicep CLI Not Found**
   - Install Azure CLI with Bicep extension: `az extension add --name bicep`
   - Or install standalone Bicep CLI

4. **Parameter File Errors**
   - Use literal values instead of functions like `resourceGroup().location`
   - Validate parameter file syntax with Bicep CLI

### Enable Debug Logging
```powershell
# Enable verbose logging
.\..\..\Toolshed\Scripts\Deploy-BicepTemplate.ps1 `
    -SubscriptionId "your-subscription-id" `
    -ResourceGroupName "my-logicapp-rg" `
    -BicepFile "bicep\main.bicep" `
    -ParameterFile ".local\main.bicepparam" `
    -Verbose
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes following the established patterns
4. Test deployment in a development environment
5. Submit a pull request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

For issues and questions:
- Create an issue in this repository
- Check the [troubleshooting section](#troubleshooting)
- Review Azure documentation for Logic Apps Standard

---

**Author**: theAlistairRoss and Github Copilot
**Version**: 1.0.0  
**Last Updated**: October 9, 2025