. $PsScriptRoot\Progress.ps1
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

    $what =
        $table.Keys |
        where {
            $TypeName -match $_ -and
            (-not $IgnoreLists -or
            $_ -ne $listPattern)
        } |
        foreach {
            $table[$_]
        }

    if ($what) {
        return @($what)[0]
    }

    return $table[$defaultName]
}

function ConvertTo-QformParameter {
    [OutputType([PsCustomObject[]])]
    Param(
        [System.Management.Automation.CommandParameterInfo]
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
    [OutputType([PsCustomObject])]
    Param(
        [Parameter(ValueFromPipeline = $true)]
        [ValidateSet('Object', 'Preference', 'MenuSpec')]
        [String[]]
        $Type
    )

    Begin {
        $root =
            dir "$PsScriptRoot/../res/properties.json" |
            Get-Content |
            ConvertFrom-Json
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
        [ArgumentCompleter({
            Param($A, $B, $C)

            (Get-QformResource -Type Preference).Name |
            where { $_ -like "$C*" }
        })]
        [ValidateScript({
            $_ -in (Get-QformResource -Type Preference).Name
        })]
        [String[]]
        $Name
    )

    Begin {
        if ($null -eq $ReferencePreferences) {
            $ReferencePreferences =
                dir "$PsScriptRoot/../res/preference.json" |
                Get-Content |
                ConvertFrom-Json
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
                    $myProperties = $myPreferences |
                        Get-Member |
                        Where-Object {
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

        [Controls]
        $Builder,

        [ProgressWriter]
        $Progress
    )

    Begin {
        $mandates = @()
        $patterns = @()
        $scripts = @()
        $list = @()
        $pageInfo = @()
        $controls = @{}
        $hasLog = $false

        $deferScripts =
            $Builder.Preferences |
            Get-PropertyOrDefault `
                -Name DeferScripts `
                -Default $false
    }

    Process {
        foreach ($item in $MenuSpecs) {
            try {
                $id = [Controls]::GetNameAndText($item)
                $text = $id.Text
                $name = $id.Name

                if ($Progress -and $Progress.Any()) {
                    [void] $Progress.Next({ "New $($item.Type) element: `"$name`"" })
                }

                $mandatory = $item | Get-PropertyOrDefault `
                    -Name Mandatory `
                    -Default $false

                $pattern = $item | Get-PropertyOrDefault `
                    -Name Pattern

                $default = $item | Get-PropertyOrDefault `
                    -Name 'Default'

                $newParams = @{
                    Item = $item
                    Builder = $Builder
                    Text = $id.Text
                    Default = $default
                    Mandatory = $mandatory
                }

                # Infer the Table type from the Rows property
                if ($null -eq $item.Type) {
                    $rows = $item | Get-PropertyOrDefault `
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
                    # todo: yields to $mandates
                    $mandates += @([PsCustomObject]@{
                        Type = $item.Type
                        Control = $what.Object
                    })
                }

                if ($pattern) {
                    # todo: yields to $patterns
                    $patterns += @([PsCustomObject]@{
                        Type = $item.Type
                        Name = $name
                        Pattern = $pattern
                        Control = $what.Object
                    })
                }

                switch ($item.Type) {
                    'Script' {
                        if ($deferScripts) {
                            $item.Type = 'DeferredScript'
                        }

                        $scripts += @([PsCustomObject]@{
                            Type = $item.Type
                            Control = $what.Object
                        })
                    }

                    'Log' {
                        $hasLog = $true
                    }
                }

                # todo: yields to $list
                $list += @([PsCustomObject]@{
                    Name = $name
                    Type = $item.Type
                    Container = $what.Container
                    Object = $what.Object
                })

                # todo: yields to $pageInfo
                $pageInfo += @($item)

                # todo: alters $controls
                $controls.Add($name, $what.Object)
            }
            catch {
                throw $_
            }
        }
    }

    End {
        if ($Progress -and $Progress.Any()) {
            [void] $Progress.Next({ "New Ok-Cancel buttons" })
        }

        if (-not $hasLog -and $scripts.Count -gt 0) {
            $item = [PsCustomObject]@{
                Name = '__Log__'
                Text = 'Error Log'
                Type = 'Log'
            }

            $newParams = @{
                Item = $item
                Builder = $Builder
                Text = $item.Text
            }

            $what = & $types.Table.Log.New @newParams

            $list += @([PsCustomObject]@{
                Name = $item.Name
                Type = $item.Type
                Container = $what.Container
                Object = $what.Object
            })

            $pageInfo += @($item)
            $controls.Add($item.Name, $what.Object)
        }

        $what = $Builder.NewOkCancelButtons()

        $list += @([PsCustomObject]@{
            Name = '__EndButtons__'
            Container = $what.Container
            Object = $what.Object
        })

        $endButtons = $what.Object

        $endButtons.CancelButton.Add_Click($Builder.NewClosure(
            $Window,
            {
                $Parameters.DialogResult = $false
                $Parameters.Close()
            }
        ))

        $action = if (($mandates.Count + $patterns.Count + $scripts.Count) -eq 0) {
            $Builder.NewClosure(
                $Window,
                {
                    $Parameters.DialogResult = $true
                    $Parameters.Close()
                }
            )
        } else {
            $parameters = [PsCustomObject]@{
                Types = $types
                Window = $Window
                Mandates = $mandates
                Patterns = $patterns
                Scripts = $scripts
                Builder = $Builder
            }

            $Builder.NewClosure(
                $parameters,
                {
                    $mandatesSet = $true

                    foreach ($item in $Parameters.Mandates) {
                        $itemIsSet = $item.Control |
                            foreach ($Parameters.
                                Types.
                                Table.
                                ($item.Type).
                                HasAny)

                        $mandatesSet = $mandatesSet -and $itemIsSet
                    }

                    if (-not $mandatesSet) {
                        $Parameters.Builder.SetStatus('MandatoryValuesNotSet')
                        return
                    }

                    foreach ($item in $Parameters.Patterns) {
                        $value = $item.Control |
                            foreach ($Parameters.
                                Types.
                                Table.
                                ($item.Type).
                                GetValue)

                        if ($value -notmatch $item.Pattern) {
                            $Parameters.Builder.SetStatus(
                                "Text element '$($item.Name)' must match the pattern '$($item.Pattern)'"
                            )

                            return
                        }
                    }

                    foreach ($item in $Parameters.Scripts) {
                        try {
                            $value =
                                $item.Control |
                                foreach ($Parameters.
                                    Types.
                                    Table.
                                    ($item.Type).
                                    GetValue
                                )

                            if ($item.Type -eq 'DeferredScript') {
                                iex $value
                            }
                        }
                        catch {
                            throw $_
                        }
                    }

                    $Parameters.Window.DialogResult = $true
                    $Parameters.Window.Close()
                }
            )
        }

        $endButtons.OkButton.Add_Click($action)

        if ($Progress -and $Progress.Any()) {
            [void] $Progress.Next({ 'Adding post-process scripts' })
        }

        foreach ($item in $list) {
            $postProcess =
                $types.Table.($item.Type) |
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
                -ItemName $item.Name `
                -Logger $Builder.Logger |
                Out-Null
        }

        # todo: change return type, due to redundant use of Controls table
        return $list
    }
}

function Convert-CommandInfoToPageInfo {
    [OutputType([PsCustomObject[]])]
    Param(
        [System.Management.Automation.CommandInfo]
        $CommandInfo,

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
            Name =
                $parameterSet.Name
            MenuSpecs =
                $parameterSet.Parameters |
                Where-Object {
                    $IncludeCommonParameters `
                        -or -not (Test-IsCommonParameter -ParameterInfo $_)
                } |
                ForEach-Object {
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

