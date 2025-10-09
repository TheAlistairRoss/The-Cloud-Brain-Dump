@description('The name of the storage account')
param storageAccountName string

@description('The location where the storage account will be deployed')
param location string

@description('The SKU name for the storage account')
param skuName string = 'Standard_LRS'

@description('Tags to apply to the storage account')
param tags object = {}

@description('Whether to allow blob public access')
param allowBlobPublicAccess bool = false

@description('Whether to allow shared key access')
param allowSharedKeyAccess bool = true

@description('Public network access setting')
param publicNetworkAccess string = 'Enabled'

@description('Minimum TLS version')
param minimumTlsVersion string = 'TLS1_2'

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountName
  location: location
  tags: tags
  sku: {
    name: skuName
  }
  kind: 'StorageV2'
  properties: {
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: minimumTlsVersion
    defaultToOAuthAuthentication: true
    allowBlobPublicAccess: allowBlobPublicAccess
    allowSharedKeyAccess: allowSharedKeyAccess
    publicNetworkAccess: publicNetworkAccess
    accessTier: 'Hot'
  }
}

@description('The resource ID of the storage account')
output storageAccountId string = storageAccount.id

@description('The name of the storage account')
output storageAccountName string = storageAccount.name

@description('The blob service URI of the storage account')
output blobServiceUri string = 'https://${storageAccount.name}.blob.${environment().suffixes.storage}'

@description('The queue service URI of the storage account')
output queueServiceUri string = 'https://${storageAccount.name}.queue.${environment().suffixes.storage}'

@description('The table service URI of the storage account')
output tableServiceUri string = 'https://${storageAccount.name}.table.${environment().suffixes.storage}'

@description('The primary connection string of the storage account')
@secure()
output connectionString string = 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${storageAccount.listKeys().keys[0].value};EndpointSuffix=${environment().suffixes.storage}'

@description('The storage account resource reference')
output storageAccountReference object = storageAccount
