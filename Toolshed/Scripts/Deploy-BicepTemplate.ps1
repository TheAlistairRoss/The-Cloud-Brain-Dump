#Requires -Version 5.1
#Requires -Modules Az.Accounts, Az.Resources

<#
.SYNOPSIS
    Deploys a Bicep template to Azure Resource Group

.DESCRIPTION
    This script deploys any Bicep template using a Bicep parameter file with comprehensive 
    error handling, validation, and output display. Supports both deployment and what-if operations.

.PARAMETER SubscriptionId
    The Azure subscription ID where resources will be deployed

.PARAMETER ResourceGroupName
    The name of the resource group where resources will be deployed

.PARAMETER BicepFile
    Path to the Bicep template file (default: ".\main.bicep")

.PARAMETER ParameterFile
    Path to the Bicep parameter file (default: ".\main.bicepparam")

.PARAMETER DeploymentName
    Optional custom deployment name (default: auto-generated with timestamp)

.PARAMETER WhatIf
    Performs a what-if deployment to preview changes without actually deploying

.PARAMETER Force
    Bypasses confirmation prompts

.EXAMPLE
    .\Deploy-BicepTemplate.ps1 -SubscriptionId "12345678-1234-1234-1234-123456789012" -ResourceGroupName "my-resource-group"

.EXAMPLE
    .\Deploy-BicepTemplate.ps1 -SubscriptionId "12345678-1234-1234-1234-123456789012" -ResourceGroupName "my-resource-group" -BicepFile ".\templates\app.bicep" -ParameterFile ".\parameters\dev.bicepparam"

.EXAMPLE
    .\Deploy-BicepTemplate.ps1 -SubscriptionId "12345678-1234-1234-1234-123456789012" -ResourceGroupName "my-resource-group" -WhatIf

.NOTES
    Author: theAlistairRoss and Github Copilot
    Version: 1.0
    Requires: Azure PowerShell module (Az)
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $true, HelpMessage = "Azure subscription ID")]
    [ValidatePattern('^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$')]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory = $true, HelpMessage = "Resource group name")]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory = $false, HelpMessage = "Path to Bicep template file")]
    [ValidateNotNullOrEmpty()]
    [string]$BicepFile = ".\main.bicep",
    
    [Parameter(Mandatory = $false, HelpMessage = "Path to Bicep parameter file")]
    [ValidateNotNullOrEmpty()]
    [string]$ParameterFile = ".\main.bicepparam",
    
    [Parameter(Mandatory = $false, HelpMessage = "Custom deployment name")]
    [ValidateNotNullOrEmpty()]
    [string]$DeploymentName = "BicepDeployment-$(Get-Date -Format 'yyyyMMdd-HHmmss')",
    
    [Parameter(Mandatory = $false, HelpMessage = "Force deployment without confirmation")]
    [switch]$Force
)

# Set strict mode and error action preference
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Initialize variables
$script:ExitCode = 0

# Function to write timestamped log messages
function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet('Info', 'Warning', 'Error', 'Success')]
        [string]$Level = 'Info'
    )
    
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $prefix = switch ($Level) {
        'Info'    { '[INFO]' }
        'Warning' { '[WARN]' }
        'Error'   { '[ERROR]' }
        'Success' { '[SUCCESS]' }
    }
    
    $color = switch ($Level) {
        'Info'    { 'White' }
        'Warning' { 'Yellow' }
        'Error'   { 'Red' }
        'Success' { 'Green' }
    }
    
    Write-Host "$timestamp $prefix $Message" -ForegroundColor $color
}

# Function to validate prerequisites
function Test-Prerequisites {
    Write-Log "Validating prerequisites..." -Level Info
    
    # Check if required modules are installed
    $requiredModules = @('Az.Accounts', 'Az.Resources')
    foreach ($module in $requiredModules) {
        if (-not (Get-Module -Name $module -ListAvailable)) {
            Write-Log "Required module '$module' is not installed. Please install it using: Install-Module -Name $module" -Level Error
            return $false
        }
    }
    
    # Validate file paths
    if (-not (Test-Path -Path $BicepFile)) {
        Write-Log "Bicep file not found: $BicepFile" -Level Error
        return $false
    }
    
    if (-not (Test-Path -Path $ParameterFile)) {
        Write-Log "Parameter file not found: $ParameterFile" -Level Error
        return $false
    }
    
    # Validate Bicep file extension
    if ([System.IO.Path]::GetExtension($BicepFile) -ne '.bicep') {
        Write-Log "Invalid Bicep file extension. Expected .bicep file." -Level Error
        return $false
    }
    
    # Validate parameter file extension
    if ([System.IO.Path]::GetExtension($ParameterFile) -ne '.bicepparam') {
        Write-Log "Invalid parameter file extension. Expected .bicepparam file." -Level Error
        return $false
    }
    
    Write-Log "Prerequisites validation completed successfully" -Level Success
    return $true
}

# Function to set Azure context
function Set-AzureContext {
    Write-Log "Setting Azure context to subscription: $SubscriptionId" -Level Info
    
    try {
        # Check if already connected to Azure
        $context = Get-AzContext
        if (-not $context) {
            Write-Log "Not connected to Azure. Please run Connect-AzAccount first." -Level Error
            return $false
        }
        
        # Set the subscription context
        $null = Set-AzContext -SubscriptionId $SubscriptionId -ErrorAction Stop
        
        # Verify the context was set correctly
        $currentContext = Get-AzContext
        if ($currentContext.Subscription.Id -ne $SubscriptionId) {
            Write-Log "Failed to set subscription context" -Level Error
            return $false
        }
        
        Write-Log "Azure context set successfully" -Level Success
        return $true
    }
    catch {
        Write-Log "Failed to set Azure context: $($_.Exception.Message)" -Level Error
        return $false
    }
}

# Function to execute what-if deployment
function Invoke-WhatIfDeployment {
    Write-Log "Starting what-if analysis: $DeploymentName" -Level Info
    Write-Log "Resource Group: $ResourceGroupName" -Level Info
    Write-Log "Bicep File: $BicepFile" -Level Info
    Write-Log "Parameter File: $ParameterFile" -Level Info
    
    try {
        $whatIfParams = @{
            ResourceGroupName     = $ResourceGroupName
            TemplateFile         = $BicepFile
            TemplateParameterFile = $ParameterFile
            Verbose              = $true
        }
        
        $whatIfResult = Get-AzResourceGroupDeploymentWhatIfResult @whatIfParams
        
        Write-Log "What-if analysis completed" -Level Success
        Write-Log "Status: $($whatIfResult.Status)" -Level Info
        
        return $whatIfResult
    }
    catch {
        Write-Log "What-if analysis failed: $($_.Exception.Message)" -Level Error
        $script:ExitCode = 1
        throw
    }
}

# Function to execute deployment
function Invoke-Deployment {
    Write-Log "Starting deployment: $DeploymentName" -Level Info
    Write-Log "Resource Group: $ResourceGroupName" -Level Info
    Write-Log "Bicep File: $BicepFile" -Level Info
    Write-Log "Parameter File: $ParameterFile" -Level Info
    
    # Confirmation prompt unless -Force is specified
    if (-not $Force -and -not $PSCmdlet.ShouldProcess($ResourceGroupName, "Deploy Bicep template")) {
        Write-Log "Deployment cancelled by user" -Level Warning
        return $null
    }
    
    try {
        $deploymentParams = @{
            ResourceGroupName     = $ResourceGroupName
            TemplateFile         = $BicepFile
            TemplateParameterFile = $ParameterFile
            Name                 = $DeploymentName
            Verbose              = $true
        }
        
        $deployment = New-AzResourceGroupDeployment @deploymentParams
        
        if ($deployment.ProvisioningState -eq "Succeeded") {
            Write-Log "Deployment completed successfully" -Level Success
            
            # Display outputs
            Write-Log "Deployment Outputs:" -Level Info
            if ($deployment.Outputs -and $deployment.Outputs.Count -gt 0) {
                foreach ($output in $deployment.Outputs.GetEnumerator()) {
                    $outputName = $output.Key
                    $outputValue = $output.Value.Value
                    Write-Log "${outputName}: $outputValue" -Level Info
                }
            }
            else {
                Write-Log "No outputs defined in template" -Level Info
            }
            
            return $deployment
        }
        else {
            Write-Log "Deployment failed with status: $($deployment.ProvisioningState)" -Level Error
            $script:ExitCode = 1
            return $deployment
        }
    }
    catch {
        Write-Log "Deployment failed: $($_.Exception.Message)" -Level Error
        $script:ExitCode = 1
        throw
    }
}

# Main execution block
try {
    Write-Log "Starting Bicep deployment script" -Level Info
    
    # Validate prerequisites
    if (-not (Test-Prerequisites)) {
        $script:ExitCode = 1
        exit $script:ExitCode
    }
    
    # Set Azure context
    if (-not (Set-AzureContext)) {
        $script:ExitCode = 1
        exit $script:ExitCode
    }
    
    # Execute deployment or what-if
    if ($WhatIfPreference) {
        $result = Invoke-WhatIfDeployment
    }
    else {
        $result = Invoke-Deployment
    }
    
    Write-Log "Script execution completed" -Level Success
}
catch {
    Write-Log "Script execution failed: $($_.Exception.Message)" -Level Error
    $script:ExitCode = 1
}
finally {
    exit $script:ExitCode
}