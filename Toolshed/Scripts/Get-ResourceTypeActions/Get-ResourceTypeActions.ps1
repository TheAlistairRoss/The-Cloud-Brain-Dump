<#
.SYNOPSIS
    Discovers all resource types in a scope — including extension providers — and retrieves their actions.

.DESCRIPTION
    This script combines multiple discovery methods to build a complete picture of
    resource types in a given scope:

    1. Get-AzResource — discovers deployed top-level resources
    2. REST API /providers — identifies registered extension providers (SupportsExtension capability)
    3. ARM probing — for each deployed resource, probes registered extension providers to detect
       which extensions are actually attached (e.g., Microsoft.SecurityInsights on a Log Analytics workspace)

    Once all resource types are discovered, it queries Get-AzProviderOperation for each to return
    all control plane and data plane actions with their descriptions and action type.

.PARAMETER ResourceType
    One or more Azure resource types to query directly (e.g., "Microsoft.Storage/storageAccounts").
    Skips all discovery logic.

.PARAMETER SubscriptionId
    Target a subscription to discover resource types. Uses current context if omitted with -ResourceGroupName.

.PARAMETER ResourceGroupName
    Target a specific resource group to discover resource types, including extension providers.

.PARAMETER SkipExtensionProbe
    Skip the extension provider probing step. Faster but won't discover extensions like SecurityInsights.

.EXAMPLE
    # Direct resource type query
    .\Get-ResourceTypeActions.ps1 -ResourceType "Microsoft.Storage/storageAccounts"

.EXAMPLE
    # Multiple resource types
    .\Get-ResourceTypeActions.ps1 -ResourceType "Microsoft.Storage/storageAccounts","Microsoft.SecurityInsights"

.EXAMPLE
    # Full discovery including extension providers in a resource group
    .\Get-ResourceTypeActions.ps1 -SubscriptionId "00000000-0000-0000-0000-000000000000" -ResourceGroupName "myRG"

.EXAMPLE
    # Resource group in current subscription
    .\Get-ResourceTypeActions.ps1 -ResourceGroupName "myRG"

.EXAMPLE
    # Skip extension probing for faster results
    .\Get-ResourceTypeActions.ps1 -ResourceGroupName "myRG" -SkipExtensionProbe

.EXAMPLE
    # Pipe results
    .\Get-ResourceTypeActions.ps1 -ResourceGroupName "myRG" | Out-GridView
    .\Get-ResourceTypeActions.ps1 -ResourceGroupName "myRG" | Export-Csv .\actions.csv -NoTypeInformation
#>

[CmdletBinding(DefaultParameterSetName = 'ByType')]
param(
    [Parameter(Mandatory = $true, ParameterSetName = 'ByType', ValueFromPipeline = $true,
        HelpMessage = "One or more Azure resource types (e.g., Microsoft.Storage/storageAccounts)")]
    [string[]]$ResourceType,

    [Parameter(Mandatory = $false, ParameterSetName = 'ByScope',
        HelpMessage = "Subscription ID to discover resource types from")]
    [string]$SubscriptionId,

    [Parameter(Mandatory = $false, ParameterSetName = 'ByScope',
        HelpMessage = "Resource group name to discover resource types from")]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $false, ParameterSetName = 'ByScope',
        HelpMessage = "Skip extension provider probing (faster, but won't discover extensions)")]
    [switch]$SkipExtensionProbe
)

#region Module Check
if (-not (Get-Module -ListAvailable -Name Az.Resources)) {
    Write-Error "The Az.Resources module is required. Install it with: Install-Module -Name Az -Scope CurrentUser"
    return
}
Import-Module Az.Resources -ErrorAction Stop
#endregion

#region Helper Functions

function Get-RegisteredExtensionProviders {
    <#
    .SYNOPSIS
        Returns registered extension provider namespaces and their first listable resource type.
        Uses the REST API to access the capabilities property not exposed by Get-AzResourceProvider.
    #>
    param(
        [string]$SubscriptionId
    )

    $uri = "https://management.azure.com/subscriptions/$SubscriptionId/providers?api-version=2021-04-01"
    $response = Invoke-AzRestMethod -Method GET -Uri $uri -ErrorAction Stop

    if ($response.StatusCode -ne 200) {
        Write-Warning "Failed to retrieve providers via REST API (Status: $($response.StatusCode))"
        return @()
    }

    $providers = ($response.Content | ConvertFrom-Json -Depth 10).value |
        Where-Object { $_.registrationState -eq 'Registered' }

    $extensionProviders = @()

    foreach ($provider in $providers) {
        # Find resource types with SupportsExtension capability
        $extTypes = $provider.resourceTypes | Where-Object {
            $_.capabilities -match 'SupportsExtension'
        }

        if ($extTypes) {
            # Pick the first resource type that has locations (i.e., is a real listable type, not 'operations')
            $probeType = $extTypes | Where-Object { $_.locations.Count -gt 0 } | Select-Object -First 1
            if (-not $probeType) {
                $probeType = $extTypes | Select-Object -First 1
            }

            $latestApi = $probeType.apiVersions | Where-Object { $_ -notmatch 'preview' } | Select-Object -First 1
            if (-not $latestApi) {
                $latestApi = $probeType.apiVersions | Select-Object -First 1
            }

            $extensionProviders += [PSCustomObject]@{
                Namespace       = $provider.namespace
                ProbeType       = $probeType.resourceType
                ApiVersion      = $latestApi
                ResourceTypes   = ($extTypes | Select-Object -ExpandProperty resourceType)
            }
        }
    }

    return $extensionProviders
}

function Test-ExtensionOnResource {
    <#
    .SYNOPSIS
        Probes whether an extension provider has resources attached to a parent resource.
        Returns $true if the extension is active (200 with results or non-empty response).
    #>
    param(
        [string]$ParentResourceId,
        [string]$ExtensionNamespace,
        [string]$ExtensionResourceType,
        [string]$ApiVersion
    )

    $probeUri = "https://management.azure.com$ParentResourceId/providers/$ExtensionNamespace/$($ExtensionResourceType)?api-version=$ApiVersion"

    try {
        $resp = Invoke-AzRestMethod -Method GET -Uri $probeUri -ErrorAction SilentlyContinue
        if ($resp.StatusCode -eq 200) {
            $content = $resp.Content | ConvertFrom-Json -ErrorAction SilentlyContinue
            # Check if there's a value array with items, or any content indicating the extension is active
            if ($content.value -and ($content.value | Measure-Object).Count -gt 0) {
                return $true
            }
            # Some extension types return a single object (not an array)
            if (-not $content.value -and $content.id) {
                return $true
            }
        }
    }
    catch {
        # Silently ignore — extension not present
    }

    return $false
}

function Get-ActionsForResourceType {
    <#
    .SYNOPSIS
        Retrieves all operations for a given resource type, including child resources.
    #>
    param(
        [string]$Type,
        [string]$DiscoveryMethod
    )

    $operations = Get-AzProviderOperation -OperationSearchString "$Type/*"
    $parentOps = Get-AzProviderOperation -OperationSearchString "$Type"
    $operations = @($parentOps) + @($operations) | Sort-Object -Property Operation -Unique

    if (-not $operations -or $operations.Count -eq 0) {
        return @()
    }

    $results = $operations | ForEach-Object {
        $operationParts = $_.Operation -split '/'
        $actionVerb = $operationParts[-1]

        $actionType = switch -Wildcard ($actionVerb.ToLower()) {
            'read'   { 'Read' }
            'write'  { 'Write' }
            'delete' { 'Delete' }
            'action' { 'Action' }
            default  { 'Action' }
        }

        $plane = if ($_.IsDataAction) { 'Data' } else { 'Control' }

        [PSCustomObject]@{
            ResourceType    = $Type
            Operation       = $_.Operation
            ActionType      = $actionType
            Plane           = $plane
            DisplayName     = $_.OperationName
            Description     = $_.Description
            DiscoveryMethod = $DiscoveryMethod
        }
    }

    return $results
}

#endregion

#region Scope-Based Discovery

if ($PSCmdlet.ParameterSetName -eq 'ByScope') {

    # Set subscription context
    if ($SubscriptionId) {
        Write-Host "Setting subscription context to: $SubscriptionId" -ForegroundColor Cyan
        Set-AzContext -SubscriptionId $SubscriptionId -ErrorAction Stop | Out-Null
    }
    else {
        $SubscriptionId = (Get-AzContext).Subscription.Id
        Write-Host "Using current subscription: $SubscriptionId" -ForegroundColor Cyan
    }

    # --- Step 1: Discover deployed resources ---
    Write-Host ""
    Write-Host "=== Step 1: Discovering deployed resources ===" -ForegroundColor Yellow

    $getParams = @{}
    if ($ResourceGroupName) {
        Write-Host "Scope: Resource Group '$ResourceGroupName'" -ForegroundColor Cyan
        $getParams['ResourceGroupName'] = $ResourceGroupName
    }
    else {
        Write-Host "Scope: Entire subscription" -ForegroundColor Cyan
    }

    $deployedResources = Get-AzResource @getParams -ErrorAction Stop
    $deployedTypes = $deployedResources | Select-Object -ExpandProperty ResourceType -Unique | Sort-Object
    $deployedProviders = $deployedTypes | ForEach-Object { ($_ -split '/')[0] } | Select-Object -Unique

    Write-Host "Found $($deployedTypes.Count) deployed resource type(s):" -ForegroundColor Green
    $deployedTypes | ForEach-Object { Write-Host "  [Deployed] $_" -ForegroundColor White }

    # --- Step 2: Discover extension providers ---
    $extensionNamespaces = @()

    if (-not $SkipExtensionProbe) {
        Write-Host ""
        Write-Host "=== Step 2: Discovering registered extension providers ===" -ForegroundColor Yellow

        $extensionProviders = Get-RegisteredExtensionProviders -SubscriptionId $SubscriptionId

        # Exclude extension providers already covered by deployed resources
        $uncoveredExtensions = $extensionProviders | Where-Object {
            $_.Namespace -notin $deployedProviders
        }

        Write-Host "Found $($extensionProviders.Count) registered extension provider(s), $($uncoveredExtensions.Count) not covered by deployed resources" -ForegroundColor Green

        # --- Step 3: Probe extension providers against deployed resources ---
        if ($uncoveredExtensions.Count -gt 0) {
            Write-Host ""
            Write-Host "=== Step 3: Probing extension providers against deployed resources ===" -ForegroundColor Yellow
            Write-Host "Testing $($uncoveredExtensions.Count) extension provider(s) against $($deployedResources.Count) resource(s)..." -ForegroundColor Cyan

            $discoveredExtensions = @{}
            $notFoundExtensions = @()
            $extIndex = 0

            foreach ($ext in $uncoveredExtensions) {
                $extIndex++
                $extPct = [math]::Round(($extIndex / $uncoveredExtensions.Count) * 100)
                Write-Progress -Id 1 -Activity "Probing extension providers" `
                    -Status "[$extIndex/$($uncoveredExtensions.Count)] $($ext.Namespace)" `
                    -PercentComplete $extPct

                $found = $false
                $resIndex = 0

                foreach ($resource in $deployedResources) {
                    $resIndex++
                    $resPct = [math]::Round(($resIndex / $deployedResources.Count) * 100)
                    Write-Progress -Id 2 -ParentId 1 -Activity "Testing against resources" `
                        -Status "[$resIndex/$($deployedResources.Count)] $($resource.Name) ($($resource.ResourceType))" `
                        -PercentComplete $resPct

                    $isActive = Test-ExtensionOnResource `
                        -ParentResourceId $resource.ResourceId `
                        -ExtensionNamespace $ext.Namespace `
                        -ExtensionResourceType $ext.ProbeType `
                        -ApiVersion $ext.ApiVersion

                    if ($isActive -and -not $discoveredExtensions.ContainsKey($ext.Namespace)) {
                        $discoveredExtensions[$ext.Namespace] = $ext
                        Write-Host "  [Extension Found] $($ext.Namespace) attached to $($resource.Name) ($($resource.ResourceType))" -ForegroundColor Magenta
                        $found = $true
                        break  # No need to probe other resources for this extension
                    }
                }

                Write-Progress -Id 2 -ParentId 1 -Activity "Testing against resources" -Completed

                if (-not $found) {
                    $notFoundExtensions += $ext.Namespace
                    Write-Host "  [Not Found] $($ext.Namespace) — probed $($deployedResources.Count) resource(s), no attachment detected" -ForegroundColor DarkGray
                }
            }

            Write-Progress -Id 1 -Activity "Probing extension providers" -Completed

            $extensionNamespaces = $discoveredExtensions.Keys | Sort-Object
            Write-Host ""
            Write-Host "Discovered $($extensionNamespaces.Count) active extension provider(s)" -ForegroundColor Green
            $extensionNamespaces | ForEach-Object { Write-Host "  [Extension] $_" -ForegroundColor Magenta }

            if ($notFoundExtensions.Count -gt 0) {
                Write-Host ""
                Write-Host "$($notFoundExtensions.Count) extension provider(s) tested with no results:" -ForegroundColor DarkGray
                $notFoundExtensions | Sort-Object | ForEach-Object { Write-Host "  [No Match] $_" -ForegroundColor DarkGray }
            }
        }
    }
    else {
        Write-Host ""
        Write-Host "=== Step 2: Skipping extension provider discovery (SkipExtensionProbe) ===" -ForegroundColor Yellow
    }

    # --- Build final resource type list ---
    $ResourceType = @($deployedTypes)
    foreach ($ns in $extensionNamespaces) {
        $ResourceType += $ns
    }

    Write-Host ""
    Write-Host "=== Final resource type list: $($ResourceType.Count) type(s) ===" -ForegroundColor Yellow
    Write-Host ""
}

#endregion

#region Query Operations for Each Resource Type

$allResults = [System.Collections.Generic.List[PSObject]]::new()

foreach ($type in $ResourceType) {
    # Determine if this is an extension namespace (no '/' means it's a provider namespace, not a specific type)
    $isExtensionNamespace = $type -notmatch '/'
    $discoveryMethod = if ($PSCmdlet.ParameterSetName -eq 'ByType') { 'Manual' }
                       elseif ($type -in $extensionNamespaces) { 'Extension Probe' }
                       else { 'Deployed Resource' }

    if ($isExtensionNamespace) {
        # For extension providers, query all operations under the namespace
        Write-Host "Querying operations for extension provider: $type/*" -ForegroundColor Cyan
        $searchString = "$type/*"
        $operations = Get-AzProviderOperation -OperationSearchString $searchString

        if (-not $operations -or $operations.Count -eq 0) {
            Write-Warning "No operations found for extension provider: $type"
            continue
        }

        $results = $operations | ForEach-Object {
            $operationParts = $_.Operation -split '/'
            $actionVerb = $operationParts[-1]

            $actionType = switch -Wildcard ($actionVerb.ToLower()) {
                'read'   { 'Read' }
                'write'  { 'Write' }
                'delete' { 'Delete' }
                'action' { 'Action' }
                default  { 'Action' }
            }

            $plane = if ($_.IsDataAction) { 'Data' } else { 'Control' }

            [PSCustomObject]@{
                ResourceType    = $type
                Operation       = $_.Operation
                ActionType      = $actionType
                Plane           = $plane
                DisplayName     = $_.OperationName
                Description     = $_.Description
                DiscoveryMethod = $discoveryMethod
            }
        }

        foreach ($r in $results) { $allResults.Add($r) }

        $controlCount = ($results | Where-Object { $_.Plane -eq 'Control' }).Count
        $dataCount = ($results | Where-Object { $_.Plane -eq 'Data' }).Count
        Write-Host "  $type — $($results.Count) operations (Control: $controlCount, Data: $dataCount)" -ForegroundColor Green
    }
    else {
        Write-Host "Querying operations for: $type" -ForegroundColor Cyan
        $results = Get-ActionsForResourceType -Type $type -DiscoveryMethod $discoveryMethod

        if ($results.Count -eq 0) {
            Write-Warning "No operations found for: $type"
            continue
        }

        foreach ($r in $results) { $allResults.Add($r) }

        $controlCount = ($results | Where-Object { $_.Plane -eq 'Control' }).Count
        $dataCount = ($results | Where-Object { $_.Plane -eq 'Data' }).Count
        Write-Host "  $type — $($results.Count) operations (Control: $controlCount, Data: $dataCount)" -ForegroundColor Green
    }
}

#endregion

#region Output

# Sort results
$allResults = $allResults | Sort-Object -Property ResourceType, Plane, ActionType, Operation

# Summary
$uniqueTypes = ($allResults | Select-Object -ExpandProperty ResourceType -Unique).Count
$totalOps = $allResults.Count
$controlTotal = ($allResults | Where-Object { $_.Plane -eq 'Control' }).Count
$dataTotal = ($allResults | Where-Object { $_.Plane -eq 'Data' }).Count

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "  Summary" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host "  Resource Types:        $uniqueTypes" -ForegroundColor White
Write-Host "  Total Operations:      $totalOps" -ForegroundColor White
Write-Host "  Control Plane Actions: $controlTotal" -ForegroundColor White
Write-Host "  Data Plane Actions:    $dataTotal" -ForegroundColor White

if ($PSCmdlet.ParameterSetName -eq 'ByScope' -and -not $SkipExtensionProbe) {
    $extOps = ($allResults | Where-Object { $_.DiscoveryMethod -eq 'Extension Probe' }).Count
    Write-Host "  Extension Operations:  $extOps" -ForegroundColor Magenta
}

Write-Host "============================================" -ForegroundColor Green
Write-Host ""

# Return results to pipeline
return $allResults

#endregion
