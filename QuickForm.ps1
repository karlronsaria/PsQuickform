function Get-QuickformObject {
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline = $true)]
        [PsCustomObject]
        $InputObject,

        [Switch]
        $AsHashtable
    )

    if (-not $InputObject) {
        return New-ObjectForm
    }

    return $InputObject.Controls `
        | New-QuickformObject `
            -Preferences $InputObject.Preferences `
            -AsHashtable:$AsHashtable
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
        $myPreferences = [PsCustomObject]@{
            Title = "Preferences";
            FontFamily = "Microsoft Sans Serif";
            Point = 10;
            Width = 500;
            Margin = 10;
            ConfirmType = "TrueOrFalse";
        }

        if ($Preferences) {
            foreach ($property in $myPreferences.PsObject.Properties.Name) {
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
            $default = if ($item.PsObject.Properties.Name -contains "Default") {
                $item.Default
            } else {
                $null
            }

            $value = switch ($item.Type) {
                "Check" {
                    Add-QuickformCheckBox `
                        -Parent $layout `
                        -Text $item.Text `
                        -Default $default `
                        -Preferences $myPreferences
                }

                "Field" {
                    Add-QuickformFieldBox `
                        -Parent $layout `
                        -Text $item.Text `
                        -Default $default `
                        -Preferences $myPreferences
                }

                "Enum" {
                    Add-QuickformRadioBox `
                        -Parent $layout `
                        -Text $item.Text `
                        -Symbols $item.Symbols `
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

        $confirmChanges = switch ($form.ShowDialog()) {
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
                        $buttons.Keys | ? { $buttons[$_].Checked } | % { $_ }
                    }
                }
            }

            $out | Add-Member `
                -MemberType NoteProperty `
                -Name $item.Name `
                -Value $value
        }

        $out | Add-Member `
            -MemberType NoteProperty `
            -Name ConfirmChanges `
            -Value $confirmChanges

        if ($AsHashtable) {
            $table = @{}

            foreach ($property in $out.PsObject.Properties.Name) {
                $table[$property] = $out.$property
            }

            return $table
        }

        return $out
    }
}

function New-QuickformMainForm {
    Param(
        [PsCustomObject]
        $Preferences
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
        $Preferences
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

        $Default,

        [PsCustomObject]
        $Preferences
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

    if ($null -ne $Default) {
        $textBox.Text = $Default
    }

    $flowPanel.Controls.Add($label)
    $flowPanel.Controls.Add($textBox)
    $Parent.Controls.Add($flowPanel)
    return $textBox
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
        $Preferences
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
        $button.Text = $symbol.Text
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
