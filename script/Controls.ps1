#Requires -Assembly PresentationFramework

. $PsScriptRoot\Other.ps1
. $PsScriptRoot\NumberSlider.ps1

<#
.LINK
Issue: Event handler fails to update variable from outer scope
Url: https://stackoverflow.com/questions/55403528/why-wont-variable-update
Retreived: 2022_03_02
#>
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
    Url: https://stackoverflow.com/questions/34552311/wpf-systemparameters-windowcaptionbuttonheight-returns-smaller-number-than-expe
    Url: https://stackoverflow.com/users/3137337/emoacht
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
    Url: https://stackoverflow.com/questions/20423211/setting-cursor-at-the-end-of-any-text-of-a-textbox
    Url: https://stackoverflow.com/users/1042848/vishal-suthar
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

    $status = ( `
        Get-Content "$PsScriptRoot/../res/text.json" `
            | ConvertFrom-Json `
    ).Status `
        | where Name -eq $LineName

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
        $Preferences
    )

    $layout = New-Control StackPanel
    $layout.Width = $Preferences.Width

    $layout.Add_Loaded({
        if ([double]::IsNaN($this.Width)) {
            $this.Width = $this.ActualWidth
        }

        $this.Width = [double]::NaN
    })

    return $layout
}

function New-ControlsMultilayout {
    Param(
        [PsCustomObject]
        $Preferences
    )

    $multilayout = New-Control StackPanel
    $multilayout.MaxWidth = [Double]::PositiveInfinity
    $multilayout.Orientation = 'Horizontal'
    $multilayout.Margin = $Preferences.Margin

    # link
    # - url: https://stackoverflow.com/questions/1927540/how-to-get-the-size-of-the-current-screen-in-wpf
    # - retrieved: 2022_08_28
    $maxHeight =
        [System.Windows.SystemParameters]::WorkArea.Height - 200

    $pageControl = [PsCustomObject]@{
        Multilayout = $multilayout
        Sublayouts = @()
        Controls = @{}
        MaxHeight = $maxHeight
        CurrentHeight = 0
    }

    return Add-ControlToMultiLayout `
        -PageControl $pageControl `
        -Preferences $Preferences
}

function Add-ControlsTabItem {
    Param(
        [System.Windows.Controls.TabControl]
        $TabControl,

        [System.Windows.FrameworkElement]
        $Control,

        [String]
        $Header
    )

    $tab = New-Control TabItem
    $tab.Header = $Header
    $tab.AddChild($Control)
    $TabControl.Items.Add($tab)
}

function New-ControlsTabLayout {
    Param(
        [System.Windows.FrameworkElement[]]
        $Control,

        [String[]]
        $Header
    )

    $tabs = New-Control TabControl
    $count = [Math]::Min($Control.Count, $Header.Count)
    $index = 0

    while ($index -lt $count) {
        Add-ControlsTabItem `
            -Control @($Control)[$index] `
            -Header @($Header)[$index]

        $index = $index + 1
    }

    return $tabs
}

function Add-ControlsFormKeyBindings {
    Param(
        [System.Windows.Controls.Control]
        $Control,

        [PsCustomObject]
        $PageControl,

        [PsCustomObject]
        $Preferences
    )

    if ($Preferences.EnterToConfirm) {
        $Control.Add_KeyDown(( `
            New-Closure `
                -InputObject `
                    $PageControl.Controls['__EndButtons__'].OkButton `
                -ScriptBlock {
                    if ($_.Key -eq 'Enter') {
                        $InputObject.PerformClick()
                    }
                } `
        ))
    }

    if ($Preferences.EscapeToCancel) {
        $Control.Add_KeyDown(( `
            New-Closure `
                -InputObject `
                    $PageControl.Controls['__EndButtons__'].CancelButton `
                -ScriptBlock {
                    if ($_.Key -eq 'Escape') {
                        $InputObject.PerformClick()
                    }
                } `
        ))
    }

    $helpMessage = ( `
        Get-Content `
            "$PsScriptRoot/../res/text.json" `
            | ConvertFrom-Json `
    ).Help

    $Control.Add_KeyDown(( `
        New-Closure `
            -InputObject $helpMessage `
            -ScriptBlock {
                if ($_.Key -eq [System.Windows.Input.Key]::OemQuestion `
                    -and $_.Control)
                {
                    $message = $InputObject -join "`r`n"
                    $caption = 'Help'
                    [System.Windows.MessageBox]::Show($message, $caption)
                }
            } `
    ))
}

function Add-ControlToMultilayout {
    Param(
        [PsCustomObject]
        $PageControl,

        $Control,

        [PsCustomObject]
        $Preferences
    )

    $nextHeight = if ($null -ne $Control) {
        # link
        # - url: https://stackoverflow.com/questions/3401636/measuring-controls-created-at-runtime-in-wpf
        # - retrieved: 2022_08_28
        $Control.Measure([System.Windows.Size]::new(
            [Double]::PositiveInfinity,
            [Double]::PositiveInfinity
        ))

        $Control.Height = $Control.DesiredSize.Height
        $Control.Margin = $Preferences.Margin

        $PageControl.CurrentHeight `
            + $Control.DesiredSize.Height `
            + (2 * $Preferences.Margin)
    }

    $needNewSublayout =
        $null -eq $Control `
        -or $PageControl.Multilayout.Children.Count -eq 0 `
        -or $nextHeight -gt $Preferences.Height `
        -or $nextHeight -gt $PageControl.MaxHeight

    if ($needNewSublayout) {
        $layout = New-ControlsLayout `
            -Preferences $Preferences

        $PageControl.Multilayout.AddChild($layout)
        $PageControl.Sublayouts += @($layout)
        $PageControl.CurrentHeight = 0
    }

    if ($null -ne $Control) {
        $PageControl.Sublayouts[-1].AddChild($Control)
        $PageControl.CurrentHeight +=
            $Control.Height + (2 * $Control.Margin.Top)
    }

    return $PageControl
}

<#
    .LINK
    Url: https://wpf.2000things.com/2014/11/05/1195-making-a-window-partially-transparent/
    Url: https://wpf.2000things.com/2011/02/05/208-color-values-are-stored-as-rgb-values/
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
    $form = New-Object System.Windows.Window
    $form.SizeToContent = 'WidthAndHeight'
    $form.WindowStartupLocation = 'CenterScreen'

    $form.Add_ContentRendered({
        $this.Activate()
    })

    $grid = New-Control StackPanel
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

function Get-ControlsAsterized {
    Param(
        $Control
    )

    $asterisk = New-Control Label
    $asterisk.Content = '*'
    $asterisk.FontSize = $asterisk.FontSize + 5
    $asterisk.Foreground = 'DarkRed'
    $asterisk.VerticalContentAlignment = 'Center'
    $asterisk.HorizontalContentAlignment = 'Center'
    $row = New-Control DockPanel
    $row.Margin = $Control.Margin
    $Control.Margin = 0
    $row.AddChild($asterisk)
    $row.AddChild($Control)
    return $row
}

function Get-ControlsTextDialog {
    Param(
        [PsCustomObject]
        $Preferences,

        [String]
        $Text,

        [String]
        $Caption,

        [Int]
        $MaxLength
    )

    if ($null -eq $Preferences) {
        $Preferences = Get-Content "$PsScriptRoot/../res/preference.json" `
            | ConvertFrom-Json
    }

    $textBox = New-Control TextBox
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

    $main.Window.Add_KeyDown({
        if ($_.Key -eq 'Enter') {
            $this.DialogResult = $true
            $this.Close()
        }

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

function Add-ControlsCheckBox {
    Param(
        [PsCustomObject]
        $PageControl,

        [String]
        $Text,

        $Default,

        [PsCustomObject]
        $Preferences
    )

# new
    $checkBox = New-Control CheckBox
    $checkBox.Content = $Text

    if ($null -ne $Default) {
        $checkBox.IsChecked = $Default
    }

# add
    $PageControl = Add-ControlToMultilayout `
        -PageControl $PageControl `
        -Control $checkBox `
        -Preferences $Preferences

# return
    return $checkBox
}

function Add-ControlsTable {
    Param(
        [PsCustomObject]
        $PageControl,

        [String]
        $Text,

        [PsCustomObject[]]
        $Rows,

        [Switch]
        $Mandatory,

        [PsCustomObject]
        $Preferences
    )

# new
    $tableControl = New-ControlsTable `
        -Text $Text `
        -Rows $Rows `
        -Asterized:$Mandatory `
        -Margin $Preferences.Margin

# add
    $PageControl = Add-ControlToMultilayout `
        -PageControl $PageControl `
        -Control $tableControl.GroupBox `
        -Preferences $Preferences

# return
    return $tableControl.ListView
}

function Add-ControlsListBox {
    Param(
        [PsCustomObject]
        $PageControl,

        [String]
        $Text,

        [Switch]
        $Mandatory,

        $MaxLength,
        $MaxCount,
        $Default,

        [System.Windows.Controls.Label]
        $StatusLine,

        [PsCustomObject]
        $Preferences
    )

# new
    $outerPanel = New-Control StackPanel
    $mainPanel = New-Control DockPanel
    $buttonPanel = New-Control StackPanel

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
        $button = New-Control Button
        $button.Content = $name
        $buttonPanel.AddChild($button)
        $buttonTable.Add($name, $button)
    }

    $listBox = New-Control ListBox
    $listBox.Height = 200
    $listBox.SelectionMode = 'Multiple'

    $parameters = [PsCustomObject]@{
        ListBox = $listBox
        MaxCount = $MaxCount
        MaxLength = $MaxLength
        StatusLine = $StatusLine
        Preferences = $Preferences
    }

    $actionTable['New'] = New-Closure `
        -InputObject $parameters `
        -ScriptBlock {
            $listBox = $InputObject.ListBox
            $maxCount = $InputObject.MaxCount
            $maxLength = $InputObject.MaxLength
            $statusLine = $InputObject.StatusLine
            $prefs = $InputObject.Preferences
            $index = $listBox.SelectedIndex

            . $PsScriptRoot\Controls.ps1

            if ($null -ne $maxCount `
                -and $listBox.Items.Count -eq $maxCount)
            {
                Set-ControlsStatus `
                    -StatusLine $statusLine `
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
        $button.Add_Click($action)

        $action = New-Closure `
            -InputObject $action `
            -ScriptBlock {
                if ($_.Key -eq 'Space') {
                    & $InputObject
                }
            }

        $button.Add_KeyDown($action)
    }

    $newAction = $actionTable['New']
    $editAction = $actionTable['Edit']
    $deleteAction = $actionTable['Delete']

    $parameters = [PsCustomObject]@{
        ListBox = $listBox
        NewAction = $newAction
        EditAction = $editAction
        DeleteAction = $deleteAction
        StatusLine = $StatusLine
    }

    $keyDown = New-Closure `
        -InputObject $parameters `
        -ScriptBlock {
            $listBox = $InputObject.ListBox
            $newAction = $InputObject.NewAction
            $editAction = $InputObject.EditAction
            $deleteAction = $InputObject.DeleteAction
            $statusLine = $InputObject.StatusLine
            $myEventArgs = $_

            $isKeyCombo = [System.Windows.Input.Keyboard]::Modifiers `
                -and [System.Windows.Input.ModifierKeys]::Alt

            if ($isKeyCombo) {
                if ([System.Windows.Input.Keyboard]::IsKeyDown('C')) {
                    $index = $listBox.SelectedIndex

                    if ($index -lt 0) {
                        return
                    }

                    Set-Clipboard `
                        -Value $listBox.Items[$index]

                    . $PsScriptRoot\Controls.ps1

                    Set-ControlsStatus `
                        -StatusLine $statusLine `
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
                    $myEventArgs.Handled = $true
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

    $listBox.Add_PreViewKeyDown($keyDown)

    $listBox.Add_GotFocus((New-Closure `
        -InputObject $StatusLine `
        -ScriptBlock {
            . $PsScriptRoot\Controls.ps1

            Set-ControlsStatus `
                -StatusLine $InputObject `
                -LineName 'InListBox'
        } `
    ))

    $listBox.Add_LostFocus((New-Closure `
        -InputObject $StatusLine `
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

# add
    $PageControl = Add-ControlToMultilayout `
        -PageControl $PageControl `
        -Control $outerPanel `
        -Preferences $Preferences

# return
    return $listBox
}

<#
    .NOTE
    Needs to be an 'Add-' cmdlet. Adds multiple controls other than the
    operative control, to a target container. 'Add-' rather than 'New-'
    helps encapsulate inoperative controls.
#>
function Add-ControlsFieldBox {
    Param(
        [PsCustomObject]
        $PageControl,

        [String]
        $Text,

        [Switch]
        $Mandatory,

        $MaxLength,
        $Default,

        [PsCustomObject]
        $Preferences
    )

# new
    $stackPanel = New-Control StackPanel
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

            $isKeyCombo = [System.Windows.Input.Keyboard]::Modifiers `
                -and [System.Windows.Input.ModifierKeys]::Control

            if ($isKeyCombo) {
                if ([System.Windows.Input.Keyboard]::IsKeyDown('O')) {
                    . $PsScriptRoot\Controls.ps1

                    Set-ControlsWritableText `
                        -Control $this `
                        -Text ( `
                            $this.Text `
                            + (Open-ControlsFileDialog -Directory) `
                        )

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

    $textBox.Add_PreViewKeyDown($keyDown)

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

# add
    $PageControl = Add-ControlToMultilayout `
        -PageControl $PageControl `
        -Control $stackPanel `
        -Preferences $Preferences

# return
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
    Needs to be an 'Add-' cmdlet. Adds multiple controls other than the
    operative control, to a target container. 'Add-' rather than 'New-'
    helps encapsulate inoperative controls.
#>
function Add-ControlsSlider {
    Param(
        [PsCustomObject]
        $PageControl,

        [String]
        $Text,

        [Switch]
        $Mandatory,

        $Minimum,
        $Maximum,
        $DecimalPlaces,
        $Default,

        [System.Windows.Controls.Label]
        $StatusLine,

        [PsCustomObject]
        $Preferences
    )

# new
    if ($null -eq $Minimum) {
        $Minimum = $Preferences.NumericMinimum
    }

    if ($null -eq $Maximum) {
        $Maximum = $Preferences.NumericMaximum
    }

    if ($null -eq $DecimalPlaces) {
        $DecimalPlaces = $Preferences.NumericDecimalPlaces
    }

    $dockPanel = New-Control StackPanel
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
            -InputObject $StatusLine `
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
            -InputObject $StatusLine `
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
            -InputObject $StatusLine `
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

# add
    $PageControl = Add-ControlToMultilayout `
        -PageControl $PageControl `
        -Control $dockPanel `
        -Preferences $Preferences

# retrun
    return $slider
}

<#
    .NOTE
    Needs to be an 'Add-' cmdlet. Adds multiple controls other than the
    operative control, to a target container. 'Add-' rather than 'New-'
    helps encapsulate inoperative controls.
#>
function Add-ControlsRadioBox {
    Param(
        [PsCustomObject]
        $PageControl,

        [String]
        $Text,

        [Switch]
        $Mandatory,

        [PsCustomObject[]]
        $Symbols,

        $Default,

        [PsCustomObject]
        $Preferences
    )

# new
    $groupBox = New-Control GroupBox
    $groupBox.Header = $Text

    $stackPanel = New-Control StackPanel
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

# add
    $PageControl = Add-ControlToMultilayout `
        -PageControl $PageControl `
        -Control $groupBox `
        -Preferences $Preferences

# return
    return $buttons
}

function New-ControlsTable {
    Param(
        [String]
        $Text,

        [PsCustomObject[]]
        $Rows,

        [Switch]
        $Asterized,

        [Int]
        $Margin
    )

    <#
    .LINK
    Url: https://stackoverflow.com/questions/560581/how-to-autosize-and-right-align-gridviewcolumn-data-in-wpf
    Retrieved: 2023_03_16
    #>
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

    $groupBox = New-Control GroupBox
    $groupBox.Header = $Text

    $stackPanel = New-Control StackPanel
    $groupBox.AddChild($stackPanel)

    $textBox = New-Control TextBox
    $textBox.Margin = $Margin
    $stackPanel.AddChild($textBox)

    Set-ControlsWritableText `
        -Control $textBox

    $label = New-Control Label
    $label.Content = 'Find in table:'
    $stackPanel.AddChild($label)

    # karlr (2023_03_14)
    $grid = New-Control Grid

    $asterism = if ($Asterized) {
        Get-ControlsAsterized `
            -Control $grid
    } else {
        $grid
    }

    $grid.Margin = $Margin
    $listView = New-Control ListView
    $listView.HorizontalAlignment = 'Stretch'
    $grid.AddChild($listView)
    $stackPanel.AddChild($asterism)

    if ($Rows.Count -gt 0) {
        $header = $Rows[0]
        $gridView = New-Control GridView

        foreach ($property in $header.PsObject.Properties) {
            $column = New-Control GridViewColumn
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

    $stackPanel.Add_Loaded(( `
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

    $textBox.Add_TextChanged(( `
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
        $Preferences
    )

    $endButtons = New-Control WrapPanel

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
    Needs to be an 'Add-' cmdlet. Adds multiple controls other than the
    operative control, to a target container. 'Add-' rather than 'New-'
    helps encapsulate inoperative controls.
#>
function Add-ControlsOkCancelButtons {
    Param(
        [PsCustomObject]
        $PageControl,

        [PsCustomObject]
        $Preferences
    )

# new
    $endButtons = New-ControlsOkCancelButtons `
        -Preferences $Preferences

# add
    $PageControl = Add-ControlToMultilayout `
        -PageControl $PageControl `
        -Control $endButtons.Panel `
        -Preferences $Preferences

# return
    return [PsCustomObject]@{
        OkButton = $endButtons.OkButton
        CancelButton = $endButtons.CancelButton
    }
}

function Open-ControlsTable {
    Param(
        [PsCustomObject]
        $Preferences,

        [String]
        $Text,

        [PsCustomObject[]]
        $Rows
    )

    if ($null -eq $Preferences) {
        $Preferences = Get-Content "$PsScriptRoot/../res/preference.json" `
            | ConvertFrom-Json
    }

    $main = New-ControlsMain `
        -Preferences $Preferences

    $tableControl = New-ControlsTable `
        -Text $Text `
        -Rows $Rows `
        -Margin $Preferences.Margin

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

    $main.Window.Add_PreViewKeyDown(( `
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

    $openFile = New-Control OpenFileDialog
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
        $Preferences
    )

    if ($null -eq $Preferences) {
        $Preferences = Get-Content "$PsScriptRoot/../res/preference.json" `
            | ConvertFrom-Json
    }

    $main = New-ControlsMain `
        -Preferences $Preferences

    $calendar = New-Control Calendar
    $calendar.DisplayMode = 'Month'
    $textBox = New-Control TextBox
    $textBox.Width = $Preferences.Width
    $textBox.Margin = $Preferences.Margin

    Set-ControlsWritableText `
        -Control $textBox `
        -Text $Preferences.DateFormat

    $label = New-Control Label
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

    $main.Window.Add_PreViewKeyDown(( `
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

