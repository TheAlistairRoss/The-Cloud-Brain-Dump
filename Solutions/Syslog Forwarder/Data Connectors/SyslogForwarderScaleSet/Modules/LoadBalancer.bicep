param loadBalancerName string
param loadbalancingRuleFrontEndPort int
param loadbalancingRuleBackendEndPort int
param loadbalancingRuleProtocol string
param publicIpAddressName string
param publicIpAddressSku string
param publicIpAddressType string
param location string



resource loadBalancerName_publicip 'Microsoft.Network/publicIpAddresses@2020-08-01' = {
  name: '${loadBalancerName}-publicip'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
    idleTimeoutInMinutes: 15
  }
}

resource loadBalancer 'Microsoft.Network/loadBalancers@2021-05-01' = {
  name: loadBalancerName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    frontendIPConfigurations: [
      {
        name: '${take(loadBalancerName,(80-length('-frontendconfig01')))}-frontendconfig01'
        properties: {
          publicIPAddress: {
            id: loadBalancerName_publicip.id
          }
        }
      }
    ]
    backendAddressPools: [
      {
        name: '${take(loadBalancerName,(80-length('-backendpool01')))}-backendpool01'
      }
    ]
    loadBalancingRules: [
      {
        name: '${loadBalancerName}-lbrule01'
        properties: {
          frontendIPConfiguration: {
            id: resourceId(
              'Microsoft.Network/loadBalancers/frontendIPConfigurations',
              loadBalancerName,
              '${take(loadBalancerName,(80-length('-frontendconfig01')))}-frontendconfig01'
            )
          }
          backendAddressPool: {
            id: resourceId(
              'Microsoft.Network/loadBalancers/backendAddressPools',
              loadBalancerName,
              '${take(loadBalancerName,(80-length('-backendpool01')))}-backendpool01'
            )
          }
          frontendPort: loadbalancingRuleFrontEndPort
          backendPort: loadbalancingRuleBackendEndPort
          enableFloatingIP: false
          idleTimeoutInMinutes: 15
          disableOutboundSnat: true
          loadDistribution: 'Default'
          protocol: loadbalancingRuleProtocol
          probe: {
            id: resourceId('Microsoft.Network/loadBalancers/probes', loadBalancerName, '${loadBalancerName}-probe01')
          }
        }
      }
    ]
    probes: [
      {
        name: '${loadBalancerName}-probe01'
        properties: {
          intervalInSeconds: 15
          numberOfProbes: 2
          requestPath: ((loadbalancingRuleProtocol == 'Tcp') ? json('null') : '/')
          port: ((loadbalancingRuleProtocol == 'Tcp') ? loadbalancingRuleBackendEndPort : '80')
          protocol: ((loadbalancingRuleProtocol == 'Tcp') ? 'Tcp' : 'Http')
        }
      }
    ]
  }
  dependsOn: [
    'Microsoft.Network/publicIpAddresses/${loadBalancerName}-publicip'
  ]
}

resource publicIpAddress 'Microsoft.Network/publicIpAddresses@2020-08-01' = {
  name: publicIpAddressName
  location: location
  sku: {
    name: publicIpAddressSku
  }
  properties: {
    publicIPAllocationMethod: publicIpAddressType
  }
}
