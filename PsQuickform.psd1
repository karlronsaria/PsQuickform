#
# Module manifest for module 'PsQuickform'
#
# Generated by: Andrew Daniels
#
# Generated on: 3/5/2022
#

@{

# Script module or binary module file associated with this manifest.
RootModule = 'PsQuickform.psm1'

# Version number of this module.
ModuleVersion = '1.0.0'

# Supported PSEditions
# CompatiblePSEditions = @()

# ID used to uniquely identify this module
GUID = '9db92977-ed9e-4422-8d3d-8f398d5ca4a1'

# Author of this module
Author = 'Andrew Daniels'

# Company or vendor of this module
CompanyName = 'Unknown'

# Copyright statement for this module
Copyright = '(c) 2022 Andrew Daniels. All rights reserved.'

# Description of the functionality provided by this module
Description = 'Generate a quick Windows form from a PsCustomObject and return all values as a result object. Can generate a Windows form for the parameters of a PowerShell function or cmdlet.'

# Minimum version of the Windows PowerShell engine required by this module
# PowerShellVersion = ''

# Name of the Windows PowerShell host required by this module
# PowerShellHostName = ''

# Minimum version of the Windows PowerShell host required by this module
# PowerShellHostVersion = ''

# Minimum version of Microsoft .NET Framework required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
# DotNetFrameworkVersion = ''

# Minimum version of the common language runtime (CLR) required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
# CLRVersion = ''

# Processor architecture (None, X86, Amd64) required by this module
# ProcessorArchitecture = ''

# Modules that must be imported into the global environment prior to importing this module
# RequiredModules = @()

# Assemblies that must be loaded prior to importing this module
RequiredAssemblies = @(
    "PresentationFramework"
    "System.Windows.Forms"
)

# Script files (.ps1) that are run in the caller's environment prior to importing this module.
ScriptsToProcess = @(
    "Required.ps1"
)

# Type files (.ps1xml) to be loaded when importing this module
# TypesToProcess = @()

# Format files (.ps1xml) to be loaded when importing this module
# FormatsToProcess = @()

# Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
# NestedModules = @()

# Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
FunctionsToExport = @(
    'Get-QformPreference',
    'Show-QformMenu',
    'Get-QformControlType',
    'ConvertTo-QformMenuSpecs',
    'Invoke-QformCommand',
    'Get-NonEmpty',
    'Invoke-SplatCommand',
    'Get-QformResource'
)

# Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
CmdletsToExport = @()

# Variables to export from this module
VariablesToExport = @()

# Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
AliasesToExport = @()

# DSC resources to export from this module
# DscResourcesToExport = @()

# List of all modules packaged with this module
# ModuleList = @()

# List of all files packaged with this module
# (karlr 2024_01_20): No. No. This is not how we do things. No. Please, no.
FileList = @(
    'res\default_preference.json',
    'res\properties.json',
    'res\text.json',
    'script\CommandInfo.ps1',
    'script\Controls.ps1',
    'script\Other.ps1',
    'script\Qform.ps1',
    'script\Quickform.ps1',
    'sample\myform.json',
    'sample\myformwithdefaults.json',
    'sample\myformwithmandatories.json',
    'sample\myformwithnumerics.json',
    'sample\mylargeform.json'
)

# Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
PrivateData = @{

    PSData = @{

        # Tags applied to this module. These help with module discovery in online galleries.
        # Tags = @()

        # A URL to the license for this module.
        # LicenseUri = ''

        # A URL to the main website for this project.
        # ProjectUri = ''

        # A URL to an icon representing this module.
        # IconUri = ''

        # ReleaseNotes of this module
        # ReleaseNotes = ''

    } # End of PSData hashtable

} # End of PrivateData hashtable

# HelpInfo URI of this module
# HelpInfoURI = ''

# Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
# DefaultCommandPrefix = ''

}

