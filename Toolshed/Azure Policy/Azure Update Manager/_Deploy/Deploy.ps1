param(
    #$SubscriptionId Parameter. This must be in a parameter set that is different to the management group parameter set
    [Parameter(Mandatory=$true,ParameterSetName="SubscriptionId")]
    [string]$SubscriptionId,

    #$ManagementGroupName Parameter. This must be in a parameter set that is different to the subscription ID parameter set
    [Parameter(Mandatory=$true,ParameterSetName="ManagementGroupName")]
    [string]$ManagementGroupName,

    # The branch of the GitHub repo to deploy from. Defaults to main
    [Parameter(Mandatory=$false)]
    [string]$branch = "main"

)

$policyDefinitions = @(
    "Update Management Center/set-azure-update-manager-settings-for-azure-machines",
    "Update Management Center/set-azure-update-manager-settings-for-azure-arc-machines"
)

$policySetDefinition = "Update Management Center/set-azure-update-manager-settings-for-machines"

$branch = "main"
$baseurl = "https://raw.githubusercontent.com/TheAlistairRoss/The-Cloud-Brain-Dump/$branch/Toolshed/Azure Policy/Azure Update Manager"

ForEach ($policyDefinition in $policyDefinitions) {
    $policyDefinitionUrl = [System.Uri]::EscapeUriString("$baseurl/policyDefinitions/$policyDefinition/"+"azurepolicy.json")
    # Get the content of a json file from a URL
    $policyContent = Invoke-WebRequest -Uri $policyDefinitionUrl | Select-Object -ExpandProperty Content
    # Convert the json content to a PowerShell object
    $policyContentJson = $policyContent | ConvertFrom-Json -Depth 20

    # Get the name of the policy definition
    $policyDefinitionName = $policyContentJson.name
    $policyDefinitionDisplayName = $policyContentJson.properties.displayName
    
    $NewAzPolicyDefinitionParams =  @{
        Name = $policyDefinitionName
        Policy = $policyContent   
    }
    if ($SubscriptionId){
        $NewAzPolicyDefinitionParams.Add("SubscriptionId",$SubscriptionId)
    }
    else {
        $NewAzPolicyDefinitionParams.Add("ManagementGroupName",$ManagementGroupName)
    }

    Write-Host "Deploying policy definition '$policyDefinitionDisplayName' ($policyDefinitionName) from $policyDefinitionUrl"
    New-AzPolicyDefinition @NewAzPolicyDefinitionParams 

}

$policySetDefinitionUrl = [System.Uri]::EscapeUriString("$baseurl/policySetDefinitions/$policySetDefinition/"+"azurepolicyset.json")
# Get the content of a json file from a URL
$policySetDefinitionContent = Invoke-WebRequest -Uri $policySetDefinitionUrl | Select-Object -ExpandProperty Content
# Convert the json content to a PowerShell object
$policySetDefinitionContentJson = $policySetDefinitionContent | ConvertFrom-Json -Depth 20

# Get the name of the policy definition
$policySetDefinitionSetName = $policySetDefinitionContentJson.name
$policySetDefinitionDisplayName = $policySetDefinitionContentJson.properties.displayName

$NewAzPolicySetDefinitionParams =  @{
    Name = $policySetDefinitionSetName
    DisplayName = $policySetDefinitionContentJson.properties.displayName
    Description = $policySetDefinitionContentJson.properties.description
    Metadata = $policySetDefinitionContentJson.properties.metadata | ConvertTo-Json
    Parameter = $policySetDefinitionContentJson.properties.parameters | ConvertTo-Json
}
if ($SubscriptionId){
    $NewAzPolicySetDefinitionParams.Add("SubscriptionId",$SubscriptionId)
    $policySetDefinitionIdPrefix = "/subscriptions/$SubscriptionId"

}
else {
    $NewAzPolicySetDefinitionParams.Add("ManagementGroupName",$ManagementGroupName)
    $policySetDefinitionIdPrefix = "/providers/Microsoft.Management/managementGroups/$ManagementGroupName"
}


$PolicySetdefinitionContentJson.properties.policyDefinitions | ForEach-Object {
    $_.policyDefinitionId = $policySetDefinitionIdPrefix + $_.policyDefinitionId
}

$policySetDefinitions = $PolicySetdefinitionContentJson.properties.policyDefinitions  |ConvertTo-Json -Depth 20

Write-Host "Deploying policy set definition '$policySetDefinitionDisplayName' ($policyDefinitionName) from $policyDefinitionSetUrl"

New-AzPolicySetDefinition @NewAzPolicySetDefinitionParams -PolicyDefinition $policySetDefinitions 
