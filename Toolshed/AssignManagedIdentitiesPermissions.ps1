# Assign Managed Identity Permissions
# Author: TheAlistairRoss

$TenantId = "00000000-0000-0000-0000-000000000000"
$ObjectId = "00000000-0000-0000-0000-000000000000" #Use the object id to avoid ambiguity

$oPermissions = @(
    @{
    apiId       = "fc780465-2017-40d4-a0c5-307022471b92" #WindowsDefenderATP 
    permissions = @(
      "Vulnerability.Read.All"
    )
  }
)

# Connect to Microsoft graph with the required scope
Connect-MgGraph -TenantId $TenantId -Scopes @("AppRoleAssignment.ReadWrite.All", "Application.Read.All")

#Part 1 - Get the Application Object Id
if ($ObjectId) {
  Write-Host "Getting Service Principal with the Object Id: $ObjectId"
  $oPrincipalId = (Get-MgServicePrincipal -ServicePrincipalId $ObjectId).id
}
  
if (-not $oPrincipalId) {
  Write-Host "No Service Principal found. Check the Managed Identity Object Id and try again."
  exit
}

#Part 2
$oApiSPNs = @()
foreach ($permissions in $oPermissions) {
  $oApiSPNs += Get-MgServicePrincipal -Filter "appId eq '$($permissions.apiId)'"
}


#Part 3 
foreach ($oApiSPN in $oApiSPNs) { 
  $oAppRoles = @()
  $oApiPermissions = $oPermissions | Where-Object { $_.apiId -eq $oApiSPN.AppId }

  $oAppRoles += $oApiSPN.AppRoles | Where-Object { ($_.Value -in $oAapiPermissions.Permissions) -and ($_.AllowedMemberTypes -contains "Application") }

  foreach ($oAppRole in $oAppRoles) {
    New-MgServicePrincipalAppRoleAssignment `
      -ServicePrincipalId $oPrincipalId `
      -PrincipalId $oPrincipalId `
      -ResourceId $oApiSPN.Id `
      -AppRoleId $oAppRole.Id `
      -Verbose
  }
}

# Verify
<#
Get-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $oPrincipalId | Format-Table -AutoSize
#>

$Link = "https://portal.azure.com/#view/Microsoft_AAD_IAM/ManagedAppMenuBlade/~/Permissions/objectId/$($oMsi.Id)/appId/$($oMsi.AppId)/preferredSingleSignOnMode~/null/servicePrincipalType/ManagedIdentity"
Write-Host "View permissions in the portal. Follow link here --->  " -ForegroundColor Green -NoNewline
Write-Host "$Link" -ForegroundColor Cyan


# Clean Up
# Note this removes all app roles
<#
Get-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $oPrincipalId | Foreach-Object {
  Remove-MgServicePrincipalAppRoleAssignment `
    -ServicePrincipalId $oPrincipalId `
    -AppRoleAssignmentId $_.Id
}
#>
