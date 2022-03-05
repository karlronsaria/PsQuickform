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

function Get-QformObject {
    [CmdletBinding(DefaultParameterSetName = 'BySingleObject')]
    Param(
        [Parameter(
            ParameterSetName = 'BySingleObject',
            ValueFromPipeline = $true)]
        [PsCustomObject]
        $InputObject,

        [Parameter(ParameterSetName = 'BySeparateObjects')]
        [PsCustomObject[]]
        $Controls,

        [Parameter(ParameterSetName = 'BySeparateObjects')]
        [PsCustomObject]
        $Preferences,

        [Switch]
        $AsHashtable
    )

    switch ($PsCmdlet.ParameterSetName) {
        'BySingleObject' {
            $Controls = $InputObject.Controls
            $Preferences = $InputObject.Preferences
        }
    }

    if ($null -eq $InputObject) {
        return New-QformObject
    }

    return New-QformObject `
        -Controls $Controls `
        -Preferences $Preferences `
        -AsHashtable:$AsHashtable
}

function New-QformObject {
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline = $true)]
        [PsCustomObject[]]
        $Controls,

        [PsCustomObject]
        $Preferences,

        [Switch]
        $AsHashtable
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
        $list += @($Controls)
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
            -Controls $list `
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

        if ($AsHashtable) {
            $out = $out | ConvertTo-Hashtable
        }

        return [PsCustomObject]@{
            Confirm = $confirm;
            FormResult = $out;
        }
    }
}

function Set-QformLayout {
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline = $true)]
        [PsCustomObject[]]
        $Controls,

        [PsCustomObject]
        $Layouts,

        [PsCustomObject]
        $Preferences
    )

    Begin {
        $controlTable = @{}
    }

    Process {
        foreach ($item in $Controls) {
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
        $Controls,

        [PsCustomObject]
        $Layouts
    )

    Begin {
        $out = [PsCustomObject]@{}
        $controlTable = $Layouts.Controls
    }

    Process {
        foreach ($item in $Controls) {
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
        $Controls,

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

    $layouts.Controls = $Controls | Set-QformLayout `
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

function ConvertTo-QformCommand {
    Param(
        [Parameter(ParameterSetName = 'ByCommandInfo')]
        [System.Management.Automation.CommandInfo]
        $CommandInfo,

        [Parameter(ParameterSetName = 'ByParameterSet')]
        $ParameterSet,

        [Switch]
        $IncludeCommonParameters
    )

    switch ($PsCmdlet.ParameterSetName) {
        'ByCommandInfo' {
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

function ConvertTo-QformString {
    Param(
        [PsCustomObject]
        $FormResult
    )

    $outStr = ""

    foreach ($property in $FormResult.PsObject.Properties) {
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

function Get-QformCommand {
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
        $AsHashtable
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

    $defaultParamSet = $CommandInfo | Get-PropertyOrDefault `
        -Name DefaultParameterSet `
        -Default $paramSets[0]

    $currentIndex = 0

    while ($currentIndex -lt $paramSets.Count `
        -and $paramSets[$currentIndex].Name -ne $defaultParamSet)
    {
        $currentIndex = $currentIndex + 1
    }

    $index = 1

    $what = [PsCustomObject]@{
        ParameterSets = $paramSets | foreach {
            [PsCustomObject]@{
                Name = $_.Name;
                Index = $index;
                Preferences = [PsCustomObject]@{
                    Title = "Command: $CommandName $([Char] 0x2014) " `
                          + "ParameterSet $index`: $($_.Name)";
                };
                Controls = $_.Parameters | where {
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
        return New-QformObject
    }

    $script:myPreferences = New-QformPreferences `
        -Preferences $paramSet.Preferences

    $script:form = New-ControlsMain `
        -Preferences $myPreferences

    $script:controls = $paramset.Controls

    $script:layouts = [PsCustomObject]@{
        Multilayout = $null;
        Sublayouts = @();
        Controls = @{};
        StatusLine = $null;
    }

    $script:layouts = Set-QformMainLayout `
        -MainForm $form `
        -Controls $controls `
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

            $script:controls = $paramset.Controls

            $script:layouts = Set-QformMainLayout `
                -MainForm $script:form `
                -Controls $script:controls `
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

    $script:controls =
        $what.ParameterSets[$what.CurrentParameterSetIndex].Controls

    $formResult = $script:controls | Start-QformEvaluate `
        -Layouts $script:layouts

    $parameterString = ConvertTo-QformString `
        -FormResult $formResult

    if ($AsHashtable) {
        $table = @{}

        foreach ($property in $formResult.PsObject.Properties.Name) {
            $table[$property] = $formResult.$property
        }

        $formResult = $table
    }

    return [PsCustomObject]@{
        Confirm = $confirm;
        FormResult = $formResult;
        CommandString = "$CommandName$parameterString";
    }
}

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
        $AsHashtable
    )

    if ($AsHashtable -and -not $Tee) {
        Write-Warning ((Get-ThisFunctionName) `
            + ": AsHashtable has no effect unless Tee is specified.")
    }

    $quickform = [PsCustomObject]@{
        Confirm = $false;
        FormResult = @{};
    }

    switch ($PsCmdlet.ParameterSetName) {
        'ByCommandName' {
            $quickform = Get-QformCommand `
                -CommandName $CommandName `
                -ParameterSetName:$ParameterSetName `
                -IncludeCommonParameters:$IncludeCommonParameters

            $CommandInfo = Get-Command `
                -Name $CommandName
        }

        'ByCommandInfo' {
            $quickform = Get-QformCommand `
                -CommandInfo $CommandInfo `
                -ParameterSetName:$ParameterSetName `
                -IncludeCommonParameters:$IncludeCommonParameters

            $CommandName = $CommandInfo.Name
        }
    }

    $table = $quickform.FormResult | ConvertTo-Hashtable

    $params = $table | Get-TrimTable `
        -RemoveEmptyString

    $value = $null

    if ($quickform.Confirm) {
        # # OLD (2022_03_02_211308)
        # Invoke-Expression "$CommandName `@params"

        $value = & $CommandName @params
    }

    if ($Tee) {
        if ($AsHashtable) {
            $quickform.FormResult = $table
        }

        $quickform | Add-Member `
            -MemberType NoteProperty `
            -Name Value `
            -Value $value

        return $quickform
    }

    return $value
}

