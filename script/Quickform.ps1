. $PsScriptRoot\Controls.ps1
. $PsScriptRoot\CommandInfo.ps1

function New-QformPreferences {
    Param(
        [PsCustomObject]
        $Preferences
    )

    $myPreferences = $script:DEFAULT_PREFERENCES

    if ($Preferences) {
        foreach ($property in $Preferences.PsObject.Properties.Name) {
            $myPreferences.$property = $Preferences.$property
        }
    }

    return $myPreferences
}

<#
    .SYNOPSIS
    Shows a menu
#>
function Show-QformMenu {
    [CmdletBinding(DefaultParameterSetName = 'BySingleObject')]
    Param(
        [Parameter(
            ParameterSetName = 'BySingleObject',
            ValueFromPipeline = $true)]
        [PsCustomObject]
        $InputObject,

        [Parameter(ParameterSetName = 'BySeparateObjects')]
        [PsCustomObject[]]
        $MenuSpecs,

        [Parameter(ParameterSetName = 'BySeparateObjects')]
        [PsCustomObject]
        $Preferences,

        [Parameter(ParameterSetName = 'ByCommandName', Position = 0)]
        [String]
        $CommandName,

        [Parameter(ParameterSetName = 'ByCommandInfo', ValueFromPipeline = $true)]
        [System.Management.Automation.CommandInfo]
        $CommandInfo,

        [Switch]
        $AnswersAsHashtable
    )

    DynamicParam {
        if ($PsCmdlet.ParameterSetName -like 'ByCommand*') {
            $paramDictionary = `
                New-Object System.Management.Automation.RuntimeDefinedParameterDictionary

            $attributeCollection = `
                New-Object System.Collections.ObjectModel.Collection[System.Attribute]
            $attribute = `
                New-Object System.Management.Automation.ParameterAttribute
            $attribute.DontShow = $false
            $attributeCollection.Add($attribute)
            $param = `
                New-Object System.Management.Automation.RuntimeDefinedParameter( `
                    'ParameterSetName', `
                    [String], `
                    $attributeCollection `
                )
            $paramDictionary.Add('ParameterSetName', $param)

            $attributeCollection = `
                New-Object System.Collections.ObjectModel.Collection[System.Attribute]
            $attribute = `
                New-Object System.Management.Automation.ParameterAttribute
            $attribute.DontShow = $false
            $attributeCollection.Add($attribute)
            $param = `
                New-Object System.Management.Automation.RuntimeDefinedParameter( `
                    'IncludeCommonParameters', `
                    [Switch], `
                    $attributeCollection `
                )
            $paramDictionary.Add('IncludeCommonParameters', $param)

            return $paramDictionary
        }
    }

    Process {
        switch ($PsCmdlet.ParameterSetName) {
            'BySingleObject' {
                if ($null -eq $InputObject) {
                    return New-QformMenu
                }

                return New-QformMenu `
                    -MenuSpecs $InputObject.MenuSpecs `
                    -Preferences $InputObject.Preferences `
                    -AnswersAsHashtable:$AnswersAsHashtable
            }

            'BySeparateObjects' {
                return New-QformMenu `
                    -MenuSpecs $MenuSpecs `
                    -Preferences $Preferences `
                    -AnswersAsHashtable:$AnswersAsHashtable
            }

            'ByCommandName' {
                return Show-QformMenuForCommand `
                    -CommandName $CommandName `
                    -IncludeCommonParameters:$PsBoundParameters.IncludeCommonParameters `
                    -ParameterSetName:$PsBoundParameters.ParameterSetName `
                    -AnswersAsHashtable:$AnswersAsHashtable
            }

            'ByCommandInfo' {
                return Show-QformMenuForCommand `
                    -CommandInfo $CommandInfo `
                    -IncludeCommonParameters:$PsBoundParameters.IncludeCommonParameters `
                    -ParameterSetName:$PsBoundParameters.ParameterSetName `
                    -AnswersAsHashtable:$AnswersAsHashtable
            }
        }
    }
}

<#
    .SYNOPSIS
    Creates a new menu
#>
function New-QformMenu {
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline = $true)]
        [PsCustomObject[]]
        $MenuSpecs,

        [PsCustomObject]
        $Preferences,

        [Switch]
        $AnswersAsHashtable
    )

    Begin {
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName System.Drawing

        $myPreferences = New-QformPreferences `
            -Preferences $Preferences

        $form = New-ControlsMain `
            -Preferences $myPreferences

        $list = @()
    }

    Process {
        $list += @($MenuSpecs)
    }

    End {
        $layouts = [PsCustomObject]@{
            Multilayout = $null;
            Sublayouts = @();
            Controls = @{};
            StatusLine = $null;
        }

        $layouts = Set-QformMainLayout `
            -MainForm $form `
            -MenuSpecs $list `
            -Preferences $myPreferences

        Add-ControlsFormKeyBindings `
            -Control $form `
            -Layouts $layouts `
            -Preferences $myPreferences

        $confirm = switch ($form.ShowDialog()) {
            'OK' { $true }
            'Cancel' { $false }
        }

        $out = $list | Start-QformEvaluate `
            -Layouts $layouts

        if ($AnswersAsHashtable) {
            $out = $out | ConvertTo-Hashtable
        }

        return [PsCustomObject]@{
            Confirm = $confirm;
            MenuAnswers = $out;
        }
    }
}

function Set-QformLayout {
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline = $true)]
        [PsCustomObject[]]
        $MenuSpecs,

        [PsCustomObject]
        $Layouts,

        [PsCustomObject]
        $Preferences
    )

    Begin {
        $controlTable = @{}
    }

    Process {
        foreach ($item in $MenuSpecs) {
            $default = Get-PropertyOrDefault `
                -InputObject $item `
                -Name 'Default'

            $text = Get-PropertyOrDefault `
                -InputObject $item `
                -Name 'Text' `
                -Default $item.Name

            $value = switch ($item.Type) {
                'Check' {
                    Add-ControlsCheckBox `
                        -Layouts $Layouts `
                        -Text $text `
                        -Default $default `
                        -Preferences $Preferences
                }

                'Field' {
                    $minLength = $item | Get-PropertyOrDefault `
                        -Name MinLength;
                    $maxLength = $item | Get-PropertyOrDefault `
                        -Name MaxLength;

                    Add-ControlsFieldBox `
                        -Layouts $Layouts `
                        -Text $text `
                        -MinLength $minLength `
                        -MaxLength $maxLength `
                        -Default $default `
                        -Preferences $Preferences
                }

                'Enum' {
                    $mandatory = $item | Get-PropertyOrDefault `
                        -Name Mandatory `
                        -Default $false;

                    Add-ControlsRadioBox `
                        -Layouts $Layouts `
                        -Text $text `
                        -Symbols $item.Symbols `
                        -Mandatory:$mandatory `
                        -Default $default `
                        -Preferences $Preferences
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

                    Add-ControlsSlider `
                        -Layouts $Layouts `
                        -Text $text `
                        -DecimalPlaces $places `
                        -Minimum $min `
                        -Maximum $max `
                        -Default $default `
                        -Preferences $Preferences
                }
            }

            $controlTable.Add($item.Name, $value)
        }
    }

    End {
        $endButtons = Add-ControlsOkCancelButtons `
            -Layouts $Layouts `
            -Preferences $Preferences

        $controlTable.Add('EndButtons__', $endButtons)
        return $controlTable
    }
}

function Start-QformEvaluate {
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline = $true)]
        [PsCustomObject[]]
        $MenuSpecs,

        [PsCustomObject]
        $Layouts
    )

    Begin {
        $out = [PsCustomObject]@{}
        $controlTable = $Layouts.Controls
    }

    Process {
        foreach ($item in $MenuSpecs) {
            $value = switch ($item.Type) {
                'Check' {
                    $tempValue = $controlTable[$item.Name].Checked;

                    switch ($myPreferences.ConfirmType) {
                        'TrueOrFalse' {
                            $tempValue
                        }

                        'AllowOrDeny' {
                            switch ($tempValue) {
                                'True' { 'Allow' }
                                'False' { 'Deny' }
                            }
                        }
                    }
                }

                'Field' {
                    $controlTable[$item.Name].Text
                }

                'Enum' {
                    $buttons = $controlTable[$item.Name];

                    $temp = if ($buttons) {
                        $buttons.Keys | where {
                            $buttons[$_].Checked
                        }
                    } else {
                        $null
                    };

                    if ($temp -eq 'None') {
                        $null
                    }
                    else {
                        $temp
                    }
                }

                'Numeric' {
                    if ($controlTable[$item.Name].Text) {
                        $controlTable[$item.Name].Value
                    } else {
                        $null
                    }
                }
            }

            $out | Add-Member `
                -MemberType NoteProperty `
                -Name $item.Name `
                -Value $value
        }
    }

    End {
        return $out
    }
}

function Set-QformMainLayout {
    Param(
        [System.Windows.Forms.Form]
        $MainForm,

        [PsCustomObject[]]
        $MenuSpecs,

        [PsCustomObject]
        $Preferences
    )

    $MainForm.Controls.Clear()

    $layouts = New-ControlsMultilayout `
        -Preferences $Preferences

    $statusLine = New-ControlsStatusLine `
        -Preferences $Preferences

    $layouts = [PsCustomObject]@{
        Multilayout = $layouts.Multilayout;
        Sublayouts = $layouts.Sublayouts;
        Controls = $layouts.Controls;
        StatusLine = $statusLine;
    }

    $layouts.Controls = $MenuSpecs | Set-QformLayout `
        -Layouts $layouts `
        -Preferences $Preferences

    $MainForm.Text = $Preferences.Title

    # Resolving a possible race condition
    while ($null -eq $layouts.Multilayout) { }

    $fillLayout = New-ControlsLayout `
        -Preferences $Preferences

    $fillLayout.Controls.Add($layouts.Multilayout)
    $fillLayout.Controls.Add($statusLine)
    $MainForm.Controls.Add($fillLayout)
    return $layouts
}

<#
    .SYNOPSIS
    Identifies the menu control type used to process a PowerShell type
#>
function Get-QformControlType {
    Param(
        [String]
        $TypeName
    )

    $controlType = switch -Wildcard ($TypeName) {
        'String' { 'Field' }
        'Int*' { 'Numeric' }
        'Float' { 'Numeric' }
        'Double' { 'Numeric' }
        'Switch*' { 'Check' }
        'Bool*' { 'Check' }
        default { 'Field' }
    }

    return $controlType
}

function ConvertTo-QformParameter {
    Param(
        $ParameterInfo
    )

    $type = $ParameterInfo.ParameterType
    $validators = Get-FieldValidators -ParameterInfo $ParameterInfo
    $validatorType = $null

    $obj = [PsCustomObject]@{
        Name = $ParameterInfo.Name;
        Type = '';
    }

    if ($validators) {
        $validatorType = $validators.Type

        switch ($validatorType) {
            'Enum' {
                $obj.Type = 'Enum'

                $values = $validators.Values.Name | where {
                    $_ -ne 'value__'
                }

                $obj | Add-Member `
                    -MemberType NoteProperty `
                    -Name Symbols `
                    -Value ($values | foreach {
                        [PsCustomObject]@{
                            Name = $_;
                        }
                    })
            }

            'ValidSet' {
                $obj.Type = 'Enum'
                $values = $validators.Values

                $obj | Add-Member `
                    -MemberType NoteProperty `
                    -Name Symbols `
                    -Value ($values | foreach {
                        [PsCustomObject]@{
                            Name = $_;
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
            -TypeName $type.Name
    }

    return $obj
}

<#
    .SYNOPSIS
    Gets quickform menu specs for a PowerShell function or cmdlet

    .TODO
    Export with module
#>
function ConvertTo-QformMenuSpecs {
    Param(
        [Parameter(ParameterSetName = 'ByCommandName', Position = 0)]
        [String]
        $CommandName,

        [Parameter(ParameterSetName = 'ByCommandInfo', ValueFromPipeline = $true)]
        [System.Management.Automation.CommandInfo]
        $CommandInfo,

        [Parameter(ParameterSetName = 'ByParameterSet')]
        $ParameterSet,

        [Switch]
        $IncludeCommonParameters
    )

    DynamicParam {
        if ($PsCmdlet.ParameterSetName -like 'ByCommand*') {
            $paramDictionary = `
                New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
            $attributeCollection = `
                New-Object System.Collections.ObjectModel.Collection[System.Attribute]
            $attribute = `
                New-Object System.Management.Automation.ParameterAttribute
            $attribute.DontShow = $false

            $attributeCollection.Add($attribute)

            $param = `
                New-Object System.Management.Automation.RuntimeDefinedParameter( `
                    'ParameterSetName', `
                    [String], `
                    $attributeCollection `
                )

            $paramDictionary.Add('ParameterSetName', $param)
            return $paramDictionary
        }
    }

    Process {
        switch ($PsCmdlet.ParameterSetName) {
            'ByCommandName' {
                $CommandInfo = Get-Command -Name $CommandName

                if ($PsBoundParameters.ParameterSetName) {
                    $ParameterSet = $CommandInfo.ParameterSets | where {
                        $_.Name -like $PsBoundParameters.ParameterSetName
                    }

                    return ConvertTo-QformMenuSpecs `
                        -ParameterSet $ParameterSet `
                        -IncludeCommonParameters:$IncludeCommonParameters
                }

                return ConvertTo-QformMenuSpecs `
                    -CommandInfo $CommandInfo `
                    -IncludeCommonParameters:$IncludeCommonParameters
            }

            'ByCommandInfo' {
                if ($PsBoundParameters.ParameterSetName) {
                    $ParameterSet = $CommandInfo.ParameterSets | where {
                        $_.Name -like $PsBoundParameters.ParameterSetName
                    }

                    return ConvertTo-QformMenuSpecs `
                        -ParameterSet $ParameterSet `
                        -IncludeCommonParameters:$IncludeCommonParameters
                }

                return $CommandInfo.Parameters.Keys | foreach {
                    $CommandInfo.Parameters[$_]
                } | where {
                    $IncludeCommonParameters `
                        -or -not (Test-IsCommonParameter -ParameterInfo $_)
                } | foreach {
                    ConvertTo-QformParameter -ParameterInfo $_
                }
            }

            'ByParameterSet' {
                return $ParameterSet.Parameters | where {
                    $IncludeCommonParameters `
                        -or -not (Test-IsCommonParameter -ParameterInfo $_)
                } | foreach {
                    ConvertTo-QformParameter -ParameterInfo $_
                }
            }
        }
    }
}

<#
    .SYNOPSIS
    Converts a menu answer into the parameter set of a command string
#>
function ConvertTo-QformString {
    Param(
        [PsCustomObject]
        $MenuAnswers
    )

    $outStr = ""

    foreach ($property in $MenuAnswers.PsObject.Properties) {
        $name = $property.Name
        $value = $property.Value

        if ($null -eq $value) {
            continue
        }

        $outStr += switch -Regex ($value.GetType().Name) {
            'String' {
                if (-not [String]::IsNullOrEmpty($value)) {
                    " -$name `"$value`""
                }
            }

            'Bool.*' {
                if ($value) {
                    " -$name"
                }
            }

            'Int.*|Decimal|Float|Double' {
                " -$name $value"
            }

            '.*\[\]' {
                " -$name $(`"$value`" -join ', ')"
            }
        }
    }

    return $outStr
}

<#
    .SYNOPSIS
    Shows a menu with controls matching the parameters of a given function or
    cmdlet
#>
function Show-QformMenuForCommand {
    [CmdletBinding(DefaultParameterSetName = 'ByCommandName')]
    Param(
        [Parameter(ParameterSetName = 'ByCommandName', Position = 0)]
        [String]
        $CommandName,

        [Parameter(ParameterSetName = 'ByCommandInfo', ValueFromPipeline = $true)]
        [System.Management.Automation.CommandInfo]
        $CommandInfo,

        [String]
        $ParameterSetName,

        [Switch]
        $IncludeCommonParameters,

        [Switch]
        $AnswersAsHashtable
    )

    function Get-NextIndex {
        Param([Int] $Index, [Int] $Count)

        $Index = if ($Index -ge ($Count - 1)) {
            0
        } else {
            $Index + 1
        }

        return $Index
    }

    function Get-PreviousIndex {
        Param([Int] $Index, [Int] $Count)

        $Index = if ($Index -le 0) {
            $Count - 1
        } else {
            $Index - 1
        }

        return $Index
    }

    switch ($PsCmdlet.ParameterSetName) {
        'ByCommandName' {
            $CommandInfo = Get-Command -Name $CommandName
        }

        'ByCommandInfo' {
            $CommandName = $CommandInfo.Name
        }
    }

    if (-not $CommandInfo) {
        return
    }

    $paramSets = if ($ParameterSetName) {
        $CommandInfo.ParameterSets | where {
            $_.Name -like $ParameterSetName
        }
    } else {
        $CommandInfo.ParameterSets
    }

    if (-not $paramSets) {
        throw "No parameter sets could be found $(
            if ($ParameterSetName) { "matching '$ParameterSetName' " }
        )for command name '$CommandName'"
    }

    $defaultParamSet = $CommandInfo | Get-PropertyOrDefault `
        -Name DefaultParameterSet `
        -Default $paramSets[0]

    $currentIndex = 0
    $count = $paramSets.Count

    while ($currentIndex -lt $count `
        -and $paramSets[$currentIndex].Name -ne $defaultParamSet)
    {
        $currentIndex = $currentIndex + 1
    }

    if ($currentIndex -ge $count) {
        $currentIndex = 0
    }

    $index = 1

    $what = [PsCustomObject]@{
        ParameterSets = $paramSets | foreach {
            [PsCustomObject]@{
                Name = $_.Name;
                Index = $index;
                Preferences = [PsCustomObject]@{
                    Title = "Command: $CommandName $([Char] 0x2014) " `
                          + "ParameterSet $index` of $count`: $($_.Name)";
                };
                MenuSpecs = $_.Parameters | where {
                    $IncludeCommonParameters `
                        -or -not (Test-IsCommonParameter -ParameterInfo $_)
                } | foreach {
                    ConvertTo-QformParameter -ParameterInfo $_
                };
            }

            $index = $index + 1
        };
        CurrentParameterSetIndex = $currentIndex;
    }

    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $script:paramSet = $what.ParameterSets[$what.CurrentParameterSetIndex]

    if ($null -eq $script:paramSet) {
        return New-QformMenu
    }

    $script:myPreferences = New-QformPreferences `
        -Preferences $paramSet.Preferences

    $script:form = New-ControlsMain `
        -Preferences $myPreferences

    $script:menuSpecs = $paramset.MenuSpecs

    $script:layouts = [PsCustomObject]@{
        Multilayout = $null;
        Sublayouts = @();
        Controls = @{};
        StatusLine = $null;
    }

    $script:layouts = Set-QformMainLayout `
        -MainForm $form `
        -MenuSpecs $script:menuSpecs `
        -Preferences $myPreferences

    Add-ControlsFormKeyBindings `
        -Control $form `
        -Layouts $script:layouts `
        -Preferences $myPreferences

    # Issue: Event handler fails to update variable from outer scope
    # Link: https://stackoverflow.com/questions/55403528/why-wont-variable-update
    # Retreived: 2022_03_02

    $script:form.add_KeyDown({
        $refresh = $false
        $eventArgs = $_

        switch ($eventArgs.KeyCode) {
            'Right' {
                if ($eventArgs.Alt) {
                    $what.CurrentParameterSetIndex = Get-NextIndex `
                        -Index $what.CurrentParameterSetIndex `
                        -Count $what.ParameterSets.Count

                    $refresh = $true
                }
            }

            'Left' {
                if ($eventArgs.Alt) {
                    $what.CurrentParameterSetIndex = Get-PreviousIndex `
                        -Index $what.CurrentParameterSetIndex `
                        -Count $what.ParameterSets.Count

                    $refresh = $true
                }
            }
        }

        if ($refresh) {
            $script:paramSet = $what.ParameterSets[$what.CurrentParameterSetIndex]

            $script:myPreferences = New-QformPreferences `
                -Preferences $paramSet.Preferences

            $script:menuSpecs = $paramset.MenuSpecs

            $script:layouts = Set-QformMainLayout `
                -MainForm $script:form `
                -MenuSpecs $script:menuSpecs `
                -Preferences $script:myPreferences

            Set-ControlsCenterScreen `
                -Control $script:form

            $this.Focus()
        }
    })

    $confirm = switch ($script:form.ShowDialog()) {
        'OK' { $true }
        'Cancel' { $false }
    }

    $script:menuSpecs =
        $what.ParameterSets[$what.CurrentParameterSetIndex].MenuSpecs

    $formResult = $script:menuSpecs `
        | Start-QformEvaluate `
            -Layouts $script:layouts `
        | Get-TrimObject `
            -RemoveEmptyString

    $parameterString = ConvertTo-QformString `
        -MenuAnswers $formResult

    if ($AnswersAsHashtable) {
        $table = @{}

        foreach ($property in $formResult.PsObject.Properties.Name) {
            $table[$property] = $formResult.$property
        }

        $formResult = $table
    }

    return [PsCustomObject]@{
        Confirm = $confirm;
        MenuAnswers = $formResult;
        CommandString = "$CommandName$parameterString";
    }
}

<#
    .SYNOPSIS
    Runs a given PowerShell function or cmdlet by procuring argument values from
    a menu
#>
function Invoke-QformCommand {
    [CmdletBinding(DefaultParameterSetName = 'ByCommandName')]
    Param(
        [Parameter(ParameterSetName = 'ByCommandName', Position = 0)]
        [String]
        $CommandName,

        [Parameter(ParameterSetName = 'ByCommandInfo', ValueFromPipeline = $true)]
        [System.Management.Automation.CommandInfo]
        $CommandInfo,

        [String]
        $ParameterSetName,

        [Switch]
        $IncludeCommonParameters,

        [Switch]
        $Tee,

        [Switch]
        $AnswersAsHashtable
    )

    if ($AnswersAsHashtable -and -not $Tee) {
        Write-Warning ((Get-ThisFunctionName) `
            + ": AnswersAsHashtable has no effect unless Tee is specified.")
    }

    $quickform = [PsCustomObject]@{
        Confirm = $false;
        MenuAnswers = @{};
    }

    switch ($PsCmdlet.ParameterSetName) {
        'ByCommandName' {
            $quickform = Show-QformMenuForCommand `
                -CommandName $CommandName `
                -ParameterSetName:$ParameterSetName `
                -IncludeCommonParameters:$IncludeCommonParameters

            $CommandInfo = Get-Command `
                -Name $CommandName
        }

        'ByCommandInfo' {
            $quickform = Show-QformMenuForCommand `
                -CommandInfo $CommandInfo `
                -ParameterSetName:$ParameterSetName `
                -IncludeCommonParameters:$IncludeCommonParameters

            $CommandName = $CommandInfo.Name
        }
    }

    $table = $quickform.MenuAnswers | ConvertTo-Hashtable

    $params = $table | Get-TrimTable `
        -RemoveEmptyString

    $value = $null

    if ($quickform.Confirm) {
        # # OLD (2022_03_02_211308)
        # Invoke-Expression "$CommandName `@params"

        $value = & $CommandName @params
    }

    if ($Tee) {
        if ($AnswersAsHashtable) {
            $quickform.MenuAnswers = $table
        }

        $quickform | Add-Member `
            -MemberType NoteProperty `
            -Name Value `
            -Value $value

        return $quickform
    }

    return $value
}

