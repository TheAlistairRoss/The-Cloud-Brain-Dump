
@description('Log Analytics Workspace Id')
param logAnalyticsWorkspaceId string

@description('Data Collection Endpoint Id')
param dataCollectionEndpointId string

@description('Name of the proxy server. This is added manually as the logs do not contain the source computer name. You will need to deploy one DCR per proxy server. NOTE: If you are deploying to an exisiting server with a DCR, ensure you delete the duplicate DCRs')
param ProxyName string

@description('Squid Log to be collected (access, cache)')
param collectLog array = [
  'access'
  'cache'
]

@description('Which Squid Proxy access logs results to exlude from ingestion. (ABORTED, ASYNC, CACHE, CF, CLIENT, DENIED, FAIL, HIT, IGNORED, IMS, INVALID, MEM, MISS, MODIFIED, NEGATIVE, NOFETCH, OFFLINE, REDIRECT, REFRESH, REPLY, SHARED, STALE, SWAPFAIL, TIMEOUT, TUNNEL, UNMODIFIED)')
param accessLogResultIncludeFilter array = [
  'ABORTED'
  'ASYNC'
  'CACHE'
  'CF'
  'CLIENT'
  'DENIED'
  'FAIL'
  'HIT'
  'IGNORED'
  'IMS'
  'INVALID'
  'MEM'
  'MISS'
  'MODIFIED'
  'NEGATIVE'
  'NOFETCH'
  'OFFLINE'
  'REDIRECT'
  'REFRESH'
  'REPLY'
  'SHARED'
  'STALE'
  'SWAPFAIL'
  'TIMEOUT'
  'TUNNEL'
  'UNMODIFIED'
]



var dataCollectionRuleNamePrefix = ((!empty(ProxyName)) ? 'SquidProxyLinux-${ProxyName}' : 'SquidProxyLinux')

var SquidProxyCustomTableName = 'SquidProxy_CL'

var accessLogTransform = 'let squidResultCodes = parse_json("${accessLogResultIncludeFilter}");\nsource\n| where split(extract(@\'^(\\d+\\.\\d+)\\s+(\\d+)\\s(\\S+)\\s([A-Z_]+)\', 4, RawData ), "_")[1]  in (squidResultCodes)\n| extend Log = "Access"\n| extend Computer = "${ProxyName}"'
var cacheLogTransform = 'source\n| extend Log = "Cache"\n| extend Computer = "${ProxyName}"'
var transforms = {
  access: accessLogTransform
  cache: cacheLogTransform
}

// Existing Log Analytics Workspace
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: logAnalyticsWorkspaceId
}

resource SquidProxyCustomTable 'Microsoft.OperationalInsights/workspaces/tables@2022-10-01' = {
  name: SquidProxyCustomTableName
  parent: logAnalyticsWorkspace
  properties: {
    plan: 'Analytics'
    schema: {
      columns: [
        {
          dataTypeHint: 'datetime'
          description: 'Time the of the event'
          name: 'TimeGenerated'
          type: 'datetime'
        }
        //log
        {
          dataTypeHint: 'string'
          description: 'Log type (Access or Cache)'
          name: 'Log'
          type: 'string'
        }
        //computer
        {
          dataTypeHint: 'string'
          description: 'Name of the Proxy Server'
          name: 'Computer'
          type: 'string'
        }
        //RawData
        {
          dataTypeHint: 'string'
          description: 'Raw log data'
          name: 'RawData'
          type: 'string'
        }
      ]
      description: 'This is a custom table for Squid Proxy logs. This is formatted as per the original method using the Log Analytics Agent.  '
      displayName: 'string'
      name: 'string'
    }
  }
}


// Deploys a Data Collection Rule for each log type
resource dataCollectionRule 'Microsoft.Insights/dataCollectionRules@2022-06-01' = [for item in collectLog: {
  name: '${dataCollectionRuleNamePrefix}-${item}'
  location: location
  kind: 'Linux'
  dependsOn: [
    SquidProxyCustomTable
  ]
  properties: {
    dataCollectionEndpointId: dataCollectionEndpointId
    streamDeclarations: {
      'Custom-Text-${SquidProxyCustomTableName}': {
        columns: [
          {
            name: 'TimeGenerated'
            type: 'datetime'
          }
          {
            name: 'RawData'
            type: 'string'
          }
        ]
      }
    }
    dataSources: {
      logFiles: [
        {
          streams: [
            'Custom-Text-${SquidProxyCustomTableName}'
          ]
          filePatterns: [
            '/var/log/squid/${item}.log'
          ]
          format: 'text'
          settings: {
            text: {
              recordStartTimestampFormat: 'ISO 8601'
            }
          }
          name: 'Custom-Text-${item}-${SquidProxyCustomTableName}'
        }
      ]
    }
    destinations: {
      logAnalytics: [
        {
          workspaceResourceId: logAnalyticsWorkspaceId
          name: 'logAnalyticsWorkspaceDestination'
        }
      ]
    }
    dataFlows: [
      {
        streams: [
          'Custom-Text-${SquidProxyCustomTableName}'
        ]
        destinations: [
          'logAnalyticsWorkspaceDestination'
        ]
        transformKql: transforms[item]
        outputStream: 'Custom-${SquidProxyCustomTableName}'
      }
    ]
  }
}
]

output resultcodes array = accessLogResultIncludeFilter
