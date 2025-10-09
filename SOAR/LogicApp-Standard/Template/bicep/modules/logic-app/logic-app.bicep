@description('The name of the Logic App Standard instance')
param logicAppName string

@description('The location where the Logic App will be deployed')
param location string

@description('The server farm ID for the Logic App')
param serverFarmId string

@description('The managed identity resource ID')
param managedIdentityId string

@description('The client ID of the managed identity')
param managedIdentityClientId string

@description('Storage account blob service URI')
param storageAccountBlobUri string

@description('Storage account queue service URI')
param storageAccountQueueUri string

@description('Storage account table service URI')
param storageAccountTableUri string

@description('Application Insights connection string')
param appInsightsConnectionString string

@description('Storage account connection string for content share')
@secure()
param storageAccountConnectionString string

@description('Tags to apply to the Logic App resource')
param tags object = {}

@description('Content share name for the Logic App')
param contentShare string = toLower('${logicAppName}${uniqueString(resourceGroup().id)}')

resource logicApp 'Microsoft.Web/sites@2023-12-01' = {
  name: logicAppName
  kind: 'functionapp,workflowapp'
  location: location
  tags: tags
  properties: {
    siteConfig: {
      appSettings: [
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'dotnet'
        }
        {
          name: 'WEBSITE_NODE_DEFAULT_VERSION'
          value: '~20'
        }
        {
          name: 'APPLICATIONINSIGHTS_AUTHENTICATION_STRING'
          value: 'ClientId=${managedIdentityClientId};Authorization=AAD'
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsightsConnectionString
        }
        {
          name: 'AzureWebJobsStorage__credential'
          value: 'managedidentity'
        }
        {
          name: 'AzureWebJobsStorage__blobServiceUri'
          value: storageAccountBlobUri
        }
        {
          name: 'AzureWebJobsStorage__queueServiceUri'
          value: storageAccountQueueUri
        }
        {
          name: 'AzureWebJobsStorage__tableServiceUri'
          value: storageAccountTableUri
        }
        {
          name: 'AzureWebJobsStorage__managedIdentityResourceId'
          value: managedIdentityId
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: contentShare
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: storageAccountConnectionString
        }
        {
          name: 'AzureFunctionsJobHost__extensionBundle__id'
          value: 'Microsoft.Azure.Functions.ExtensionBundle.Workflows'
        }
        {
          name: 'AzureFunctionsJobHost__extensionBundle__version'
          value: '[1.*, 2.0.0)'
        }
        {
          name: 'APP_KIND'
          value: 'workflowApp'
        }
        {
          name: 'FUNCTIONS_INPROC_NET8_ENABLED'
          value: '1'
        }
      ]
      cors: {}
      use32BitWorkerProcess: false
      ftpsState: 'FtpsOnly'
      netFrameworkVersion: 'v6.0'
    }
    clientAffinityEnabled: false
    virtualNetworkSubnetId: null
    publicNetworkAccess: 'Enabled'
    httpsOnly: true
    serverFarmId: serverFarmId
  }
  identity: {
    type: 'SystemAssigned, UserAssigned'
    userAssignedIdentities: {
      '${managedIdentityId}': {}
    }
  }
}

resource logicAppScmPolicy 'Microsoft.Web/sites/basicPublishingCredentialsPolicies@2023-12-01' = {
  parent: logicApp
  name: 'scm'
  properties: {
    allow: false
  }
}

resource logicAppFtpPolicy 'Microsoft.Web/sites/basicPublishingCredentialsPolicies@2023-12-01' = {
  parent: logicApp
  name: 'ftp'
  properties: {
    allow: false
  }
}

@description('The resource ID of the Logic App')
output logicAppId string = logicApp.id

@description('The name of the Logic App')
output logicAppName string = logicApp.name

@description('The default hostname of the Logic App')
output defaultHostName string = logicApp.properties.defaultHostName

@description('The Logic App resource reference')
output logicAppReference object = logicApp
