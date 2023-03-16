#Requires -Assembly PresentationFramework

. $PsScriptRoot\Other.ps1
. $PsScriptRoot\NumberSlider.ps1

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
            Width = 300
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

$script:__RADIOBUTTON_HEIGHT__ = 15
$script:__LABEL_HEIGHT__ = 30

function New-Closure {
    Param(
        [ScriptBlock]
        $ScriptBlock,

        $InputObject
    )

    return & {
        Param($InputObject)
        return $ScriptBlock.GetNewClosure()
    } $InputObject
}

function Add-ControlsTypes {
    Add-Type -AssemblyName PresentationFramework
}

function Show-ControlRectangle {
    Param(
        [System.Windows.Controls.Control]
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
        [System.Windows.Controls.Control]
        $Control,

        [String]
        $Text
    )

    $Control.Text = $Text
    $Control.Select($Control.Text.Length, 0)
}

function Set-ControlsStatus {
    Param(
        [System.Windows.Controls.Control]
        $StatusLine,

        [String]
        $LineName
    )

    $status = $script:STATUS | where Name -eq $LineName

    $text = $status | Get-PropertyOrDefault `
        -Name Text `
        -Default 'ToolTip missing!'

    $foreColor = $status | Get-PropertyOrDefault `
        -Name Foreground `
        -Default 'Black'

    $StatusLine.Content = $text
    $StatusLine.Foreground = $foreColor
}

function New-ControlsLayout {
    Param(
        [PsCustomObject]
        $Preferences = $script:DEFAULT_PREFERENCES
    )

    $layout = New-Object System.Windows.Controls.StackPanel
    $layout.Width = $Preferences.Width
    return $layout
}

function New-ControlsMultilayout {
    Param(
        [PsCustomObject]
        $Preferences = $script:DEFAULT_PREFERENCES
    )

    $multilayout = New-Object System.Windows.Controls.StackPanel
    $multilayout.MaxWidth = [Double]::PositiveInfinity
    $multilayout.Orientation = 'Horizontal'
    $multilayout.Margin = $Preferences.Margin

    # link: https://stackoverflow.com/questions/1927540/how-to-get-the-size-of-the-current-screen-in-wpf
    # retrieved: 2022_08_28
    $maxHeight =
        [System.Windows.SystemParameters]::WorkArea.Height - 200

    $layouts = [PsCustomObject]@{
        Multilayout = $multilayout
        Sublayouts = @()
        Controls = @{}
        MaxHeight = $maxHeight
        CurrentHeight = 0
    }

    return Add-ControlToMultiLayout `
        -Layouts $layouts `
        -Preferences $Preferences
}

function Add-ControlsFormKeyBindings {
    Param(
        [System.Windows.Controls.Control]
        $Control,

        [PsCustomObject]
        $Layouts,

        [PsCustomObject]
        $Preferences
    )

    $script:layouts = $Layouts

    # TODO
    if ($Preferences.EnterToConfirm) {
        $Control.add_KeyDown({
            if ($_.Key -eq 'Enter') {
                $script:layouts.Controls[
                '__EndButtons__'
                ].OkButton.PerformClick()
            }
        })
    }

    # TODO
    if ($Preferences.EscapeToCancel) {
        $Control.add_KeyDown({
            if ($_.Key -eq 'Escape') {
                $script:layouts.Controls[
                '__EndButtons__'
                ].CancelButton.PerformClick()
            }
        })
    }

    $Control.add_KeyDown({
        if ($_.Key -eq [System.Windows.Input.Key]::OemQuestion `
            -and $_.Control)
        {
            $message = (Get-Content `
                -Path $script:TEXT_PATH `
                | ConvertFrom-Json).Help

            $message = $message -join "`r`n"
            $caption = 'Help'
            [System.Windows.MessageBox]::Show($message, $caption)
        }
    })
}

function Add-ControlToMultilayout {
    Param(
        [PsCustomObject]
        $Layouts,

        $Control,

        [PsCustomObject]
        $Preferences
    )

    $nextHeight = if ($null -ne $Control) {
        # link: https://stackoverflow.com/questions/3401636/measuring-controls-created-at-runtime-in-wpf
        # retrieved: 2022_08_28
        $Control.Measure([System.Windows.Size]::new(
            [Double]::PositiveInfinity,
            [Double]::PositiveInfinity
        ))

        $Control.Height = $Control.DesiredSize.Height
        $Control.Margin = $Preferences.Margin

        $Layouts.CurrentHeight `
            + $Control.DesiredSize.Height `
            + (2 * $Preferences.Margin)
    }

    $needNewSublayout =
        $null -eq $Control `
        -or $Layouts.Multilayout.Children.Count -eq 0 `
        -or $nextHeight -gt $Preferences.Height `
        -or $nextHeight -gt $Layouts.MaxHeight

    if ($needNewSublayout) {
        $layout = New-ControlsLayout `
            -Preferences $Preferences

        $Layouts.Multilayout.AddChild($layout)
        $Layouts.Sublayouts += @($layout)
        $Layouts.CurrentHeight = 0
    }

    if ($null -ne $Control) {
        $Layouts.Sublayouts[-1].AddChild($Control)
        $Layouts.CurrentHeight += $Control.Height + (2 * $Control.Margin.Top)
    }

    return $Layouts
}

<#
    .LINK
    Link: https://wpf.2000things.com/2014/11/05/1195-making-a-window-partially-transparent/
    Link: https://wpf.2000things.com/2011/02/05/208-color-values-are-stored-as-rgb-values/
    Retrieved: 2022_09_14
#>
function Set-ControlsStyleTransparent {
    Param(
        $Window
    )

    $Window.AllowsTransparency = $true
    $Window.WindowStyle = [System.Windows.WindowStyle]::None
    $Window.Background = '#D5F0F0FF'
}

function New-ControlsMain {
    Param(
        [PsCustomObject]
        $Preferences = $script:DEFAULT_PREFERENCES
    )

    $form = New-Object System.Windows.Window
    $form.Title = $Preferences.Caption
    $form.SizeToContent = 'WidthAndHeight'
    $form.WindowStartupLocation = 'CenterScreen'

<#
    # TODO: temp, remove
    Set-ControlsStyleTransparent `
        -Window $form
#>

    $form.Add_ContentRendered({
        $this.Activate()
    })

    $grid = New-Object System.Windows.Controls.StackPanel
    $form.AddChild($grid)

    return [PsCustomObject]@{
        Window = $form
        Grid = $grid
    }
}

function New-Control {
    Param(
        [Parameter(Position = 0)]
        [String]
        $Type
    )

    $control = New-Object "System.Windows.Controls.$Type"
    return $control
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

    $checkBox = New-Control CheckBox
    $checkBox.Content = $Text

    if ($null -ne $Default) {
        $checkBox.IsChecked = $Default
    }

    $Layouts = Add-ControlToMultilayout `
        -Layouts $Layouts `
        -Control $checkBox `
        -Preferences $Preferences

    return $checkBox
}

function Get-ControlsAsterized {
    Param(
        $Control
    )

    $asterisk = New-Object System.Windows.Controls.Label
    $asterisk.Content = '*'
    $asterisk.FontSize = $asterisk.FontSize + 5
    $asterisk.Foreground = 'DarkRed'
    $asterisk.VerticalContentAlignment = 'Center'
    $asterisk.HorizontalContentAlignment = 'Center'
    $row = New-Object System.Windows.Controls.DockPanel
    $row.Margin = $Control.Margin
    $Control.Margin = 0
    $row.AddChild($asterisk)
    $row.AddChild($Control)
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

    $textBox = New-Object System.Windows.Controls.TextBox
    $textBox.Width = $Preferences.Width
    $textBox.Margin = $Preferences.Margin

    if ($null -ne $MaxLength) {
        $textBox.MaxLength = $MaxLength
    }

    Set-ControlsWritableText `
        -Control $textBox `
        -Text $Text

    $main = New-ControlsMain `
        -Preferences $Preferences

    $main.Window.Title = $Caption
    $main.Grid.AddChild($textBox)

    $main.Window.add_KeyDown({
        if ($_.Key -eq 'Enter') {
            $this.DialogResult = $true
            $this.Close()
        }
    })

    $main.Window.add_KeyDown({
        if ($_.Key -eq 'Escape') {
            $this.DialogResult = $false
            $this.Close()
        }
    })

    $main.Window.Add_ContentRendered(( `
        New-Closure `
            -InputObject $textBox `
            -ScriptBlock {
                $InputObject.Focus()
        } `
    ))

    if (-not $main.Window.ShowDialog()) {
        return
    }

    return $textBox.Text
}

function Add-ControlsTable {
    Param(
        [PsCustomObject]
        $Layouts,

        [String]
        $Text,

        [PsCustomObject[]]
        $Rows,

        [Switch]
        $Mandatory,

        [PsCustomObject]
        $Preferences = $script:DEFAULT_PREFERENCES
    )

    $tableControl = New-ControlsTable `
        -Preferences $Preferences `
        -Text $Text `
        -Rows $Rows `
        -Asterized:$Mandatory

    $Layouts = Add-ControlToMultilayout `
        -Layouts $Layouts `
        -Control $tableControl.GroupBox `
        -Preferences $Preferences

    return $tableControl.ListView
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

    $outerPanel = New-Object System.Windows.Controls.StackPanel
    $mainPanel = New-Object System.Windows.Controls.DockPanel
    $buttonPanel = New-Object System.Windows.Controls.StackPanel

    $label = New-Control Label
    $label.Content = $Text

    $asterism = if ($Mandatory) {
        Get-ControlsAsterized `
            -Control $label
    } else {
        $label
    }

    $buttonNames = @(
        'New', 'Edit', 'Delete', 'Move Up', 'Move Down', 'Sort'
    )

    $buttonTable = @{}
    $actionTable = @{}

    foreach ($name in $buttonNames) {
        $button = New-Object System.Windows.Controls.Button
        $button.Content = $name
        $buttonPanel.AddChild($button)
        $buttonTable.Add($name, $button)
    }

    $listBox = New-Object System.Windows.Controls.ListBox
    $listBox.Height = 200
    $listBox.SelectionMode = 'Multiple'

    $parameters = [PsCustomObject]@{
        ListBox = $listBox
        MaxCount = $MaxCount
        MaxLength = $MaxLength
        Layouts = $layouts
        Preferences = $Preferences
    }

    $actionTable['New'] = New-Closure `
        -InputObject $parameters `
        -ScriptBlock {
            $listBox = $InputObject.ListBox
            $maxCount = $InputObject.MaxCount
            $maxLength = $InputObject.MaxLength
            $layouts = $InputObject.Layouts
            $prefs = $InputObject.Preferences
            $index = $listBox.SelectedIndex

            . $PsScriptRoot\Controls.ps1

            if ($null -ne $maxCount `
                -and $listBox.Items.Count -eq $maxCount)
            {
                Set-ControlsStatus `
                    -StatusLine $layouts.StatusLine `
                    -LineName 'MaxCountReached'

                return
            }

            if ($index -ge 0) {
                $listBox.Items.Insert($index, '')
            }
            else {
                $listBox.Items.Add('')
                $index = $listBox.Items.Count - 1
            }

            $listBox.Items[$index] =
                Get-ControlsTextDialog `
                    -Preferences $prefs `
                    -Text $listBox.Items[$index] `
                    -Caption 'Edit ListBox Item' `
                    -MaxLength $maxLength
        }

    $parameters = [PsCustomObject]@{
        ListBox = $listBox
        MaxLength = $MaxLength
        Preferences = $Preferences
    }

    $actionTable['Edit'] = New-Closure `
        -InputObject $parameters `
        -ScriptBlock {
            $listBox = $InputObject.ListBox
            $prefs = $InputObject.Preferences
            $maxLength = $InputObject.MaxLength
            $index = $listBox.SelectedIndex

            if ($index -lt 0) {
                return
            }

            . $PsScriptRoot\Controls.ps1

            $listBox.Items[$index] =
                Get-ControlsTextDialog `
                    -Preferences $prefs `
                    -Text $listBox.Items[$index] `
                    -Caption 'Edit ListBox Item' `
                    -MaxLength $maxLength
        }

    $actionTable['Delete'] = New-Closure `
        -InputObject $listBox `
        -ScriptBlock {
            $listBox = $InputObject
            $index = $listBox.SelectedIndex

            if ($index -lt 0) {
                return
            }

            $listBox.Items.RemoveAt($index)

            if ($listBox.Items.Count -eq 0) {
                return
            }

            $index = if ($index -eq 0) {
                0
            } else {
                $index - 1
            }

            $listBox.SelectedItems.Add(
                $listBox.Items.GetItemAt($index)
            )
        }

    $actionTable['Move Up'] = New-Closure `
        -InputObject $listBox `
        -ScriptBlock {
            $listBox = $InputObject
            $index = $listBox.SelectedIndex

            $immovable = $listBox.Items.Count -le 1 `
                -or $index -le 0

            if ($immovable) {
                return
            }

            $items = $listBox.Items
            $temp = $items[$index - 1]
            $items[$index - 1] = $items[$index]
            $items[$index] = $temp

            $listBox.SelectedItems.Remove(
                $listBox.Items.GetItemAt($index)
            )

            $listBox.SelectedItems.Add(
                $listBox.Items.GetItemAt($index - 1)
            )
        }

    $actionTable['Move Down'] = New-Closure `
        -InputObject $listBox `
        -ScriptBlock {
            $listBox = $InputObject
            $index = $listBox.SelectedIndex

            $immovable = $listBox.Items.Count -le 1 `
                -or $index -lt 0 `
                -or $index -eq $listBox.Items.Count - 1

            if ($immovable) {
                return
            }

            $items = $listBox.Items
            $temp = $items[$index + 1]
            $items[$index + 1] = $items[$index]
            $items[$index] = $temp

            $listBox.SelectedItems.Remove(
                $listBox.Items.GetItemAt($index)
            )

            $listBox.SelectedItems.Add(
                $listBox.Items.GetItemAt($index + 1)
            )
        }

    $actionTable['Sort'] = New-Closure `
        -InputObject $listBox `
        -ScriptBlock {
            $listBox = $InputObject

            $items = $listBox.Items | sort | foreach {
                [String]::new($_)
            }

            $listBox.Items.Clear()

            foreach ($item in $items) {
                $listBox.Items.Add($item)
            }
        }

    foreach ($name in $buttonNames) {
        $button = $buttonTable[$name]
        $action = $actionTable[$name]
        $button.add_Click($action)

        $action = New-Closure `
            -InputObject $action `
            -ScriptBlock {
                if ($_.Key -eq 'Space') {
                    & $InputObject
                }
            }

        $button.add_KeyDown($action)
    }

    $newAction = $actionTable['New']
    $editAction = $actionTable['Edit']
    $deleteAction = $actionTable['Delete']

    $parameters = [PsCustomObject]@{
        ListBox = $listBox
        Layouts = $layouts
        NewAction = $newAction
        EditAction = $editAction
        DeleteAction = $deleteAction
    }

    $keyDown = New-Closure `
        -InputObject $parameters `
        -ScriptBlock {
            $listBox = $InputObject.ListBox
            $layouts = $InputObject.Layouts
            $newAction = $InputObject.NewAction
            $editAction = $InputObject.EditAction
            $deleteAction = $InputObject.DeleteAction
            $myEventArgs = $_

            $isKeyComb = [System.Windows.Input.Keyboard]::Modifiers `
                -and [System.Windows.Input.ModifierKeys]::Alt

            if ($isKeyComb) {
                if ([System.Windows.Input.Keyboard]::IsKeyDown('C')) {
                    $index = $listBox.SelectedIndex

                    if ($index -lt 0) {
                        return
                    }

                    Set-Clipboard `
                        -Value $listBox.Items[$index]

                    . $PsScriptRoot\Controls.ps1

                    Set-ControlsStatus `
                        -StatusLine $layouts.StatusLine `
                        -LineName 'TextClipped'
                }

                if ([System.Windows.Input.Keyboard]::IsKeyDown('N')) {
                    & $newAction
                    return
                }

                if ([System.Windows.Input.Keyboard]::IsKeyDown('Space')) {
                    $index = $listBox.SelectedIndex

                    if ($index -lt 0) {
                        return
                    }

                    $listBox.UnselectAll()

                    # # TODO: Remove once new solution is verified
                    # $myEventArgs.Handled = $true
                }
            }

            if ($myEventArgs.Key -eq 'F2') {
                & $editAction
                return
            }

            if ($myEventArgs.Key -eq 'Delete') {
                & $deleteAction
                return
            }
        }

    $listBox.add_PreViewKeyDown($keyDown)

    $listBox.add_GotFocus((New-Closure `
        -InputObject $layouts.StatusLine `
        -ScriptBlock {
            . $PsScriptRoot\Controls.ps1

            Set-ControlsStatus `
                -StatusLine $InputObject `
                -LineName 'InListBox'
        } `
    ))

    $listBox.add_LostFocus((New-Closure `
        -InputObject $layouts.StatusLine `
        -ScriptBlock {
            . $PsScriptRoot\Controls.ps1

            Set-ControlsStatus `
                -StatusLine $InputObject `
                -LineName 'Idle'
        } `
    ))

    foreach ($item in $Default) {
        $listBox.Items.Add($item)
    }

    $mainPanel.AddChild($buttonPanel)
    $mainPanel.AddChild($listBox)
    $outerPanel.AddChild($asterism)
    $outerPanel.AddChild($mainPanel)

    $Layouts = Add-ControlToMultilayout `
        -Layouts $Layouts `
        -Control $outerPanel `
        -Preferences $Preferences

    return $listBox
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

    $stackPanel = New-Object System.Windows.Controls.StackPanel
    $label = New-Control Label
    $label.Content = $Text
    $textBox = New-Control TextBox

    $row2 = if ($Mandatory) {
        Get-ControlsAsterized `
            -Control $textBox
    } else {
        $textBox
    }

    $monthCalendarPrefs = $Preferences.PsObject.Copy()
    $monthCalendarPrefs.Caption = 'Get Date'
    $monthCalendarPrefs.Width = 350

    $keyDown = New-Closure `
        -InputObject $monthCalendarPrefs `
        -ScriptBlock {
            $monthCalendarPrefs = $InputObject
            $myEventArgs = $_

            $isKeyComb = [System.Windows.Input.Keyboard]::Modifiers `
                -and [System.Windows.Input.ModifierKeys]::Control

            if ($isKeyComb) {
                if ([System.Windows.Input.Keyboard]::IsKeyDown('O')) {
                    . $PsScriptRoot\Controls.ps1

                    Set-ControlsWritableText `
                        -Control $this `
                        -Text ($this.Text + (Open-ControlsFileDialog -Directory))

                    $myEventArgs.Handled = $true
                }

                if ([System.Windows.Input.Keyboard]::IsKeyDown('D')) {
                    . $PsScriptRoot\Controls.ps1

                    $text = Open-ControlsMonthCalendar `
                        -Preferences $monthCalendarPrefs

                    Set-ControlsWritableText `
                        -Control $this `
                        -Text ($this.Text + $text)

                    $myEventArgs.Handled = $true
                }
            }
        }

    $textBox.add_PreViewKeyDown($keyDown)

    if ($null -ne $MaxLength) {
        $textBox.MaxLength = $MaxLength
    }

    if ($null -ne $Default) {
        Set-ControlsWritableText `
            -Control $textBox `
            -Text $Default
    }

    $stackPanel.AddChild($label)
    $stackPanel.AddChild($row2)

    $Layouts = Add-ControlToMultilayout `
        -Layouts $Layouts `
        -Control $stackPanel `
        -Preferences $Preferences

    return $textBox
}

function New-ControlsSlider {
    Param(
        [Int]
        $InitialValue,

        [Int]
        $Minimum,

        [Int]
        $Maximum
    )

    return [NumberSlider]::new($InitialValue, $Minimum, $Maximum, 1)
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

    $dockPanel = New-Object System.Windows.Controls.StackPanel
    $label = New-Control Label
    $label.Content = $Text

    $slider = New-ControlsSlider `
        -InitialValue:$Default `
        -Minimum:$Minimum `
        -Maximum:$Maximum

    $row2 = if ($Mandatory) {
        Get-ControlsAsterized `
            -Control $slider
    } else {
        $slider
    }

    if ($null -ne $Minimum -or $null -ne $Maximum) {
        $closure = New-Closure `
            -InputObject $Layouts.StatusLine `
            -ScriptBlock {
                . $PsScriptRoot\Controls.ps1

                Set-ControlsStatus `
                    -StatusLine $InputObject `
                    -LineName 'Idle'
            }

        $slider.OnIdle += @($closure)
    }

    if ($null -ne $Minimum) {
        $closure = New-Closure `
            -InputObject $Layouts.StatusLine `
            -ScriptBlock {
                . $PsScriptRoot\Controls.ps1

                Set-ControlsStatus `
                    -StatusLine $InputObject `
                    -LineName 'MinReached'
            }

        $slider.OnMinReached += @($closure)
    }

    if ($null -ne $Maximum) {
        $closure = New-Closure `
            -InputObject $Layouts.StatusLine `
            -ScriptBlock {
                . $PsScriptRoot\Controls.ps1

                Set-ControlsStatus `
                    -StatusLine $InputObject `
                    -LineName 'MaxReached'
            }

        $slider.OnMaxReached += @($closure)
    }

    $dockPanel.AddChild($label)
    $dockPanel.AddChild($row2)

    $Layouts = Add-ControlToMultilayout `
        -Layouts $Layouts `
        -Control $dockPanel `
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

    $groupBox = New-Object System.Windows.Controls.GroupBox
    $groupBox.Header = $Text

    $stackPanel = New-Object System.Windows.Controls.StackPanel
    $groupBox.AddChild($stackPanel)

    if (-not $Mandatory -and @($Symbols | where {
        $_.Name -like 'None'
    }).Count -eq 0) {
        $Symbols += @([PsCustomObject]@{ Name = 'None'; })
    }

    $buttons = @{}
    $noneOptionSpecified = $false

    foreach ($symbol in $Symbols) {
        $button = New-Control RadioButton

        $button.Content = $symbol | Get-PropertyOrDefault `
            -Name Text `
            -Default $symbol.Name

        $noneOptionSpecified = $button.Content -like 'None'
        $buttons.Add($symbol.Name, $button)
        $stackPanel.AddChild($button)
    }

    $key = if ($noneOptionSpecified -or (-not $Mandatory)) {
        'None'
    } elseif ($null -ne $Default) {
        $Default
    } elseif ($Symbols.Count -gt 0) {
        $Symbols[0].Name
    } else {
        ''
    }

    if (-not [String]::IsNullOrEmpty($key)) {
        $buttons[$key].IsChecked = $true
    }

    $Layouts = Add-ControlToMultilayout `
        -Layouts $Layouts `
        -Control $groupBox `
        -Preferences $Preferences

    return $buttons
}

function New-ControlsTable {
    Param(
        [PsCustomObject]
        $Preferences = $script:DEFAULT_PREFERENCES,

        [String]
        $Text,

        [PsCustomObject[]]
        $Rows,

        [Switch]
        $Asterized
    )

    function Set-ColumnPreferredSize {
        Param(
            [System.Windows.Controls.GridView]
            $GridViewControl
        )

        foreach ($col in $GridViewControl.Columns) {
            if ([double]::IsNaN($col.Width)) {
                $col.Width = $col.ActualWidth
            }

            $col.Width = [double]::NaN
        }
    }

    $groupBox = New-Object System.Windows.Controls.GroupBox
    $groupBox.Header = $Text

    $stackPanel = New-Object System.Windows.Controls.StackPanel
    $groupBox.AddChild($stackPanel)

    $textBox = New-Object System.Windows.Controls.TextBox
    $textBox.Width = $Preferences.Width
    $textBox.Margin = $Preferences.Margin
    $stackPanel.AddChild($textBox)

    Set-ControlsWritableText `
        -Control $textBox

    $label = New-Object System.Windows.Controls.Label
    $label.Content = 'Find in table:'
    $stackPanel.AddChild($label)

    # karlr (2023_03_14)
    $grid = New-Object System.Windows.Controls.Grid

    $asterism = if ($Asterized) {
        Get-ControlsAsterized `
            -Control $grid
    } else {
        $grid
    }

    $grid.Margin = $Preferences.Margin
    $listView = New-Object System.Windows.Controls.ListView
    $listView.HorizontalAlignment = 'Stretch'
    $grid.AddChild($listView)
    $stackPanel.AddChild($asterism)

    if ($Rows.Count -gt 0) {
        $header = $Rows[0]
        $gridView = New-Object System.Windows.Controls.GridView

        foreach ($property in $header.PsObject.Properties) {
            $column = New-Object System.Windows.Controls.GridViewColumn
            $column.Header = $property.Name
            $column.DisplayMemberBinding =
                [System.Windows.Data.Binding]::new($property.Name)
            $gridView.Columns.Add($column)
        }

        $listView.View = $gridView

        foreach ($row in $Rows) {
            [void]$listView.Items.Add($row)
        }
    }

    $stackPanel.add_Loaded(( `
        New-Closure `
            -InputObject ( `
                [PsCustomObject]@{
                    GridView = $gridView
                    Resize =
                        (Get-Command Set-ColumnPreferredSize).ScriptBlock
                } `
            ) `
            -ScriptBlock {
                & $InputObject.Resize $InputObject.GridView
            } `
    ))

    $textBox.add_TextChanged(( `
        New-Closure `
            -InputObject ( `
                [PsCustomObject]@{
                    TextBox = $textBox
                    ListView = $listView
                    GridView = $gridView
                    Rows = $Rows
                }
            ) `
            -ScriptBlock {
                $InputObject.ListView.Items.Clear()
                $text = $InputObject.TextBox.Text

                $items = if ([String]::IsNullOrEmpty($text)) {
                    $InputObject.Rows
                } else {
                    $InputObject.Rows | where {
                        $_.PsObject.Properties.Value -like "*$text*"
                    }
                }

                foreach ($item in $items) {
                    [void]$InputObject.ListView.Items.Add($item)
                }
            }
    ))

    return [PsCustomObject]@{
        GroupBox = $groupBox
        ListView = $listView
    }
}

function New-ControlsOkCancelButtons {
    Param(
        [PsCustomObject]
        $Preferences = $script:DEFAULT_PREFERENCES
    )

    $endButtons = New-Object System.Windows.Controls.WrapPanel

    $okButton = New-Control Button
    $okButton.Width = 50
    $okButton.Margin = $Preferences.Margin
    $okButton.Content = 'OK'

    $cancelButton = New-Control Button
    $cancelButton.Width = 50
    $cancelButton.Margin = $Preferences.Margin
    $cancelButton.Content = 'Cancel'

    $endButtons.AddChild($okButton)
    $endButtons.AddChild($cancelButton)

    $endButtons.HorizontalAlignment = 'Center'

    return [PsCustomObject]@{
        Panel = $endButtons
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
        -Control $endButtons.Panel `
        -Preferences $Preferences

    return [PsCustomObject]@{
        OkButton = $endButtons.OkButton
        CancelButton = $endButtons.CancelButton
    }
}

function Open-ControlsTable {
    Param(
        [PsCustomObject]
        $Preferences = $script:DEFAULT_PREFERENCES,

        [String]
        $Text,

        [PsCustomObject[]]
        $Rows
    )

    $main = New-ControlsMain `
        -Preferences $Preferences

    $tableControl = New-ControlsTable `
        -Preferences $Preferences `
        -Text $Text `
        -Rows $Rows

    $endButtons = New-ControlsOkCancelButtons `
        -Preferences $Preferences

    $okAction = New-Closure `
        -InputObject $main.Window `
        -ScriptBlock {
            $InputObject.DialogResult = $true
            $InputObject.Close()
        }

    $cancelAction = New-Closure `
        -InputObject $main.Window `
        -ScriptBlock {
            $InputObject.DialogResult = $false
            $InputObject.Close()
        }

    $endButtons.OkButton.Add_Click($okAction)
    $endButtons.CancelButton.Add_Click($cancelAction)

    $main.Grid.AddChild($tableControl.GroupBox)
    $main.Grid.AddChild($endButtons.Panel)

    $parameters = [PsCustomObject]@{
        OkAction = $okAction
        CancelAction = $cancelAction
    }

    $main.Window.add_PreViewKeyDown(( `
        New-Closure `
            -InputObject $parameters `
            -ScriptBlock {
                if ($_.Key -eq 'Enter') {
                    & $InputObject.OkAction
                    $_.Handled = $true
                    return
                }

                if ($_.Key -eq 'Escape') {
                    & $InputObject.CancelAction
                    $_.Handled = $true
                    return
                }
            } `
    ))

    if (-not $main.Window.ShowDialog()) {
        return
    }

    return $tableControl.ListView.SelectedItems
}

function Open-ControlsFileDialog {
    Param(
        [String]
        $Caption = 'Browse Files',

        [String]
        $Filter = 'All Files (*.*)|*.*|All|*',

        [String]
        $InitialDirectory,

        [Switch]
        $Directory,

        [Switch]
        $Multiselect
    )

    Add-Type -AssemblyName System.Windows.Forms

    $openFile = New-Object System.Windows.Forms.OpenFileDialog
    $openFile.Title = $Caption
    $openFile.Filter = $Filter
    $openFile.FilterIndex = 1
    $openFile.MultiSelect = $Multiselect

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

    $main = New-ControlsMain `
        -Preferences $Preferences

    $calendar = New-Object System.Windows.Controls.Calendar
    $calendar.DisplayMode = 'Month'
    $textBox = New-Object System.Windows.Controls.TextBox
    $textBox.Width = $Preferences.Width
    $textBox.Margin = $Preferences.Margin

    Set-ControlsWritableText `
        -Control $textBox `
        -Text $Preferences.DateFormat

    $label = New-Object System.Windows.Controls.Label
    $label.Content = 'Format:'

    $endButtons = New-ControlsOkCancelButtons `
        -Preferences $Preferences

    $okAction = New-Closure `
        -InputObject $main.Window `
        -ScriptBlock {
            $InputObject.DialogResult = $true
            $InputObject.Close()
        }

    $cancelAction = New-Closure `
        -InputObject $main.Window `
        -ScriptBlock {
            $InputObject.DialogResult = $false
            $InputObject.Close()
        }

    $endButtons.OkButton.Add_Click($okAction)
    $endButtons.CancelButton.Add_Click($cancelAction)
    $main.Grid.AddChild($calendar)
    $main.Grid.AddChild($label)
    $main.Grid.AddChild($textBox)
    $main.Grid.AddChild($endButtons.Panel)

    $parameters = [PsCustomObject]@{
        OkAction = $okAction
        CancelAction = $cancelAction
    }

    $main.Window.add_PreViewKeyDown(( `
        New-Closure `
            -InputObject $parameters `
            -ScriptBlock {
                if ($_.Key -eq 'Enter') {
                    & $InputObject.OkAction
                    $_.Handled = $true
                    return
                }

                if ($_.Key -eq 'Escape') {
                    & $InputObject.CancelAction
                    $_.Handled = $true
                    return
                }
            } `
    ))

    if (-not $main.Window.ShowDialog()) {
        return
    }

    $dates = $calendar.SelectedDates

    if ($dates.Count -eq 0) {
        if ($null -eq $textBox.Text) {
            return Get-Date
        }

        return Get-Date -Format $textBox.Text
    }

    $item = $dates[0]

    $date = if ($null -eq $textBox.Text) {
        $item.ToString()
    } else {
        $item.ToString($textBox.Text)
    }

    return $date
}

