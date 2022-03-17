. $PsScriptRoot\Other.ps1

$script:RESOURCE_PATH =
    if ((Test-Path "$PsScriptRoot\res")) {
        "$PsScriptRoot\res"
    } else {
        "$PsScriptRoot\..\res"
    }

$script:DEFAULT_PREFERENCES_PATH =
    "$($script:RESOURCE_PATH)\default_preference.json"

$script:TEXT_PATH =
    "$($script:RESOURCE_PATH)\text.json"

$script:DEFAULT_PREFERENCES =
    if ((Test-Path $script:DEFAULT_PREFERENCES_PATH)) {
        Get-Content $script:DEFAULT_PREFERENCES_PATH | ConvertFrom-Json
    } else {
        [PsCustomObject]@{
            Caption = "Quickform Settings"
            FontFamily = "Microsoft Sans Serif"
            Point = 10
            Width = 450
            Height = 800
            Margin = 10
            ConfirmType = "TrueOrFalse"
            EnterToConfirm = $true
            EscapeToCancel = $true
            DateFormat = "yyyy_MM_dd"
            NumericMinimum = -9999
            NumericMaximum = 9999
            NumericDecimalPlaces = 0
        }
    }

$script:DEFAULT_NUMERIC_MINIMUM =
    $script:DEFAULT_PREFERENCES.NumericMinimum

$script:DEFAULT_NUMERIC_MAXIMUM =
    $script:DEFAULT_PREFERENCES.NumericMaximum

$script:DEFAULT_NUMERIC_DECIMALPLACES =
    $script:DEFAULT_PREFERENCES.NumericDecimalPlaces

$script:STATUS =
    (Get-Content $script:TEXT_PATH | ConvertFrom-Json).Status

function Show-ControlRectangle {
    Param(
        [System.Windows.Forms.Control]
        $Control
    )

    Add-Type -AssemblyName System.Drawing
    $Control.BackColor =
        [System.Drawing.Color]::Red
}

<#
    .LINK
    Link: https://stackoverflow.com/questions/34552311/wpf-systemparameters-windowcaptionbuttonheight-returns-smaller-number-than-expe
    Link: https://stackoverflow.com/users/3137337/emoacht
    Retrieved: 2022_03_07
#>
function Get-WindowsCaptionHeight {
    Add-Type -AssemblyName PresentationFramework

    $sysInfo = [System.Windows.Forms.SystemInformation]
    $sysParams = [System.Windows.SystemParameters]

    return $sysInfo::CaptionHeight `
        + $sysParams::WindowResizeBorderThickness.Bottom `
        + $sysParams::WindowNonClientFrameThickness.Bottom
}

<#
    .LINK
    Link: https://stackoverflow.com/questions/20423211/setting-cursor-at-the-end-of-any-text-of-a-textbox
    Link: https://stackoverflow.com/users/1042848/vishal-suthar
    Retreived: 2022_03_02
#>
function Set-ControlsWritableText {
    Param(
        [System.Windows.Forms.Control]
        $Control,

        [String]
        $Text
    )

    $Control.Text = $Text
    $Control.Select($Control.Text.Length, 0)
}

<#
    .LINK
    Link: https://stackoverflow.com/questions/4601827/how-do-i-center-a-window-onscreen-in-c
    Link: https://stackoverflow.com/users/1527490/sarsur-a
    Link: https://stackoverflow.com/users/1306012/bruno-bieri
    Retrieved: 2022_03_02
#>
function Set-ControlsCenterScreen {
    Param(
        [System.Windows.Forms.Control]
        $Control
    )

    $screen = [System.Windows.Forms.Screen]::FromControl($Control)
    $workingArea = $screen.WorkingArea

    $Control.Left =
        [Math]::Max(
            $workingArea.X,
            $workingArea.X + ($workingArea.Width - $Control.Width) / 2
        )

    $Control.Top =
        [Math]::Max(
            $workingArea.Y,
            $workingArea.Y + ($workingArea.Height - $Control.Height) / 2
        )
}

function Set-ControlsStatus {
    Param(
        [System.Windows.Forms.Control]
        $StatusLine,

        [String]
        $LineName
    )

    $status = $script:STATUS | where Name -eq $LineName

    $text = $status | Get-PropertyOrDefault `
        -Name Text `
        -Default 'ToolTip missing!'

    $foreColor = $status | Get-PropertyOrDefault `
        -Name ForeColor `
        -Default 'Black'

    $StatusLine.Text = $text
    $StatusLine.ForeColor = $foreColor
}

function New-ControlsInfoLabel {
    Param(
        [PsCustomObject]
        $Preferences = $script:DEFAULT_PREFERENCES
    )

    $infoLabel = New-Object System.Windows.Forms.Label
    $infoLabel.Left = $Preferences.Margin
    $infoLabel.Width = $Preferences.Width - (2 * $Preferences.Margin)
    return $infoLabel
}

function New-ControlsLayout {
    Param(
        [PsCustomObject]
        $Preferences = $script:DEFAULT_PREFERENCES
    )

    $layout = New-Object System.Windows.Forms.FlowLayoutPanel
    $layout.FlowDirection =
        [System.Windows.Forms.FlowDirection]::TopDown
    $layout.Left = $Preferences.Margin
    $layout.Width = $Preferences.Width - (2 * $Preferences.Margin)
    $layout.AutoSize = $true
    $layout.WrapContents = $false
    return $layout
}

function New-ControlsMultilayout {
    Param(
        [PsCustomObject]
        $Preferences = $script:DEFAULT_PREFERENCES
    )

    $multilayout = New-Object System.Windows.Forms.FlowLayoutPanel
    $multilayout.Left = $Preferences.Margin
    $multilayout.AutoSize = $true
    $multilayout.FlowDirection =
        [System.Windows.Forms.FlowDirection]::LeftToRight

    $layout = New-ControlsLayout `
        -Preferences $Preferences

    $multilayout.Controls.Add($layout)

    return [PsCustomObject]@{
        Multilayout = $multilayout
        Sublayouts = @($layout)
        Controls = @{}
    }
}

function Add-ControlsFormKeyBindings {
    Param(
        [System.Windows.Forms.Control]
        $Control,

        [PsCustomObject]
        $Layouts,

        [PsCustomObject]
        $Preferences
    )

    $script:layouts = $Layouts

    if ($Preferences.EnterToConfirm) {
        $Control.add_KeyDown({
            if ($_.KeyCode -eq 'Enter') {
                $script:layouts.Controls[
                '__EndButtons__'
                ].OkButton.PerformClick()
            }
        })
    }

    if ($Preferences.EscapeToCancel) {
        $Control.add_KeyDown({
            if ($_.KeyCode -eq 'Escape') {
                $script:layouts.Controls[
                '__EndButtons__'
                ].CancelButton.PerformClick()
            }
        })
    }

    $Control.add_KeyDown({
        if ($_.KeyCode -eq [System.Windows.Forms.Keys]::OemQuestion `
            -and $_.Control)
        {
            $message = (Get-Content `
                -Path $script:TEXT_PATH `
                | ConvertFrom-Json).Help

            $message = $message -join "`r`n"
            $caption = 'Help'
            [System.Windows.Forms.MessageBox]::Show($message, $caption)
        }
    })
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

    $totalHeight =
        (Get-WindowsCaptionHeight) `
        + $final.Height `
        + ($Layouts.Controls.Keys `
            | where { $_ -match '^__.*__$' } `
            | foreach { $Layouts.Controls[$_].Height } `
            | measure -Sum).Sum

    $Control | foreach {
        $totalHeight += $Control.Height
    }

    if ($totalHeight -gt $Preferences.Height) {
        $layout = New-ControlsLayout `
            -Preferences $Preferences

        $Layouts.Multilayout.Controls.Add($layout)
        $Layouts.Sublayouts += @($layout)
        $final = $Layouts.Sublayouts[-1]
    }

    $Control | foreach {
        $final.Controls.Add($_)
    }

    return $Layouts
}

<#
    .LINK
    Link: https://stackoverflow.com/questions/12801563/powershell-setforegroundwindow
    Link: https://stackoverflow.com/users/520612/cb
    Retrieved: 2022_03_02
#>
function Add-ControlsFocusOnShownEvent {
    Param(
        [System.Windows.Forms.Form]
        $Form
    )

    Add-Type @"
    using System;
    using System.Runtime.InteropServices;
    public class SFW {
        [DllImport("user32.dll")]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool SetForegroundWindow(IntPtr hWnd);
    }
"@

    $Form.add_Shown({
        $handle = $this.WindowTarget.Handle
        [void] [SFW]::SetForegroundWindow($handle)
    })
}

function New-ControlsMain {
    Param(
        [PsCustomObject]
        $Preferences = $script:DEFAULT_PREFERENCES
    )

    $font = New-Object System.Drawing.Font(
        $Preferences.FontFamily,
        $Preferences.Point,
        [System.Drawing.FontStyle]::Regular
    )

    $form = New-Object System.Windows.Forms.Form
    $form.Text = $Preferences.Caption
    $form.Font = $font
    $form.AutoSize = $true
    $form.KeyPreview = $true
    $form.AutoSizeMode =
        [System.Windows.Forms.AutoSizeMode]::GrowAndShrink
    $form.FormBorderStyle =
        [System.Windows.Forms.FormBorderStyle]::FixedSingle
    $form.StartPosition =
        [System.Windows.Forms.FormStartPosition]::CenterScreen

    Add-ControlsFocusOnShownEvent `
        -Form $form

    return $form
}

function Add-ControlsCheckBox {
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

function Get-ControlsAsterizable {
    Param(
        [System.Windows.Forms.Control]
        $Control,

        [Int]
        $Width,

        [Switch]
        $Asterize
    )

    $row = $null

    if ($Asterize) {
        $asterisk = New-Object System.Windows.Forms.Label
        $asterisk.Text = '*'
        $asterisk.Size =
            [System.Windows.Forms.TextRenderer]::MeasureText(
                $asterisk.Text,
                $asterisk.Font
            )
        $asterisk.Dock =
            [System.Windows.Forms.DockStyle]::Bottom
        $asterisk.Height = $asterisk.Height + $Preferences.Margin
        $asterisk.Margin = 0

        Add-Type -AssemblyName System.Drawing

        $asterisk.ForeColor =
            [System.Drawing.Color]::DarkRed

        $row = New-Object System.Windows.Forms.FlowLayoutPanel
        $row.FlowDirection =
            [System.Windows.Forms.FlowDirection]::LeftToRight
        $row.WrapContents = $false
        $row.AutoSize = $true
        $row.Padding = $row.Margin = 0
        $row.Width = $Width

        $Control.Width = $row.Width - $asterisk.Width

        $row.Controls.Add($asterisk)
        $row.Controls.Add($Control)
    }
    else {
        $row = $Control
        $row.Width = $Width
    }

    return $row
}

function Get-ControlsTextDialog {
    Param(
        [PsCustomObject]
        $Preferences = $script:DEFAULT_PREFERENCES,

        [String]
        $Text,

        [String]
        $Caption,

        [Int]
        $MaxLength
    )

    $textBox = New-Object System.Windows.Forms.TextBox
    $textBox.Width =
        $script:prefs.Width - (4 * $script:prefs.Margin)

    if ($null -ne $MaxLength) {
        $textBox.MaxLength = $MaxLength
    }

    Set-ControlsWritableText `
        -Control $textBox `
        -Text $Text

    $form = New-ControlsMain `
        -Preferences $script:prefs

    $form.Text = $Caption
    $form.KeyPreview = $true
    $form.Controls.Add($textBox)

    $form.add_KeyDown({
        if ($_.KeyCode -eq 'Enter') {
            $this.DialogResult = [System.Windows.Forms.DialogResult]::OK
            $this.Close()
        }
    })

    $form.add_KeyDown({
        if ($_.KeyCode -eq 'Escape') {
            $this.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
            $this.Close()
        }
    })

    switch ($form.ShowDialog()) {
        'Cancel' {
            return
        }
    }

    return $textBox.Text
}

function Add-ControlsListBox {
    Param(
        [PsCustomObject]
        $Layouts,

        [String]
        $Text,

        [Switch]
        $Mandatory,

        $MaxLength,
        $MaxCount,
        $Default,

        [PsCustomObject]
        $Preferences = $script:DEFAULT_PREFERENCES
    )

    $outerPanel = New-Object System.Windows.Forms.FlowLayoutPanel
    $outerPanel.FlowDirection =
        [System.Windows.Forms.FlowDirection]::TopDown
    $outerPanel.Left = $Preferences.Margin
    $outerPanel.AutoSize = $true
    $outerPanel.WrapContents = $false
    $outerPanel.Padding = 0

    $label = New-Object System.Windows.Forms.Label
    $label.Text = $Text
    $label.Left = $Preferences.Margin
    $label.AutoSize = $true

    $row1 = Get-ControlsAsterizable `
        -Control $label `
        -Width ($Preferences.Width - (4 * $Preferences.Margin)) `
        -Asterize:$Mandatory

    $mainPanel = New-Object System.Windows.Forms.FlowLayoutPanel
    $mainPanel.FlowDirection =
        [System.Windows.Forms.FlowDirection]::RightToLeft
    $mainPanel.Left = $Preferences.Margin
    $mainPanel.Width = $Preferences.Width # - (2 * $Preferences.Margin)
    $mainPanel.AutoSize = $true
    $mainPanel.AutoSizeMode =
        [System.Windows.Forms.AutoSizeMode]::GrowAndShrink
    $mainPanel.WrapContents = $false
    $mainPanel.Margin = $mainPanel.Padding = 0

    $buttonPanel = New-Object System.Windows.Forms.FlowLayoutPanel
    $buttonPanel.FlowDirection =
        [System.Windows.Forms.FlowDirection]::TopDown
    $buttonPanel.Width = 90
    $buttonPanel.WrapContents = $false
    $buttonPanel.Margin = $buttonPanel.Padding = 0
    $buttonPanel.AutoSize = $true
    $buttonPanel.AutoSizeMode =
        [System.Windows.Forms.AutoSizeMode]::GrowAndShrink

    $buttonNames = @(
        'New', 'Edit', 'Delete', 'Move Up', 'Move Down', 'Sort'
    )

    $buttonTable = @{}
    $actionTable = @{}

    foreach ($name in $buttonNames) {
        $button = New-Object System.Windows.Forms.Button
        $button.Text = $name
        $button.Width = $buttonPanel.Width

        $buttonPanel.Controls.Add($button)
        $buttonTable.Add($name, $button)
    }

    $script:listBox = New-Object System.Windows.Forms.ListBox
    $script:listBox.Width = $mainPanel.Width - $buttonPanel.Width
    $script:listBox.Height = 200

    $script:prefs = $Preferences
    $script:maxCount = $MaxCount
    $script:maxLength = $MaxLength

    $actionTable['New'] = {
        $index = $script:listBox.SelectedIndex

        if ($null -ne $script:MaxCount `
            -and $script:listBox.Items.Count -eq $script:MaxCount)
        {
            Set-ControlsStatus `
                -StatusLine $script:layouts.StatusLine `
                -LineName 'MaxCountReached'

            return
        }

        if ($index -ge 0) {
            $script:listBox.Items.Insert($index, '')
        }
        else {
            $script:listBox.Items.Add('')
            $index = $script:listBox.Items.Count - 1
        }

        $script:listBox.Items[$index] =
            Get-ControlsTextDialog `
                -Preferences $script:prefs `
                -Text $script:listBox.Items[$index] `
                -Caption 'Edit ListBox Item' `
                -MaxLength $script:maxLength
    }

    $actionTable['Edit'] = {
        $index = $script:listBox.SelectedIndex

        if ($index -lt 0) {
            return
        }

        $script:listBox.Items[$index] =
            Get-ControlsTextDialog `
                -Preferences $script:prefs `
                -Text $script:listBox.Items[$index] `
                -Caption 'Edit ListBox Item' `
                -MaxLength $script:maxLength
    }

    $actionTable['Delete'] = {
        $index = $script:listBox.SelectedIndex

        if ($index -lt 0) {
            return
        }

        $script:listBox.Items.RemoveAt($index)

        if ($script:listBox.Items.Count -eq 0) {
            return
        }

        if ($index -eq 0) {
            $script:listBox.SetSelected(0, $true)
        }
        else {
            $script:listBox.SetSelected($index - 1, $true)
        }
    }

    $actionTable['Move Up'] = {
        $index = $script:listBox.SelectedIndex

        $immovable = $script:listBox.Items.Count -le 1 `
            -or $index -le 0

        if ($immovable) {
            return
        }

        $items = $script:listBox.Items
        $temp = $items[$index - 1]
        $items[$index - 1] = $items[$index]
        $items[$index] = $temp

        $script:listBox.SetSelected($index, $false)
        $script:listBox.SetSelected($index - 1, $true)
    }

    $actionTable['Move Down'] = {
        $index = $script:listBox.SelectedIndex

        $immovable = $script:listBox.Items.Count -le 1 `
            -or $index -lt 0 `
            -or $index -eq $script:listBox.Items.Count - 1

        if ($immovable) {
            return
        }

        $items = $script:listBox.Items
        $temp = $items[$index + 1]
        $items[$index + 1] = $items[$index]
        $items[$index] = $temp

        $script:listBox.SetSelected($index, $false)
        $script:listBox.SetSelected($index + 1, $true)
    }

    $actionTable['Sort'] = {
        $items = $script:listBox.Items | sort | foreach {
            [String]::new($_)
        }

        $script:listBox.Items.Clear()

        foreach ($item in $items) {
            $script:listBox.Items.Add($item)
        }
    }

    foreach ($name in $buttonNames) {
        $button = $buttonTable[$name]
        $script:action = $actionTable[$name]

        $button.add_Click($script:action)
        $button.add_KeyDown({
            if ($_.KeyCode -eq 'Space') {
                & $script:action
            }
        })
    }

    $script:newAction = $actionTable['New']
    $script:editAction = $actionTable['Edit']
    $script:deleteAction = $actionTable['Delete']

    $script:listBox.add_keyDown({
        $myEventArgs = $_

        if ($myEventArgs.Control) {
            switch ($myEventArgs.KeyCode) {
                'C' {
                    $index = $script:listBox.SelectedIndex

                    if ($index -lt 0) {
                        return
                    }

                    Set-Clipboard `
                        -Value $script:listBox.Items[$index]

                    Set-ControlsStatus `
                        -StatusLine $script:layouts.StatusLine `
                        -LineName 'TextClipped'
                }

                'N' {
                    & $script:newAction
                    return
                }

                'Space' {
                    $index = $script:listBox.SelectedIndex

                    if ($index -lt 0) {
                        return
                    }

                    $script:listBox.ClearSelected()
                    $myEventArgs.Handled = $true
                }
            }
        }

        if ($myEventArgs.KeyCode -eq [System.Windows.Forms.Keys]::F2) {
            & $script:editAction
            return
        }

        if ($myEventArgs.KeyCode -eq [System.Windows.Forms.Keys]::Delete) {
            & $script:deleteAction
            return
        }
    })

    $script:listBox.add_GotFocus({
        Set-ControlsStatus `
            -StatusLine $script:layouts.StatusLine `
            -LineName 'InListBox'
    })

    $script:listBox.add_LostFocus({
        Set-ControlsStatus `
            -StatusLine $script:layouts.StatusLine `
            -LineName 'Idle'
    })

    foreach ($item in $Default) {
        $script:listBox.Items.Add($item)
    }

    $mainPanel.Height = $buttonPanel.Height
    $mainPanel.Controls.Add($buttonPanel)
    $mainPanel.Controls.Add($script:listBox)

    $outerPanel.Controls.Add($row1)
    $outerPanel.Controls.Add($mainPanel)

    $Layouts = Add-ControlToMultilayout `
        -Layouts $Layouts `
        -Control $outerPanel `
        -Preferences $Preferences

    return $script:listBox
}

<#
    .NOTE
    Needs to be an 'Add-' cmdlet. Adds multiple controls other than the operative
    control, to a target container. 'Add-' rather than 'New-' helps encapsulate
    inoperative controls.
#>
function Add-ControlsFieldBox {
    Param(
        [PsCustomObject]
        $Layouts,

        [String]
        $Text,

        [Switch]
        $Mandatory,

        $MaxLength,
        $Default,

        [PsCustomObject]
        $Preferences = $script:DEFAULT_PREFERENCES
    )

    $flowPanel = New-Object System.Windows.Forms.FlowLayoutPanel
    $flowPanel.FlowDirection =
        [System.Windows.Forms.FlowDirection]::TopDown
    $flowPanel.Left = $Preferences.Margin
    $flowPanel.AutoSize = $true
    $flowPanel.WrapContents = $false
    $flowPanel.Padding = 0

    $label = New-Object System.Windows.Forms.Label
    $label.Text = $Text
    $label.Left = $Preferences.Margin
    $label.AutoSize = $true

    $textBox = New-Object System.Windows.Forms.TextBox

    $row2 = Get-ControlsAsterizable `
        -Control $textBox `
        -Width ($Preferences.Width - (4 * $Preferences.Margin)) `
        -Asterize:$Mandatory

    $script:monthCalendarPrefs = $Preferences.PsObject.Copy()
    $script:monthCalendarPrefs.Caption = 'Get Date'
    $script:monthCalendarPrefs.Width = 350

    $textBox.add_KeyDown({
        $myEventArgs = $_

        switch ($myEventArgs.KeyCode) {
            'O' {
                if ($myEventArgs.Control) {
                    Set-ControlsWritableText `
                        -Control $this `
                        -Text ($this.Text + (Open-ControlsFileDialog))

                    $myEventArgs.Handled = $true
                    $myEventArgs.SuppressKeyPress = $true
                }
            }

            'D' {
                if ($myEventArgs.Control) {
                    $text = Open-ControlsMonthCalendar `
                        -Preferences $script:monthCalendarPrefs

                    Set-ControlsWritableText `
                        -Control $this `
                        -Text ($this.Text + $text)

                    $myEventArgs.Handled = $true
                    $myEventArgs.SuppressKeyPress = $true
                }
            }
        }
    })

    if ($null -ne $MaxLength) {
        $textBox.MaxLength = $MaxLength
    }

    if ($null -ne $Default) {
        Set-ControlsWritableText `
            -Control $textBox `
            -Text $Default
    }

    $flowPanel.Controls.Add($label)
    $flowPanel.Controls.Add($row2)

    $Layouts = Add-ControlToMultilayout `
        -Layouts $Layouts `
        -Control $flowPanel `
        -Preferences $Preferences

    return $textBox
}

<#
    .NOTE
    Needs to be an 'Add-' cmdlet. Adds multiple controls other than the operative
    control, to a target container. 'Add-' rather than 'New-' helps encapsulate
    inoperative controls.
#>
function Add-ControlsSlider {
    Param(
        [PsCustomObject]
        $Layouts,

        [String]
        $Text,

        [Switch]
        $Mandatory,

        $Minimum = $script:DEFAULT_NUMERIC_MINIMUM,
        $Maximum = $script:DEFAULT_NUMERIC_MAXIMUM,
        $DecimalPlaces = $script:DEFAULT_NUMERIC_DECIMALPLACES,
        $Default,

        [PsCustomObject]
        $Preferences = $script:DEFAULT_PREFERENCES
    )

    $flowPanel = New-Object System.Windows.Forms.FlowLayoutPanel
    $flowPanel.FlowDirection =
        [System.Windows.Forms.FlowDirection]::TopDown
    $flowPanel.Left = $Preferences.Margin
    $flowPanel.AutoSize = $true
    $flowPanel.WrapContents = $false
    $flowPanel.Padding = 0

    $label = New-Object System.Windows.Forms.Label
    $label.Text = $Text
    $label.Left = $Preferences.Margin
    $label.AutoSize = $true

    $slider = New-Object System.Windows.Forms.NumericUpDown
    $slider.Left = $Preferences.Margin

    $row2 = Get-ControlsAsterizable `
        -Control $slider `
        -Width ($Preferences.Width - (4 * $Preferences.Margin)) `
        -Asterize:$Mandatory

    $slider.Minimum = $Minimum
    $slider.Maximum = $Maximum
    $script:layouts = $Layouts

    if ($null -ne $Minimum -and $null -ne $Maximum) {
        $slider.add_KeyDown({
            if ($_.Control) {
                switch ($_.KeyCode) {
                    'Up' {
                        $this.Value = $this.Maximum
                    }

                    'Down' {
                        $this.Value = $this.Minimum
                    }
                }
            }
        })

        $slider.add_TextChanged({
            $name =
                if ($this.Text -eq $this.Minimum) {
                    'MinReached'
                }
                elseif ($this.Text -eq $this.Maximum) {
                    'MaxReached'
                }
                else {
                    'Idle'
                }

            Set-ControlsStatus `
                -StatusLine $script:layouts.StatusLine `
                -LineName $name
        })
    }

    if ($null -ne $Default) {
        $slider.Value = $Default
    }
    else {
        $slider.Text = ''
    }

    $flowPanel.Controls.Add($label)
    $flowPanel.Controls.Add($row2)

    $Layouts = Add-ControlToMultilayout `
        -Layouts $Layouts `
        -Control $flowPanel `
        -Preferences $Preferences

    return $slider
}

<#
    .NOTE
    Needs to be an 'Add-' cmdlet. Adds multiple controls other than the operative
    control, to a target container. 'Add-' rather than 'New-' helps encapsulate
    inoperative controls.
#>
function Add-ControlsRadioBox {
    Param(
        [PsCustomObject]
        $Layouts,

        [String]
        $Text,

        [Switch]
        $Mandatory,

        [PsCustomObject[]]
        $Symbols,

        $Default,

        [PsCustomObject]
        $Preferences = $script:DEFAULT_PREFERENCES
    )

    $groupBox = New-Object System.Windows.Forms.GroupBox
    $groupBox.Left = $Preferences.Margin
    $groupBox.AutoSize = $true
    $groupBox.Text = $Text

    $flowPanel = New-Object System.Windows.Forms.FlowLayoutPanel
    $flowPanel.FlowDirection =
        [System.Windows.Forms.FlowDirection]::TopDown
    $flowPanel.AutoSize = $true
    $flowPanel.WrapContents = $false
    $flowPanel.Top = 3 * $Preferences.Margin
    $flowPanel.Left = $Preferences.Margin
    $groupBox.Controls.Add($flowPanel)

    if (-not $Mandatory) {
        $Symbols += @([PsCustomObject]@{ Name = 'None'; })
    }

    $buttons = @{}

    foreach ($symbol in $Symbols) {
        $button = New-Object System.Windows.Forms.RadioButton
        $button.Left = $Preferences.Margin
        $button.Width = $Preferences.Width - (5 * $Preferences.Margin)

        $button.Text = $symbol | Get-PropertyOrDefault `
            -Name Text `
            -Default $symbol.Name

        $buttons.Add($symbol.Name, $button)
        $flowPanel.Controls.Add($button)
    }

    if (-not $Mandatory) {
        $buttons['None'].Checked = $true
    }
    elseif ($null -ne $Default) {
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

function New-ControlsOkCancelButtons {
    Param(
        [PsCustomObject]
        $Preferences = $script:DEFAULT_PREFERENCES
    )

    $endButtons = New-Object System.Windows.Forms.FlowLayoutPanel
    $endButtons.AutoSize = $true
    $endButtons.WrapContents = $false
    $endButtons.FlowDirection =
        [System.Windows.Forms.FlowDirection]::LeftToRight

    $okButton = New-Object System.Windows.Forms.Button
    $okButton.Text = 'OK'
    $okButton.DialogResult =
        [System.Windows.Forms.DialogResult]::OK

    $cancelButton = New-Object System.Windows.Forms.Button
    $cancelButton.Text = 'Cancel'
    $cancelButton.DialogResult =
        [System.Windows.Forms.DialogResult]::Cancel

    $endButtons.Controls.Add($okButton)
    $endButtons.Controls.Add($cancelButton)

    $endButtons.Anchor =
        [System.Windows.Forms.AnchorStyles]::None

    return [PsCustomObject]@{
        FlowPanel = $endButtons
        OkButton = $okButton
        CancelButton = $cancelButton
    }
}

<#
    .NOTE
    Needs to be an 'Add-' cmdlet. Adds multiple controls other than the operative
    control, to a target container. 'Add-' rather than 'New-' helps encapsulate
    inoperative controls.
#>
function Add-ControlsOkCancelButtons {
    Param(
        [PsCustomObject]
        $Layouts,

        [PsCustomObject]
        $Preferences = $script:DEFAULT_PREFERENCES
    )

    $endButtons = New-ControlsOkCancelButtons `
        -Preferences $Preferences

    $Layouts = Add-ControlToMultilayout `
        -Layouts $Layouts `
        -Control $endButtons.FlowPanel `
        -Preferences $Preferences

    return [PsCustomObject]@{
        OkButton = $endButtons.OkButton
        CancelButton = $endButtons.CancelButton
    }
}

function Open-ControlsFileDialog {
    Param(
        [String]
        $Caption = 'Browse Files',

        [String]
        $Filter = 'All Files (*.*)|*.*',

        [String]
        $InitialDirectory,

        [Switch]
        $Directory,

        [Switch]
        $Multiselect
    )

    $openFile = New-Object System.Windows.Forms.OpenFileDialog
    $openFile.Caption = $Caption
    $openFile.Filter = $Filter
    $openFile.FilterIndex = 1
    $openFile.Multiselect = $Multiselect

    if ($Directory) {
        $openFile.ValidateNames = $false
        $openFile.CheckFileExists = $false
        $openFile.CheckPathExists = $false
        $openFile.FileName = 'Folder Selection.'
    }

    $openFile.InitialDirectory = if ($InitialDirectory) {
        $InitialDirectory
    } else {
        (Get-Location).Path
    }

    if ($openFile.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        if ($Directory) {
            return [System.IO.Path]::GetDirectoryName($openFile.FileName)
        }

        if ($Multiselect) {
            return $openFile.FileNames
        }

        return $openFile.FileName
    }
}

function Open-ControlsMonthCalendar {
    Param(
        [PsCustomObject]
        $Preferences = $script:DEFAULT_PREFERENCES
    )

    $form = New-ControlsMain `
        -Preferences $Preferences

    $layout = New-ControlsLayout `
        -Preferences $Preferences

    $form.KeyPreview = $true
    $layout.Dock = [System.Windows.Forms.DockStyle]::Fill

    $calendar = New-Object System.Windows.Forms.MonthCalendar
    $calendar.Dock = [System.Windows.Forms.DockStyle]::Fill
    $calendar.MaxSelectionCount = 1
    $calendar.Left = ($Preferences.Width - $calendar.Width) / 2
    $calendar.Anchor =
        [System.Windows.Forms.AnchorStyles]::None

    $textBox = New-Object System.Windows.Forms.TextBox
    $textBox.Left = ($Preferences.Width - $textBox.Width) / 2
    $textBox.Anchor =
        [System.Windows.Forms.AnchorStyles]::Top + `
        [System.Windows.Forms.AnchorStyles]::Left + `
        [System.Windows.Forms.AnchorStyles]::Right

    Set-ControlsWritableText `
        -Control $textBox `
        -Text $Preferences.DateFormat

    $label = New-Object System.Windows.Forms.Label
    $label.Text = 'Format:'

    $script:endButtons = New-ControlsOkCancelButtons `
        -Preferences $Preferenes

    $layout.Controls.Add($calendar)
    $layout.Controls.Add($label)
    $layout.Controls.Add($textBox)
    $layout.Controls.Add($script:endButtons.FlowPanel)
    $form.Controls.Add($layout)

    $form.add_KeyDown({
        if ($_.KeyCode -eq 'Enter') {
            $script:endButtons.OkButton.PerformClick()
        }

        $_.Handled = $true
        $_.SuppressKeyPress = $true
    })

    $form.add_KeyDown({
        if ($_.KeyCode -eq 'Escape') {
            $script:endButtons.CancelButton.PerformClick()
        }

        $_.Handled = $true
        $_.SuppressKeyPress = $true
    })

    switch ($form.ShowDialog()) {
        'Cancel' {
            return
        }
    }

    $date = if ($null -eq $textBox.Text) {
        $calendar.SelectionRange.Start.ToString()
    } else {
        $calendar.SelectionRange.Start.ToString($textBox.Text)
    }

    return $date
}

