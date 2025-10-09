targetScope = 'resourceGroup'

@metadata({
  version: '1.0.0'
  author: 'Azure Infrastructure Team'
  lastUpdated: '2025-10-09'
})

// ========== User-Defined Types ==========
// User-defined types removed - Logic App configuration is now hardcoded in module

// ========== Parameters ==========
@description('The base name for all resources (will be used to generate specific resource names)')
@minLength(3)
@maxLength(50) // Reasonable length for most Azure resources
param baseName string

@description('The location where all resources will be deployed')
param location string = resourceGroup().location

@description('Environment suffix (e.g. dev, prod, qa, stage, test)')
@allowed(['dev', 'prod', 'qa', 'stage', 'test'])
param environment string = 'dev'

@description('Existing hosting plan resource ID (optional - will create new hosting plan if not provided)')
param hostingPlanId string = ''

@description('Logic App Workflow SKU (only used when creating new hosting plan)')
@allowed(['WS1', 'WS2', 'WS3'])
param workflowSku string = 'WS1'

@description('Log Analytics workspace resource ID for Application Insights (optional - will create new workspace if not provided)')
param workspaceResourceId string = ''

@description('Tags to apply to all resources')
param tags object = {}

// ========== Variables ==========
// Azure resource naming conventions following Microsoft recommendations
var baseNameLower = toLower(baseName)
var envSuffix = environment
var uniqueSuffix = uniqueString(resourceGroup().id) // 13 characters

// For storage accounts: intelligent trimming to fit 24-char limit (alphanumeric only)
var baseNameClean = replace(replace(replace(baseNameLower, '-', ''), '_', ''), ' ', '') // Remove hyphens, underscores, spaces
var envTrimmed = take(envSuffix, 4) // Trim environment to max 4 chars
var availableCharsForBaseName = 24 - 2 - length(envTrimmed) - length(uniqueSuffix) // 24 - 'st' - env - unique = remaining chars
var baseNameTrimmed = take(baseNameClean, availableCharsForBaseName)

// Resource names following Azure naming conventions
var logicAppName = '${baseNameLower}-la-${envSuffix}'
var storageAccountName = '${baseNameTrimmed}st${envTrimmed}${uniqueSuffix}' // Intelligently trimmed for 24-char limit (alphanumeric only)
var userAssignedIdentityName = '${baseNameLower}-mi-${envSuffix}'
var logAnalyticsWorkspaceName = '${baseNameLower}-law-${envSuffix}'
var appInsightsName = '${baseNameLower}-ai-${envSuffix}'
var hostingPlanName = '${baseNameLower}-asp-${envSuffix}'

var serverFarmId = !empty(hostingPlanId) ? hostingPlanId : hostingPlan.?outputs.?appServicePlanId ?? ''

// ========== Module Deployments ==========

// Deploy Managed Identity
module identity './modules/identity/managed-identity.bicep' = {
  name: '${deployment().name}-Identity'
  params: {
    identityName: userAssignedIdentityName
    location: location
    tags: tags
  }
}

// Deploy Storage Account
module storage './modules/storage/storage-account.bicep' = {
  name: '${deployment().name}-Storage'
  params: {
    storageAccountName: storageAccountName
    location: location
    tags: tags
  }
}

// Deploy App Service Plan (if hosting plan ID is not provided)
module hostingPlan './modules/hosting/app-service-plan.bicep' = if (empty(hostingPlanId)) {
  name: '${deployment().name}-HostingPlan'
  params: {
    appServicePlanName: hostingPlanName
    location: location
    workflowSku: workflowSku
    numberOfWorkers: 1
    tags: tags
  }
}

// Deploy Log Analytics workspace (if workspace resource ID is not provided)
module logAnalytics './modules/monitoring/log-analytics.bicep' = if (empty(workspaceResourceId)) {
  name: '${deployment().name}-LogAnalytics'
  params: {
    workspaceName: logAnalyticsWorkspaceName
    location: location
    tags: tags
  }
}

// Deploy Application Insights
module monitoring './modules/monitoring/application-insights.bicep' = {
  name: '${deployment().name}-Monitoring'
  params: {
    appInsightsName: appInsightsName
    location: location
    tags: tags
    workspaceResourceId: !empty(workspaceResourceId) ? workspaceResourceId : logAnalytics.?outputs.?workspaceId ?? ''
  }
}

// Deploy Logic App
module logicApp './modules/logic-app/logic-app.bicep' = {
  name: '${deployment().name}-LogicApp'
  params: {
    logicAppName: logicAppName
    location: location
    serverFarmId: serverFarmId
    managedIdentityId: identity.outputs.identityId
    managedIdentityClientId: identity.outputs.clientId
    storageAccountBlobUri: storage.outputs.blobServiceUri
    storageAccountQueueUri: storage.outputs.queueServiceUri
    storageAccountTableUri: storage.outputs.tableServiceUri
    storageAccountConnectionString: storage.outputs.connectionString
    appInsightsConnectionString: monitoring.outputs.connectionString
    tags: tags
  }
}

// Deploy Role Assignments
module roleAssignments './modules/logic-app/role-assignments.bicep' = {
  name: '${deployment().name}-RoleAssignments'
  params: {
    principalId: identity.outputs.principalId
    namePrefix: logicAppName
    storageAccountName: storageAccountName
    appInsightsName: appInsightsName
  }
  dependsOn: [
    storage
    monitoring
  ]
}

// ========== Outputs ==========
@description('The resource ID of the Logic App')
output logicAppId string = logicApp.outputs.logicAppId

@description('The name of the Logic App')
output logicAppName string = logicApp.outputs.logicAppName

@description('The default hostname of the Logic App')
output logicAppHostname string = logicApp.outputs.defaultHostName

@description('The resource ID of the storage account')
output storageAccountId string = storage.outputs.storageAccountId

@description('The resource ID of the managed identity')
output managedIdentityId string = identity.outputs.identityId

@description('The resource ID of Application Insights')
output appInsightsId string = monitoring.outputs.appInsightsId

@description('The resource ID of the Log Analytics workspace (if created)')
output logAnalyticsWorkspaceId string = logAnalytics.?outputs.?workspaceId ?? ''

@description('The resource ID of the hosting plan (if created)')
output hostingPlanId string = hostingPlan.?outputs.?appServicePlanId ?? hostingPlanId
