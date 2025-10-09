@description('The name of the user assigned managed identity')
param identityName string

@description('The location where the managed identity will be deployed')
param location string

@description('Tags to apply to the managed identity resource')
param tags object = {}

resource userAssignedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: identityName
  location: location
  tags: tags
}

@description('The resource ID of the user assigned managed identity')
output identityId string = userAssignedIdentity.id

@description('The principal ID of the user assigned managed identity')
output principalId string = userAssignedIdentity.properties.principalId

@description('The client ID of the user assigned managed identity')
output clientId string = userAssignedIdentity.properties.clientId

@description('The resource reference for the managed identity')
output identityReference object = userAssignedIdentity
