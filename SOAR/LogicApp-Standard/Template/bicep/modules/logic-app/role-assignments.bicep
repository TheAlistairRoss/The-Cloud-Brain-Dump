@description('The principal ID of the managed identity')
param principalId string

@description('The name prefix for role assignments')
param namePrefix string

@description('The storage account name for storage role assignments')
param storageAccountName string

@description('The Application Insights resource name for monitoring role assignments')
param appInsightsName string

// Reference existing storage account
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: storageAccountName
}

// Reference existing Application Insights
resource appInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: appInsightsName
}

// Storage Blob Data Owner role (ba92f5b4-2d11-453d-a403-e96b0029c9fe)
resource storageBlobDataOwnerRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: storageAccount
  name: guid(subscription().id, resourceGroup().id, namePrefix, 'ba92f5b4-2d11-453d-a403-e96b0029c9fe')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe')
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}

// Storage Queue Data Contributor role (974c5e8b-45b9-4653-ba55-5f855dd0fb88)
resource storageQueueDataContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: storageAccount
  name: guid(subscription().id, resourceGroup().id, namePrefix, '974c5e8b-45b9-4653-ba55-5f855dd0fb88')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '974c5e8b-45b9-4653-ba55-5f855dd0fb88')
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}

// Storage Table Data Contributor role (0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3)
resource storageTableDataContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: storageAccount
  name: guid(subscription().id, resourceGroup().id, namePrefix, '0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3')
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}

// Monitoring Metrics Publisher role (3913510d-42f4-4e42-8a64-420c390055eb)
resource monitoringMetricsPublisherRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: appInsights
  name: guid(subscription().id, resourceGroup().id, namePrefix, '3913510d-42f4-4e42-8a64-420c390055eb')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '3913510d-42f4-4e42-8a64-420c390055eb')
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}
