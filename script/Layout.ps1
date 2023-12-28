<#
    .SYNOPSIS
    Identifies the menu control type used to process a given PowerShell type.

    .PARAMETER TypeName
    The name of a PowerShell type.

    .OUTPUTS
        System.String
            The accepted name of a Quickform menu control.

        System.Collections.Hashtable
            When no TypeName is specified, a table containing all pairs of
            PowerShell type patterns and their respective Quickform menu
            controls. Pattern '_' means default.
#>
function Get-QformControlType {
    [OutputType([String])]
    [OutputType([Hashtable])]
    Param(
        [String]
        $TypeName,

        [Switch]
        $IgnoreLists
    )

    $defaultName = '_'
    $listPattern = '.*\[\]$'

    $table = [PsCustomObject]@{
        '^PsCustomObject(\[\])?$' = 'Table'
        $listPattern = 'List'
        '^String$' = 'Field'
        '^Int.*$' = 'Numeric'
        '^Decimal$' = 'Numeric'
        '^Double$' = 'Numeric'
        '^Float$' = 'Numeric'
        '^Switch.*$' = 'Check'
        '^Bool.*$' = 'Check'
        $defaultName = 'Script'
    }

    if ([String]::IsNullOrWhiteSpace($TypeName)) {
        return $table
    }

    foreach ($property in $table.PsObject.Properties) {
        if ($TypeName -match $property.Name) {
            if ($IgnoreLists -and $property.Name -eq $listPattern) {
                continue
            }

            return $property.Value
        }
    }

    return $table.$defaultName
}

function ConvertTo-QformParameter {
    Param(
        $ParameterInfo,

        [Switch]
        $IgnoreLists
    )

    $type = $ParameterInfo.ParameterType
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
                    -Value ($values | ForEach-Object {
                        [PsCustomObject]@{
                            Name = $_
                        }
                    })
            }

            'ValidSet' {
                $obj.Type = 'Enum'
                $values = $validators.Values

                $obj | Add-Member `
                    -MemberType NoteProperty `
                    -Name Symbols `
                    -Value ($values | ForEach-Object {
                        [PsCustomObject]@{
                            Name = $_
                        }
                    })
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
            -TypeName $type.Name `
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
        $masterObj = Get-Content `
            -Path "$PsScriptRoot/../res/properties.json" `
        | ConvertFrom-Json
    }

    Process {
        foreach ($item in $Type) {
            $masterObj."$($Type)s"
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
    }

    Process {
        foreach ($item in $MenuSpecs) {
            $default = Get-PropertyOrDefault `
                -InputObject $item `
                -Name 'Default'

            $what = Get-ControlsNameAndText $item
            $text = $what.Text
            $name = $what.Name
            $mandatory = $false

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

            $what = switch -Regex ($item.Type) {
                'Check' {
                    New-ControlsCheckBox `
                        -Text $text `
                        -Default $default
                }

                'Field|Script' {
                    $maxLength = $item | Get-PropertyOrDefault `
                        -Name MaxLength;
                    $mandatory = $item | Get-PropertyOrDefault `
                        -Name Mandatory `
                        -Default $false;

                    New-ControlsFieldBox `
                        -Text $text `
                        -Mandatory:$mandatory `
                        -MaxLength $maxLength `
                        -Default $default `
                        -Preferences $Preferences `
                        -CodeBlockStyle:$($_ -eq 'Script')
                }

                'Enum' {
                    $mandatory = $item | Get-PropertyOrDefault `
                        -Name Mandatory `
                        -Default $false;
                    $as = $item | Get-PropertyOrDefault `
                        -Name As `
                        -Default 'RadioPanel';

                    $params = @{
                        Text = $text
                        Mandatory = $mandatory
                        Symbols =
                            $item.Symbols |
                            foreach {
                                switch ($_) {
                                    { $_ -is [String] } {
                                        [PsCustomObject]@{
                                            Text = $_
                                        }
                                    }

                                    default { $_ }
                                }
                            }
                        Default = $default
                    }

                    $control = switch ($as) {
                        'RadioPanel' {
                            New-ControlsRadioBox @params
                        }

                        'DropDown' {
                            New-ControlsDropDown @params
                        }
                    }

                    # Mandatory enumerations are self-managed. They either do
                    # or don't implement 'None'.
                    $mandatory = $false

                    [PsCustomObject]@{
                        Container = $control.Container
                        Object = [PsCustomObject]@{
                            As = $as
                            Object = $control.Object
                        }
                    }
                }

                'Numeric' {
                    $places = $item | Get-PropertyOrDefault `
                        -Name DecimalPlaces `
                        -Default $Preferences.NumericDecimalPlaces;
                    $min = $item | Get-PropertyOrDefault `
                        -Name Minimum `
                        -Default $Preferences.NumericMinimum;
                    $max = $item | Get-PropertyOrDefault `
                        -Name Maximum `
                        -Default $Preferences.NumericMaximum;
                    $mandatory = $item | Get-PropertyOrDefault `
                        -Name Mandatory `
                        -Default $false;

                    New-ControlsSlider `
                        -Text $text `
                        -Mandatory:$mandatory `
                        -DecimalPlaces $places `
                        -Minimum $min `
                        -Maximum $max `
                        -Default $default `
                        -StatusLine $StatusLine `
                        -Preferences $Preferences
                }

                'List' {
                    $maxCount = $item | Get-PropertyOrDefault `
                        -Name MaxCount;
                    $maxLength = $item | Get-PropertyOrDefault `
                        -Name MaxLength;
                    $mandatory = $item | Get-PropertyOrDefault `
                        -Name Mandatory `
                        -Default $false;

                    New-ControlsListBox `
                        -Text $text `
                        -Mandatory:$mandatory `
                        -MaxCount $maxCount `
                        -MaxLength $maxLength `
                        -Default $default `
                        -StatusLine $StatusLine `
                        -Preferences $Preferences
                }

                'Table' {
                    $mandatory = $item | Get-PropertyOrDefault `
                        -Name Mandatory `
                        -Default $false;
                    $rows = $item | Get-PropertyOrDefault `
                        -Name Rows `
                        -Default @();

                    New-ControlsTable `
                        -Text $text `
                        -Mandatory:$mandatory `
                        -Rows $rows `
                        -Margin $Preferences.Margin
                }
            }

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
                Window = $Window
                Mandates = $mandates
                StatusLine = $StatusLine
            }

            New-Closure `
                -InputObject $parameters `
                -ScriptBlock {
                    $mandatesSet = $true

                    foreach ($object in $InputObject.Mandates) {
                        $itemIsSet = switch -Regex ($object.Type) {
                            'List' {
                                $object.Control.Items.Count -gt 0
                            }

                            'Table' {
                                $object.Control.SelectedItems.Count -gt 0
                            }

                            'Field|Numeric|Script' {
                                -not [String]::IsNullOrEmpty(
                                    $object.Control.Text
                                )
                            }

                            default {
                                -not [String]::IsNullOrEmpty(
                                    $object.Control.Content
                                )
                            }
                        }

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

    # TODO: consider revising as failable type
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

