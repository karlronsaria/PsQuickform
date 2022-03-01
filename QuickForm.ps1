function Get-QuickformObject {
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline = $true)]
        [PsCustomObject]
        $InputObject,

        [Switch]
        $AsHashtable
    )

    if ($null -eq $InputObject) {
        return New-QuickformObject
    }

    return $InputObject.Controls `
        | New-QuickformObject `
            -Preferences $InputObject.Preferences `
            -AsHashtable:$AsHashtable
}

$script:DEFAULT_PREFERENCES = [PsCustomObject]@{
    Title = 'Preferences';
    FontFamily = 'Microsoft Sans Serif';
    Point = 10;
    Width = 500;
    Height = 800;
    Margin = 10;
    ConfirmType = 'TrueOrFalse';
}

$script:DEFAULT_SLIDER_MINIMUM = -99999
$script:DEFAULT_SLIDER_MAXIMUM = 99999
$script:DEFAULT_SLIDER_DECIMALPLACES = 2

function Get-PropertyOrDefault {
    Param(
        [Parameter(ValueFromPipeline = $true)]
        [PsCustomObject]
        $InputObject,

        [String]
        $Name,

        $Default = $null
    )

    if ($InputObject.PsObject.Properties.Name -contains $Name) {
        return $InputObject.$Name
    }

    return $Default
}

function Set-QuickformLayout {
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline = $true)]
        [PsCustomObject[]]
        $Control,

        [PsCustomObject]
        $Layouts,

        [PsCustomObject]
        $Preferences
    )

    Begin {
        $controls = @{}
    }

    Process {
        foreach ($item in $Control) {
            $default = Get-PropertyOrDefault `
                -InputObject $item `
                -Name 'Default'

            $text = Get-PropertyOrDefault `
                -InputObject $item `
                -Name 'Text' `
                -Default $item.Name

            $value = switch ($item.Type) {
                'Check' {
                    Add-QuickformCheckBox `
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

                    Add-QuickformFieldBox `
                        -Layouts $Layouts `
                        -Text $text `
                        -MinLength $minLength `
                        -MaxLength $maxLength `
                        -Default $default `
                        -Preferences $Preferences
                }

                'Enum' {
                    Add-QuickformRadioBox `
                        -Layouts $Layouts `
                        -Text $text `
                        -Symbols $item.Symbols `
                        -Default $default `
                        -Preferences $Preferences
                }

                'Numeric' {
                    $places = $item | Get-PropertyOrDefault `
                        -Name DecimalPlaces;
                    $min = $item | Get-PropertyOrDefault `
                        -Name Minimum `
                        -Default $script:DEFAULT_SLIDER_MINIMUM;
                    $max = $item | Get-PropertyOrDefault `
                        -Name Maximum `
                        -Default $script:DEFAULT_SLIDER_MAXIMUM;
                    $asFloat = $item | Get-PropertyOrDefault `
                        -Name AsFloat `
                        -Default $false;

                    Add-QuickformSlider `
                        -Layouts $Layouts `
                        -Text $text `
                        -DecimalPlaces $places `
                        -Minimum $min `
                        -Maximum $max `
                        -AsFloat:$asFloat `
                        -Default $default `
                        -Preferences $Preferences
                }
            }

            $controls.Add($item.Name, $value)
        }
    }

    End {
        $endButtons = Add-QuickformOkCancelButtons `
            -Layouts $Layouts `
            -Preferences $Preferences

        $controls.Add('EndButtons__', $endButtons)
        return $controls
    }
}

function Start-QuickformEvaluate {
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline = $true)]
        [PsCustomObject[]]
        $Control
    )

    Begin {
        $out = [PsCustomObject]@{}
    }

    Process {
        foreach ($item in $Control) {
            $value = switch ($item.Type) {
                'Check' {
                    $tempValue = $controls[$item.Name].Checked;

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
                    $controls[$item.Name].Text
                }

                'Enum' {
                    $buttons = $controls[$item.Name];

                    if ($buttons) {
                        $buttons.Keys | where {
                            $buttons[$_].Checked
                        }
                    }
                }

                'Numeric' {
                    $controls[$item.Name].Value
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

function New-QuickformObject {
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline = $true)]
        [PsCustomObject[]]
        $Control,

        [PsCustomObject]
        $Preferences,

        [Switch]
        $AsHashtable
    )

    Begin {
        $myPreferences = $script:DEFAULT_PREFERENCES

        if ($Preferences) {
            foreach ($property in $Preferences.PsObject.Properties.Name) {
                $myPreferences.$property = $Preferences.$property
            }
        }

        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName System.Drawing

        $what = New-QuickformMain `
            -Preferences $myPreferences

        $form = $what.MainForm
        $layouts = $what.Layouts
        $list = @()
    }

    Process {
        $list += @($Control)
    }

    End {
        $controls = $list | Set-QuickformLayout `
            -Layouts $layouts `
            -Preferences $myPreferences

        [void]$form.Focus()

        $confirm = switch ($form.ShowDialog()) {
            'OK' { $true }
            'Cancel' { $false }
        }

        $out = $list | Start-QuickformEvaluate

        if ($AsHashtable) {
            $table = @{}

            foreach ($property in $out.PsObject.Properties.Name) {
                $table[$property] = $out.$property
            }

            $out = $table
        }

        return [PsCustomObject]@{
            Confirm = $confirm;
            FormResult = $out;
        }
    }
}

function Add-QuickformLayout {
    Param(
        [System.Windows.Forms.Control]
        $Parent,

        [PsCustomObject]
        $Preferences = $script:DEFAULT_PREFERENCES
    )

    $layout = New-Object System.Windows.Forms.FlowLayoutPanel
    $layout.FlowDirection = `
        [System.Windows.Forms.FlowDirection]::TopDown
    $layout.Left = $Preferences.Margin
    $layout.Width = $Preferences.Width - (2 * $Preferences.Margin)
    $layout.AutoSize = $true
    $layout.WrapContents = $false
    $Parent.Controls.Add($layout)
    return $layout
}

function Add-QuickformMultilayout {
    Param(
        [System.Windows.Forms.Control]
        $Parent,

        [PsCustomObject]
        $Preferences = $script:DEFAULT_PREFERENCES
    )

    $multilayout = New-Object System.Windows.Forms.FlowLayoutPanel
    $multilayout.Left = $Preferences.Margin
    $multilayout.AutoSize = $true
    $multilayout.FlowDirection = `
        [System.Windows.Forms.FlowDirection]::LeftToRight

    $layout = Add-QuickformLayout `
        -Parent $multilayout `
        -Preferences $Preferences

    $form.Controls.Add($multilayout)

    return [PsCustomObject]@{
        Multilayout = $multilayout;
        Sublayouts = @($layout);
    }
}

function Add-ControlToMultilayout {
    Param(
        [PsCustomObject]
        $Layouts,

        [System.Windows.Forms.Control[]]
        $Control,

        [PsCustomObject]
        $Preferences
    )

    $final = $Layouts.Sublayouts[-1]
    $totalHeight = $final.Height

    $Control | % {
        $totalHeight += $Control.Height
    }

    if ($totalHeight -gt $Preferences.Height) {
        $layout = Add-QuickformLayout `
            -Parent $Layouts.Multilayout `
            -Preferences $Preferences

        $Layouts.Sublayouts += @($layout)
        $final = $Layouts.Sublayouts[-1]
    }

    $Control | % {
        $final.Controls.Add($_)
    }

    return $Layouts
}

function New-QuickformMain {
    Param(
        [PsCustomObject]
        $Preferences = $script:DEFAULT_PREFERENCES
    )

    $font = New-Object System.Drawing.Font( `
        $Preferences.FontFamily, `
        $Preferences.Point, `
        [System.Drawing.FontStyle]::Regular `
    )

    $form = New-Object System.Windows.Forms.Form
    $form.Text = $Preferences.Title
    $form.Font = $font
    $form.AutoSize = $true
    $form.FormBorderStyle = `
        [System.Windows.Forms.FormBorderStyle]::FixedSingle

    $layouts = Add-QuickformMultilayout `
        -Parent $form `
        -Preferences $Preferences

    return [PsCustomObject]@{
        MainForm = $form;
        Layouts = $layouts;
    }
}

function Add-QuickformCheckBox {
    Param(
        [PsCustomObject]
        $Layouts,

        [String]
        $Text,

        $Default,

        [PsCustomObject]
        $Preferences = $script:DEFAULT_PREFERENCES
    )

    $checkBox = New-Object System.Windows.Forms.CheckBox
    $checkBox.Text = $Text
    $checkBox.Left = $Preferences.Margin
    $checkBox.Width = $Preferences.Width - (2 * $Preferences.Margin)

    if ($null -ne $Default) {
        $checkBox.Checked = $Default
    }

    $Layouts = Add-ControlToMultilayout `
        -Layouts $Layouts `
        -Control $checkBox `
        -Preferences $Preferences

    return $checkBox
}

function Add-QuickformFieldBox {
    Param(
        [PsCustomObject]
        $Layouts,

        [String]
        $Text,

        $MinLength,
        $MaxLength,
        $Default,

        [PsCustomObject]
        $Preferences = $script:DEFAULT_PREFERENCES
    )

    $flowPanel = New-Object System.Windows.Forms.FlowLayoutPanel
    $flowPanel.FlowDirection = `
        [System.Windows.Forms.FlowDirection]::TopDown
    $flowPanel.Left = $Preferences.Margin
    $flowPanel.Width = $Preferences.Width - (3 * $Preferences.Margin)
    $flowPanel.AutoSize = $true
    $flowPanel.WrapContents = $false

    $label = New-Object System.Windows.Forms.Label
    $label.Text = $Text
    $label.Left = $Preferences.Margin
    $label.Width = $Preferences.Width - (4 * $Preferences.Margin)
    $label.Anchor = `
        [System.Windows.Forms.AnchorStyles]::Right

    $textBox = New-Object System.Windows.Forms.TextBox
    $textBox.Left = $Preferences.Margin
    $textBox.Width = $Preferences.Width - (4 * $Preferences.Margin)
    $textBox.Anchor = `
        [System.Windows.Forms.AnchorStyles]::Left + `
        [System.Windows.Forms.AnchorStyles]::Right

    if ($null -ne $MinLength) {
        $textBox.MinLength = $MinLength
    }

    if ($null -ne $MaxLength) {
        $textBox.MaxLength = $MaxLength
    }

    if ($null -ne $Default) {
        $textBox.Text = $Default
    }

    $flowPanel.Controls.Add($label)
    $flowPanel.Controls.Add($textBox)

    $Layouts = Add-ControlToMultilayout `
        -Layouts $Layouts `
        -Control $flowPanel `
        -Preferences $Preferences

    return $textBox
}

function Add-QuickformSlider {
    Param(
        [PsCustomObject]
        $Layouts,

        [String]
        $Text,

        $Default,
        $Minimum = $script:DEFAULT_SLIDER_MINIMUM,
        $Maximum = $script:DEFAULT_SLIDER_MAXIMUM,
        $DecimalPlaces,

        [Switch]
        $AsFloat,

        [PsCustomObject]
        $Preferences = $script:DEFAULT_PREFERENCES
    )

    $flowPanel = New-Object System.Windows.Forms.FlowLayoutPanel
    $flowPanel.FlowDirection = `
        [System.Windows.Forms.FlowDirection]::TopDown
    $flowPanel.Left = $Preferences.Margin
    $flowPanel.Width = $Preferences.Width - (3 * $Preferences.Margin)
    $flowPanel.AutoSize = $true
    $flowPanel.WrapContents = $false

    $label = New-Object System.Windows.Forms.Label
    $label.Text = $Text
    $label.Left = $Preferences.Margin
    $label.Width = $Preferences.Width - (4 * $Preferences.Margin)
    $label.Anchor = `
        [System.Windows.Forms.AnchorStyles]::Right

    $slider = New-Object System.Windows.Forms.NumericUpDown
    $slider.Left = $Preferences.Margin
    $slider.Width = $Preferences.Width - (4 * $Preferences.Margin)
    $slider.Anchor = `
        [System.Windows.Forms.AnchorStyles]::Left + `
        [System.Windows.Forms.AnchorStyles]::Right
    $slider.Minimum = $Minimum
    $slider.Maximum = $Maximum

    if ($null -ne $DecimalPlaces) {
        $slider.DecimalPlaces = $DecimalPlaces
    }
    elseif ($AsFloat) {
        $slider.DecimalPlaces = $script:DEFAULT_SLIDER_DECIMALPLACES
    }

    if ($null -ne $Default) {
        $slider.Value = $Default
    }

    $flowPanel.Controls.Add($label)
    $flowPanel.Controls.Add($slider)

    $Layouts = Add-ControlToMultilayout `
        -Layouts $Layouts `
        -Control $flowPanel `
        -Preferences $Preferences

    return $slider
}

function Add-QuickformRadioBox {
    Param(
        [PsCustomObject]
        $Layouts,

        [String]
        $Text,

        $Default,

        [PsCustomObject[]]
        $Symbols,

        [PsCustomObject]
        $Preferences = $script:DEFAULT_PREFERENCES
    )

    $groupBox = New-Object System.Windows.Forms.GroupBox
    $groupBox.Left = $Preferences.Margin
    $groupBox.Width = $Preferences.Width - (2 * $Preferences.Margin)
    $groupBox.AutoSize = $true
    $groupBox.Text = $Text

    $flowPanel = New-Object System.Windows.Forms.FlowLayoutPanel
    $flowPanel.FlowDirection = `
        [System.Windows.Forms.FlowDirection]::TopDown
    $flowPanel.Left = $Preferences.Margin
    $flowPanel.Width = $Preferences.Width - (3 * $Preferences.Margin)
    $flowPanel.AutoSize = $true
    $flowPanel.WrapContents = $false
    $flowPanel.Top = 2 * $Preferences.Margin
    $groupBox.Controls.Add($flowPanel)

    $buttons = @{}

    foreach ($symbol in $Symbols) {
        $button = New-Object System.Windows.Forms.RadioButton
        $button.Left = $Preferences.Margin
        $button.Width = $Preferences.Width - (4 * $Preferences.Margin)

        $button.Text = $symbol | Get-PropertyOrDefault `
            -Name Text `
            -Default $symbol.Name

        $buttons.Add($symbol.Name, $button)
        $flowPanel.Controls.Add($button)
    }

    if ($null -ne $Default) {
        $buttons[$Default].Checked = $true
    }
    elseif ($Symbols.Count -gt 0) {
        $buttons[$Symbols[0].Name].Checked = $true
    }

    $Layouts = Add-ControlToMultilayout `
        -Layouts $Layouts `
        -Control $groupBox `
        -Preferences $Preferences

    return $buttons
}

function Add-QuickformOkCancelButtons {
    Param(
        [PsCustomObject]
        $Layouts,

        [PsCustomObject]
        $Preferences = $script:DEFAULT_PREFERENCES
    )

    $endButtons = New-Object System.Windows.Forms.FlowLayoutPanel
    $endButtons.AutoSize = $true
    $endButtons.WrapContents = $false
    $endButtons.FlowDirection = `
        [System.Windows.Forms.FlowDirection]::LeftToRight

    $okButton = New-Object System.Windows.Forms.Button
    $okButton.Text = 'OK'
    $okButton.DialogResult = `
        [System.Windows.Forms.DialogResult]::OK

    $cancelButton = New-Object System.Windows.Forms.Button
    $cancelButton.Text = 'Cancel'
    $cancelButton.DialogResult = `
        [System.Windows.Forms.DialogResult]::Cancel

    $endButtons.Controls.Add($okButton)
    $endButtons.Controls.Add($cancelButton)
    $endButtons.Left = ($Preferences.Width - $endButtons.Width) / 2
    $endButtons.Anchor = `
        [System.Windows.Forms.AnchorStyles]::None

    $Layouts = Add-ControlToMultilayout `
        -Layouts $Layouts `
        -Control $endButtons `
        -Preferences $Preferences

    return [PsCustomObject]@{
        OkButton = $okButton;
        CancelButton = $cancelButton;
    }
}

function Get-FieldValidators {
    [CmdletBinding(DefaultParameterSetName = 'ByInputObject')]
    Param(
        [Parameter(ParameterSetName = 'ByParameterInfo')]
        $ParameterInfo,

        [Parameter(ParameterSetName = 'ByCommandInfo', ValueFromPipeline = $true)]
        [System.Management.Automation.CommandInfo]
        $CommandInfo,

        [Parameter(ParameterSetName = 'ByCommandName')]
        [String]
        $CommandName
    )

    Process {
        switch ($PsCmdlet.ParameterSetName) {
            'ByParameterInfo' {
                $isEnum = $ParameterInfo.ParameterType.PsObject.Properties.Name `
                    -contains 'BaseType' `
                    -and $ParameterInfo.ParameterType.BaseType.Name `
                    -eq 'Enum'

                if ($isEnum) {
                    [PsCustomObject]@{
                        Type = 'Enum';
                        Values = $ParameterInfo.ParameterType.GetFields();
                    }
                }

                foreach ($attribute in $ParameterInfo.Attributes) {
                    switch ($attribute.TypeId.Name) {
                        'ValidateSetAttribute' {
                            [PsCustomObject]@{
                                Type = 'ValidSet';
                                Values = $attribute.ValidValues;
                            }
                        }

                        'ValidateRangeAttribute' {
                            [PsCustomObject]@{
                                Type = 'ValidRange';
                                Minimum = $attribute.MinRange;
                                Maximum = $attribute.MaxRange;
                            }
                        }

                        'ValidateCountAttribute' {
                            [PsCustomObject]@{
                                Type = 'ValidCount';
                                Minimum = $attribute.MinLength;
                                Maximum = $attribute.MaxLength;
                            }
                        }

                        'ValidateLengthAttribute' {
                            [PsCustomObject]@{
                                Type = 'ValidLength';
                                Minimum = $attribute.MinLength;
                                Maximum = $attribute.MaxLength;
                            }
                        }
                    }
                }
            }

            'ByCommandInfo' {
                $parameters = $CommandInfo.Parameters.Keys | % {
                    $CommandInfo.Parameters[$_]
                }

                foreach ($parameter in $parameters) {
                    [PsCustomObject]@{
                        Name = $parameter.Name;
                        Parameter = $parameter;
                        Fields = Get-FieldValidators -ParameterInfo $parameter;
                    }
                }
            }

            'ByCommandName' {
                return Get-Command $CommandName | Get-FieldValidators
            }
        }
    }
}

function Test-IsCommonParameter {
    Param(
        $ParameterInfo
    )

    # link: https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_commonparameters?view=powershell-7.2
    # retrieved: 2022_02_28
    $names = @(
        'Debug',
        'ErrorAction',
        'ErrorVariable',
        'InformationAction',
        'InformationVariable',
        'OutVariable',
        'OutBuffer',
        'PipelineVariable',
        'Verbose',
        'WarningAction',
        'WarningVariable'
    )

    return $names -contains $ParameterInfo.Name
}

function ConvertTo-QuickformParameter {
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

                $values = $validators.Values.Name | ? {
                    $_ -ne 'value__'
                }

                $obj | Add-Member `
                    -MemberType NoteProperty `
                    -Name Symbols `
                    -Value ($values | % {
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
                    -Value ($values | % {
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
        $obj.Type = switch -Wildcard ($type.Name) {
            'String' { 'Field' }
            'Int*' { 'Numeric' }
            'Float' { 'Numeric' }
            'Double' { 'Numeric' }
            'Switch*' { 'Check' }
            'Bool*' { 'Check' }
            default { 'Field' }
        }
    }

    return $obj
}

function ConvertTo-QuickformCommand {
    Param(
        [Parameter(ParameterSetName = 'ByCommandName')]
        [String]
        $CommandName,

        [Parameter(ParameterSetName = 'ByCommandName')]
        [String]
        $ParameterSetName,

        [Parameter(ParameterSetName = 'ByCommandInfo')]
        [System.Management.Automation.CommandInfo]
        $CommandInfo,

        [Parameter(ParameterSetName = 'ByParameterSet')]
        $ParameterSet,

        [Switch]
        $IncludeCommonParameters
    )

    switch ($PsCmdlet.ParameterSetName) {
        'ByCommandName' {
            $command = Get-Command $CommandName

            $parameterSets = if ($ParameterSetName) {
                $command.ParameterSets | where {
                    $_.Name -like $ParameterSetName
                }
            } else {
                $command.ParameterSets
            }
        }

        'ByCommandInfo' {
            return [PsCustomObject]@{
                Preferences = [PsCustomObject]@{
                    Title = $CommandInfo.Name;
                };

                Controls = $CommandInfo.Parameters.Keys | foreach {
                    $CommandInfo.Parameters[$_]
                } | where {
                    $IncludeCommonParameters `
                        -or -not (Test-IsCommonParameter -ParameterInfo $_)
                } | foreach {
                    ConvertTo-QuickformParameter -ParameterInfo $_
                };
            }
        }

        'ByParameterSet' {
            return [PsCustomObject]@{
                Preferences = [PsCustomObject]@{
                    Title = $ParameterSet.Name;
                };

                Controls = $ParameterSet.Parameters | where {
                    $IncludeCommonParameters `
                        -or -not (Test-IsCommonParameter -ParameterInfo $_)
                } | foreach {
                    ConvertTo-QuickformParameter -ParameterInfo $_
                };
            }
        }
    }
}



