### Get-ThreatIndicatorsMetrics

## Description
This function retrives the threat indicator metrics from the specified workspace.

#### Syntax

```PowerShell
Get-ThreatIndicatorsMetrics
       -SubscriptionId <String>
       -ResourceGroupName <String>
       -WorkspaceName <String>
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

#### Examples

This gets the threat indicator metrics for the workspace
```powershell
    Get-ThreatIndicatorsMetrics `
        -SubscriptionId "12345678-1234-1234-1234-1234567890ab" `
        -ResourceGroupName "MyResourceGroup" `
        -WorkspaceName "MyWorkspace"
```

