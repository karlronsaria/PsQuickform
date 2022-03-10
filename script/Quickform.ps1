. $PsScriptRoot\Controls.ps1
. $PsScriptRoot\CommandInfo.ps1

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
function New-QformPreferences {
    [OutputType([PsCustomObject])]
    Param(
        [Parameter(ValueFromPipeline = $true)]
        [PsCustomObject]
        $Preferences
    )

    Process {
        $myPreferences = $script:DEFAULT_PREFERENCES

        if ($Preferences) {
            foreach ($property in $Preferences.PsObject.Properties.Name) {
                $myPreferences.$property = $Preferences.$property
            }
        }

        return $myPreferences
    }
}

<#
    .SYNOPSIS
    Shows a Quickform menu.

    .PARAMETER InputObject
    An object containing the specifications for a Quickform menu.
    Must match the JSON:

        {
            Preferences: [],
            MenuSpecs: []
        }

    .PARAMETER MenuSpecs
    Any number of objects containing the specifications for a control in a
    Quickform menu.
    Must match the JSON:

        {
            Name: "",
            Type: "",
            ...
        }

    .PARAMETER Preferences
    An object containing the specifications for customizing the look and default
    behavior of a Quickform menu.

    .PARAMETER CommandName
    The name of a PowerShell function or cmdlet.

    .PARAMETER ParameterSetName
    The name of a ParameterSet used by a PowerShell function or cmdlet. Can be
    procured from a call to 'Get-Command'.
    Ex:

        $cmdInfo = Get-Command Get-Item
        $parameterSetNames = $cmdInfo.ParameterSets | foreach { $_.Name }

        Show-QformMenu `
            -CommandName $cmdInfo.Name `
            -ParameterSetName $parameterSetNames[0]

        Show-QformMenu `
            -CommandInfo $cmdInfo `
            -ParameterSetName $cmdInfo.DefaultParameterSet

    .PARAMETER IncludeCommonParameters
    Indicates that the CommonParameters should be included in the Quickform menu.

    See about_CommonParameters

    .PARAMETER AnswersAsHashtable
    Indicates that the menu answers returned should be given in hashtable form.

    .OUTPUTS
        PsCustomObject
            An object containing Quickform menu answers.
            Matches the JSON:

                {
                    Confirm: <Bool>,
                    MenuAnswers: {}
                }
#>
function Show-QformMenu {
    [OutputType([PsCustomObject])]
    [CmdletBinding(DefaultParameterSetName = 'BySingleObject')]
    Param(
        [Parameter(
            ParameterSetName = 'BySingleObject',
            ValueFromPipeline = $true)]
        [PsCustomObject]
        $InputObject,

        [Parameter(
            ParameterSetName = 'BySeparateObjects')]
        [PsCustomObject[]]
        $MenuSpecs,

        [Parameter(
            ParameterSetName = 'BySeparateObjects')]
        [PsCustomObject]
        $Preferences,

        [Parameter(
            ParameterSetName = 'ByCommandName',
            Position = 0)]
        [String]
        $CommandName,

        [Parameter(
            ParameterSetName = 'ByCommandName')]
        [String]
        $ParameterSetName,

        [Parameter(
            ParameterSetName = 'ByCommandName')]
        [Switch]
        $IncludeCommonParameters,

        [Switch]
        $AnswersAsHashtable
    )

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
                    -IncludeCommonParameters:$IncludeCommonParameters `
                    -ParameterSetName $ParameterSetName `
                    -AnswersAsHashtable:$AnswersAsHashtable
            }
        }
    }
}

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
        $TypeName
    )

    $table = [PsCustomObject]@{
        'String' = 'Field';
        'Int*' = 'Numeric';
        'Decimal' = 'Numeric';
        'Double' = 'Numeric';
        'Float' = 'Numeric';
        'Switch*' = 'Check';
        'Bool*' = 'Check';
        '_' = 'Field';
    }

    if ([String]::IsNullOrWhiteSpace($TypeName)) {
        return $table
    }

    foreach ($property in $table.PsObject.Properties) {
        if ($TypeName -like $property.Name) {
            return $property.Value
        }
    }

    return $table.'_'
}

<#
    .SYNOPSIS
    Gets Quickform menu specs for a PowerShell function or cmdlet.

    .PARAMETER CommandName
    The name of a PowerShell function or cmdlet.

    .PARAMETER CommandInfo
    An object containing PowerShell function or cmdlet information, typically
    procured from a call to 'Get-Command'.
    Ex:

        $cmdInfo = Get-Command Get-Item
        ConvertTo-QformMenuSpecs -CommandInfo $cmdInfo
        $cmdInfo | ConvertTo-QformMenuSpecs

    .PARAMETER ParameterSetName
    The name of a ParameterSet used by a PowerShell function or cmdlet. Can be
    procured from a call to 'Get-Command'.
    Ex:

        $cmdInfo = Get-Command Get-Item
        $parameterSetNames = $cmdInfo.ParameterSets | foreach { $_.Name }

        ConvertTo-QformMenuSpecs `
            -CommandName $cmdInfo.Name `
            -ParameterSetName $parameterSetNames[0]

        ConvertTo-QformMenuSpecs `
            -CommandInfo $cmdInfo `
            -ParameterSetName $cmdInfo.DefaultParameterSet

    .PARAMETER ParameterSet
    An object containing parameter information associated with a single
    ParameterSet used by a PowerShell function or cmdlet. Can be procured from
    a call to 'Get-Command'.
    Ex:

        $cmdInfo = Get-Command Get-Item
        $parameterSet = $cmdInfo.ParameterSets | where Name -eq 'LiteralPath'
        ConvertTo-QformMenuSpecs -ParameterSet $parameterSet

    .PARAMETER IncludeCommonParameters
    Indicates that the CommonParameters should be included in the Quickform menu.

    See about_CommonParameters

    .INPUTS
        PsCustomObject
            Pipeline accepts command info.

    .OUTPUTS
        PsCustomObject
            An object containing Quickform menu specs.
#>
function ConvertTo-QformMenuSpecs {
    [OutputType([PsCustomObject])]
    [CmdletBinding(DefaultParameterSetName = 'ByCommandName')]
    Param(
        [Parameter(
            ParameterSetName = 'ByCommandName',
            Position = 0)]
        [String]
        $CommandName,

        [Parameter(
            ParameterSetName = 'ByCommandInfo',
            ValueFromPipeline = $true)]
        [System.Management.Automation.CommandInfo]
        $CommandInfo,

        [Parameter(
            ParameterSetName = 'ByParameterSet')]
        $ParameterSet,

        [Switch]
        $IncludeCommonParameters
    )

    DynamicParam {
        if ($PsCmdlet.ParameterSetName -like 'ByCommand*') {
            $paramDictionary = `
                New-Object `
                System.Management.Automation.RuntimeDefinedParameterDictionary
            $attributeCollection = `
                New-Object `
                System.Collections.ObjectModel.Collection[System.Attribute]
            $attribute = `
                New-Object `
                System.Management.Automation.ParameterAttribute
            $attribute.DontShow = $false

            $attributeCollection.Add($attribute)

            $param = `
                New-Object `
                System.Management.Automation.RuntimeDefinedParameter( `
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
    Runs a given PowerShell function or cmdlet by procuring argument values from
    a Quickform menu.

    .PARAMETER CommandName
    The name of a PowerShell function or cmdlet.

    .PARAMETER CommandInfo
    An object containing PowerShell function or cmdlet information, typically
    procured from a call to 'Get-Command'.
    Ex:

        $cmdInfo = Get-Command Get-Item
        Invoke-QformCommand -CommandInfo $cmdInfo
        $cmdInfo | Invoke-QformCommand

    .PARAMETER ParameterSetName
    The name of a ParameterSet used by a PowerShell function or cmdlet. Can be
    procured from a call to 'Get-Command'.
    Ex:

        $cmdInfo = Get-Command Get-Item
        $parameterSetNames = $cmdInfo.ParameterSets | foreach { $_.Name }

        Invoke-QformCommand `
            -CommandInfo $cmdInfo `
            -ParameterSetName $parameterSetNames[0]

    .PARAMETER IncludeCommonParameters
    Indicates that the CommonParameters should be included in the Quickform menu.

    See about_CommonParameters

    .PARAMETER Tee
    Indicates that Quickform menu specs should be returned along with the menu
    answers.

    .PARAMETER AnswersAsHashtable
    Indicates that the menu answers returned should be given in hashtable form.

    .INPUTS
        PsCustomObject
            Pipeline accepts command info.

    .OUTPUTS
        any
            The return value of whatever command is called by this cmdlet.

        PsCustomObject
            When Tee is active, an object containing Quickform menu answers, a
            command call string, and the return value of whatever command is
            called by this cmdlet.
            Matches the JSON:

                {
                    Confirm: <Bool>,
                    MenuAnswers: {},
                    CommandString: "",
                    Value: <any>
                }
#>
function Invoke-QformCommand {
    [OutputType([Object])]
    [OutputType([PsCustomObject])]
    [CmdletBinding(DefaultParameterSetName = 'ByCommandName')]
    Param(
        [Parameter(
            ParameterSetName = 'ByCommandName',
            Position = 0)]
        [String]
        $CommandName,

        [Parameter(
            ParameterSetName = 'ByCommandInfo',
            ValueFromPipeline = $true)]
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

    $params = $table | Get-NonEmptyTable `
        -RemoveEmptyString

    $value = if ($quickform.Confirm) {
        & $CommandName @params
    } else {
        $null
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

<#
    .SYNOPSIS
    Creates a Quickform new menu.

    .PARAMETER MenuSpecs
    Any number of objects containing the specifications for a control in a
    Quickform menu.
    Must match the JSON:

        {
            Name: "",
            Type: "",
            ...
        }

    .PARAMETER Preferences
    An object containing the specifications for customizing the look and default
    behavior of a Quickform menu.

    .PARAMETER AnswersAsHashtable
    Indicates that the menu answers returned should be given in hashtable form.

    .INPUTS
        PsCustomObject
            Pipeline accepts any number of Quickform menu specs.

    .OUTPUTS
        PsCustomObject
            An object containing Quickform menu answers.
            Matches the JSON:

                {
                    Confirm: <Bool>,
                    MenuAnswers: {}
                }
#>
function New-QformMenu {
    [OutputType([PsCustomObject])]
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
        $script:mandates = @()
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

            $mandatory = $false

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
                    $mandatory = $item | Get-PropertyOrDefault `
                        -Name Mandatory `
                        -Default $false;

                    Add-ControlsFieldBox `
                        -Layouts $Layouts `
                        -Text $text `
                        -Mandatory:$mandatory `
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
                        -Mandatory:$mandatory `
                        -Symbols $item.Symbols `
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
                    $mandatory = $item | Get-PropertyOrDefault `
                        -Name Mandatory `
                        -Default $false;

                    Add-ControlsSlider `
                        -Layouts $Layouts `
                        -Text $text `
                        -Mandatory:$mandatory `
                        -DecimalPlaces $places `
                        -Minimum $min `
                        -Maximum $max `
                        -Default $default `
                        -Preferences $Preferences
                }
            }

            $controlTable.Add($item.Name, $value)

            if ($mandatory) {
                $script:mandates += @($value)
            }
        }
    }

    End {
        $endButtons = Add-ControlsOkCancelButtons `
            -Layouts $Layouts `
            -Preferences $Preferences

        $script:form = $Layouts.MainForm
        $script:statusline = $Layouts.StatusLine

        if ($script:mandates.Count -gt 0) {
            $endButtons.OkButton.DialogResult =
                [System.Windows.Forms.DialogResult]::None

            $action = {
                $mandatesSet = $true

                foreach ($text in $script:mandates.Text) {
                    $mandatesSet = $mandatesSet `
                        -and -not [String]::IsNullOrEmpty($text)
                }

                if ($mandatesSet) {
                    $form.DialogResult =
                        [System.Windows.Forms.DialogResult]::OK
                    $form.Close()
                }
                else {
                    Set-ControlsStatus `
                        -StatusLine $script:statusLine `
                        -LineName 'MandatoryValuesNotSet'
                }
            }

            $endButtons.OkButton.add_Click($action)
            $endButtons.OkButton.add_KeyDown({
                if ($_.KeyCode -eq 'Enter') {
                    & $action
                }
            })
        }

        $controlTable.Add('__EndButtons__', $endButtons)
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
        MainForm = $MainForm;
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
    Converts menu answers into the parameter-argument list of a command call
    string.

    .PARAMETER MenuAnswers
    An object containing the key-value pairs set by a Quickform menu.

    .OUTPUTS
        System.String
            The parameter-argument-list portion of a command call string.
#>
function ConvertTo-QformString {
    [OutputType([String])]
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
    cmdlet.

    .PARAMETER CommandName
    The name of a PowerShell function or cmdlet.

    .PARAMETER CommandInfo
    An object containing PowerShell function or cmdlet information, typically
    procured from a call to 'Get-Command'.
    Ex:

        $cmdInfo = Get-Command Get-Item
        ConvertTo-QformMenuSpecs -CommandInfo $cmdInfo
        $cmdInfo | ConvertTo-QformMenuSpecs

    .PARAMETER ParameterSetName
    The name of a ParameterSet used by a PowerShell function or cmdlet. Can be
    procured from a call to 'Get-Command'.
    Ex:

        $cmdInfo = Get-Command Get-Item

        $parameterSetNames = $cmdInfo.ParameterSets | foreach { $_.Name }
        Show-QformMenuForCommand -ParameterSetName $parameterSetNames[0]

        Show-QformMenuForCommand -ParameterSetName $cmdInfo.DefaultParameterSet

    .PARAMETER IncludeCommonParameters
    Indicates that the CommonParameters should be included in the Quickform menu.

    See about_CommonParameters

    .PARAMETER AnswersAsHashtable
    Indicates that the menu answers returned should be given in hashtable form.

    .INPUTS
        PsCustomObject
            Pipeline accepts command info.

    .OUTPUTS
        PsCustomObject
            An object containing Quickform menu answers and a command call
            string.
            Matches the JSON:

                {
                    Confirm: <Bool>,
                    MenuAnswers: {},
                    CommandString: ""
                }
#>
function Show-QformMenuForCommand {
    [OutputType([PsCustomObject])]
    [CmdletBinding(DefaultParameterSetName = 'ByCommandName')]
    Param(
        [Parameter(
            ParameterSetName = 'ByCommandName',
            Position = 0)]
        [String]
        $CommandName,

        [Parameter(
            ParameterSetName = 'ByCommandInfo',
            ValueFromPipeline = $true)]
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

    # issue: Event handler fails to update variable from outer scope
    # link: https://stackoverflow.com/questions/55403528/why-wont-variable-update
    # retreived: 2022_03_02

    $script:form.add_KeyDown({
        $refresh = $false
        $eventArgs = $_

        if ($eventArgs.Alt) {
            switch ($eventArgs.KeyCode) {
                'Right' {
                    $what.CurrentParameterSetIndex = Get-NextIndex `
                        -Index $what.CurrentParameterSetIndex `
                        -Count $what.ParameterSets.Count

                    $refresh = $true
                }

                'Left' {
                    $what.CurrentParameterSetIndex = Get-PreviousIndex `
                        -Index $what.CurrentParameterSetIndex `
                        -Count $what.ParameterSets.Count

                    $refresh = $true
                }
            }
        }

        if ($refresh) {
            $script:paramSet = `
                $what.ParameterSets[$what.CurrentParameterSetIndex]

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
        | Get-NonEmptyObject `
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

