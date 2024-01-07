. $PsScriptRoot\Type.ps1

<#
    .SYNOPSIS
    Identifies the menu control type used to process a given PowerShell type.

    .PARAMETER TypeName
    The name of a PowerShell type.

    .OUTPUTS
        System.String
            The accepted name of a Quickform menu control.

        System.Collections.Specialized.OrderedDictionary
            When no TypeName is specified, a table containing all pairs of
            PowerShell type patterns and their respective Quickform menu
            controls. Pattern '_' means default.
#>
function Get-QformControlType {
    [OutputType([String])]
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    Param(
        [String]
        $TypeName,

        [Switch]
        $IgnoreLists
    )

    $defaultName = '_'
    $listPattern = '.*\[\]$'

    $table = [Ordered]@{
        '^PsCustomObject(\[\])?$' = 'Table'  # This state will never be reached
        $listPattern = 'List'
        '^String$' = 'Field'
        '^Int.*$' = 'Numeric'
        '^Decimal$' = 'Numeric'
        '^Long$' = 'Numeric'
        '^Single$' = 'Numeric'
        '^Double$' = 'Numeric'
        '^Float$' = 'Numeric'
        '^Switch.*$' = 'Check'
        '^Bool.*$' = 'Check'
        $defaultName = 'Script'
    }

    if ([String]::IsNullOrWhiteSpace($TypeName)) {
        return $table
    }

    $table.Keys |
    where {
        $TypeName -match $_ -and
        (-not $IgnoreLists -or
        $_ -ne $listPattern)
    } |
    foreach {
        return $table[$_]
    }

    return $table[$defaultName]
}

function ConvertTo-QformParameter {
    Param(
        $ParameterInfo,

        [Switch]
        $IgnoreLists
    )

    $paramType = $ParameterInfo.ParameterType
    $validators = Get-FieldValidators -ParameterInfo $ParameterInfo

    $obj = [PsCustomObject]@{
        Name = $ParameterInfo.Name
        Type = ''
    }

    if ($validators) {
        switch ($validators.Type) {
            'Enum' {
                $obj.Type = 'Enum'

                $values = $validators.Values.Name | Where-Object {
                    $_ -ne 'value__'
                }

                $obj | Add-Member `
                    -MemberType NoteProperty `
                    -Name Symbols `
                    -Value $values
            }

            'ValidSet' {
                $obj.Type = 'Enum'

                $obj | Add-Member `
                    -MemberType NoteProperty `
                    -Name Symbols `
                    -Value $validators.Values
            }

            'ValidRange' {
                $obj.Type = 'Numeric'

                $obj | Add-Member `
                    -MemberType NoteProperty `
                    -Name Minimum `
                    -Value $validators.Minimum

                $obj | Add-Member `
                    -MemberType NoteProperty `
                    -Name Maximum `
                    -Value $validators.Maximum
            }

            'ValidCount' {
                $obj | Add-Member `
                    -MemberType NoteProperty `
                    -Name MinCount `
                    -Value $validators.Minimum

                $obj | Add-Member `
                    -MemberType NoteProperty `
                    -Name MaxCount `
                    -Value $validators.Maximum
            }

            'ValidLength' {
                $obj | Add-Member `
                    -MemberType NoteProperty `
                    -Name MinLength `
                    -Value $validators.Minimum

                $obj | Add-Member `
                    -MemberType NoteProperty `
                    -Name MaxLength `
                    -Value $validators.Maximum
            }
        }
    }

    if ($obj.Type -eq '') {
        $obj.Type = Get-QformControlType `
            -TypeName $paramType.Name `
            -IgnoreLists:$IgnoreLists
    }

    return $obj
}

<#
    .SYNOPSIS
    Gets a list of valid names associated with a certain resource object.
    Call

        Get-QformResource -Type Object

    to get a list of available resource types.

    .PARAMETER Type
    A type of resource.

    .INPUTS
        System.String[]
            Pipeline accepts any number of resource types.

    .OUTPUTS
        PsCustomObject[]
            All properties associated with a given resource type.
#>
function Get-QformResource {
    Param(
        [Parameter(ValueFromPipeline = $true)]
        [ValidateSet('Object', 'Preference', 'MenuSpec')]
        [String[]]
        $Type
    )

    Begin {
        $root = Get-Content `
            -Path "$PsScriptRoot/../res/properties.json" `
        | ConvertFrom-Json
    }

    Process {
        foreach ($item in $Type) {
            $root."$($item)s"
        }
    }
}

<#
    .SYNOPSIS
    Builds a set of Quickform menu preferences using a set of supplemental
    default values.

    .PARAMETER Preferences
    An object containing the specifications for customizing the look and default
    behavior of a Quickform menu.

    .INPUTS
        PsCustomObject
            Pipeline accepts Quickform menu preferences.

    .OUTPUTS
        PsCustomObject
            An object containing Quickform menu preferences.
#>
function Get-QformPreference {
    [OutputType([PsCustomObject])]
    [CmdletBinding(DefaultParameterSetName = 'BuildNewObject')]
    Param(
        [Parameter(
            ParameterSetName = 'BuildNewObject',
            ValueFromPipeline = $true
        )]
        [PsCustomObject]
        $Preferences,

        [Parameter(
            ParameterSetName = 'BuildNewObject'
        )]
        [PsCustomObject]
        $ReferencePreferences,

        [Parameter(
            ParameterSetName = 'QueryValues'
        )]
        [ArgumentCompleter(
            {
                (Get-QformResource -Type Preference).Name
            }
        )]
        [ValidateScript(
            {
                $_ -in (Get-QformResource -Type Preference).Name
            }
        )]
        [String[]]
        $Name
    )

    Begin {
        if ($null -eq $ReferencePreferences) {
            $ReferencePreferences =
                Get-Content "$PsScriptRoot/../res/preference.json" `
                    | ConvertFrom-Json
        }
    }

    Process {
        switch ($PsCmdlet.ParameterSetName) {
            'BuildNewObject' {
                if (-not $Preferences) {
                    return $ReferencePreferences.PsObject.Copy()
                }

                $myPreferences = $ReferencePreferences.PsObject.Copy()
                $names = $Preferences.PsObject.Properties.Name

                if ($Preferences) {
                    $myProperties = $myPreferences `
                        | Get-Member `
                        | Where-Object {
                            $_.MemberType -like 'NoteProperty'
                        }

                    foreach ($property in $names) {
                        if ($property -notin $myProperties.Name) {
                            $myPreferences | Add-Member `
                                -MemberType 'NoteProperty' `
                                -Name $property `
                                -Value $Preferences.$property
                        }
                        else {
                            $myPreferences.$property = $Preferences.$property
                        }
                    }
                }

                return $myPreferences
            }

            'QueryValues' {
                foreach ($item in $Name) {
                    [PsCustomObject]@{
                        Name = $item
                        Value = $ReferencePreferences.$item
                    }
                }
            }
        }
    }
}

function Get-QformLayout {
    [OutputType([Hashtable])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline = $true)]
        [PsCustomObject[]]
        $MenuSpecs,

        [System.Windows.Window]
        $Window,

        [System.Windows.Controls.Label]
        $StatusLine,

        [PsCustomObject]
        $Preferences
    )

    Begin {
        $mandates = @()
        $list = @()
        $pageInfo = @()
        $controls = @{}
    }

    Process {
        foreach ($item in $MenuSpecs) {
            $id = Get-ControlsNameAndText $item
            $text = $id.Text
            $name = $id.Name

            $mandatory = $item | Get-PropertyOrDefault `
                -Name Mandatory `
                -Default $false

            $default = Get-PropertyOrDefault `
                -InputObject $item `
                -Name 'Default'

            $newParams = @{
                Item = $item
                Pref = $Preferences
                Label = $StatusLine
                Text = $id.Text
                Default = $default
                Mandatory = $mandatory
            }

            # Infer the Table type from the Rows property
            if ($null -eq $item.Type) {
                $rows = Get-PropertyOrDefault `
                    -InputObject $item `
                    -Name 'Rows'

                if ($null -ne $rows) {
                    $item | Add-Member `
                        -MemberType NoteProperty `
                        -Name 'Type' `
                        -Value 'Table'
                }
            }

            $what = & $types.Table.($item.Type).New @newParams

            if ($mandatory) {
                $mandates += @([PsCustomObject]@{
                    Type = $item.Type
                    Control = $what.Object
                })
            }

            $list += @([PsCustomObject]@{
                Name = $name
                Type = $item.Type
                Container = $what.Container
                Object = $what.Object
            })

            $pageInfo += @($item)
            $controls.Add($name, $what.Object)
        }
    }

    End {
        $what = New-ControlsOkCancelButtons `
            -Margin $Preferences.Margin

        $list += @([PsCustomObject]@{
            Name = '__EndButtons__'
            Container = $what.Container
            Object = $what.Object
        })

        $endButtons = $what.Object

        $endButtons.CancelButton.Add_Click(( `
            New-Closure `
                -InputObject $Window `
                -ScriptBlock {
                    $InputObject.DialogResult = $false
                    $InputObject.Close()
                } `
        ))

        $action = if ($mandates.Count -eq 0) {
            New-Closure `
                -InputObject $Window `
                -ScriptBlock {
                    $InputObject.DialogResult = $true
                    $InputObject.Close()
                }
        } else {
            $parameters = [PsCustomObject]@{
                Types = $types
                Window = $Window
                Mandates = $mandates
                StatusLine = $StatusLine
            }

            New-Closure `
                -InputObject $parameters `
                -ScriptBlock {
                    $mandatesSet = $true

                    foreach ($item in $InputObject.Mandates) {
                        $itemIsSet = $item |
                            foreach $InputObject.Types.Table.($item.Type).HasAny

                        $mandatesSet = $mandatesSet -and $itemIsSet
                    }

                    if ($mandatesSet) {
                        $InputObject.Window.DialogResult = $true
                        $InputObject.Window.Close()
                    }
                    else {
                        . $PsScriptRoot\Controls.ps1

                        Set-ControlsStatus `
                            -StatusLine $InputObject.StatusLine `
                            -LineName 'MandatoryValuesNotSet'
                    }
                }
        }

        $endButtons.OkButton.Add_Click($action)

        foreach ($item in $list) {
            $postProcess = $types.Table.($item.Type) |
                Get-PropertyOrDefault `
                    -Name PostProcess `
                    -Default $null

            if ($null -eq $postProcess) {
                continue
            }

            & $postProcess `
                -PageInfo $pageInfo `
                -Controls $controls `
                -Types $types `
                -ItemName $item.Name
        }

        # todo: change return type, due to redundant use of Controls table
        return $list
    }
}

function Convert-CommandInfoToPageInfo {
    Param(
        [String]
        $ParameterSetName,

        [Switch]
        $IncludeCommonParameters,

        [Switch]
        $IgnoreLists,

        [Int]
        $StartingIndex
    )

    $parameterSets = $CommandInfo.ParameterSets

    if ($ParameterSetName) {
        $parameterSets = $parameterSets | Where-Object {
            $_.Name -like $ParameterSetName
        }
    }

    # todo: consider revising as failable type
    if (-not $parameterSets) {
        throw "No parameter sets could be found $(
            if ($ParameterSetName) { "matching '$ParameterSetName' " }
        )for command name '$($CommandInfo.Name)'"
    }

    if ($null -eq $StartingIndex) {
        $StartingIndex = [Qform]::FindDefaultParameterSet($CommandInfo)
    }

    $pageInfo = foreach ($parameterSet in $parameterSets) {
        [PsCustomObject]@{
            Name = $parameterSet.Name
            MenuSpecs = $parameterSet.Parameters | Where-Object {
                $IncludeCommonParameters `
                    -or -not (Test-IsCommonParameter -ParameterInfo $_)
            } | ForEach-Object {
                ConvertTo-QformParameter `
                    -ParameterInfo $_ `
                    -IgnoreLists:$IgnoreLists
            }
        }
    }

    return [PsCustomObject]@{
        StartingIndex = $StartingIndex
        PageInfo = $pageInfo
    }
}

