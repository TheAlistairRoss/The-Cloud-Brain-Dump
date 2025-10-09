@description('The name of the Application Insights component')
param appInsightsName string

@description('The location where Application Insights will be deployed')
param location string

@description('Tags to apply to the Application Insights resource')
param tags object = {}

@description('Log Analytics workspace resource ID')
param workspaceResourceId string = ''

@description('Whether to disable local authentication')
param disableLocalAuth bool = true

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    Request_Source: 'IbizaWebAppExtensionCreate'
    Flow_Type: 'Redfield'
    WorkspaceResourceId: !empty(workspaceResourceId) ? workspaceResourceId : null
    DisableLocalAuth: disableLocalAuth
  }
}

@description('The resource ID of the Application Insights component')
output appInsightsId string = applicationInsights.id

@description('The connection string for Application Insights')
output connectionString string = applicationInsights.properties.ConnectionString

@description('The instrumentation key for Application Insights')
output instrumentationKey string = applicationInsights.properties.InstrumentationKey

@description('The Application Insights resource reference')
output appInsightsReference object = applicationInsights
