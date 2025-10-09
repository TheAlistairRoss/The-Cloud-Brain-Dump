<#
.SYNOPSIS
    Exports Microsoft Sentinel Hunts (preview and the relations) to an ARM template
.DESCRIPTION
    This will export all your Hunts and their relations to a single ARM template. You will need to sign in to the using Connect-AzAccount before running the script. 
    
    It will create an ARM template in current directory called "Microsoft Sentinel Hunts <Date Time>.template.json"
.NOTES
    There is little error checking in this script for scenarios, such as the ARM template is too large for deployments of any dynamic referencing of Hunt Relation resources.
.LINK
    https://thealistairross.co.uk/2023/09/01/exporting-microsoft-sentinel-hunts-preview-to-arm/
.EXAMPLE
    .\Export-Hunts.ps1 - WorkspaceId "/subscriptions/00000000-0000-0000-0000-000000000000/resourcegroups/<myResourceGroup>/providers/microsoft.operationalinsights/workspaces/<myWorkspaceName>"
#>

param(
    [string]
    $workspaceId 
)

#Constants
$baseUrl = "https://management.azure.com"
$workspaceScopeFunction = "[format('Microsoft.OperationalInsights/workspaces/{0}', parameters('workspaceName'))]"
$template = [ordered]@{
    '$schema'      = 'https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#'
    contentVersion = '1.0.0.0'
    parameters     = @{
        workspaceName = @{
            type = "string"
        }
    }
    resources      = @()
}

# List Hunts
$apiVersion = "2023-07-01-preview"
$url = $baseUrl + $workspaceResourceId + "/providers/Microsoft.SecurityInsights/hunts?api-version=" + $apiVersion
$request = Invoke-AzRestMethod -Uri $url -Method GET

if ($request.StatusCode -ne 200) {
    Write-Error "Failed to get hunts. Ensure the workspace id is correct and you have signed in with an account with correct permissions"
    $url
    exit
}

# Iterate though each hunt to build the resource and get relations
$i = 1
$hunts = ($request.content | convertfrom-json -Depth 5).value
foreach ($hunt in $hunts) {
    Start-Sleep -Seconds 1 # Added to ensure unique file names and avoid API throttling
    Write-Progress -Activity "Exporting Hunts" -Status "$i of $($Hunts.count)" -PercentComplete ((100 / $Hunts.count) * $i) -Id "1"

    # Build Hunts resource
    $huntResource = [ordered]@{
        type       = $hunt.type
        apiVersion = $apiVersion
        scope      = $workspaceScopeFunction
        name       = $hunt.name
        properties = $hunt.properties
    }
    $template.resources += $huntResource

    # Get and build the hunt relations
    $apiVersion = "2023-07-01-preview"
    $url = $baseUrl + $workspaceResourceId + "/providers/Microsoft.SecurityInsights/hunts/" + $hunt.name + "/relations?api-version=" + $apiVersion
    $request = Invoke-AzRestMethod -Uri $url -Method GET
    $huntRelations = ($request.content | convertfrom-json -Depth 5).value

    $i2 = 1
    foreach ($huntRelation in $huntRelations) {
        Write-Progress -Activity "Exporting Hunts Relation" -Status "$i2 of $($huntRelations.count)" -PercentComplete ((100 / $huntRelations.count) * $i2) -Id "2"

        $huntRelationResource = [ordered]@{
            type       = $huntRelation.type
            apiVersion = $apiVersion
            scope      = $workspaceScopeFunction
            name       = $hunt.name + "/" + $huntRelation.name
            properties = $huntRelation.properties
            dependsOn  = @(
                "[extensionResourceId(resourceId('Microsoft.OperationalInsights/workspaces', parameters('workspaceName')), 'Microsoft.SecurityInsights/hunts', '$($hunt.name)')]"
            )
        }
        $template.resources += $huntRelationResource
        $i2++

    }
    $i++

}
Write-Progress -Activity "Exporting Hunts Relation" -Id 2 -Completed
Write-Progress -Activity "Exporting Hunts" -Id 1 -Completed

# Output template file
$fileDateTime = Get-Date -Format 'yyyy-MM-dd hh_mm_ss'
$templateName = "Microsoft Sentinel Hunts " + $fileDateTime + ".template.json"
$template | ConvertTo-Json -Depth 50 | Out-File -FilePath $templateName -ErrorAction Stop

Write-Host "Script Complete"
