#Requires -Version 7.0
<#
.SYNOPSIS
    Builds ARM templates and parameter files from Bicep files.

.DESCRIPTION
    This script compiles Bicep templates to ARM JSON format and generates corresponding
    parameter files. It validates the Bicep files before compilation and provides
    detailed output about the build process.

.PARAMETER BicepFile
    Path to the main Bicep template file to compile.
    Default: "bicep\main.bicep"

.PARAMETER OutputDirectory
    Directory where the compiled ARM templates will be saved.
    Default: "arm-templates"

.PARAMETER ParameterFile
    Path to the Bicep parameter file to compile to ARM parameters.
    Optional - if not provided, only the template will be compiled.

.PARAMETER Force
    Overwrite existing ARM template files without prompting.

.PARAMETER Verbose
    Enable verbose output for detailed build information.

.EXAMPLE
    .\scripts\Build-ArmTemplates.ps1
    Builds ARM template from default Bicep file to default output directory.

.EXAMPLE
    .\scripts\Build-ArmTemplates.ps1 -BicepFile "bicep\main.bicep" -ParameterFile ".local\main.bicepparam" -OutputDirectory "dist"
    Builds both ARM template and parameters file to custom output directory.

.EXAMPLE
    .\scripts\Build-ArmTemplates.ps1 -Force -Verbose
    Builds with verbose output and overwrites existing files.

.NOTES
    Author: theAlistairRoss and Github Copilot
    Version: 1.0.0
    Requires: Azure CLI with Bicep CLI extension or standalone Bicep CLI
    Last Updated: 2025-10-09
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$BicepFile = "bicep\main.bicep",
    
    [Parameter(Mandatory = $false)]
    [string]$OutputDirectory = "arm",
    
    [Parameter(Mandatory = $false)]
    [string]$ParameterFile = "",
    
    [Parameter(Mandatory = $false)]
    [switch]$Force,
    
    [Parameter(Mandatory = $false)]
    [switch]$VerboseOutput
)

# Error handling
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Logging functions
function Write-Log {
    param(
        [string]$Message,
        [ValidateSet('INFO', 'SUCCESS', 'WARNING', 'ERROR')]
        [string]$Level = 'INFO'
    )
    
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $color = switch ($Level) {
        'INFO' { 'White' }
        'SUCCESS' { 'Green' }
        'WARNING' { 'Yellow' }
        'ERROR' { 'Red' }
    }
    
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

function Test-Prerequisites {
    Write-Log "Validating prerequisites..."
    
    # Check if Bicep CLI is available
    try {
        $bicepVersion = bicep --version 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Log "Bicep CLI found: $bicepVersion" -Level 'SUCCESS'
            return $true
        }
    }
    catch {
        # Bicep CLI not found, check Azure CLI
    }
    
    # Check if Azure CLI with Bicep extension is available
    try {
        $azVersion = az version --query '"azure-cli"' -o tsv 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Log "Azure CLI found: $azVersion" -Level 'SUCCESS'
            
            # Check if Bicep extension is installed
            $bicepExtension = az extension list --query "[?name=='bicep'].version" -o tsv 2>$null
            if ($bicepExtension) {
                Write-Log "Azure CLI Bicep extension found: $bicepExtension" -Level 'SUCCESS'
                return $false  # Use Azure CLI instead of standalone Bicep
            }
            else {
                Write-Log "Azure CLI Bicep extension not found. Installing..." -Level 'WARNING'
                az extension add --name bicep --only-show-errors
                return $false
            }
        }
    }
    catch {
        # Azure CLI not found
    }
    
    throw "Neither Bicep CLI nor Azure CLI with Bicep extension is available. Please install one of them."
}

function Build-ARMTemplate {
    param(
        [string]$InputFile,
        [string]$OutputFile,
        [bool]$UseStandaloneBicep
    )
    
    Write-Log "Building ARM template from: $InputFile"
    Write-Log "Output file: $OutputFile"
    
    try {
        if ($UseStandaloneBicep) {
            # Use standalone Bicep CLI
            if ($VerboseOutput) {
                bicep build $InputFile --outfile $OutputFile --verbose
            }
            else {
                bicep build $InputFile --outfile $OutputFile
            }
        }
        else {
            # Use Azure CLI Bicep
            if ($VerboseOutput) {
                az bicep build --file $InputFile --outfile $OutputFile --verbose
            }
            else {
                az bicep build --file $InputFile --outfile $OutputFile
            }
        }
        
        if ($LASTEXITCODE -eq 0) {
            Write-Log "ARM template built successfully: $OutputFile" -Level 'SUCCESS'
            
            # Get file size for information
            $fileSize = (Get-Item $OutputFile).Length
            $fileSizeKB = [math]::Round($fileSize / 1KB, 2)
            Write-Log "Template size: $fileSizeKB KB"
            
            return $true
        }
        else {
            throw "Bicep build failed with exit code: $LASTEXITCODE"
        }
    }
    catch {
        Write-Log "Failed to build ARM template: $($_.Exception.Message)" -Level 'ERROR'
        throw
    }
}

function Build-ARMParameters {
    param(
        [string]$InputFile,
        [string]$OutputFile,
        [bool]$UseStandaloneBicep
    )
    
    Write-Log "Building ARM parameters from: $InputFile"
    Write-Log "Output file: $OutputFile"
    
    try {
        if ($UseStandaloneBicep) {
            # Use standalone Bicep CLI
            if ($VerboseOutput) {
                bicep build-params $InputFile --outfile $OutputFile --verbose
            }
            else {
                bicep build-params $InputFile --outfile $OutputFile
            }
        }
        else {
            # Use Azure CLI Bicep
            if ($VerboseOutput) {
                az bicep build-params --file $InputFile --outfile $OutputFile --verbose
            }
            else {
                az bicep build-params --file $InputFile --outfile $OutputFile
            }
        }
        
        if ($LASTEXITCODE -eq 0) {
            Write-Log "ARM parameters built successfully: $OutputFile" -Level 'SUCCESS'
            
            # Get file size for information
            $fileSize = (Get-Item $OutputFile).Length
            $fileSizeKB = [math]::Round($fileSize / 1KB, 2)
            Write-Log "Parameters size: $fileSizeKB KB"
            
            return $true
        }
        else {
            throw "Bicep parameters build failed with exit code: $LASTEXITCODE"
        }
    }
    catch {
        Write-Log "Failed to build ARM parameters: $($_.Exception.Message)" -Level 'ERROR'
        throw
    }
}

function Test-BicepFile {
    param(
        [string]$FilePath
    )
    
    if (-not (Test-Path $FilePath)) {
        throw "Bicep file not found: $FilePath"
    }
    
    $extension = [System.IO.Path]::GetExtension($FilePath)
    if ($extension -ne '.bicep' -and $extension -ne '.bicepparam') {
        throw "Invalid file extension. Expected .bicep or .bicepparam, got: $extension"
    }
    
    Write-Log "Validated Bicep file: $FilePath" -Level 'SUCCESS'
}

# Main execution
try {
    Write-Log "Starting ARM template build process"
    Write-Log "Bicep File: $BicepFile"
    Write-Log "Output Directory: $OutputDirectory"
    if ($ParameterFile) {
        Write-Log "Parameter File: $ParameterFile"
    }
    
    # Validate prerequisites
    $useStandaloneBicep = Test-Prerequisites
    
    # Validate input files
    Test-BicepFile -FilePath $BicepFile
    if ($ParameterFile) {
        Test-BicepFile -FilePath $ParameterFile
    }
    
    # Create output directory if it doesn't exist
    if (-not (Test-Path $OutputDirectory)) {
        New-Item -Path $OutputDirectory -ItemType Directory -Force | Out-Null
        Write-Log "Created output directory: $OutputDirectory"
    }
    
    # Generate output file names
    $templateOutputPath = Join-Path $OutputDirectory "azureDeploy.json"
    
    # Check if output files exist and handle Force parameter
    if ((Test-Path $templateOutputPath) -and -not $Force) {
        $overwrite = Read-Host "ARM template file already exists. Overwrite? (y/N)"
        if ($overwrite -ne 'y' -and $overwrite -ne 'Y') {
            Write-Log "Build cancelled by user" -Level 'WARNING'
            exit 0
        }
    }
    
    # Build ARM template
    $templateSuccess = Build-ARMTemplate -InputFile $BicepFile -OutputFile $templateOutputPath -UseStandaloneBicep $useStandaloneBicep
    
    # Build ARM parameters if parameter file is provided
    $parametersSuccess = $true
    if ($ParameterFile) {
        $paramFileName = [System.IO.Path]::GetFileNameWithoutExtension($ParameterFile)
        $parametersOutputPath = Join-Path $OutputDirectory "$paramFileName.json"
        
        if ((Test-Path $parametersOutputPath) -and -not $Force) {
            $overwrite = Read-Host "ARM parameters file already exists. Overwrite? (y/N)"
            if ($overwrite -ne 'y' -and $overwrite -ne 'Y') {
                Write-Log "Parameters build skipped by user" -Level 'WARNING'
            }
            else {
                $parametersSuccess = Build-ARMParameters -InputFile $ParameterFile -OutputFile $parametersOutputPath -UseStandaloneBicep $useStandaloneBicep
            }
        }
        else {
            $parametersSuccess = Build-ARMParameters -InputFile $ParameterFile -OutputFile $parametersOutputPath -UseStandaloneBicep $useStandaloneBicep
        }
    }
    
    # Summary
    Write-Log "Build process completed" -Level 'SUCCESS'
    Write-Log "Output directory: $OutputDirectory"
    
    if ($templateSuccess) {
        Write-Log "ARM Template: $templateOutputPath"
    }
    
    if ($ParameterFile -and $parametersSuccess) {
        Write-Log "ARM Parameters: $(Join-Path $OutputDirectory "$([System.IO.Path]::GetFileNameWithoutExtension($ParameterFile)).json")"
    }
    
    Write-Log "ARM templates are ready for deployment using Azure CLI, PowerShell, or Azure DevOps pipelines" -Level 'SUCCESS'
}
catch {
    Write-Log "Build process failed: $($_.Exception.Message)" -Level 'ERROR'
    exit 1
}