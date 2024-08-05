# Get-ThreatIndicatorsQuery

## Description
This function retrieves threat indicators based on the specified on filters.

## Syntax
```PowerShell
Get-ThreatIndicatorsQuery
       -SubscriptionId <String>
       -ResourceGroupName <String>
       -WorkspaceName <String>
       [-Ids <String>[]]
       [-IncludeDisabled <Bool>]
       [-Keywords <String>[]]
       [-MaxConfidence <Int32>]
       [-MaxValidUntil <String>]
       [-MinConfidence <Int32>]
       [-MinValidUntil <String>]
       [-PageSize <Int32>]
       [-PatternTypes <String>[]]
       [-SortByColumn <String>]
       [-SortByOrder <String>]
       [-Sources <String>[]]
       [-ThreatTypes <String>[]]
       [-ShowRateLimitMetrics]
       [-Scope <ContextModificationScope>]
       [-DefaultProfile <IAzureContextContainer>]
       [-WhatIf]
       [-Confirm]
       [<CommonParameters>]
```

```PowerShell
Get-ThreatIndicatorsQuery
       -SubscriptionId <String>
       -ResourceGroupName <String>
       -WorkspaceName <String>
       -SkipToken <String>
       [-ShowRateLimitMetrics]
       [-Scope <ContextModificationScope>]
       [-DefaultProfile <IAzureContextContainer>]
       [-WhatIf]
       [-Confirm]
       [<CommonParameters>]
```
## Parameters
|Name|Type |Description|
|--|--|--|
|SubscriptionId|string|The unique identifier of the subscription.|
|ResourceGroupName|string|The name of the resource group|
|WorkspaceName|string|The name of the Microsoft Sentinel workspace.indicators|
|ids|string[]|Ids of threat intelligence indicators|
|includeDisabled|boolean|Parameter to include/exclude disabled indicators |
|keywords|string[]|Keywords for searching threat intelligence indicators |
|maxConfidence|integer|Maximum confidence|
|maxValidUntil|string|End time for ValidUntil filter|
|minConfidence|integer|Minimum confidence|
|minValidUntil|string|Start time for ValidUntil filter|
|pageSize|integer|Page size|
|patternTypes|string[]|Pattern types|
|ShowRateLimitMetrics|switch|Returns the Rate limit metrics for measuring throttling|
|skipToken|string|Skip token|
|sortBy|ThreatIntelligenceSortingCriteria[] |Columns to sort by and sorting order |
|sources|string[]|Sources of threat intelligence indicators|
|threatTypes|string[]|Threat types of threat intelligence indicators|

## Examples

This gets 100 indicators from the workspace
```powershell
    $indicators = Get-ThreatIndicatorsQuery `
        -SubscriptionId "12345678-1234-1234-1234-1234567890ab" `
        -ResourceGroupName "MyResourceGroup" `
        -WorkspaceName "MyWorkspace"
```

This gets 100 indicators where the source equals "Microsoft Defender Threat Intelligence"
```powershell
    $indicators = Get-ThreatIndicatorsQuery `
        -SubscriptionId "12345678-1234-1234-1234-1234567890ab" `
        -ResourceGroupName "MyResourceGroup" `
        -WorkspaceName "MyWorkspace" `
        -Sources "Microsoft Defender Threat Intelligence"
```


