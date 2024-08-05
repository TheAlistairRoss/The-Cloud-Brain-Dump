#region Internal Functions

<#
.SYNOPSIS
    Retrieves the rate limit metrics from the response headers.

.DESCRIPTION
    This function retrieves the rate limit metrics from the response headers and returns them as a PSObject.

.PARAMETER Headers
    The response headers containing the rate limit metrics.

.EXAMPLE
    $Response = Invoke-AzRestMethod -Uri $uri -Method GET -Headers $requestHeaders
    $rateLimitMetrics = Get-RateLimitMetrics -Headers $Response.Headers

    This example demonstrates how to retrieve the rate limit metrics from the response headers.

#>
function Get-RateLimitMetrics {
    param(
        [parameter(Mandatory = $true)]
        $Headers
    )

    if ($null -eq $Headers) {
        Write-Error -Message "Headers are null"
        exit 1
    }
    
    $PropertyKeys = @(
        "x-ms-ratelimit-remaining-subscription-reads"
        "x-ms-ratelimit-remaining-subscription-global-reads"
        "x-ms-ratelimit-remaining-subscription-deletes"
        "x-ms-ratelimit-remaining-subscription-global-deletes"
    )
        
    $OutputProperties = @{}
    
    foreach ($Key in $PropertyKeys) {
        $KeyValue = $Headers.where({ $_.key -eq $Key })
        if ($KeyValue) {
            $OutputProperties.add($KeyValue.Key, $KeyValue.Value)
        }
    }

    $Output = New-Object PSObject -Property $OutputProperties
    return $Output
}

#endregion Internal Functions

#region Public Functions

<#
.SYNOPSIS
    Retrieves Microsoft Sentinel threat indicators based on the specified parameters.

.DESCRIPTION
    This function retrieves threat indicators based on the specified parameters such as subscription ID, resource group name, workspace name, and optional filters.

.PARAMETER SubscriptionId
    The unique identifier of the subscription.

.PARAMETER ResourceGroupName
    The name of the resource group.

.PARAMETER WorkspaceName
    The name of the Microsoft Sentinel workspace.

.PARAMETER Ids
    The IDs of threat intelligence indicators.

.PARAMETER IncludeDisabled
    Specifies whether to include disabled indicators.

.PARAMETER Keywords
    The keywords for searching threat intelligence indicators.

.PARAMETER MaxConfidence
    The maximum confidence level.

.PARAMETER MaxValidUntil
    The end time for the ValidUntil filter.

.PARAMETER MinConfidence
    The minimum confidence level.

.PARAMETER MinValidUntil
    The start time for the ValidUntil filter.

.PARAMETER PageSize
    The page size.

.PARAMETER PatternTypes
    The pattern types.

.PARAMETER SkipToken
    The skip token.

.PARAMETER SortByColumn
    The column to sort by.

.PARAMETER SortByOrder
    The sorting order.

.PARAMETER Sources
    The sources of threat intelligence indicators.

.PARAMETER ThreatTypes
    The threat types of threat intelligence indicators.

.PARAMETER ShowRateLimitMetrics
    Specifies whether to return the rate limit metrics in the response.

.EXAMPLE
    $indicators = Get-ThreatIndicatorsQuery -SubscriptionId "12345678-1234-1234-1234-1234567890ab" -ResourceGroupName "MyResourceGroup" -WorkspaceName "MyWorkspace"

    This example demonstrates how to retrieve threat indicators without any filters. It returns the first 100 indicators.

.EXAMPLE
    $Indicators =@()
    $indicator = Get-ThreatIndicatorsQuery -SubscriptionId "12345678-1234-1234-1234-1234567890ab" -ResourceGroupName "MyResourceGroup" -WorkspaceName "MyWorkspace" 
    
    $Indicators += $indicator.Indicators

    if ($indicator.SkipToken) {
        while ($true){
            $indicator = Get-ThreatIndicatorsQuery -SubscriptionId "12345678-1234-1234-1234-1234567890ab" -ResourceGroupName "MyResourceGroup" -WorkspaceName "MyWorkspace" -SkipToken $indicator.SkipToken
            $Indicators += $indicator.Indicators
            if ($indicator.SkipToken -eq $null) {
                break
            }
        }
    }

    This example demonstrates how to returieve all the indicators in a workspace.
#>
function Get-ThreatIndicatorsQuery {
    [CmdletBinding(DefaultParameterSetName = 'Queries')]
    param (
        [Parameter(Mandatory = $true, ParameterSetName = 'Queries')]
        [Parameter(Mandatory = $true, ParameterSetName = 'Skip')]
        [string]$SubscriptionId,

        [Parameter(Mandatory = $true, ParameterSetName = 'Queries')]
        [Parameter(Mandatory = $true, ParameterSetName = 'Skip')]
        [string]$ResourceGroupName,

        [Parameter(Mandatory = $true, ParameterSetName = 'Queries')]
        [Parameter(Mandatory = $true, ParameterSetName = 'Skip')]
        [string]$WorkspaceName,

        [Parameter(Mandatory = $false, ParameterSetName = 'Queries')]
        [string[]]$Ids,
        
        [Parameter(Mandatory = $false, ParameterSetName = 'Queries')]
        [boolean]$IncludeDisabled,
        
        [Parameter(Mandatory = $false, ParameterSetName = 'Queries')]
        [string[]]$Keywords,
        
        [Parameter(Mandatory = $false, ParameterSetName = 'Queries')]
        [ValidateRange(0, 100)]
        [int]$MaxConfidence,
        
        [Parameter(Mandatory = $false, ParameterSetName = 'Queries')]
        [string]$MaxValidUntil,
        
        [Parameter(Mandatory = $false, ParameterSetName = 'Queries')]
        [ValidateRange(0, 100)]
        [int]$MinConfidence,
        
        [Parameter(Mandatory = $false, ParameterSetName = 'Queries')]
        [string]$MinValidUntil,
            
        [Parameter(Mandatory = $false, ParameterSetName = 'Queries')]
        [int]$PageSize = 100,
            
        [Parameter(Mandatory = $false, ParameterSetName = 'Queries')]
        [string[]]$PatternTypes,
        
        [Parameter(Mandatory = $true, ParameterSetName = 'Skip')]
        [string]$SkipToken,
        
        [Parameter(Mandatory = $false, ParameterSetName = 'Queries')]
        [string]$SortByColumn,
            
        [Parameter(Mandatory = $false, ParameterSetName = 'Queries')]
        [ValidateSet("ascending", "descending", "unsorted")]
        [string]$SortByOrder,
        
        [Parameter(Mandatory = $false, ParameterSetName = 'Queries')]
        [string[]]$Sources = $null,
        
        [Parameter(Mandatory = $false, ParameterSetName = 'Queries')]
        [string[]]$ThreatTypes,

        [switch]$ShowRateLimitMetrics
    )

    $BaseUri = "https://management.azure.com"
    $ThreatIndicatorsApi = $BaseUri + "/subscriptions/$SubscriptionId/resourcegroups/$ResourceGroupName/providers/Microsoft.OperationalInsights/workspaces/$WorkspaceName/providers/Microsoft.SecurityInsights/threatIntelligence/main/"
    $getIndicatorsQueryUri = $ThreatIndicatorsApi + "queryIndicators?api-version=2024-03-01"
    
    $getIndicatorsQueryPostParameters = @{}

    if (!$SkipToken) {
        $getIndicatorsQueryPostParameters.Add("pageSize", $PageSize)
        
        if ($Ids) {
            $getIndicatorsQueryPostParameters.Add("ids", $Ids)
        }
        if ($IncludeDisabled) {
            $getIndicatorsQueryPostParameters.Add("includeDisabled", $IncludeDisabled)
        }
        if ($Keywords) {
            $getIndicatorsQueryPostParameters.Add("keywords", $Keywords)
        }
        if ($MaxConfidence) {
            $getIndicatorsQueryPostParameters.Add("maxConfidence", $MaxConfidence)
        }
        if ($MaxValidUntil) {
            $getIndicatorsQueryPostParameters.Add("maxValidUntil", $MaxValidUntil)
        }
        if ($MinConfidence) {
            $getIndicatorsQueryPostParameters.Add("minConfidence", $MinConfidence)
        }
        if ($MinValidUntil) {
            $getIndicatorsQueryPostParameters.Add("minValidUntil", $MinValidUntil)
        }
        if ($PatternTypes) {
            $getIndicatorsQueryPostParameters.Add("patternTypes", $PatternTypes)
        }
        if ($SortByColumn -and $SortByOrder) {
            $getIndicatorsQueryPostParameters.Add("sortBy", 
                @{
                    "itemKey"   = $SortByColumn
                    "sortOrder" = $SortByOrder
                }
            )
        }
        elseif ($SortByColumn -or $SortByColumn) {
            Write-Error -Message "Both SortByColumn and SortByOrder should be provided"
            exit 1
        }
        if ($SortByOrder) {
            $getIndicatorsQueryPostParameters.Add("sortByOrder", $SortByOrder)
        }
        if ($Sources) {
            $getIndicatorsQueryPostParameters.Add("sources", $Sources)
        }
        if ($ThreatTypes) {
            $getIndicatorsQueryPostParameters.Add("threatTypes", $ThreatTypes)
        }
    }
    else {
        $getIndicatorsQueryPostParameters.Add("skipToken", $SkipToken)  
    }

    $getIndicatorsQueryPostParameters = $getIndicatorsQueryPostParameters | ConvertTo-Json -Depth 5
  		
    $response = Invoke-AzRestMethod -Uri $getIndicatorsQueryUri -Method POST -Payload $getIndicatorsQueryPostParameters -ErrorAction $ErrorActionPreference
    if ($null -eq $response) {                
        Write-Error -Message "Failed to get a response." -Exception $_.Exception
        exit 1
    }

    Write-Debug -Message "Compiling Indicator Object"
    $indicatorObject = $null
    $indicatorObject = $response.Content | ConvertFrom-Json
    $IndictorHash = @{}
    $IndictorHash.Indicators = $indicatorObject.value
    Write-Debug "NextLink: $($indicatorObject.nextLink)"
    if ($indicatorObject.nextLink){
        $IndictorHash.SkipToken  = $indicatorObject.nextLink.split('$skipToken=')[1]
    }
    $indicatorReturn = New-Object PSObject -Property $IndictorHash
    
    Write-Debug -Message "Checking if Rate limit metrics are required"
    Write-Debug -Message "ShowRateLimitMetrics: $ShowRateLimitMetrics"
    if ($ShowRateLimitMetrics) {
        $indicatorReturn | Add-Member -MemberType NoteProperty -Name "RateLimitMetrics" -Value (Get-RateLimitMetrics -Headers $response.Headers)
    }

    if ( $response.StatusCode -eq 200) {
        return $indicatorReturn
        exit 0
    }

    if ($response.StatusCode -ne 200) {
        Write-Error -Message "Failed to get indicators. Status Code = $($response.StatusCode)" -Exception $_.Exception
        return $indicatorReturn
        exit 1
    }
}

<#
.SYNOPSIS
    Retrieves threat indicator metrics.

.DESCRIPTION
    This function retrieves threat indicator metrics based on the specified subscription ID, resource group name, and workspace name.

.PARAMETER SubscriptionId
    The unique identifier of the subscription.

.PARAMETER ResourceGroupName
    The name of the resource group.

.PARAMETER WorkspaceName
    The name of the Microsoft Sentinel workspace.

.EXAMPLE
    $metrics = Get-ThreatIndicatorsMetrics -SubscriptionId "12345678-1234-1234-1234-1234567890ab" -ResourceGroupName "MyResourceGroup" -WorkspaceName "MyWorkspace"

    This example demonstrates how to retrieve threat indicator metrics.

#>
function Get-ThreatIndicatorsMetrics {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$SubscriptionId,

        [Parameter(Mandatory = $true)]
        [string]$ResourceGroupName,

        [Parameter(Mandatory = $true)]
        [string]$WorkspaceName
    )
    
    $BaseUri = "https://management.azure.com"
    $ThreatIndicatorsApi = $BaseUri + "/subscriptions/$SubscriptionId/resourcegroups/$ResourceGroupName/providers/Microsoft.OperationalInsights/workspaces/$WorkspaceName/providers/Microsoft.SecurityInsights/threatIntelligence/main/"
    $getThreatIndicatorMetricsUri = $ThreatIndicatorsApi + "metrics?api-version=2024-03-01"
    
    try {
        $response = Invoke-AzRestMethod -Uri $getThreatIndicatorMetricsUri -Method GET -ErrorAction $ErrorActionPreference
        if ($null -eq $response -or $response.StatusCode -ne 200) {    
            Write-Error -Message "Failed to fetch indicators Metrics. Status Code = $($response.StatusCode)"        
            exit 1
        }
        $sourceMetrics = ($Response.Content | ConvertFrom-Json).value.properties
        return $sourceMetrics
    }
    catch {    
        Write-Error -Message "Failed to get the indicator metrics" -Exception $_.Exception
        exit 1
    }
}

<#
.SYNOPSIS
    Removes a threat indicator.

.DESCRIPTION
    This function removes a single threat indicator from a specified workspace

.PARAMETER SubscriptionId
    The unique identifier of the subscription.

.PARAMETER ResourceGroupName
    The name of the resource group.

.PARAMETER WorkspaceName
    The name of the Microsoft Sentinel workspace.

.EXAMPLE
    Remove-ThreatIndicator -SubscriptionId "12345678-1234-1234-1234-1234567890ab" -ResourceGroupName "MyResourceGroup" -WorkspaceName "MyWorkspace"

    This example demonstrates how to remove a threat indicator.

#>
function Remove-ThreatIndicator {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$SubscriptionId,

        [Parameter(Mandatory = $true)]
        [string]$ResourceGroupName,

        [Parameter(Mandatory = $true)]
        [string]$WorkspaceName,
        
        # Indicator Name
        [Parameter(Mandatory = $true)]
        [array]$IndicatorName,

        # Returns the RateLimit Metrics in the response
        [switch]$ShowRateLimitMetrics
    )
    
    Write-Verbose -Message "Deleting indicator: $indicatorName"

    $BaseUri = "https://management.azure.com"
    $ThreatIndicatorsResourceId = "/subscriptions/$SubscriptionId/resourcegroups/$ResourceGroupName/providers/Microsoft.OperationalInsights/workspaces/$WorkspaceName/providers/Microsoft.SecurityInsights/threatIntelligence/main/indicators/$IndicatorName"
    $deleteIndicatorUri = $BaseUri + $ThreatIndicatorsResourceId + "?api-version=2024-03-01"
    $response = Invoke-AzRestMethod -Uri $deleteIndicatorUri -Method DELETE -ErrorAction $ErrorActionPreference

    
    if ( $response.StatusCode -eq 200) {
        $indicatorObject = $null
        $indicatorObject = $response.Content | ConvertFrom-Json
        $indicatorReturn = New-Object PSObject -Property @{
            "Id"        = $ThreatIndicatorsResourceId
            "Indicator" = $indicatorObject.value
            "Status"    = "Success"
        }
        
        if ($ShowRateLimitMetrics) {
            $indicatorReturn | Add-Member -MemberType NoteProperty -Name "RateLimitMetrics" -Value (Get-RateLimitMetrics -Headers $response.Headers)
        }        
        return $indicatorReturn
    
        exit 0
    }

    if ($response.StatusCode -eq 204) {
        $indicatorReturn = New-Object PSObject -Property @{
            "Id"        = $ThreatIndicatorsResourceId
            "Indicator" = $null
            "Status"    = "Success"
        }            
        if ($ShowRateLimitMetrics) {
            $indicatorReturn | Add-Member -MemberType NoteProperty -Name "RateLimitMetrics" -Value (Get-RateLimitMetrics -Headers $response.Headers)
        }
        return $indicatorReturn       
        exit 0
    }
    
    if ($null -eq $response) {                
        Write-Error -Message "Failed to delete indicators." -Exception $_.Exception 
        $indicatorReturn = New-Object PSObject -Property @{
            "Id"        = $ThreatIndicatorsResourceId
            "Indicator" = $null
            "Status"    = "Failure"
            "Error"     = $Response.Content
        }            
        return
        exit 1
    }

    if ($response.StatusCode -eq 400) {
        Write-Error -Message "Failed to delete indicators. Status Code: $($Response.StatusCode)`n$($Response.Content)" 
        $indicatorObject = $null
        $indicatorReturn = New-Object PSObject -Property @{
            "Id"         = $ThreatIndicatorsResourceId
            "Indicators" = $null
            "Status"     = "Failure"
            "Error"      = $Response
        }
        
        if ($ShowRateLimitMetrics) {
            $indicatorReturn | Add-Member -MemberType NoteProperty -Name "RateLimitMetrics" -Value (Get-RateLimitMetrics -Headers $response.Headers)
        }
        return $indicatorReturn
        exit 1
    }

    if ($response.StatusCode -ne 200) {
        Write-Error -Message "Failed to delete indicators. Status Code: $($Response.StatusCode)`n$($Response.Content)" 
        $indicatorObject = $null
        $indicatorReturn = New-Object PSObject -Property @{
            "Id"         = $ThreatIndicatorsResourceId
            "Indicators" = $null
            "Status"     = "Failure"
            "Error"      = $Response.Content
        }
        return $indicatorReturn
        exit 1
    }
}


<#
.SYNOPSIS
    Remove-ThreatIndicatorsQuery is a PowerShell function that removes threat indicators from a Microsoft Sentinel workspace.
.DESCRIPTION
    The Remove-ThreatIndicatorsQuery function removes threat indicators from a Microsoft Sentinel workspace based on various parameters such as subscription ID, resource group name, workspace name, indicator IDs, keywords, confidence levels, valid until dates, pattern types, sorting options, sources, and threat types.
.PARAMETER SubscriptionId
    Specifies the unique identifier of the subscription.
.PARAMETER ResourceGroupName
    Specifies the name of the resource group.
.PARAMETER WorkspaceName
    Specifies the name of the Microsoft Sentinel workspace.
.PARAMETER TotalToDelete
    Specifies the total number of indicators to delete. Default value is -1, which means delete all indicators.
.PARAMETER Ids
    Specifies the IDs of threat intelligence indicators to delete.
.PARAMETER IncludeDisabled
    Specifies whether to include or exclude disabled indicators.
.PARAMETER Keywords
    Specifies the keywords for searching threat intelligence indicators.
.PARAMETER MaxConfidence
    Specifies the maximum confidence level of threat intelligence indicators.
.PARAMETER MaxValidUntil
    Specifies the end time for the ValidUntil filter.
.PARAMETER MinConfidence
    Specifies the minimum confidence level of threat intelligence indicators.
.PARAMETER MinValidUntil
    Specifies the start time for the ValidUntil filter.
.PARAMETER PageSize
    Specifies the page size for fetching threat indicators. Default value is 100.
.PARAMETER PatternTypes
    Specifies the pattern types of threat intelligence indicators.
.PARAMETER SortByColumn
    Specifies the column to sort by.
.PARAMETER SortByOrder
    Specifies the sorting order. Valid values are "ascending", "descending", and "unsorted".
.PARAMETER Sources
    Specifies the sources of threat intelligence indicators.
.PARAMETER ThreatTypes
    Specifies the threat types of threat intelligence indicators.
.PARAMETER ShowProgress
    Specifies whether to show progress while deleting indicators.
.EXAMPLE
    Remove-ThreatIndicatorsQuery -SubscriptionId "12345678-1234-1234-1234-1234567890AB" -ResourceGroupName "MyResourceGroup" -WorkspaceName "MyWorkspace" -TotalToDelete 100 -IncludeDisabled -Keywords "malware" -MaxConfidence 80 -MaxValidUntil "2022-12-31" -MinConfidence 50 -MinValidUntil "2022-01-01" -PageSize 50 -PatternTypes "FileHash" -SortByColumn "Name" -SortByOrder "ascending" -Sources "Microsoft" -ThreatTypes "Malware"
.NOTES
    Author: Your Name
    Date: Current Date
    Version: 1.0
#>
function Remove-ThreatIndicatorsQuery {
    [CmdletBinding(DefaultParameterSetName = 'Queries')]
    param (
        # Unique Identifier of the subscription
        [Parameter(Mandatory = $true)]
        [string]$SubscriptionId,

        # Name of the resource group
        [Parameter(Mandatory = $true)]
        [string]$ResourceGroupName,

        # Name of the Microsoft Sentinel workspace
        [Parameter(Mandatory = $true)]
        [string]$WorkspaceName,

        # Total To Delete
        [Parameter(Mandatory = $false)]
        [string]$TotalToDelete = -1,

        #Ids of threat intelligence indicators
        [Parameter(Mandatory = $false)]
        [string[]]$Ids,
        
        #Parameter to include/exclude disabled indicators.
        [Parameter(Mandatory = $false)]
        [boolean]$IncludeDisabled,
        
        #Keywords for searching threat intelligence indicators
        [Parameter(Mandatory = $false)]
        [string[]]$Keywords,
        
        #Maximum confidence.
        [Parameter(Mandatory = $false)]
        [ValidateRange(0, 100)]
        [int]$MaxConfidence,
        
        #End time for ValidUntil filter.
        [Parameter(Mandatory = $false)]
        [string]$MaxValidUntil,
        
        #Minimum confidence.
        [Parameter(Mandatory = $false)]
        [ValidateRange(0, 100)]
        [int]$MinConfidence,
        
        #Start time for ValidUntil filter.
        [Parameter(Mandatory = $false)]
        [string]$MinValidUntil,
            
        #Page size
        [Parameter(Mandatory = $false)]
        [int]$PageSize = 100,
            
        #Pattern types
        [Parameter(Mandatory = $false)]
        [string[]]$PatternTypes,
        
        #Columns to sort by and sorting order
        [Parameter(Mandatory = $false)]
        [string]$SortByColumn,
            
        #Columns to sort by and sorting order
        [Parameter(Mandatory = $false)]
        [ValidateSet("ascending", "descending", "unsorted")]
        [string]$SortByOrder,
        
        #Sources of threat intelligence indicators
        [Parameter(Mandatory = $false)]
        [string[]]$Sources,
        
        #Threat types of threat intelligence indicators
        [Parameter(Mandatory = $false)]
        [string[]]$ThreatTypes,

        [switch]$ShowProgress
    )
    #>
    $StartTime = Get-Date

    # This flag checks whether the initial count of indicators in the workspace is already 0 or not
    $indicatorsFound = $false

    # Total count of indicators fetched for the customer's workspace ,and for the provided source
    $indicatorsFetched = 0

    # Total count of indicators deleted
    $indicatorsDeleted = 0

    # Total count of failedindicators deleted
    $indicatorsDeletedFailed = 0

    $pageSize = 100

    # Foreach parameter, if value, add to query
    $GetThreatIndicatorsQueryParameters = [ordered]@{}

    $Parameters = @(
        "SubscriptionId"
        "ResourceGroupName"
        "WorkspaceName"
        "Ids"
        "IncludeDisabled"
        "Keywords"
        "MaxConfidence"
        "MaxValidUntil"
        "MinConfidence"
        "MinValidUntil"
        "PageSize"
        "PatternTypes"
        "SortByColumn"
        "SortByOrder"
        "Sources"
        "ThreatTypes"
    )

    foreach ($Parameter in $Parameters) {
        if (Get-Variable -Name $Parameter -ValueOnly -ErrorAction SilentlyContinue) {
            $GetThreatIndicatorsQueryParameters.Add($Parameter, (Get-Variable -Name $Parameter -ValueOnly))
        }
    }

    while ($true) {
        try {
            $Indicators = Get-ThreatIndicatorsQuery @GetThreatIndicatorsQueryParameters -ShowRateLimitMetrics -ErrorAction $ErrorActionPreference
        }
        catch {
            Write-Error -Message "Failed to get indicators" -Exception $_.Exception
            exit 1
        }

        if ($Indicators.Indicators.Count -eq 0) {
            # If the initial count of indicators in the customer's workspace is already 0, exit.
            if ($indicatorsFound -eq $false) {
                Write-Error "No indicators found! Exiting ..."
                break
            }
            else {
                Write-Information "Finished querying workspace = $WorkspaceName for indicators"
                Write-Information "Fetched $indicatorsFetched indicators"
                Write-Information "Deleted $indicatorsDeleted indicators"
    
                if ($indicatorsFetched -eq $indicatorsDeleted) {                
                    Write-Information "Successfully deleted all indicators in workspace = $WorkspaceName"
                }
                else {                
                    Write-Warning "Please re-run the script to delete remaining indicators or reach out to the script owners if you're facing any issues."
                }
                break
            }
        }

        if ($TotalToDelete -ne -1 -and $IndicatorsDeleted + $Indicators.Indicators.Count -gt $TotalToDelete) {
            $Indicators.Indicators = $Indicators.Indicators[0..($TotalToDelete - $IndicatorsDeleted - 1)]
        }

        $indicatorsFound = $true    
        Write-Information "Successfully fetched $($Indicators.Indicators.Count) indicators. Deleting ..."
        $indicatorsFetched += $Indicators.Indicators.Count

        $Results = @{}
        [int]$RateLimit = 200
        [int]$RunCount = 0

        $Indicators.Indicators | ForEach-Object {
            if ($ShowProgress) {
                Write-Progress -Id 0 -Activity "Indicators Status" -Status "Fetched: $indicatorsFetched | Deleted: $indicatorsDeleted | Failed: $indicatorsDeletedFailed" -PercentComplete (100 / $Indicators.Indicators.Count * $RunCount)
            }
            $Results.($_.Name) = @{}
            $Results.($_.Name).Run = Remove-ThreatIndicator  -SubscriptionId $SubscriptionId -ResourceGroupName $ResourceGroupName -WorkspaceName $WorkspaceName -IndicatorName $PSItem.Name -ShowRateLimitMetrics -ErrorAction $ErrorActionPreference
            $RateLimit = if ($Results.($_.Name).Run.RateLimitMetrics.'x-ms-ratelimit-remaining-subscription-deletes') {
                $Results.($_.Name).Run.RateLimitMetrics.'x-ms-ratelimit-remaining-subscription-deletes'
            }

            if ($Results.($_.Name).Run.Status -eq "Success") {
                $indicatorsDeleted++
            }
            else {
                $indicatorsDeletedFailed++
            }

            if ($RateLimit -lt 100) {
                Write-Information "Delete Rate limit is below 10. Sleeping for 10 seconds ..."
                Start-Sleep -Seconds 10
            }
            $RunCount++
        } 
        
        if ($indicatorsFetched -ge $TotalToDelete -and $TotalToDelete -ne -1) {
            if ($ShowProgress) {
                Write-Progress -Id 0 -Activity "Indicators Status" -Status "Fetched: $indicatorsFetched | Deleted: $indicatorsDeleted | Failed: $indicatorsDeletedFailed" -Completed
            }
            break
        }
    } 
    
    $EndTime = Get-Date
    $ScriptExecutionTime = ($EndTime - $StartTime)
    Write-Information "Total Indicators Found: $indicatorsFetched"
    Write-Information "Total Indicators Deleted: $indicatorsDeleted"
    Write-Information "Execution Time: $($ScriptExecutionTime.days) days, $($ScriptExecutionTime.hours) hours, $($ScriptExecutionTime.Minutes) minutes,$($ScriptExecutionTime.seconds) seconds,"
    Write-Information "End of Script"

}


#endregion Public Functions

#region Exported Functions

Export-ModuleMember -Function Get-ThreatIndicatorsQuery
Export-ModuleMember -Function Get-ThreatIndicatorsMetrics
Export-ModuleMember -Function Remove-ThreatIndicator
Export-ModuleMember -Function Remove-ThreatIndicatorsQuery

#endregion Exported Functions
