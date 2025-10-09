# Azure Resource Naming Convention Reference

This document shows how resource names are generated from the base name parameter.

## Naming Pattern Variables
- **Base Name**: User-provided parameter (e.g., "contoso")
- **Environment**: dev, test, staging, or prod
- **Unique Suffix**: 6-character unique string based on resource group ID

## Resource Naming Conventions

| Resource Type | Convention | Example (baseName="contoso", env="dev") |
|---------------|------------|----------------------------------------|
| Logic App Standard | `{baseName}-la-{env}` | `contoso-la-dev` |
| Storage Account | `{baseName}st{env}{uniqueSuffix}` | `contosostdeva1b2c3` |
| Managed Identity | `{baseName}-mi-{env}` | `contoso-mi-dev` |
| Log Analytics Workspace | `{baseName}-law-{env}` | `contoso-law-dev` |
| Application Insights | `{baseName}-ai-{env}` | `contoso-ai-dev` |

## Naming Rules Compliance

✅ **Logic Apps**: 1-80 characters, alphanumeric and hyphens  
✅ **Storage Accounts**: 3-24 characters, lowercase alphanumeric only  
✅ **Managed Identity**: 3-128 characters, alphanumeric and hyphens  
✅ **Log Analytics**: 4-63 characters, alphanumeric and hyphens  
✅ **Application Insights**: 1-255 characters, alphanumeric and hyphens  

## Examples for Different Base Names

### Base Name: "contoso"
- Logic App: `contoso-la-dev`
- Storage: `contosostdeva1b2c3`
- Identity: `contoso-mi-dev`
- Log Analytics: `contoso-law-dev`
- App Insights: `contoso-ai-dev`

### Base Name: "mycompany"
- Logic App: `mycompany-la-prod`
- Storage: `mycompanystproda1b2c3`
- Identity: `mycompany-mi-prod`
- Log Analytics: `mycompany-law-prod`
- App Insights: `mycompany-ai-prod`

## Benefits
- ✅ Follows Microsoft Azure naming conventions
- ✅ Environment-specific naming
- ✅ Consistent pattern across all resources
- ✅ Avoids naming conflicts with unique suffixes
- ✅ Easy to identify resource relationships