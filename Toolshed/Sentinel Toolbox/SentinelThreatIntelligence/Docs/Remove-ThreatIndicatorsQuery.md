### Remove-ThreatIndicatorsQuery

This function retrieves and deletes threat indicators based on the specified on filters.

#### Syntax
```PowerShell
Remove-ThreatIndicatorsQuery
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
       [-TotalToDelete<Int32>]
       [-ShowRateLimitMetrics]
       [-ShowProgress]
       [-Scope <ContextModificationScope>]
       [-DefaultProfile <IAzureContextContainer>]
       [-WhatIf]
       [-Confirm]
       [<CommonParameters>]
```

#### Parameters
|Name|Type |Description|

|SubscriptionId|string|The unique identifier of the subscription.|
|ResourceGroupName|string|The name of the resource group|
|WorkspaceName|string|The name of the Microsoft Sentinel workspace indicators|
|Ids|string[]|Ids of threat intelligence indicators|
|IncludeDisabled|boolean|Parameter to include/exclude disabled indicators |
|Keywords|string[]|Keywords for searching threat intelligence indicators |
|MaxConfidence|integer|Maximum confidence|
|MaxValidUntil|string|End time for ValidUntil filter|
|MinConfidence|integer|Minimum confidence|
|MinValidUntil|string|Start time for ValidUntil filter|
|PageSize|integer|Page size|
|PatternTypes|string[]|Pattern types|
|ShowRateLimitMetrics|switch|Returns the Rate limit metrics for measuring throttling|
|SkipToken|string|Skip token|
|SortBy|ThreatIntelligenceSortingCriteria[] |Columns to sort by and sorting order |
|Sources|string[]|Sources of threat intelligence indicators|
|ShowProgress|Switch|Displays the progress in the console. It displayed total fetched, deleted and failed.|
|ThreatTypes|string[]|Threat types of threat intelligence indicators|
|TotalToDelete|integer|Specifies the total number of indicators to delete. Default value is -1, which means delete all indicators.|


#### Examples

This will delete all threat intelligence indicators from the specified workspace
```powershell
    Remove-ThreatIndicatorsQuery `
        -SubscriptionId "12345678-1234-1234-1234-1234567890ab" `
        -ResourceGroupName "MyResourceGroup" `
        -WorkspaceName "MyWorkspace"
```

This will delete up to 10,000 threat intelligence indicators from the specified workspace with the source "Microsoft Defender Threat Intelligence"
```powershell
    $indicators = Get-ThreatIndicatorsQuery `
        -SubscriptionId "12345678-1234-1234-1234-1234567890ab" `
        -ResourceGroupName "MyResourceGroup" `
        -WorkspaceName "MyWorkspace" `
        -Sources "Microsoft Defender Threat Intelligence" `
        -TotalToDelete 10000
```


