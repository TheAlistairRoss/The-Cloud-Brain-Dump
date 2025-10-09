@description('The name of the App Service Plan')
param appServicePlanName string

@description('The location where the App Service Plan will be deployed')
param location string

@description('The Logic App Workflow SKU')
@allowed(['WS1', 'WS2', 'WS3'])
param workflowSku string = 'WS1'

@description('The number of workers for the App Service Plan')
@minValue(1)
@maxValue(30)
param numberOfWorkers int = 1

@description('Whether to enable zone redundancy')
param zoneRedundant bool = false

@description('Tags to apply to the App Service Plan')
param tags object = {}

// SKU configuration mapping based on Azure Portal values
var skuConfig = {
  WS1: {
    tier: 'WorkflowStandard'
    name: 'WS1'
    workerSizeId: 3
  }
  WS2: {
    tier: 'WorkflowStandard'
    name: 'WS2'
    workerSizeId: 4
  }
  WS3: {
    tier: 'WorkflowStandard'
    name: 'WS3'
    workerSizeId: 5
  }
}

resource appServicePlan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: appServicePlanName
  location: location
  tags: tags
  kind: ''
  properties: {
    targetWorkerCount: numberOfWorkers
    targetWorkerSizeId: skuConfig[workflowSku].workerSizeId
    maximumElasticWorkerCount: 20
    zoneRedundant: zoneRedundant
  }
  sku: {
    tier: skuConfig[workflowSku].tier
    name: skuConfig[workflowSku].name
  }
}

@description('The resource ID of the App Service Plan')
output appServicePlanId string = appServicePlan.id

@description('The name of the App Service Plan')
output appServicePlanName string = appServicePlan.name

@description('The App Service Plan resource reference')
output appServicePlanReference object = appServicePlan
