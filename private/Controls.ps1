
. $PsScriptRoot\Other.ps1

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

function Set-ControlsCenterScreen {
    Param(
        [System.Windows.Forms.Control]
        $Control
    )

    $screen = [System.Windows.Forms.Screen]::FromControl($Control)
    $workingArea = $screen.WorkingArea

    # $Control.Location.X = `
    $Control.Left = `
        [Math]::Max( `
            $workingArea.X, `
            $workingArea.X + ($workingArea.Width - $Control.Width) / 2
        )

    # $Control.Location.Y = `
    $Control.Top = `
        [Math]::Max( `
            $workingArea.Y, `
            $workingArea.Y + ($workingArea.Height - $Control.Height) / 2
        )
}

function New-ControlsLayout {
    Param(
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
    $multilayout.FlowDirection = `
        [System.Windows.Forms.FlowDirection]::LeftToRight

    $layout = New-ControlsLayout `
        -Preferences $Preferences

    $multilayout.Controls.Add($layout)

    return [PsCustomObject]@{
        Multilayout = $multilayout;
        Sublayouts = @($layout);
        Controls = @{};
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
        $layout = New-ControlsLayout `
            -Preferences $Preferences

        $Layouts.Multilayout.Controls.Add($layout)
        $Layouts.Sublayouts += @($layout)
        $final = $Layouts.Sublayouts[-1]
    }

    $Control | % {
        $final.Controls.Add($_)
    }

    return $Layouts
}

function New-ControlsMain {
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
    $form.KeyPreview = $true
    $form.AutoSizeMode = `
        [System.Windows.Forms.AutoSizeMode]::GrowAndShrink
    $form.FormBorderStyle = `
        [System.Windows.Forms.FormBorderStyle]::FixedSingle
    $form.StartPosition = `
        [System.Windows.Forms.FormStartPosition]::CenterScreen
    $form.add_Shown({
        [void] $this.Focus();
    })

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

<#
    .NOTE
        Needs to be an 'Add-' cmdlet. Adds multiple controls other than the
        operative control, to a target container. 'Add-' rather than 'New-' helps
        encapsulate inoperative controls.
#>
function Add-ControlsFieldBox {
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

<#
    .NOTE
        Needs to be an 'Add-' cmdlet. Adds multiple controls other than the
        operative control, to a target container. 'Add-' rather than 'New-' helps
        encapsulate inoperative controls.
#>
function Add-ControlsSlider {
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
    else {
        $slider.Text = ''
    }

    $flowPanel.Controls.Add($label)
    $flowPanel.Controls.Add($slider)

    $Layouts = Add-ControlToMultilayout `
        -Layouts $Layouts `
        -Control $flowPanel `
        -Preferences $Preferences

    return $slider
}

<#
    .NOTE
        Needs to be an 'Add-' cmdlet. Adds multiple controls other than the
        operative control, to a target container. 'Add-' rather than 'New-' helps
        encapsulate inoperative controls.
#>
function Add-ControlsRadioBox {
    Param(
        [PsCustomObject]
        $Layouts,

        [String]
        $Text,

        $Default,

        [PsCustomObject[]]
        $Symbols,

        [Switch]
        $Mandatory,

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

    if (-not $Mandatory) {
        $Symbols += @([PsCustomObject]@{ Name = 'None'; })
    }

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

<#
    .NOTE
        Needs to be an 'Add-' cmdlet. Adds multiple controls other than the
        operative control, to a target container. 'Add-' rather than 'New-' helps
        encapsulate inoperative controls.
#>
function Add-ControlsOkCancelButtons {
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

