using './main.bicep'

param baseName = 'LogicAppStandardTemplate'
param location = resourceGroup().location
param environment = 'dev'
param hostingPlanId = '' // Leave empty to create new hosting plan
param workflowSku = 'WS1' // WS1, WS2, or WS3
param workspaceResourceId = ''
param tags = {}

