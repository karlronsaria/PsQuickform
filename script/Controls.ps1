#Requires -Assembly PresentationFramework

. $PsScriptRoot\Other.ps1
. $PsScriptRoot\NumberSlider.ps1

<#
.LINK
Issue: Event handler fails to update variable from outer scope
Url: <https://stackoverflow.com/questions/55403528/why-wont-variable-update>
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

<#
.LINK
Url: <https://stackoverflow.com/questions/20423211/setting-cursor-at-the-end-of-any-text-of-a-textbox>
Url: <https://stackoverflow.com/users/1042848/vishal-suthar>
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

function New-Control {
    Param(
        [Parameter(Position = 0)]
        [String]
        $Type
    )

    $control = New-Object "System.Windows.Controls.$Type"
    return $control
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

function New-ControlsLayout {
    Param(
        [PsCustomObject]
        $Preferences
    )

    $layout = New-Control StackPanel
    $layout.Width = $Preferences.Width
    $layout.MinWidth = $Preferences.Width

    $layout.Add_Loaded((
        New-Closure `
            -ScriptBlock {
                if ([double]::IsNaN($this.Width)) {
                    $this.Width = $this.ActualWidth
                }

                $this.Width = [double]::NaN
            } `
    ))

    return $layout
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
        return $Text
    }

    return $textBox.Text
}

function New-ControlsCheckBox {
    Param(
        [String]
        $Text,

        $Default
    )

    $checkBox = New-Control CheckBox
    $checkBox.Content = $Text

    if ($null -ne $Default) {
        $checkBox.IsChecked = $Default
    }

    return [PsCustomObject]@{
        Container = $checkBox
        Object = $checkBox
    }
}

function New-ControlsListBox {
    Param(
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

    $buttonNames = [Ordered]@{
        'New' = 'New' # '_New'
        'Edit' = 'Edit' # '_Edit'
        'Delete' = 'Delete' # '_Delete'
        'Move Up' = 'Move Up' # 'Move _Up'
        'Move Down' = 'Move Down' # 'Move _Down'
        'Sort' = 'Sort' # '_Sort'
    }

    $buttonTable = @{}
    $actionTable = @{}

    foreach ($name in $buttonNames.Keys) {
        $button = New-Control Button
        $button.Content = $buttonNames[$name]
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

    foreach ($name in $buttonNames.Keys) {
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

                # karlr (2023_11_18_233610): Not necessary when using
                # mnemonics. Cannot currently get mnemonics to work properly
                # when multiple ListBox's appear in form.
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

    return [PsCustomObject]@{
        Container = $outerPanel
        Object = $listBox
    }
}

function New-ControlsFieldBox {
    Param(
        [String]
        $Text,

        [Switch]
        $Mandatory,

        $MaxLength,
        $Default,

        [Switch]
        $CodeBlockStyle,

        [PsCustomObject]
        $Preferences
    )

    $stackPanel = New-Control StackPanel
    $label = New-Control Label
    $label.Content = $Text
    $textBox = New-Control TextBox

    if ($CodeBlockStyle) {
        $style = (cat "$PsScriptRoot\..\res\setting.json" |
            ConvertFrom-Json).
            CodeBlockStyle

        $textBox.Background =
            [System.Windows.Media.Brushes]::$($style.Background)

        $textBox.Foreground =
            [System.Windows.Media.Brushes]::$($style.Foreground)

        $textBox.TextWrapping =
            [System.Windows.TextWrapping]::$($style.TextWrapping)

        $textBox.FontFamily =
            [System.Windows.Media.FontFamily]::new($style.FontFamily)

        $textBox.Height = $style.Height
        $textBox.AcceptsReturn = $true

        $textBox.VerticalScrollBarVisibility =
        $textBox.HorizontalScrollBarVisibility =
            [System.Windows.Controls.ScrollBarVisibility]::Auto
    }

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

            $isKeyCombo =
                $myEventArgs.KeyboardDevice.Modifiers -contains `
                [System.Windows.Input.ModifierKeys]::Control

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

    return [PsCustomObject]@{
        Container = $stackPanel
        Object = $textBox
    }
}

function New-ControlsSlider {
    Param(
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

    $slider = [NumberSlider]::new($Default, $Minimum, $Maximum, 1)

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

    return [PsCustomObject]@{
        Container = $dockPanel
        Object = $slider
    }
}

function New-ControlsDropDown {
    Param(
        [String]
        $Text,

        [Switch]
        $Mandatory,

        [PsCustomObject[]]
        $Symbols,

        $Default
    )

    $stackPanel = New-Control StackPanel
    $label = New-Control Label
    $label.Content = $Text
    $comboBox = New-Control ComboBox
    $comboBox.IsReadOnly = $true

    $stackPanel.AddChild($label)
    $stackPanel.AddChild($comboBox)

    if (-not $Mandatory) {
        [void] $comboBox.Items.Add('None')
    }

    foreach ($symbol in $Symbols) {
        $what = Get-ControlsNameAndText $symbol
        [void] $comboBox.Items.Add($what.Text)
    }

    $comboBox.SelectedIndex = if ($null -eq $Default) {
        0
    } else {
        $comboBox.Items.IndexOf($Default)
    }

    return [PsCustomObject]@{
        Container = $stackPanel
        Object = $comboBox
    }
}

function Get-ControlsNameAndText {
    Param(
        $InputObject
    )

    $text = ""
    $name = ""

    switch ($InputObject) {
        { $_ -is [String] } {
            $name =
            $text =
                ConvertTo-UpperCamelCase $InputObject
        }

        { $_ -is [PsCustomObject] } {
            $text = $InputObject | Get-PropertyOrDefault `
                -Name Text `
                -Default $InputObject.Name

            $name = $InputObject | Get-PropertyOrDefault `
                -Name Name `
                -Default (ConvertTo-UpperCamelCase $text)
        }
    }

    return [PsCustomObject]@{
        Name = $name
        Text = $text
    }
}

function New-ControlsRadioBox {
    Param(
        [String]
        $Text,

        [Switch]
        $Mandatory,

        [PsCustomObject[]]
        $Symbols,

        $Default
    )

    $groupBox = New-Control GroupBox
    $groupBox.Header = $Text
    $stackPanel = New-Control StackPanel
    $groupBox.AddChild($stackPanel)
    $noneOptionSpecified = $false
    $buttons = @{}

    if (-not $Mandatory -and @($Symbols | where {
        $_.Name -like 'None'
    }).Count -eq 0) {
        $Symbols += @([PsCustomObject]@{ Name = 'None'; })
    }

    foreach ($symbol in $Symbols) {
        $button = New-Control RadioButton
        $what = Get-ControlsNameAndText $symbol
        $button.Content = $what.Text
        $noneOptionSpecified = $button.Content -like 'None'
        $buttons.Add($what.Name, $button)
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

    return [PsCustomObject]@{
        Container = $groupBox
        Object = $buttons
    }
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
    Url: <https://stackoverflow.com/questions/560581/how-to-autosize-and-right-align-gridviewcolumn-data-in-wpf>
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
        Container = $groupBox
        Object = $listView
    }
}

function New-ControlsOkCancelButtons {
    Param(
        [Int]
        $Margin
    )

    $BUTTON_WIDTH = 50

    $okButton = New-Control Button
    $okButton.Width = $BUTTON_WIDTH
    $okButton.Margin = $Margin
    $okButton.Content = 'OK'

    $cancelButton = New-Control Button
    $cancelButton.Width = $BUTTON_WIDTH
    $cancelButton.Margin = $Margin
    $cancelButton.Content = 'Cancel'

    $endButtons = New-Control WrapPanel
    $endButtons.AddChild($okButton)
    $endButtons.AddChild($cancelButton)
    $endButtons.HorizontalAlignment = 'Center'

    return [PsCustomObject]@{
        Container = $endButtons
        Object = [PsCustomObject]@{
            OkButton = $okButton
            CancelButton = $cancelButton
        }
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

    $endButtons.Object.OkButton.Add_Click($okAction)
    $endButtons.Object.CancelButton.Add_Click($cancelAction)

    $main.Grid.AddChild($tableControl.Container)
    $main.Grid.AddChild($endButtons.Container)

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

    return $tableControl.Object.SelectedItems
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

    $endButtons.Object.OkButton.Add_Click($okAction)
    $endButtons.Object.CancelButton.Add_Click($cancelAction)
    $main.Grid.AddChild($calendar)
    $main.Grid.AddChild($label)
    $main.Grid.AddChild($textBox)
    $main.Grid.AddChild($endButtons.Container)

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

