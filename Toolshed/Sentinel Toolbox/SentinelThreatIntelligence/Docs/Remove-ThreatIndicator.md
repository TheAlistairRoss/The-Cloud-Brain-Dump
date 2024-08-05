### Remove-ThreatIndicator

## Description
This function removes a single threat indicator from a specified workspace

#### Syntax
```PowerShell
Remove-ThreatIndicator
       -SubscriptionId <String>
       -ResourceGroupName <String>
       -WorkspaceName <String>
       -IndicatorName <String>
       [-ShowRateLimitMetrics]
       [-Scope <ContextModificationScope>]
       [-DefaultProfile <IAzureContextContainer>]
       [-WhatIf]
       [-Confirm]
       [<CommonParameters>]
```
#### Parameters
|Name|Type |Description|
|--|--|--|
|SubscriptionId|string|The unique identifier of the subscription.|
|ResourceGroupName|string|The name of the resource group|
|WorkspaceName|string|The name of the Microsoft Sentinel workspace.indicators|
|IndicatorName|string|Id of threat intelligence indicator|
|ShowRateLimitMetrics|switch|Returns the Rate limit metrics for measuring throttling|


#### Examples

Removes the indicator from the workspace
```powershell
    Remove-ThreatIndicator `
        -SubscriptionId "12345678-1234-1234-1234-1234567890ab" `
        -ResourceGroupName "MyResourceGroup" `
        -WorkspaceName "MyWorkspace" `
        -IndicatorName "12345678-1234-1234-1234-1234567890ab"
```

