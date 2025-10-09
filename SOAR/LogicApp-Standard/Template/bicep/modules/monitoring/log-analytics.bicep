@description('The name of the Log Analytics workspace')
param workspaceName string

@description('The location where the Log Analytics workspace will be deployed')
param location string

@description('Tags to apply to the Log Analytics workspace')
param tags object = {}

@description('The SKU name for the Log Analytics workspace')
param skuName string = 'PerGB2018'

@description('The data retention period in days (30-730 days)')
@minValue(30)
@maxValue(730)
param retentionInDays int = 30

@description('Whether to enable daily quota and limit ingestion')
param enableDailyQuota bool = false

@description('Daily quota in GB (only used if enableDailyQuota is true)')
@minValue(1)
param dailyQuotaGb int = 1

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: workspaceName
  location: location
  tags: tags
  properties: {
    sku: {
      name: skuName
    }
    retentionInDays: retentionInDays
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
    workspaceCapping: enableDailyQuota ? {
      dailyQuotaGb: dailyQuotaGb
    } : null
  }
}

@description('The resource ID of the Log Analytics workspace')
output workspaceId string = logAnalyticsWorkspace.id

@description('The name of the Log Analytics workspace')
output workspaceName string = logAnalyticsWorkspace.name

@description('The customer ID of the Log Analytics workspace')
output customerId string = logAnalyticsWorkspace.properties.customerId

@description('The Log Analytics workspace resource reference')
output workspaceReference object = logAnalyticsWorkspace
