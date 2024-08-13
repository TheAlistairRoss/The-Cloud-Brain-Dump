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
    [CmdletBinding(DefaultParameterSetName = 'Queries',
        PositionalBinding = $false
    )]
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

    $BaseUri = (Get-AzContext).Environment.ResourceManagerUrl.TrimEnd('/')
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
        Write-Error -Message "Failed to get a response: $($_.Exception.Message)" -Exception $_.Exception
        exit 1
    }

    Write-Debug -Message "Compiling Indicator Object"
    $indicatorObject = $null
    $indicatorObject = $response.Content | ConvertFrom-Json
    $IndictorHash = @{}
    $IndictorHash.Indicators = $indicatorObject.value
    Write-Debug "NextLink: $($indicatorObject.nextLink)"
    if ($indicatorObject.nextLink) {
        $IndictorHash.SkipToken = $indicatorObject.nextLink.split('$skipToken=')[1]
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
        Write-Error -Message "Failed to get indicators. Status Code = $($response.StatusCode): $($_.Exception.Message)" -Exception $_.Exception
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
    [CmdletBinding(
        PositionalBinding = $false
    )]
    param (
        [Parameter(Mandatory = $true)]
        [string]$SubscriptionId,

        [Parameter(Mandatory = $true)]
        [string]$ResourceGroupName,

        [Parameter(Mandatory = $true)]
        [string]$WorkspaceName
    )
    
    $BaseUri = (Get-AzContext).Environment.ResourceManagerUrl.TrimEnd('/')
    $ThreatIndicatorsApi = $BaseUri + "/subscriptions/$SubscriptionId/resourcegroups/$ResourceGroupName/providers/Microsoft.OperationalInsights/workspaces/$WorkspaceName/providers/Microsoft.SecurityInsights/threatIntelligence/main/"
    $getThreatIndicatorMetricsUri = $ThreatIndicatorsApi + "metrics?api-version=2024-03-01"
    
    try {
        $response = Invoke-AzRestMethod -Uri $getThreatIndicatorMetricsUri -Method GET -ErrorAction $ErrorActionPreference
        if ($null -eq $response -or $response.StatusCode -ne 200) {    
            Write-Error -Message "Failed to fetch indicators Metrics. Status Code = $($response.StatusCode): $($_.Exception.Message)"        
            exit 1
        }
        $sourceMetrics = ($Response.Content | ConvertFrom-Json).value.properties
        return $sourceMetrics
    }
    catch {    
        Write-Error -Message "Failed to get the indicator metrics: $($_.Exception.Message)" -Exception $_.Exception
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
    [CmdletBinding(
        PositionalBinding = $false
    )]
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

    $BaseUri = (Get-AzContext).Environment.ResourceManagerUrl.TrimEnd('/')
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
    }

    if ($response.StatusCode -eq 204) {
        $indicatorReturn = New-Object PSObject -Property @{
            "Id"        = $ThreatIndicatorsResourceId
            "Indicator" = $null
            "Status"    = "Success"
        }            
    }
    
    if ($null -eq $response) {                
        Write-Error -Message "Failed to delete indicators: $($_.Exception.Message)" -Exception $_.Exception 
        $indicatorReturn = New-Object PSObject -Property @{
            "Id"        = $ThreatIndicatorsResourceId
            "Indicator" = $null
            "Status"    = "Failure"
            "Error"     = $Response
        }            
    }

    if ($response.StatusCode -ne 200) {
        Write-Error -Message "Failed to delete indicators. Status Code: $($Response.StatusCode)`n$($Response.Content): $($_.Exception.Message)" 
        $indicatorObject = $null
        $indicatorReturn = New-Object PSObject -Property @{
            "Id"         = $ThreatIndicatorsResourceId
            "Indicators" = $null
            "Status"     = "Failure"
            "Error"      = $Response
        }
    }

    if ($ShowRateLimitMetrics) {
        $indicatorReturn | Add-Member -MemberType NoteProperty -Name "RateLimitMetrics" -Value (Get-RateLimitMetrics -Headers $response.Headers)
    }        

    if ($indicatorReturn.Status -eq "Success") {
        $ExitCode = 0
    }
    else {
        $ExitCode = 1
    }

    return $indicatorReturn
    exit $ExitCode
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
    [CmdletBinding(
        DefaultParameterSetName = 'Queries',
        PositionalBinding = $false
    )]
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
        [int]$TotalToDelete = -1,

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
                        
        #Pattern types
        [Parameter(Mandatory = $false)]
        [string[]]$PatternTypes,
        
        # Show Script Progress
        [switch]$ShowProgress,

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
        [string[]]$ThreatTypes
    )
    
    #Function setup
    if ($VerbosePreference -ne "SilentlyContinue") {
        Write-Verbose "Parameters List:"
        foreach ($_ in $PSBoundParameters.Keys) {
            if ($null -ne $PSBoundParameters[$_] -and $PSBoundParameters[$_] -ne -1) {
                Write-Verbose "$_ : $($PSBoundParameters[$_])"
            }
        }  
        Write-Verbose "End of Parameters"  
    }

    # Constants
    $ModulePath = (Get-Module -Name "SentinelThreatIntelligence").ModuleBase
    $DeleteRefillRatePerSecond = 10
    $MaxRetries = 3

    # Setup Variables
    $StartTime = Get-Date

    # This flag checks whether the initial count of indicators in the workspace is already 0 or not
    $IndicatorsFound = $false

    # Total Retrieved Indicators
    [ref] $TotalCollected = 0

    # Initial Deletetion Bucket Size
    [ref] $DeleteBucketSize = [int] 200

    # Total Indicators Deleted
    [ref] $TotalSuccess = [int] 0

    # Total Indicators Failed to Delete
    [ref] $TotalFailed = [int] 0

    # Foreach parameter, if value, add to query
    $GetThreatIndicatorsQueryParameters = [ordered]@{}

    # Queue to store the indicators
    $IndicatorsNameQueue = [System.Collections.Concurrent.ConcurrentQueue[string]]::new()

    $ParametersForQuery = @(
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

    # Add parameters to the query
    $ParametersForQuery | ForEach-Object {
        if ($null -ne $PSBoundParameters[$_] -and $PSBoundParameters[$_] -ne -1) {
            Write-Verbose "[RemoveThreatIndicatorsQuery] $(Get-Date): Adding Parameter to hash - $_ : $($PSBoundParameters[$_])"
            $GetThreatIndicatorsQueryParameters.Add($_, $PSBoundParameters[$_])
        }
    }

    # Set the initial page size
    $GetThreatIndicatorsQueryParameters.Add("PageSize", 100)

    # Get the number of logical processors
    $NumberOfLogicalProcessors = [Environment]::ProcessorCount
    Write-Verbose "[RemoveThreatIndicatorsQuery] $(Get-Date): Number of Logical Processors: $NumberOfLogicalProcessors"
    
    $NumberOfThreads = [math]::Min($NumberOfLogicalProcessors - 1, 8)
    $NumberOfThreads = [math]::Max($NumberOfThreads, 1)
    Write-Verbose "[RemoveThreatIndicatorsQuery] $(Get-Date): Max Number of Threads: $NumberOfThreads"

    # Get the initial access token
    $AccessToken = Get-AzAccessToken

    # Removal Jobs
    $RemoveJobScriptBlock = {
        
        # Static Variables from Parent
        $JobId = $_
        $SubscriptionId = $using:SubscriptionId
        $ResourceGroupName = $using:ResourceGroupName
        $WorkspaceName = $using:WorkspaceName
        $ModulePath = $using:ModulePath
        $AccessToken = $using:AccessToken

        # Dynamic Variables from Parent
        $TotalCollected = $using:TotalCollected
        $TotalSuccess = $using:TotalSuccess
        $TotalFailed = $using:TotalFailed
        $IndicatorsNameQueue = $using:IndicatorsNameQueue
        $DeleteBucketSize = $using:DeleteBucketSize

        $VerbosePreference = $using:VerbosePreference
        $DebugPreference = $using:DebugPreference


        # Write-Verbose each variable and parameter
        Write-Debug "[RemoveThreatIndicatorsQuery][Job $JobID] $(Get-Date): JobId = $JobId"
        Write-Debug "[RemoveThreatIndicatorsQuery][Job $JobID] $(Get-Date): SubscriptionId = $SubscriptionId"
    
        Write-Debug "[RemoveThreatIndicatorsQuery][Job $JobID] $(Get-Date): ResourceGroupName = $ResourceGroupName"
        Write-Debug "[RemoveThreatIndicatorsQuery][Job $JobID] $(Get-Date): WorkspaceName = $WorkspaceName"
        Write-Debug "[RemoveThreatIndicatorsQuery][Job $JobID] $(Get-Date): ModulePath = $ModulePath"
        Write-Debug "[RemoveThreatIndicatorsQuery][Job $JobID] $(Get-Date): AccessToken = $($AccessToken.ExpiresOn)"

        Write-Debug "[RemoveThreatIndicatorsQuery][Job $JobID] $(Get-Date): TotalCollected = $($TotalCollected.value)"
        Write-Debug "[RemoveThreatIndicatorsQuery][Job $JobID] $(Get-Date): IndicatorsNameQueue = $($IndicatorsNameQueue.Count)"
        Write-Debug "[RemoveThreatIndicatorsQuery][Job $JobID] $(Get-Date): DeleteBucketSize = $($DeleteBucketSize.Value)"
        # Variables
        $maxRetries = 3
        $JobTimeout = 120
    
        Write-Verbose "[RemoveThreatIndicatorsQuery][Job $JobID] $(Get-Date): Starting Removal Job"
        # Job Setup
        # Import the Module
        try {
            Write-Verbose "[RemoveThreatIndicatorsQuery][Job $JobID] $(Get-Date): Importing Module"
            Import-Module $ModulePath
        }
        catch {
            Write-Error -Message "[RemoveThreatIndicatorsQuery][Job $JobID] $(Get-Date): Failed to import module: $($_.Exception.Message)" -Exception $_.Exception
            break
        }

        # Authenticate
        try {
            Connect-AzAccount -Tenant $AccessToken.TenantId -AccountId $AccessToken.UserId -AccessToken $AccessToken.Token | Out-Null
            Write-Verbose "[RemoveThreatIndicatorsQuery][Job $JobID] $(Get-Date): Authenticated"
        }
        catch {
            Write-Error -Message "[RemoveThreatIndicatorsQuery][Job $JobID] $(Get-Date): Failed to authenticate: $($_.Exception.Message)" -Exception $_.Exception
            break
        }

        Write-Output "Initialized"

        $TimeoutStart = Get-Date
        while ($true) {
            # Get Indicator Name
            $IndicatorName = $null
            if ($IndicatorsNameQueue.TryDequeue([ref]$IndicatorName)) {
                Write-Verbose "[RemoveThreatIndicatorsQuery][Job $JobID] $(Get-Date): Indicator Fetched: $IndicatorName"
                $TimeoutStart = Get-Date
            }
            else {
                Write-Debug "[RemoveThreatIndicatorsQuery][Job $JobID] $(Get-Date): No Indicator in the queue."
            }

            # Exit if no indicator in the queue for the number of seconds in $Timeout
            if (-not $IndicatorName ) {
                if ((Get-Date) - $TimeoutStart -ge (New-TimeSpan -Seconds $JobTimeout)) {
                    Write-Verbose "[RemoveThreatIndicatorsQuery][Job $JobID] $(Get-Date): No Indicator in the queue for $JobTimeout seconds. Exiting Removal Job"
                    break
                }
                else {
                    Write-Verbose "[RemoveThreatIndicatorsQuery][Job $JobID] $(Get-Date): No Indicator in the queue. Waiting for $([math]::Ceiling($JobTimeout - ((Get-Date) - $TimeoutStart).TotalSeconds)) seconds"
                    Start-Sleep -Seconds 5
                    continue
                }
            }

            # Exit Signal
            if ($IndicatorName -eq "`0") {
                Write-Verbose "[RemoveThreatIndicatorsQuery][Job $JobID] $(Get-Date): Exit Signal Received, Exiting Removal Job"
                break
            }

            # Delete Indicator
            $retryCount = 0
            while ($retryCount -lt $maxRetries) {
                $Remove = Remove-ThreatIndicator -SubscriptionId $SubscriptionId -ResourceGroupName $ResourceGroupName -WorkspaceName $WorkspaceName -IndicatorName $IndicatorName -ShowRateLimitMetrics

                if ($Remove.RateLimitMetrics.'x-ms-ratelimit-remaining-subscription-deletes') {
                    $DeleteBucketSize.Value = $Remove.RateLimitMetrics.'x-ms-ratelimit-remaining-subscription-deletes'
                }
                if ($Remove.Status -eq "Success") {
                    Write-Verbose "[RemoveThreatIndicatorsQuery][Job $JobID] $(Get-Date): Indicator Deleted: $IndicatorName"
                    $TotalSuccess.Value ++
                    break
                }
                else {
                    $retryCount++
                    if ($retryCount -eq $maxRetries) {
                        Write-Error -Message "[RemoveThreatIndicatorsQuery][Job $JobID] $(Get-Date): Failed to delete indicator: $IndicatorName after $retryCount retries: $($_.Exception.Message)" -Exception $_.Exception
                        $TotalFailed.Value ++
                        break
                    }
                    else {
                        Write-Warning "[RemoveThreatIndicatorsQuery][Job $JobID] $(Get-Date): Failed to delete indicator. Retrying..."
                        continue
                    }
                }
            }
        }
        break
    }

    # Start the Removal Jobs
    Write-Verbose "[RemoveThreatIndicatorsQuery] $(Get-Date): Starting Removal Jobs"
    $RemovalJobs = 1 .. $NumberOfThreads | ForEach-Object -ThrottleLimit $NumberOfThreads -AsJob -Parallel $RemoveJobScriptBlock 
    Start-Sleep -Seconds 3

    # Check each the child jobs for $Jobs and ensure the state is running and the output is "Initialized"
    $ChildJobs = ($RemovalJobs | Get-Job).ChildJobs

    $StartJobTimeout = 30
    while ($true) {
        $ChildJobs = ($RemovalJobs | Get-Job).ChildJobs
        # If no jobs are running or initialized, exit
        if ($StartJobTimeout -le 0 -and $ChildJobs.state.Where({ $_ -eq "Running" }).count -eq 0 -or $ChildJobs.Output.Where({ $_ -eq "Initialized" }).count -eq 0) {
            Write-Error -Message "[RemoveThreatIndicatorsQuery] $(Get-Date): Removal Jobs did not start successfully after 30 seconds. Exiting..."
            break
        }

        # If some of the jobs are running and initialized, break the loop with a warning of degraded performance
        if ($StartJobTimeout -le 0 -and $ChildJobs.state.Where({ $_ -eq "Running" }).count -ne 0 -and $ChildJobs.Output.Where({ $_ -eq "Initialized" }).count -ne 0) {
            Write-Warning "[RemoveThreatIndicatorsQuery] $(Get-Date): Some Removal Jobs did not start after 30 seconds. Degraded Performance"
            break
        }

        # If all jobs are running and initialized, break the loop
        if ($ChildJobs.state.Where({ $_ -eq "Running" }).count -eq $NumberOfThreads -and $ChildJobs.Output.Where({ $_ -eq "Initialized" }).count -eq $NumberOfThreads) {
            Write-Verbose "[RemoveThreatIndicatorsQuery] $(Get-Date): All Removal Jobs Started"
            break
        }
        
        Write-Verbose "[RemoveThreatIndicatorsQuery] $(Get-Date): Waiting for all Removal Jobs to start.  Initialized: $($ChildJobs.Output.Where({ $_ -eq "Initialized" }).count)/$NumberOfThreads"
        $StartJobTimeout - 5
        Start-Sleep -Seconds 5
        continue   
    }

    # Main loop to get indicators
    while ($true) {
        # Show Progress
        Write-Debug "[RemoveThreatIndicatorsQuery] $(Get-Date): ProgressStatus = Total Collected: $($TotalCollected.value) | Deleted: $($TotalSuccess.Value) | Failed: $($TotalFailed.Value) | Time Elapsed: $(New-TimeSpan -Start $StartTime -End (Get-Date))"
        Write-Debug "[RemoveThreatIndicatorsQuery] $(Get-Date): ProgressPercentComplete = $((($TotalSuccess.Value + $TotalFailed.Value) / $TotalToDelete) * 100)"

        if ($ShowProgress -and $TotalToDelete -eq -1) {
            Write-Progress  -Id 0 -Activity "Removing Threat Indicators" -Status "Total Collected: $($TotalCollected.value) | Deleted: $($TotalSuccess.Value) | Failed: $($TotalFailed.Value) | Time Elapsed: $(New-TimeSpan -Start $StartTime -End (Get-Date))" -PercentComplete ((($TotalSuccess.Value + $TotalFailed.Value) / $TotalCollected.value) * 100)
        }
        elseif ($ShowProgress) {
            Write-Progress  -Id 0 -Activity "Removing Threat Indicators" -Status "Total Collected: $($TotalCollected.value) | Deleted: $($TotalSuccess.Value) | Failed: $($TotalFailed.Value) | Time Elapsed: $(New-TimeSpan -Start $StartTime -End (Get-Date))" -PercentComplete ((($TotalSuccess.Value + $TotalFailed.Value) / $TotalToDelete) * 100)
        }

        # Reset the retry count
        $retryCount = 0

        # Stop Collecting if the TotalCollected is greater than or equal to TotalToDelete
        if ($TotalToDelete -ne -1 -and $($TotalCollected.value) -ge $TotalToDelete) {
            Write-Verbose "[RemoveThreatIndicatorsQuery] $(Get-Date): Total Collected: $($TotalCollected.value). Total to Delete: $TotalToDelete"
            Write-Verbose "[RemoveThreatIndicatorsQuery] $(Get-Date): Exiting Enqueue Job"
            break
        }
                
        # Throttling Checks
        # If there are indicators in the after the first run and is greater than a count 150, sleep for 10 seconds to prevent throttling
        if ($IndicatorsNameQueue.count -gt 150 -and $IndicatorsFound -eq $true) {
            Write-Verbose "[RemoveThreatIndicatorsQuery] $(Get-Date): Queue Count: $($IndicatorsNameQueue.count). Sleeping for 10 seconds to prevent throttling"
            Start-Sleep -Seconds 10
        }
        elseif ($IndicatorsFound -eq $true) {
            # Sleep for 1 second to prevent read throttling
            Start-Sleep -Seconds 1
        }
        elseif ($DeleteBucketSize.Value -lt 100) {
            # The Deletion Bucket size refills at a rate of 10 per second
            # If the bucket size is less 40, sleep for the number of seconds it would take to refill the bucket to 200
            $RefillWait = [math]::Ceiling((200 - $DeleteBucketSize.Value) / $DeleteRefillRatePerSecond)
            Write-Verbose "[RemoveThreatIndicatorsQuery] $(Get-Date): Delete Bucket Size: $($DeleteBucketSize.Value). Sleeping for $RefillWait seconds to prevent rate limiting"
            Start-Sleep -Seconds $RefillWait
        }

        # Set page size to not exceed the total to delete

        Write-Debug "[RemoveThreatIndicatorsQuery] $(Get-Date): Evaluating Page Size. Total Collected: $($TotalCollected.value). Total to Delete: $TotalToDelete"
        if ($TotalToDelete -ne -1 -and $TotalCollected.Value + $GetThreatIndicatorsQueryParameters.PageSize -ge $TotalToDelete) {
            $GetThreatIndicatorsQueryParameters.PageSize = $TotalToDelete - $($TotalCollected.value)
        }
        Write-Debug "[RemoveThreatIndicatorsQuery] $(Get-Date): Setting Page Size to $($GetThreatIndicatorsQueryParameters.PageSize)"

        # Get Threat Indicators
        while ($retryCount -lt $maxRetries) {
            try {
                $ThreatIndicators = Get-ThreatIndicatorsQuery @GetThreatIndicatorsQueryParameters                
                Write-Verbose "[RemoveThreatIndicatorsQuery] $(Get-Date): Threat Indicators Count: $($ThreatIndicators.Indicators.Count)"
                $TotalCollected.Value += $ThreatIndicators.Indicators.Count
                break
            }
            catch {
                $retryCount++
                if ($retryCount -eq $maxRetries) {
                    Write-Error -Message "[RemoveThreatIndicatorsQuery] $(Get-Date): Failed to get indicators after $retryCount retries: $($_.Exception.Message)" -Exception $_.Exception
                    break
                }
                else {
                    Write-Warning "[RemoveThreatIndicatorsQuery] $(Get-Date): Failed to get indicators. Retrying..."
                }
            }
        }

        # Exit if no indicators found
        if ($ThreatIndicators.Indicators.Count -eq 0 ) {
            Write-Verbose "[RemoveThreatIndicatorsQuery] $(Get-Date): No indicators found. Is Initial Run: $IndicatorsFound"
            Write-Warning "[RemoveThreatIndicatorsQuery] $(Get-Date): No indicators found! Exiting ..."
            break
        }
    
        # Enqueue Indicators
        try {
            Write-Verbose "[RemoveThreatIndicatorsQuery] $(Get-Date): Enqueuing indicators. Current Queue Count: $($IndicatorsNameQueue.Count). Number to Enqueue: $($ThreatIndicators.Indicators.Count)"
            # Enqueue indicators at a rate of 100 per 10 seconds. The page size is set to 100, so it will enqueue all indicators in the page
            foreach ($IndicatorName in $ThreatIndicators.Indicators.Name) {
                $IndicatorsNameQueue.Enqueue($IndicatorName)
                Write-Debug "[RemoveThreatIndicatorsQuery] $(Get-Date): Enqueued: $IndicatorName"
            }       
            # Introduce a delay of 10 seconds after each batch
            Start-Sleep -Seconds 10
        }  
        catch {
            Write-Error -Message "Failed to enqueue indicators: $($_.Exception.Message)" -Exception $_.Exception
            break
        }      
        Write-Verbose "[RemoveThreatIndicatorsQuery] $(Get-Date): Enqueued indicators count $($IndicatorsNameQueue.Count)"
    }

    # Enqueue Exit Signal to all Jobs
    Write-Verbose "[RemoveThreatIndicatorsQuery] $(Get-Date): Sending Exit Signal to all Jobs"
    0.. $RemovalJobs.ChildJobs.Count  | ForEach-Object { $IndicatorsNameQueue.Enqueue("`0") }

    $StoppingTimeOut = 120
    # Wait for all jobs to finish
    while ($RemovalJobs.State -contains "Running") {
        if ($ShowProgress -and $TotalToDelete -eq -1) {
            Write-Progress  -Id 0 -Activity "Removing Threat Indicators" -Status "Total Collected: $($TotalCollected.value) | Deleted: $($TotalSuccess.Value) | Failed: $($TotalFailed.Value) | Time Elapsed: $(New-TimeSpan -Start $StartTime -End (Get-Date))"
        }
        elseif ($ShowProgress) {
            Write-Progress  -Id 0 -Activity "Removing Threat Indicators" -Status "Total Collected: $($TotalCollected.value) | Deleted: $($TotalSuccess.Value) | Failed: $($TotalFailed.Value) | Time Elapsed: $(New-TimeSpan -Start $StartTime -End (Get-Date))" -PercentComplete ((($TotalSuccess.Value + $TotalFailed.Value) / $TotalToDelete) * 100)
        }

        if ($StoppingTimeOut -le 0) {
            Write-Warning "[RemoveThreatIndicatorsQuery] $(Get-Date): Jobs taking more than 120 seconds. Force stopping removal jobs"
            $RemovalJobs.where({ $_.State -eq "Running" }).ForEach({
                    Write-Warning "Stopping Job $($_.Name)"
                    Stop-Job -Job $_ 
                })
        }

        Write-Verbose "[RemoveThreatIndicatorsQuery] $(Get-Date): Waiting for Removal Jobs to finish. Count: $($RemovalJobs.ChildJobs.where({$_.State -eq "Running"}).Count )"
        0.. $RemovalJobs.ChildJobs.Count  | ForEach-Object { $IndicatorsNameQueue.Enqueue("`0") }
        $StoppingTimeOut = $StoppingTimeOut - 5
        Start-Sleep -Seconds 5
        continue
    }

    # Cleanup
    Write-Debug "[RemoveThreatIndicatorsQuery] $(Get-Date): ProgressStatus = Total Collected: $($TotalCollected.value) | Deleted: $($TotalSuccess.Value) | Failed: $($TotalFailed.Value) | Time Elapsed: $(New-TimeSpan -Start $StartTime -End (Get-Date))"

    if ($ShowProgress) {
        Write-Progress  -Id 0 -Activity "Removing Threat Indicators" -Status "Total Collected: $($TotalCollected.value) | Deleted: $($TotalSuccess.Value) | Failed: $($TotalFailed.Value) | Time Elapsed: $(New-TimeSpan -Start $StartTime -End (Get-Date))" -Completed
    }

    # Remove Jobs
    $RemovalJobs | Stop-Job | Remove-Job

    Write-Host "[RemoveThreatIndicatorsQuery] $(Get-Date): Total Indicators Collected: $($($TotalCollected.value))"
    Write-Host "[RemoveThreatIndicatorsQuery] $(Get-Date): Total Indicators Deleted: $($TotalSuccess.Value)"
    Write-Host "[RemoveThreatIndicatorsQuery] $(Get-Date): Total Indicators Failed to Delete: $($TotalFailed.Value)"
    Write-Host "[RemoveThreatIndicatorsQuery] $(Get-Date): Total Time Taken: $((Get-Date) - $StartTime)"
}


#endregion Public Functions

#region Exported Functions

#Export-ModuleMember -Function Get-ThreatIndicatorsQuery
#Export-ModuleMember -Function Get-ThreatIndicatorsMetrics
#Export-ModuleMember -Function Remove-ThreatIndicator
#Export-ModuleMember -Function Remove-ThreatIndicatorsQuery

#endregion Exported Functions
