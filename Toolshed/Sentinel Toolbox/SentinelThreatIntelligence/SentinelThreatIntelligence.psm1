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
    
    $OutputProperties.Date = Get-Date

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

    $ParametersForQuery = @(
        "Ids"
        "IncludeDisabled"
        "Keywords"
        "MaxConfidence"
        "MaxValidUntil"
        "MinConfidence"
        "MinValidUntil"
        "PageSize"
        "PatternTypes"
        #"SortByColumn"
        #"SortByOrder"
        "Sources"
        "ThreatTypes"
    )
    Write-Debug "[GetThreatIndicatorsQuery] $(Get-Date): Adding Parameters to the query"

    if (!$SkipToken) {
        Write-Debug "[GetThreatIndicatorsQuery] $(Get-Date): No SkipToken provided, adding parameters to the query"
        # Add parameters to the query
        $ParametersForQuery | ForEach-Object {
            if ($null -ne $PSBoundParameters[$_] -and $PSBoundParameters[$_] -ne -1) {
                Write-Debug "[GetThreatIndicatorsQuery] $(Get-Date): Adding Parameter to hash - $_ : $($PSBoundParameters[$_])"
                $getIndicatorsQueryPostParameters.Add($_, $PSBoundParameters[$_])
            }
        }        
        if ($SortByColumn -and $SortByOrder) {
            $SortBy = @()
            $SortBy += @{
                "itemKey"   = $SortByColumn
                "sortOrder" = $SortByOrder
            }
            $getIndicatorsQueryPostParameters.Add("sortBy", $SortBy)
            $getIndicatorsQueryPostParameters.sortBy.keys | ForEach-Object {
                Write-Debug "[GetThreatIndicatorsQuery] $(Get-Date): Adding SortBy Parameter to hash - $_ : $($getIndicatorsQueryPostParameters.sortBy[$_])"
            }
        }
        elseif ($SortByColumn -or $SortByColumn) {
            Write-Error -Message "Both SortByColumn and SortByOrder should be provided"
            exit 1
        }
    }
    else {
        Write-Debug "[GetThreatIndicatorsQuery] $(Get-Date): SkipToken provided, adding SkipToken to the query"
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
.PARAMETER Throttle
    Specifies the number of threads used for the removal process. Default value is 15.
.PARAMETER ShowProgress
    Specifies whether to show progress while deleting indicators.
.EXAMPLE
    Remove-ThreatIndicatorsQuery -SubscriptionId "12345678-1234-1234-1234-1234567890AB" -ResourceGroupName "MyResourceGroup" -WorkspaceName "MyWorkspace" -TotalToDelete 100 -IncludeDisabled -Keywords "malware" -MaxConfidence 80 -MaxValidUntil "2022-12-31" -MinConfidence 50 -MinValidUntil "2022-01-01" -PageSize 50 -PatternTypes "FileHash" -SortByColumn "Name" -SortByOrder "ascending" -Sources "Microsoft" -ThreatTypes "Malware"
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
        [string[]]$ThreatTypes,

        # The number of threads used for the removal process. More does not always mean faster as the API has a rate limit of 10 requests per second.
        [parameter(Mandatory = $false)]
        [ValidateRange(1, 15)]
        [int]$Throttle = 15
    )
    
    Write-Warning "This function runs using background jobs and will continue to run even if the script is stopped.`nTo stop the script, use:`n`nGet-Job | Stop-Job`n`nto stop the jobs in the current session"
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

    # Setup Variables
    $StartTime = Get-Date

    # Total Retrieved Indicators
    [ref] $TotalCollected = 0

    # Initial Deletetion Bucket Size
    [ref] $DeleteBucketSize = [int] 200

    # Last Deletion Bucket Date Time
    [ref] $LastDeletionBucketDateTime = Get-Date

    # Total Indicators Deleted
    [ref] $TotalSuccess = [int] 0

    # Total Indicators Failed to Delete
    [ref] $TotalFailed = [int] 0

    # Queue to store the indicators
    $IndicatorsNameQueue = [System.Collections.Concurrent.ConcurrentQueue[string]]::new()

    # Foreach parameter, if value, add to query
    $GetThreatIndicatorsQueryParameters = [ordered]@{}

    [ref] $JobInitialized = @{
        "CollectionJobs" = @{}
        "RemovalJobs"    = @{}
    }

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
            Write-Verbose "[RemoveThreatIndicatorsQuery][Main] $(Get-Date): Adding Parameter to hash - $_ : $($PSBoundParameters[$_])"
            $GetThreatIndicatorsQueryParameters.Add($_, $PSBoundParameters[$_])
        }
    }

    # Set the initial page size
    $GetThreatIndicatorsQueryParameters.Add("PageSize", 100)

    # Get the number of logical processors
    $NumberOfLogicalProcessors = [Environment]::ProcessorCount
    Write-Verbose "[RemoveThreatIndicatorsQuery][Main] $(Get-Date): Number of Logical Processors: $NumberOfLogicalProcessors"
    
    $NumberOfThreads = [math]::Min($NumberOfLogicalProcessors - 2, $Throttle)
    $NumberOfThreads = [math]::Max($NumberOfThreads, 1)
    Write-Verbose "[RemoveThreatIndicatorsQuery][Main] $(Get-Date): Max Number of Threads: $NumberOfThreads"

    # Get the initial access token
    $AccessToken = Get-AzAccessToken

    # Collection Job 
    $CollectionJobScriptBlock = {

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
        $TotalToDelete = $using:TotalToDelete
        $DeleteBucketSize = $using:DeleteBucketSize
        $GetThreatIndicatorsQueryParameters = $using:GetThreatIndicatorsQueryParameters
        $JobInitialized = $using:JobInitialized
        
        $VerbosePreference = $using:VerbosePreference
        $DebugPreference = $using:DebugPreference
        
        # Job Variables
        $MaxRetries = 3
        $Timeout = 120
        $QueueCountLimit = 100
        $IndicatorsFound = $false

        # Write-Verbose each variable and parameter
        Write-Debug "[RemoveThreatIndicatorsQuery][Collection $JobId] $(Get-Date): JobId = $JobId"
        Write-Debug "[RemoveThreatIndicatorsQuery][Collection $JobId] $(Get-Date): SubscriptionId = $SubscriptionId"
        Write-Debug "[RemoveThreatIndicatorsQuery][Collection $JobId] $(Get-Date): ResourceGroupName = $ResourceGroupName"
        Write-Debug "[RemoveThreatIndicatorsQuery][Collection $JobId] $(Get-Date): WorkspaceName = $WorkspaceName"
        Write-Debug "[RemoveThreatIndicatorsQuery][Collection $JobId] $(Get-Date): ModulePath = $ModulePath"
        Write-Debug "[RemoveThreatIndicatorsQuery][Collection $JobId] $(Get-Date): AccessToken = $($AccessToken.ExpiresOn)"

        Write-Debug "[RemoveThreatIndicatorsQuery][Collection $JobId] $(Get-Date): TotalCollected = $($TotalCollected.value)"
        Write-Debug "[RemoveThreatIndicatorsQuery][Collection $JobId] $(Get-Date): TotalSuccess = $($TotalSuccess.value)"
        Write-Debug "[RemoveThreatIndicatorsQuery][Collection $JobId] $(Get-Date): TotalFailed = $($TotalFailed.value)"
        Write-Debug "[RemoveThreatIndicatorsQuery][Collection $JobId] $(Get-Date): IndicatorsNameQueue Count = $($IndicatorsNameQueue.Count)"
        Write-Debug "[RemoveThreatIndicatorsQuery][Collection $JobId] $(Get-Date): TotalToDelete = $TotalToDelete"
        Write-Debug "[RemoveThreatIndicatorsQuery][Collection $JobId] $(Get-Date): DeleteBucketSize = $($DeleteBucketSize.value)"
        Write-Debug "[RemoveThreatIndicatorsQuery][Collection $JobId] $(Get-Date): GetThreatIndicatorsQueryParameters:"
        foreach ($key in $GetThreatIndicatorsQueryParameters.Keys) {
            Write-Debug "[RemoveThreatIndicatorsQuery][Collection $JobId] $(Get-Date): GetThreatIndicatorsQueryParameters.$key = $($GetThreatIndicatorsQueryParameters[$key])"
        }
        foreach ($key in $JobInitialized.value.CollectionJobs.Keys) {
            Write-Debug "[RemoveThreatIndicatorsQuery][Collection $JobId] $(Get-Date): JobInitialized.CollectionJobs.$key = $($JobInitialized.value.CollectionJobs[$key])"
        }

        # Job Setup
        Write-Verbose "[RemoveThreatIndicatorsQuery][Collection $JobId] $(Get-Date): Starting Collection Job"

        # Import the Module
        try {
            Write-Verbose "[RemoveThreatIndicatorsQuery][Collection $JobId] $(Get-Date): Importing Module"
            Import-Module $ModulePath
        }
        catch {
            Write-Error -Message "[RemoveThreatIndicatorsQuery][Collection $JobId] $(Get-Date): Failed to import module: $($_.Exception.Message)" -Exception $_.Exception
            break
        }

        # Authenticate
        try {
            Connect-AzAccount -Tenant $AccessToken.TenantId -AccountId $AccessToken.UserId -AccessToken $AccessToken.Token | Out-Null
            Write-Verbose "[RemoveThreatIndicatorsQuery][Collection $JobId] $(Get-Date): Authenticated"
        }
        catch {
            Write-Error -Message "[RemoveThreatIndicatorsQuery][Collection $JobId] $(Get-Date): Failed to authenticate: $($_.Exception.Message)" -Exception $_.Exception
            break
        }

        # This is a signal to the parent job that the child job has initialized and the parent job can continue
        Write-Debug "[RemoveThreatIndicatorsQuery][Collection $JobId] $(Get-Date): Setting JobInitialized.CollectionJobs.$JobId to true"
        $JobInitialized.value.CollectionJobs[$JobId] = $true
        Write-Debug "[RemoveThreatIndicatorsQuery][Collection $JobId] $(Get-Date): JobInitialized.CollectionJobs.$JobId = $($JobInitialized.value.CollectionJobs[$JobId])"

        # Main loop
        # This will run until:
        # 1. The TotalToDelete is reached.
        # 2. The Queue count is greater than 100 for the $QueueTimeout.
        # 3. Failed to get indicators after $maxRetries.
        # 4. No Indicators are found on the first run.
        # 5. Failed to queue the indicators.
        # 6. The script is stopped manually.
        # 7. Life as we know it ends.
        while ($true) {
            # Reset the retry count
            $retryCount = 0
        
            # Stop Collecting if the TotalCollected is greater than or equal to TotalToDelete
            Write-Debug "[RemoveThreatIndicatorsQuery][Main] $(Get-Date): Is greater than or equal to TotalToDelete: [$($TotalToDelete -ne -1 -and $($TotalCollected.value) -ge $TotalToDelete)]"
            Write-Debug "[RemoveThreatIndicatorsQuery][Main] $(Get-Date): TotalToDelete: $TotalToDelete. TotalCollected: $($TotalCollected.value)"
            if ($TotalToDelete -ne -1 -and $($TotalCollected.value) -ge $TotalToDelete) {
                Write-Verbose "[RemoveThreatIndicatorsQuery][Main] $(Get-Date): Total Collected: $($TotalCollected.value). Total to Delete: $TotalToDelete"
                Write-Verbose "[RemoveThreatIndicatorsQuery][Main] $(Get-Date): Exiting Enqueue Job"
                break
            }
                
            # Throttling Checks
            # If there are indicators in the after the first run and is greater than a count $QueueCountLimit, sleep for 10 seconds to prevent throttling
            Write-Debug "[RemoveThreatIndicatorsQuery][Main] $(Get-Date): Checking Queue Count [$($IndicatorsNameQueue.count)] is greater than or equal to the Queue Count Limit [$QueueCountLimit] and Indicators Found on initial run [$($IndicatorsFound)]: Pass = $($IndicatorsNameQueue.count -gt 100 -and $IndicatorsFound)"
            $QueueTimeout = $Timeout
            while ($IndicatorsNameQueue.count -ge $QueueCountLimit -and $IndicatorsFound) {
                # Sleep for the number of seconds it would take to reduce the queue count to 100 at a rate of 10 per second

                Write-Verbose "[RemoveThreatIndicatorsQuery][Main] $(Get-Date): Queue Count: $($IndicatorsNameQueue.count). Sleeping for 10 seconds to prevent throttling"
                Start-Sleep -Seconds 10
                Write-Debug "[RemoveThreatIndicatorsQuery][Main] $(Get-Date): Remaining Queue Wait in Seconds: $QueueTimeout"
                $QueueTimeout -= 10
                
                if ($QueueTimeout -le 0) {
                    Write-Error -Message "[RemoveThreatIndicatorsQuery][Main] $(Get-Date): Queue Timeout exceeded as the queue count has not fallen below 100. Exiting script to prevent buffer overflow. Consider running the script with debug and verbose options enabled to review the issues" 
                    exit
                }
            }
            
            if ($DeleteBucketSize.Value -lt $QueueCountLimit) {
                # The Deletion Bucket size refills at a rate of 10 per second
                # If the bucket size is less 40, sleep for the number of seconds it would take to refill the bucket to 200
                # This value is populated by the deletion jobs
                $RefillWait = [math]::Ceiling((200 - $DeleteBucketSize.Value) / $DeleteRefillRatePerSecond)
                Write-Verbose "[RemoveThreatIndicatorsQuery][Main] $(Get-Date): Delete Bucket Size: $($DeleteBucketSize.Value). Sleeping for $RefillWait seconds to prevent rate limiting"
                Start-Sleep -Seconds $RefillWait
            }

            # Set page size to not exceed the total to delete
            Write-Debug "[RemoveThreatIndicatorsQuery][Main] $(Get-Date): Checking Page Size is not greater than TotalToDelete : $($TotalToDelete -ne -1 -and $TotalCollected.Value + $GetThreatIndicatorsQueryParameters.PageSize -ge $TotalToDelete)"
            Write-Debug "[RemoveThreatIndicatorsQuery][Main] $(Get-Date): Evaluating Page Size. Total Collected: $($TotalCollected.value). Total to Delete: $TotalToDelete"
            if ($TotalToDelete -ne -1 -and $TotalCollected.Value + $GetThreatIndicatorsQueryParameters.PageSize -ge $TotalToDelete) {
                $GetThreatIndicatorsQueryParameters.PageSize = $TotalToDelete - $($TotalCollected.value)
            }
            Write-Debug "[RemoveThreatIndicatorsQuery][Main] $(Get-Date): Setting Page Size to $($GetThreatIndicatorsQueryParameters.PageSize)"

            # Get Threat Indicators
            while ($retryCount -lt $maxRetries) {
                Write-Debug "[RemoveThreatIndicatorsQuery][Main] $(Get-Date): Attempting to get indicators. Retry Count: $retryCount"
                try {
                    $ThreatIndicators = Get-ThreatIndicatorsQuery @GetThreatIndicatorsQueryParameters              
                    Write-Verbose "[RemoveThreatIndicatorsQuery][Main] $(Get-Date): Threat Indicators Count: $($ThreatIndicators.Indicators.Count)"
                    $TotalCollected.Value += $ThreatIndicators.Indicators.Count

                    # Set IndicatorsFound to true if indicators are found on the initial run.
                    if (-not $IndicatorsFound) {
                        $IndicatorsFound = $true
                    }
                    break
                }
                catch {
                    $retryCount++
                    if ($retryCount -eq $maxRetries) {
                        Write-Error -Message "[RemoveThreatIndicatorsQuery][Main] $(Get-Date): Failed to get indicators after $retryCount retries: $($_.Exception.Message)" -Exception $_.Exception
                        break
                    }
                    else {
                        Write-Warning "[RemoveThreatIndicatorsQuery][Main] $(Get-Date): Failed to get indicators. Retrying..."
                    }
                }
            }

            # Exit if no indicators found
            if ($ThreatIndicators.Indicators.Count -eq 0 ) {
                Write-Verbose "[RemoveThreatIndicatorsQuery][Main] $(Get-Date): No indicators found. Is Initial Run: $IndicatorsFound"
                Write-Warning "[RemoveThreatIndicatorsQuery][Main] $(Get-Date): No indicators found! Exiting ..."
                break
            }
    
            # Enqueue Indicators
            Write-Debug "[RemoveThreatIndicatorsQuery][Main] $(Get-Date): Enqueuing indicators. Current Queue Count: $($IndicatorsNameQueue.Count). Number to Enqueue: $($ThreatIndicators.Indicators.Count)"
            try {
                Write-Verbose "[RemoveThreatIndicatorsQuery][Main] $(Get-Date): Enqueuing indicators. Current Queue Count: $($IndicatorsNameQueue.Count). Number to Enqueue: $($ThreatIndicators.Indicators.Count)"
                # Enqueue indicators at a rate of 100 per 10 seconds. The page size is set to 100, so it will enqueue all indicators in the page
                foreach ($IndicatorName in $ThreatIndicators.Indicators.Name) {
                    $IndicatorsNameQueue.Enqueue($IndicatorName)
                    Write-Debug "[RemoveThreatIndicatorsQuery][Main] $(Get-Date): Enqueued: $IndicatorName"
                }       
                # Introduce a delay of 10 seconds after each batch
                Write-Debug "[RemoveThreatIndicatorsQuery][Main] $(Get-Date): Sleeping for 10 seconds to prevent throttling"
                Start-Sleep -Seconds 10
            }  
            catch {
                Write-Error -Message "[RemoveThreatIndicatorsQuery][Main] $(Get-Date): Failed to enqueue indicators: $($_.Exception.Message)" -Exception $_.Exception
                break
            }      
            Write-Verbose "[RemoveThreatIndicatorsQuery][Main] $(Get-Date): Enqueued indicators count $($IndicatorsNameQueue.Count)"
        }
    }
    
    # Removal Job
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
        $LastDeletionBucketDateTime = $using:LastDeletionBucketDateTime
        $JobInitialized = $using:JobInitialized

        $VerbosePreference = $using:VerbosePreference
        $DebugPreference = $using:DebugPreference

        # Job Variables
        $JobTimeout = 120
        $MaxRetries = 3
       
        # Write-Verbose each variable and parameter
        Write-Debug "[RemoveThreatIndicatorsQuery][Removal $JobId] $(Get-Date): JobId = $JobId"
        Write-Debug "[RemoveThreatIndicatorsQuery][Removal $JobId] $(Get-Date): SubscriptionId = $SubscriptionId"
        Write-Debug "[RemoveThreatIndicatorsQuery][Removal $JobId] $(Get-Date): ResourceGroupName = $ResourceGroupName"
        Write-Debug "[RemoveThreatIndicatorsQuery][Removal $JobId] $(Get-Date): WorkspaceName = $WorkspaceName"
        Write-Debug "[RemoveThreatIndicatorsQuery][Removal $JobId] $(Get-Date): ModulePath = $ModulePath"
        Write-Debug "[RemoveThreatIndicatorsQuery][Removal $JobId] $(Get-Date): AccessToken = $($AccessToken.ExpiresOn)"

        Write-Debug "[RemoveThreatIndicatorsQuery][Removal $JobId] $(Get-Date): TotalCollected = $($TotalCollected.value)"
        Write-Debug "[RemoveThreatIndicatorsQuery][Removal $JobId] $(Get-Date): TotalSuccess = $($TotalSuccess.value)"
        Write-Debug "[RemoveThreatIndicatorsQuery][Removal $JobId] $(Get-Date): TotalFailed = $($TotalFailed.value)"
        Write-Debug "[RemoveThreatIndicatorsQuery][Removal $JobId] $(Get-Date): IndicatorsNameQueue = $($IndicatorsNameQueue.Count)"
        Write-Debug "[RemoveThreatIndicatorsQuery][Removal $JobId] $(Get-Date): DeleteBucketSize = $($DeleteBucketSize.Value)"
        Write-Debug "[RemoveThreatIndicatorsQuery][Removal $JobId] $(Get-Date): LastDeletionBucketDateTime = $($LastDeletionBucketDateTime.Value)"
        foreach ($key in $JobInitialized.value.RemovalJobs.Keys) {
            Write-Debug "[RemoveThreatIndicatorsQuery][Removal $JobId] $(Get-Date): JobInitialized.RemovalJobs.$key = $($JobInitialized.value.RemovalJobs[$key])"
        }

    
        # Job Setup
        Write-Verbose "[RemoveThreatIndicatorsQuery][Removal $JobId] $(Get-Date): Starting Removal Job"

        # Import the Module
        try {
            Write-Verbose "[RemoveThreatIndicatorsQuery][Removal $JobId] $(Get-Date): Importing Module"
            Import-Module $ModulePath
        }
        catch {
            Write-Error -Message "[RemoveThreatIndicatorsQuery][Removal $JobId] $(Get-Date): Failed to import module: $($_.Exception.Message)" -Exception $_.Exception
            break
        }

        # Authenticate
        try {
            Connect-AzAccount -Tenant $AccessToken.TenantId -AccountId $AccessToken.UserId -AccessToken $AccessToken.Token | Out-Null
            Write-Verbose "[RemoveThreatIndicatorsQuery][Removal $JobId] $(Get-Date): Authenticated"
        }
        catch {
            Write-Error -Message "[RemoveThreatIndicatorsQuery][Removal $JobId] $(Get-Date): Failed to authenticate: $($_.Exception.Message)" -Exception $_.Exception
            break
        }
        
        # This is a signal to the parent job that the child job has initialized and the parent job can continue
        Write-Debug "[RemoveThreatIndicatorsQuery][Removal $JobId] $(Get-Date): Setting JobInitialized.RemovalJobs.$JobId to true"
        $JobInitialized.value.RemovalJobs[$JobId] = $true
        Write-Debug "[RemoveThreatIndicatorsQuery][Removal $JobId] $(Get-Date): JobInitialized.RemovalJobs.$JobId = $($JobInitialized.value.RemovalJobs[$JobId])"

        # Main loop. 
        # This will run until:
        # 1. The queue is empty for the number of seconds in $Timeout since the last indicator was fetched.
        # 2. The exit signal `0 is received. This is sent by the Collection Job when it is done.
        # 3. The number of retries is equal to the max retries when deleting an indicator has failed.
        # 4. The script is manually stopped.
        # 5. Someone hurls the computer out the window.
        $TimeoutStart = Get-Date
        while ($true) {
            # Get Indicator Name
            $IndicatorName = $null
            if ($IndicatorsNameQueue.TryDequeue([ref]$IndicatorName)) {
                Write-Verbose "[RemoveThreatIndicatorsQuery][Removal $JobId] $(Get-Date): Indicator Fetched: $IndicatorName"
                $TimeoutStart = Get-Date
            }
            else {
                Write-Debug "[RemoveThreatIndicatorsQuery][Removal $JobId] $(Get-Date): No Indicator in the queue."
            }

            # Exit if no indicator in the queue for the number of seconds in $Timeout
            if (-not $IndicatorName ) {
                # If the time since the last indicator is greater than or equal to the timeout, exit the script. This is to prevent the script from running indefinitely
                if ((Get-Date) - $TimeoutStart -ge (New-TimeSpan -Seconds $JobTimeout)) {
                    Write-Verbose "[RemoveThreatIndicatorsQuery][Removal $JobId] $(Get-Date): No Indicator in the queue for $JobTimeout seconds. Exiting Removal Job"
                    exit
                }
                else {
                    # If the time since the last indicator is less than the timeout, sleep for 2 seconds and continue
                    Write-Verbose "[RemoveThreatIndicatorsQuery][Removal $JobId] $(Get-Date): No Indicator in the queue. Waiting for $([math]::Ceiling($JobTimeout - ((Get-Date) - $TimeoutStart).TotalSeconds)) seconds"
                    Start-Sleep -Seconds 2
                    continue
                }
            }

            # Exit Signal. End the script if the indicator name is "`0". This indicates the script should exit
            if ($IndicatorName -eq "`0") {
                Write-Verbose "[RemoveThreatIndicatorsQuery][Removal $JobId] $(Get-Date): Exit Signal Received, Exiting Removal Job"
                exit
            }

            # Delete Indicator
            $retryCount = 0
            while ($retryCount -lt $maxRetries) {
                Write-Debug "[RemoveThreatIndicatorsQuery][Removal $JobId] $(Get-Date): Attempting to delete indicator. Retry Count: $retryCount"
                # Remove the indicator
                $Remove = Remove-ThreatIndicator -SubscriptionId $SubscriptionId -ResourceGroupName $ResourceGroupName -WorkspaceName $WorkspaceName -IndicatorName $IndicatorName -ShowRateLimitMetrics

                Write-Debug "[RemoveThreatIndicatorsQuery][Removal $JobId] $(Get-Date): Remaining Deletes: $($Remove.RateLimitMetrics.'x-ms-ratelimit-remaining-subscription-deletes'). Date: $($Remove.RateLimitMetrics.Date)"
                Write-Debug "[RemoveThreatIndicatorsQuery][Removal $JobId] $(Get-Date): Last Deletion Bucket Date Time [$($LastDeletionBucketDateTime.Value)] greater than or equal to $($Remove.RateLimitMetrics.Date): $($Remove.RateLimitMetrics.Date -gt $LastDeletionBucketDateTime.Value)"

                # Update the deletion bucket size and last deletion bucket date time if a new value is found and the date is greater than the last date
                if ($Remove.RateLimitMetrics.'x-ms-ratelimit-remaining-subscription-deletes' -and $Remove.RateLimitMetrics.Date -gt $LastDeletionBucketDateTime.Value) {
                    $DeleteBucketSize.Value = $Remove.RateLimitMetrics.'x-ms-ratelimit-remaining-subscription-deletes'
                    $LastDeletionBucketDateTime.Value = $Remove.RateLimitMetrics.Date
                }

                Write-Debug "[RemoveThreatIndicatorsQuery][Removal $JobId] $(Get-Date): Remove Status = $($Remove.Status)"
                # If the deletion is successful, log a success message and break the loop
                if ($Remove.Status -eq "Success") {
                    Write-Verbose "[RemoveThreatIndicatorsQuery][Removal $JobId] $(Get-Date): Indicator Deleted: $IndicatorName"
                    $TotalSuccess.Value ++
                    break
                }
                
                # Increment the retry count if the deletion fails
                $retryCount++

                # If the retry count is equal to the max retries, log an error and break the loop
                if ($retryCount -eq $maxRetries) {
                    Write-Error -Message "[RemoveThreatIndicatorsQuery][Removal $JobId] $(Get-Date): Failed to delete indicator: $IndicatorName after $retryCount retries: $($_.Exception.Message)" -Exception $_.Exception
                    $TotalFailed.Value ++
                    break
                }
                else {
                    # If the deletion fails, log a warning and retry
                    Write-Warning "[RemoveThreatIndicatorsQuery][Removal $JobId] $(Get-Date): Failed to delete indicator. Retrying..."
                    continue
                }
            }
        }
    }

    Write-Verbose "[RemoveThreatIndicatorsQuery][Main] $(Get-Date): Starting Removal Jobs"
    1 .. $NumberOfThreads | ForEach-Object {
        $JobInitialized.value.RemovalJobs.Add($_, $false)
    }

    $RemovalJobs = 1 .. $NumberOfThreads | ForEach-Object -ThrottleLimit $NumberOfThreads -AsJob -Parallel $RemoveJobScriptBlock 
    Start-Sleep -Seconds 3

    $RemovalJobStartTimeout = 30
    while ($true) {
        Write-Debug "[RemoveThreatIndicatorsQuery][Main] $(Get-Date): Removal Job Timeout Remaining: $RemovalJobStartTimeout seconds"
        Write-Debug "[RemoveThreatIndicatorsQuery][Main] $(Get-Date): Checking Removal Child Jobs: Count $($RemovalJobs.Child.Count)"
        $RemovalInitializedCount = $JobInitialized.value.RemovalJobs.Values.Where({ $_ -eq $true }).count
        $RemovalRunningCount = ($RemovalJobs | Get-Job).ChildJobs.state.Where({ $_ -eq "Running" }).count

        # If no jobs are running or initialized, exit
        Write-Debug "[RemoveThreatIndicatorsQuery][Main] $(Get-Date): Checking Removal Child Jobs Time Remaining [$RemovalJobStartTimeout], Running State Count [$RemovalRunningCount] and Initialized Count [$RemovalInitializedCount] | Pass = [$($RemovalJobStartTimeout -le 0 -and $RemovalRunningCount -eq 0 -or $RemovalInitializedCount -eq 0)]"
        if ($RemovalJobStartTimeout -le 0 -and $RemovalRunningCount -eq 0 -or $RemovalInitializedCount -eq 0) {
            Write-Error -Message "[RemoveThreatIndicatorsQuery][Main] $(Get-Date): Removal Jobs did not start successfully after 30 seconds. Exiting..."
            try {
                $RemovalJobs | Stop-Job 
            }
            catch {
                Write-Error -Message "[RemoveThreatIndicatorsQuery][Main] $(Get-Date): Failed to stop jobs. Stop jobs manually with 'Get-Job |Stop-Job' : $($_.Exception.Message)" -Exception $_.Exception
            }
            exit
        }

        # If some of the jobs are running and initialized, break the loop with a warning of degraded performance
        Write-Debug "[RemoveThreatIndicatorsQuery][Main] $(Get-Date): Checking Removal Child Jobs running state count [$RemovalRunningCount] and Initialized Count [$RemovalInitializedCount] equals number of threads [$NumberOfThreads] | Pass = [$($RemovalJobStartTimeout -le 0 -and $RemovalRunningCount -ne 0 -and $RemovalInitializedCount -ne 0)]"
        if ($RemovalJobStartTimeout -le 0 -and $RemovalRunningCount -ne 0 -and $RemovalInitializedCount -ne 0) {
            Write-Warning "[RemoveThreatIndicatorsQuery][Main] $(Get-Date): Some Removal Jobs did not start after 30 seconds. Degraded Performance"
            break
        }

        # If all jobs are running and initialized, break the loop
        Write-Debug "[RemoveThreatIndicatorsQuery][Main] $(Get-Date): Checking Removal Child Jobs running state count [$RemovalRunningCount] and Initialized Count [$RemovalInitializedCount] equals number of threads [$NumberOfThreads] | Pass = [$($RemovalRunningCount -eq $NumberOfThreads -and $RemovalInitializedCount -eq $NumberOfThreads)]"
        if ($RemovalRunningCount -eq $NumberOfThreads -and $RemovalInitializedCount -eq $NumberOfThreads) {
            Write-Verbose "[RemoveThreatIndicatorsQuery][Main] $(Get-Date): All Removal Jobs Started. $($RemovalInitializedCount)/$NumberOfThreads"
            break
        }
        
        Write-Debug "[RemoveThreatIndicatorsQuery][Main] $(Get-Date): Initialized [$($RemovalInitializedCount)], Number of Threads [$NumberOfThreads]"
        Write-Verbose "[RemoveThreatIndicatorsQuery][Main] $(Get-Date): Waiting for all Removal Jobs to start.  Initialized: $($RemovalInitializedCount)/$NumberOfThreads"
        $RemovalJobStartTimeout -= 2
        Start-Sleep -Seconds 2
        continue   
    }
    
    Write-Verbose "[RemoveThreatIndicatorsQuery][Main] $(Get-Date): Starting Collection Jobs"
    1 | ForEach-Object {
        $JobInitialized.value.CollectionJobs.Add($_, $false)
    }

    $CollectionJobs = 1 | ForEach-Object -ThrottleLimit 1 -AsJob -Parallel $CollectionJobScriptBlock
    Start-Sleep -Seconds 3

    $CollectionJobStartTimeOut = 30
    # Check each the child jobs for $Jobs and ensure the state is running and the output is "Initialized"
    while ($true) {
        Write-Debug "[RemoveThreatIndicatorsQuery][Main] $(Get-Date): Collection Job Timeout Remaining: $CollectionJobStartTimeOut seconds"
        $CollectionRunningCount = ($CollectionJobs | Get-Job).ChildJobs.state.Where({ $_ -eq "Running" }).count
        $CollectionInitializedCount = $JobInitialized.value.CollectionJobs.Values.Where({ $_ -eq $true }).count
        Write-Debug "[RemoveThreatIndicatorsQuery][Main] $(Get-Date): Checking Collection Child Running Count [$CollectionRunningCount]"
        Write-Debug "[RemoveThreatIndicatorsQuery][Main] $(Get-Date): Checking Collection Child Initialized Count [$CollectionInitializedCount]"

        # If no jobs are running or initialized, exit
        Write-Debug "[RemoveThreatIndicatorsQuery][Main] $(Get-Date): Checking Collection Child Jobs Time Remaining [$CollectionJobStartTimeOut], Running State Count [$CollectionRunningCount] and Initialized Count [$CollectionInitializedCount] | Pass = [$($CollectionJobStartTimeOut -le 0 -and $CollectionRunningCount -eq 0 -or $CollectionInitializedCount -eq 0)]"
        if ($CollectionJobStartTimeOut -le 0 -and $CollectionRunningCount -eq 0 -or $CollectionInitializedCount -eq 0) {
            Write-Error -Message "[RemoveThreatIndicatorsQuery][Main] $(Get-Date): Collection Jobs did not start successfully after 30 seconds. Exiting..."
            try {
                $RemovalJobs, $CollectionJob | Stop-Job 
            }
            catch {
                Write-Error -Message "[RemoveThreatIndicatorsQuery][Main] $(Get-Date): Failed to stop jobs. Stop jobs manually with 'Get-Job |Stop-Job' : $($_.Exception.Message)" -Exception $_.Exception
            }
            exit
        }

        # If all jobs are running and initialized, break the loop
        Write-Debug "[RemoveThreatIndicatorsQuery][Main] $(Get-Date): Checking Collection Child Jobs running state count [$CollectionRunningCount] and Initialized Count [$CollectionInitializedCount] equals [1] | Pass = [$($CollectionRunningCount -eq $NumberOfThreads -and $CollectionInitializedCount -eq 1)]"
        if ($CollectionRunningCount -eq 1 -and $CollectionInitializedCount -eq 1) {
            Write-Verbose "[RemoveThreatIndicatorsQuery][Main] $(Get-Date): All Collection Jobs Started. 1/1"
            break
        }

        Write-Verbose "[RemoveThreatIndicatorsQuery][Main] $(Get-Date): Waiting for Collection Job to start.  Initialized: [$($CollectionInitializedCount -eq 1)]"
        $CollectionJobStartTimeOut -= 5
        Start-Sleep -Seconds 5
        continue
    }

    $StopCommandSent = $false
    # Monitor Jobs
    while ($true) {
        # Show Progress
        Start-Sleep -Seconds 1
        Write-Debug "[RemoveThreatIndicatorsQuery][Main] $(Get-Date): ProgressStatus = Total Collected: $($TotalCollected.value) | Deleted: $($TotalSuccess.Value) | Failed: $($TotalFailed.Value) | Time Elapsed: $(New-TimeSpan -Start $StartTime -End (Get-Date))"
        Write-Debug "[RemoveThreatIndicatorsQuery][Main] $(Get-Date): ProgressPercentComplete = $((($TotalSuccess.Value + $TotalFailed.Value) / $TotalToDelete) * 100)"

        if ($ShowProgress -and $TotalToDelete -eq -1) {
            Write-Progress  -Id 0 -Activity "Removing Threat Indicators" -Status "Total Collected: $($TotalCollected.value) | Deleted: $($TotalSuccess.Value) | Failed: $($TotalFailed.Value) | Time Elapsed: $(New-TimeSpan -Start $StartTime -End (Get-Date))" -PercentComplete ((($TotalSuccess.Value + $TotalFailed.Value) / $TotalCollected.value) * 100)
        }
        elseif ($ShowProgress) {
            Write-Progress  -Id 0 -Activity "Removing Threat Indicators" -Status "Total Collected: $($TotalCollected.value) | Deleted: $($TotalSuccess.Value) | Failed: $($TotalFailed.Value) | Time Elapsed: $(New-TimeSpan -Start $StartTime -End (Get-Date))" -PercentComplete ((($TotalSuccess.Value + $TotalFailed.Value) / $TotalToDelete) * 100)
        }

        # If Collection job has completed, send the exit signal to the Removal Jobs 
        if ($StopCommandSent -eq $false -and $CollectionJobs.State.where({ $_ -ne "Running" }).count -eq 1) {
            Write-Debug "[RemoveThreatIndicatorsQuery][Main] $(Get-Date): Sending an exit signal foreach Removal child jobs"
            $RemovalJobs.ChildJobs | ForEach-Object {
                $IndicatorsNameQueue.Enqueue("`0")
            }
            $StopCommandSent = $true
        }

        # Check if all jobs are complete
        $AllJobs = $CollectionJobs, $RemovalJobs | Get-Job
        if ($AllJobs.State.where({ $_ -ne "Running" }).count -eq $AllJobs.Count) {
            Write-Verbose "[RemoveThreatIndicatorsQuery][Main] $(Get-Date): Jobs Completed"
            break
        }

        if ($TotalToDelete -ne -1 -and $TotalSuccess.Value + $TotalFailed.Value -ge $TotalToDelete) {
            Write-Verbose "[RemoveThreatIndicatorsQuery][Main] $(Get-Date): Total Deleted: $($TotalSuccess.Value + $TotalFailed.Value). Total to Delete: $TotalToDelete"
            Write-Verbose "[RemoveThreatIndicatorsQuery][Main] $(Get-Date): Exiting Monitor Jobs"
            break
        }

    }

    Write-Debug "[RemoveThreatIndicatorsQuery][Main] $(Get-Date): Completed: Total Collected: $($TotalCollected.value) | Deleted: $($TotalSuccess.Value) | Failed: $($TotalFailed.Value) | Time Elapsed: $(New-TimeSpan -Start $StartTime -End (Get-Date))"

    if ($ShowProgress) {
        Write-Progress  -Id 0 -Activity "Removing Threat Indicators" -Status "Total Collected: $($TotalCollected.value) | Deleted: $($TotalSuccess.Value) | Failed: $($TotalFailed.Value) | Time Elapsed: $(New-TimeSpan -Start $StartTime -End (Get-Date))" -Completed
    }
    
    if ($DebugPreference -eq "SilentlyContinue" -and $VerbosePreference -eq "SilentlyContinue") {
        $AllJobs = $CollectionJobs, $RemovalJobs | Get-Job
        $AllJobs | Stop-Job 
        $AllJobs | Remove-Job -Force
    } 
    else {
        Write-Debug "[RemoveThreatIndicatorsQuery][Main] $(Get-Date): Keeping Jobs for Debugging. Cleanup manually with 'Get-Job | Stop-Job' and 'Get-Job | Remove-Job -Force'"
        Write-Verbose "[RemoveThreatIndicatorsQuery][Main] $(Get-Date): Keeping Jobs for Debugging. Cleanup manually with 'Get-Job | Stop-Job' and 'Get-Job | Remove-Job -Force'"
    }

    Write-Host "[RemoveThreatIndicatorsQuery][Main] $(Get-Date): Total Indicators Collected: $($($TotalCollected.value))"
    Write-Host "[RemoveThreatIndicatorsQuery][Main] $(Get-Date): Total Indicators Deleted: $($TotalSuccess.Value)"
    Write-Host "[RemoveThreatIndicatorsQuery][Main] $(Get-Date): Total Indicators Failed to Delete: $($TotalFailed.Value)"
    Write-Host "[RemoveThreatIndicatorsQuery][Main] $(Get-Date): Total Time Taken: $((Get-Date) - $StartTime)"
}


#endregion Public Functions
