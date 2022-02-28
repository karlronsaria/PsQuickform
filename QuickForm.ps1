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
    Title = "Preferences";
    FontFamily = "Microsoft Sans Serif";
    Point = 10;
    Width = 500;
    Margin = 10;
    ConfirmType = "TrueOrFalse";
}

$script:DEFAULT_SLIDER_MINIMUM = -99999
$script:DEFAULT_SLIDER_MAXIMUM = 99999
$script:DEFAULT_SLIDER_DECIMALPLACES = 2

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
        function Get-PropertyOrDefault {
            Param(
                [Parameter(ValueFromPipeline = $true)]
                $InputObject,

                [String]
                $Name,

                $Default = $null
            )

            if ($item.PsObject.Properties.Name -contains $Name) {
                return $item.$Name
            }

            return $Default
        }

        $myPreferences = $script:DEFAULT_PREFERENCES

        if ($Preferences) {
            foreach ($property in $Preferences.PsObject.Properties.Name) {
                $myPreferences.$property = $Preferences.$property
            }
        }

        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName System.Drawing

        $what = New-QuickformMainForm `
            -Preferences $myPreferences

        $form = $what.MainForm
        $layout = $what.FlowLayoutPanel

        $controls = @{}
        $list = @()
    }

    Process {
        foreach ($item in $Control) {
            $list += @($item)
        }
    }

    End {
        foreach ($item in $list) {
            $default = $item | Get-PropertyOrDefault `
                -Name "Default"

            $text = $item | Get-PropertyOrDefault `
                -Name "Text" `
                -Default $item.Name

            $value = switch ($item.Type) {
                "Check" {
                    Add-QuickformCheckBox `
                        -Parent $layout `
                        -Text $text `
                        -Default $default `
                        -Preferences $myPreferences
                }

                "Field" {
                    $minLength = $item | Get-PropertyOrDefault `
                        -Name MinLength;
                    $maxLength = $item | Get-PropertyOrDefault `
                        -Name MaxLength;

                    Add-QuickformFieldBox `
                        -Parent $layout `
                        -Text $text `
                        -MinLength $minLength `
                        -MaxLength $maxLength `
                        -Default $default `
                        -Preferences $myPreferences
                }

                "Enum" {
                    Add-QuickformRadioBox `
                        -Parent $layout `
                        -Text $text `
                        -Symbols $item.Symbols `
                        -Default $default `
                        -Preferences $myPreferences
                }

                "Numeric" {
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
                        -Parent $layout `
                        -Text $text `
                        -DecimalPlaces $places `
                        -Minimum $min `
                        -Maximum $max `
                        -AsFloat:$asFloat `
                        -Default $default `
                        -Preferences $myPreferences
                }
            }

            $controls.Add($item.Name, $value)
        }

        $endButtons = Add-QuickformOkCancelButtons -Parent $layout
        $okButton = $endButtons.OkButton
        $cancelButton = $endButtons.CancelButton
        $out = [PsCustomObject]@{}

        $confirm = switch ($form.ShowDialog()) {
            "OK" { $true }
            "Cancel" { $false }
        }

        foreach ($item in $list) {
            $value = switch ($item.Type) {
                "Check" {
                    $tempValue = $controls[$item.Name].Checked;

                    switch ($myPreferences.ConfirmType) {
                        "TrueOrFalse" {
                            $tempValue
                        }

                        "AllowOrDeny" {
                            switch ($tempValue) {
                                "True" { "Allow" }
                                "False" { "Deny" }
                            }
                        }
                    }
                }

                "Field" {
                    $controls[$item.Name].Text
                }

                "Enum" {
                    $buttons = $controls[$item.Name];

                    if ($buttons) {
                        $buttons.Keys | where {
                            $buttons[$_].Checked
                        } | foreach {
                            $_
                        }
                    }
                }

                "Numeric" {
                    $controls[$item.Name].Value
                }
            }

            $out | Add-Member `
                -MemberType NoteProperty `
                -Name $item.Name `
                -Value $value
        }

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

function New-QuickformMainForm {
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
    $form.Width = $Preferences.Width
    $form.AutoSize = $true
    $form.FormBorderStyle = `
        [System.Windows.Forms.FormBorderStyle]::FixedSingle

    $layout = New-Object System.Windows.Forms.FlowLayoutPanel
    $layout.FlowDirection = `
        [System.Windows.Forms.FlowDirection]::TopDown
    $layout.Left = $Preferences.Margin
    $layout.Width = $Preferences.Width - (2 * $Preferences.Margin)
    $layout.AutoSize = $true
    $layout.WrapContents = $false
    $form.Controls.Add($layout)

    return [PsCustomObject]@{
        MainForm = $form;
        FlowLayoutPanel = $layout;
    }
}

function Add-QuickformCheckBox {
    Param(
        [System.Windows.Forms.Control]
        $Parent,

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

    $Parent.Controls.Add($checkBox)
    return $checkBox
}

function Add-QuickformFieldBox {
    Param(
        [System.Windows.Forms.Control]
        $Parent,

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
    $Parent.Controls.Add($flowPanel)
    return $textBox
}

function Add-QuickformSlider {
    Param(
        [System.Windows.Forms.Control]
        $Parent,

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
    $Parent.Controls.Add($flowPanel)
    return $slider
}

function Add-QuickformRadioBox {
    Param(
        [System.Windows.Forms.Control]
        $Parent,

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

    $Parent.Controls.Add($groupBox)
    return $buttons
}

function Add-QuickformOkCancelButtons {
    Param(
        [System.Windows.Forms.Control]
        $Parent
    )

    $endButtons = New-Object System.Windows.Forms.FlowLayoutPanel
    $endButtons.AutoSize = $true
    $endButtons.WrapContents = $false
    $endButtons.FlowDirection = `
        [System.Windows.Forms.FlowDirection]::LeftToRight

    $okButton = New-Object System.Windows.Forms.Button
    $okButton.Text = "OK"
    $okButton.DialogResult = `
        [System.Windows.Forms.DialogResult]::OK

    $cancelButton = New-Object System.Windows.Forms.Button
    $cancelButton.Text = "Cancel"
    $cancelButton.DialogResult = `
        [System.Windows.Forms.DialogResult]::Cancel

    $endButtons.Controls.Add($okButton)
    $endButtons.Controls.Add($cancelButton)
    $endButtons.Left = ($Parent.Width - $endButtons.Width) / 2
    $endButtons.Anchor = `
        [System.Windows.Forms.AnchorStyles]::None

    $Parent.Controls.Add($endButtons)

    return [PsCustomObject]@{
        OkButton = $okButton;
        CancelButton = $cancelButton;
    }
}

function Get-FieldValidators {
    [CmdletBinding(DefaultParameterSetName = 'ByInputObject')]
    Param(
        [Parameter(ParameterSetName = 'ByParameterInfo')]
        [System.Management.Automation.ParameterMetadata]
        $ParameterInfo,

        [Parameter(ParameterSetName = 'ByCommandInfo', ValueFromPipeline = $true)]
        [System.Management.Automation.CommandInfo]
        $CommandInfo,

        [Parameter(ParameterSetName = 'ByCommandName')]
        [String]
        $CommandName
    )

    Begin {
        function Get-PropertyOrDefault {
            Param(
                [Parameter(ValueFromPipeline = $true)]
                $InputObject,

                [String]
                $Name,

                $Default = $null
            )

            if ($item.PsObject.Properties.Name -contains $Name) {
                return $item.$Name
            }

            return $Default
        }
    }

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
        [System.Management.Automation.ParameterMetadata]
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

    # $nonCommon = @($ParameterInfo.Attributes `
    #     | where TypeId -like System.Management.Automation.Internal.CommonParameters*)

    # return $null -ne $nonCommon -and $nonCommon.Count -gt 0
}

function ConvertTo-QuickformParameter {
    Param(
        [System.Management.Automation.ParameterMetadata]
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
        [Parameter(ParameterSetName = 'ByCommandInfo', ValueFromPipeline = $true)]
        [System.Management.Automation.CommandInfo]
        $CommandInfo,

        [Switch]
        $IncludeCommonParameters
    )

    return [PsCustomObject]@{
        Preferences = [PsCustomObject]@{
            Title = $CommandInfo.Name;
        };

        Controls = $CommandInfo.Parameters.Keys | % {
            $CommandInfo.Parameters[$_]
        } | where {
            $IncludeCommonParameters `
                -or -not (Test-IsCommonParameter -ParameterInfo $_)
        } | foreach {
            ConvertTo-QuickformParameter -ParameterInfo $_
        };
    }
}

