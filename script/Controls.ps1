#Requires -Assembly PresentationFramework

. $PsScriptRoot\Closure.ps1
. $PsScriptRoot\Other.ps1
. $PsScriptRoot\NumberSlider.ps1

class PageElementControl {
    $Container
    $Object
}

class Controls {
    [PsCustomObject] $Preferences
    [String[]] $Help
    [PsCustomObject[]] $Statuses
    [System.Windows.Controls.Label] $StatusLine
    [Logger] $Logger

    hidden [void] Init(
        [PsCustomObject] $Preferences,
        [System.Windows.Controls.Label] $StatusLine,
        [Logger] $Logger
    ) {
        $this.Preferences = $Preferences.PsObject.Copy()

        $temp = cat "$PsScriptRoot/../res/text.json" |
            ConvertFrom-Json

        $this.Help = $temp.Help
        $this.Statuses = $temp.Status
        $this.StatusLine = $StatusLine
        $this.Logger = $Logger
    }

    Controls(
        [PsCustomObject] $Preferences,
        [System.Windows.Controls.Label] $StatusLine,
        [Logger] $Logger
    ) {
        $this.Init($Preferences, $StatusLine, $Logger)
    }

    Controls() {
        $this.Init(
            (cat "$PsScriptRoot/../res/preference.json" |
                ConvertFrom-Json),
            [Controls]::NewControl('Label'),
            [Logger]::new()
        )
    }

    [ScriptBlock] NewClosure($Parameters, [ScriptBlock] $ScriptBlock) {
        return $this.Logger.NewClosure($Parameters, $ScriptBlock)
    }

    [ScriptBlock] NewClosure([ScriptBlock] $ScriptBlock) {
        return $this.Logger.NewClosure($ScriptBlock)
    }

<#
.LINK
Url: <https://stackoverflow.com/questions/20423211/setting-cursor-at-the-end-of-any-text-of-a-textbox>
Url: <https://stackoverflow.com/users/1042848/vishal-suthar>
Retreived: 2022_03_02
#>
    static [void] SetWriteableText(
        [System.Windows.Controls.Control]
        $Control,

        [String]
        $Text
    ) {
        $Control.Text = $Text
        $Control.Select($Control.Text.Length, 0)
    }

    [void] SetStatus(
        [String]
        $Text,

        [String]
        $ForeColor = 'Black'
    ) {
        $this.StatusLine.Content = $Text
        $this.StatusLine.Foreground = $ForeColor
    }

    [void] SetStatus(
        [String]
        $LineName
    ) {
        $status = $this.Statuses |
            where Name -eq $LineName

        $Text = $status | Get-PropertyOrDefault `
            -Name Text `
            -Default 'ToolTip missing!'

        $ForeColor = $status | Get-PropertyOrDefault `
            -Name Foreground `
            -Default 'Black'

        $this.StatusLine.Content = $Text
        $this.StatusLine.Foreground = $ForeColor
    }

    static [System.Windows.FrameworkElement]
    NewControl([String] $TypeName) {
        return New-Object "System.Windows.Controls.$TypeName"
    }

    static [PsCustomObject] NewMain([Logger] $Logger) {
        $form = New-Object System.Windows.Window
        $form.SizeToContent = 'WidthAndHeight'
        $form.WindowStartupLocation = 'CenterScreen'

        $form.Add_ContentRendered($Logger.NewClosure({
            $this.Activate()
        }))

        $grid = [Controls]::NewControl('StackPanel')
        $form.AddChild($grid)

        return [PsCustomObject]@{
            Window = $form
            Grid = $grid
        }
    }

    [PsCustomObject] NewMain() {
        return [Controls]::NewMain($this.Logger)
    }

    [System.Windows.Controls.StackPanel] NewLayout() {
        $layout = [Controls]::NewControl('StackPanel')
        $layout.Width = $this.Preferences.Width
        $layout.MinWidth = $this.Preferences.Width

        $layout.Add_Loaded($this.NewClosure({
            if ([double]::IsNaN($this.Width)) {
                $this.Width = $this.ActualWidth
            }

            $this.Width = [double]::NaN
        }))

        return $layout
    }

    static [void] AddTabItem(
        [System.Windows.Controls.TabControl]
        $TabControl,

        [System.Windows.FrameworkElement]
        $Control,

        [String]
        $Header
    ) {
        $tab = [Controls]::NewControl('TabItem')
        $tab.Header = $Header
        $tab.AddChild($Control)
        $TabControl.Items.Add($tab)
    }

    [System.Windows.Controls.TabControl] NewTabLayout(
        [System.Windows.FrameworkElement[]]
        $Control = @(),

        [String[]]
        $Header = @()
    ) {
        $tabs = [Controls]::NewControl('TabControl')

        0 .. [Math]::Min($Control.Count, $Header.Count) |
        foreach {
            [Controls]::AddTabItem(
                $tabs,
                @($Control)[$_],
                @($Header)[$_]
            )
        }

        return $tabs
    }

    [System.Windows.Controls.DockPanel] Asterize(
        [System.Windows.FrameworkElement]
        $Control
    ) {
        $asterisk = $this.NewControl('Label')
        $asterisk.Content = '*'
        $asterisk.FontSize = $asterisk.FontSize + 5
        $asterisk.Foreground = 'DarkRed'
        $asterisk.VerticalContentAlignment = 'Center'
        $asterisk.HorizontalContentAlignment = 'Center'
        $row = $this.NewControl('DockPanel')
        $row.Margin = $Control.Margin
        $Control.Margin = 0
        $row.AddChild($asterisk)
        $row.AddChild($Control)
        return $row
    }

    [String] ShowTextDialog(
        [String]
        $Text,

        [String]
        $Caption,

        [Int]
        $MaxLength
    ) {
        $textBox = [Controls]::NewControl('TextBox')
        $textBox.Width = $this.Preferences.Width
        $textBox.Margin = $this.Preferences.Margin

        if ($null -ne $MaxLength) {
            $textBox.MaxLength = $MaxLength
        }

        [Controls]::SetWriteableText($textBox, $Text)
        $main = $this.NewMain()
        $main.Window.Title = $Caption
        $main.Grid.AddChild($textBox)

        # todo: consider adding to the main window of general forms
        $main.Window.Add_KeyDown($this.NewClosure({
            if ($_.Key -eq 'Enter') {
                $this.DialogResult = $true
                $this.Close()
            }

            if ($_.Key -eq 'Escape') {
                $this.DialogResult = $false
                $this.Close()
            }
        }))

        $main.Window.Add_ContentRendered($this.NewClosure(
            $textBox,
            { $Parameters.Focus() }
        ))

        if (-not $main.Window.ShowDialog()) {
            return $Text
        }

        return $textBox.Text
    }

    [PageElementControl] NewCheckBox(
        [String]
        $Text,

        $Default
    ) {
        $checkBox = [Controls]::NewControl('CheckBox')
        $checkBox.Content = $Text

        if ($null -ne $Default) {
            $checkBox.IsChecked = $Default
        }

        return [PageElementControl]@{
            Container = $checkBox
            Object = $checkBox
        }
    }

    [PageElementControl] NewListBox(
        [String]
        $Text,

        [Switch]
        $Mandatory,

        $MaxLength,
        $MaxCount,
        $Default
    ) {
        $outerPanel = $this.NewControl('StackPanel')
        $mainPanel = $this.NewControl('DockPanel')
        $buttonPanel = $this.NewControl('StackPanel')

        $label = $this.NewControl('Label')
        $label.Content = $Text

        $asterism = if ($Mandatory) {
            $this.Asterize($label)
        }
        else {
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
            $button = $this.NewControl('Button')
            $button.Content = $buttonNames[$name]
            $buttonPanel.AddChild($button)
            $buttonTable.Add($name, $button)
        }

        $listBox = $this.NewControl('ListBox')
        $listBox.Height = 200
        $listBox.SelectionMode = 'Multiple'

        $parameters = [PsCustomObject]@{
            ListBox = $listBox
            MaxCount = $MaxCount
            MaxLength = $MaxLength
            This = $this
        }

        $actionTable['New'] = $this.NewClosure(
            $parameters,
            {
                $listBox = $Parameters.ListBox
                $maxCount = $Parameters.MaxCount
                $maxLength = $Parameters.MaxLength
                $prefs = $Parameters.This.Preferences
                $index = $listBox.SelectedIndex

                if ($null -ne $maxCount `
                    -and $listBox.Items.Count -eq $maxCount)
                {
                    $parameters.This.SetStatus('MaxCountReached')
                    return
                }

                if ($index -ge 0) {
                    $listBox.Items.Insert($index, '')
                }
                else {
                    $listBox.Items.Add('')
                    $index = $listBox.Items.Count - 1
                }

                $listBox.Items[$index] = $this.ShowTextDialog(
                    $listBox.Items[$index],
                    'Edit ListBox Item',
                    $maxLength
                )
            }
        )

        $parameters = [PsCustomObject]@{
            ListBox = $listBox
            MaxLength = $MaxLength
            Preferences = $this.Preferences
        }

        $actionTable['Edit'] = $this.NewClosure(
            $parameters,
            {
                $listBox = $Parameters.ListBox
                $prefs = $this.Parameters.Preferences
                $maxLength = $Parameters.MaxLength
                $index = $listBox.SelectedIndex

                if ($index -lt 0) {
                    return
                }

                $listBox.Items[$index] = $this.ShowTextDialog(
                    $listBox.Items[$index],
                    'Edit ListBox Item',
                    $maxLength
                )
            }
        )

        $actionTable['Delete'] = $this.NewClosure(
            $listBox,
            {
                $listBox = $Parameters
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
        )

        $actionTable['Move Up'] = $this.NewClosure(
            $listBox,
            {
                $listBox = $Parameters
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
        )

        $actionTable['Move Down'] = $this.NewClosure(
            $listBox,
            {
                $listBox = $Parameters
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
        )

        $actionTable['Sort'] = $this.NewClosure(
            $listBox,
            {
                $listBox = $Parameters

                $items = $listBox.Items | sort | foreach {
                    [String]::new($_)
                }

                $listBox.Items.Clear()

                foreach ($item in $items) {
                    $listBox.Items.Add($item)
                }
            }
        )

        foreach ($name in $buttonNames.Keys) {
            $button = $buttonTable[$name]
            $action = $actionTable[$name]
            $button.Add_Click($action)

            $action = $this.NewClosure(
                $action,
                {
                    if ($_.Key -eq 'Space') {
                        & $Parameters
                    }
                }
            )

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
            This = $this
        }

        $keyDown = $this.NewClosure(
            $parameters,
            {
                $listBox = $Parameters.ListBox
                $newAction = $Parameters.NewAction
                $editAction = $Parameters.EditAction
                $deleteAction = $Parameters.DeleteAction
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

                        $Parameters.This.SetStatus('TextClipped')
                    }

                    # karlr (2023_11_18_233610): Not necessary when using
                    # mnemonics. Cannot currently get mnemonics to work
                    # properly when multiple ListBox's appear in form.
                    if ([System.Windows.Input.Keyboard]::IsKeyDown('N')) {
                        & $newAction
                        return
                    }

                    if ([System.Windows.Input.Keyboard]::
                        IsKeyDown('Space')
                    ) {
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
        )

        $listBox.Add_PreViewKeyDown($keyDown)

        $listBox.Add_GotFocus($this.NewClosure(
            $this,
            {
                $Parameters.SetStatus('InListBox')
            }
        ))

        $listBox.Add_LostFocus($this.NewClosure(
            $this,
            {
                $Parameters.SetStatus('Idle')
            }
        ))

        foreach ($item in $Default) {
            $listBox.Items.Add($item)
        }

        $mainPanel.AddChild($buttonPanel)
        $mainPanel.AddChild($listBox)
        $outerPanel.AddChild($asterism)
        $outerPanel.AddChild($mainPanel)

        return [PageElementControl]@{
            Container = $outerPanel
            Object = $listBox
        }
    }

    static [void] SetCodeBlockStyle(
        [System.Windows.Controls.Control]
        $Control,

        [Switch]
        $IsField
    ) {
        $style = (cat "$PsScriptRoot\..\res\setting.json" |
            ConvertFrom-Json).
            CodeBlockStyle

        $Control.Background =
            [System.Windows.Media.Brushes]::$($style.Background)

        $Control.Foreground =
            [System.Windows.Media.Brushes]::$($style.Foreground)

        $Control.FontFamily =
            [System.Windows.Media.FontFamily]::new($style.FontFamily)

        $Control.Height = $style.Height

        if ($IsField) {
            $Control.TextWrapping =
                [System.Windows.TextWrapping]::$($style.TextWrapping)

            $Control.AcceptsReturn = $true

            $Control.VerticalScrollBarVisibility =
            $Control.HorizontalScrollBarVisibility =
                [System.Windows.Controls.ScrollBarVisibility]::Auto
        }
    }

    [PageElementControl] NewLabel(
        [String]
        $Text,

        [Switch]
        $Mandatory,

        $Default,

        [Switch]
        $CodeBlockStyle
    ) {
        $stackPanel = [Controls]::NewControl('StackPanel')
        $label = [Controls]::NewControl('Label')
        $label.Content = $Text
        $view = [Controls]::NewControl('Label')

        if ($CodeBlockStyle) {
            [Controls]::SetCodeBlockStyle($view, $false)
        }

        $row2 = if ($Mandatory) {
            [Controls]::Asterize($view)
        } else {
            $view
        }

        if ($null -ne $Default) {
            $view.Content = $Default
        }

        $stackPanel.AddChild($label)
        $stackPanel.AddChild($row2)

        return [PageElementControl]@{
            Container = $stackPanel
            Object = $view
        }
    }

    [PageElementControl] NewFieldBox(
        [String]
        $Text,

        [Switch]
        $Mandatory,

        $MaxLength,
        $Default
    ) {
        return $($this.NewFieldBox(
            $Text,
            $Mandatory,
            $MaxLength,
            $Default,
            ""
        ))
    }

    [PageElementControl] NewFieldBox(
        [String]
        $Text,

        [Switch]
        $Mandatory,

        $MaxLength,
        $Default,

        [String]
        $Style
    ) {
        $stackPanel = [Controls]::NewControl('StackPanel')
        $label = [Controls]::NewControl('Label')
        $label.Content = $Text
        $textBox = [Controls]::NewControl('TextBox')

        switch ($Style) {
            'CodeBlock' {
                [Controls]::SetCodeBlockStyle($textBox, $true)
            }

            # todo
            'DebugWindow' {
                [Controls]::SetCodeBlockStyle($textBox, $true)
                $textBox.IsReadOnly = $true
                $textBox.Height = $this.Preferences.LogHeight
            }
        }

        $row2 = if ($Mandatory) {
            [Controls]::Asterize($textBox)
        } else {
            $textBox
        }

        $monthCalendarPrefs = $this.Preferences.PsObject.Copy()
        $monthCalendarPrefs.Caption = 'Get Date'
        $monthCalendarPrefs.Width = 350

        $keyDown = $this.NewClosure(
            [Controls]::new($monthCalendarPrefs, $null, [Logger]::ToConsole()),
            {
                $myEventArgs = $_

                $isKeyCombo =
                    $myEventArgs.KeyboardDevice.Modifiers -contains `
                    [System.Windows.Input.ModifierKeys]::Control

                if ($isKeyCombo) {
                    if ([System.Windows.Input.Keyboard]::IsKeyDown('O')) {
                        . $PsScriptRoot\Controls.ps1

                        [Controls]::SetWriteableText(
                            $this,
                            "$($this.Text)$($Parameters.ShowFileDialog($true))" # -Directory
                        )

                        $myEventArgs.Handled = $true
                    }

                    if ([System.Windows.Input.Keyboard]::IsKeyDown('D')) {
                        $text = $Parameters.ShowMonthCalendar()

                        [Controls]::SetWriteableText(
                            $this,
                            "$($this.Text)$text"
                        )

                        $myEventArgs.Handled = $true
                    }
                }
            }
        )

        $textBox.Add_PreViewKeyDown($keyDown)

        if ($null -ne $MaxLength) {
            $textBox.MaxLength = $MaxLength
        }

        if ($null -ne $Default) {
            [Controls]::SetWriteableText($textBox, $Default)
        }

        $stackPanel.AddChild($label)
        $stackPanel.AddChild($row2)

        return [PageElementControl]@{
            Container = $stackPanel
            Object = $textBox
        }
    }

    [PageElementControl] NewSlider(
        [String]
        $Text,

        [Switch]
        $Mandatory,

        $Minimum,
        $Maximum,
        $DecimalPlaces,
        $Default
    ) {
        if ($null -eq $Minimum) {
            $Minimum = $this.Preferences.NumericMinimum
        }

        if ($null -eq $Maximum) {
            $Maximum = $this.Preferences.NumericMaximum
        }

        if ($null -eq $DecimalPlaces) {
            $DecimalPlaces = $this.Preferences.NumericDecimalPlaces
        }

        $dockPanel = [Controls]::NewControl('StackPanel')
        $label = [Controls]::NewControl('Label')
        $label.Content = $Text
        $slider = [NumberSlider]::new($Default, $Minimum, $Maximum, 1)

        $row2 = if ($Mandatory) {
            [Controls]::Asterize($slider)
        } else {
            $slider
        }

        if ($null -ne $Minimum -or $null -ne $Maximum) {
            $closure = $this.NewClosure(
                $this,
                { $Parameters.SetStatus('Idle') }
            )

            $slider.OnIdle += @($closure)
        }

        if ($null -ne $Minimum) {
            $closure = $this.NewClosure(
                $this,
                { $Parameters.SetStatus('MinReached') }
            )

            $slider.OnMinReached += @($closure)
        }

        if ($null -ne $Maximum) {
            $closure = $this.NewClosure(
                $this,
                { $Parameters.SetStatus('MaxReached') }
            )

            $slider.OnMaxReached += @($closure)
        }

        $dockPanel.AddChild($label)
        $dockPanel.AddChild($row2)

        return [PageElementControl]@{
            Container = $dockPanel
            Object = $slider
        }
    }

    [PageElementControl] NewDropDown(
        [String]
        $Text,

        [Switch]
        $Mandatory,

        [PsCustomObject[]]
        $Symbols,

        $Default
    ) {
        $stackPanel = [Controls]::NewControl('StackPanel')
        $label = [Controls]::NewControl('Label')
        $label.Content = $Text
        $comboBox = [Controls]::NewControl('ComboBox')
        $comboBox.IsReadOnly = $true

        $stackPanel.AddChild($label)
        $stackPanel.AddChild($comboBox)

        if (-not $Mandatory) {
            [void] $comboBox.Items.Add('None')
        }

        foreach ($symbol in $Symbols) {
            $id = [Controls]::GetNameAndText($symbol)
            [void] $comboBox.Items.Add($id.Text)
        }

        $comboBox.SelectedIndex = if ($null -eq $Default) {
            0
        } else {
            $comboBox.Items.IndexOf($Default)
        }

        return [PageElementControl]@{
            Container = $stackPanel
            Object = $comboBox
        }
    }

    static [PsCustomObject] GetNameAndText(
        $InputObject
    ) {
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

    [PageElementControl] NewRadioBox(
        [String]
        $Text,

        [Switch]
        $Mandatory,

        [PsCustomObject[]]
        $Symbols,

        $Default
    ) {
        $groupBox = [Controls]::NewControl('GroupBox')
        $groupBox.Header = $Text
        $stackPanel = [Controls]::NewControl('StackPanel')
        $groupBox.AddChild($stackPanel)
        $noneOptionSpecified = $false
        $buttons = @{}

        if (-not $Mandatory -and @($Symbols | where {
            $_.Name -like 'None'
        }).Count -eq 0) {
            $Symbols += @([PsCustomObject]@{ Name = 'None'; })
        }

        foreach ($symbol in $Symbols) {
            $button = [Controls]::NewControl('RadioButton')
            $id = [Controls]::GetNameAndText($symbol)
            $button.Content = $id.Text
            $noneOptionSpecified = $button.Content -like 'None'
            $buttons.Add($id.Name, $button)
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

        return [PageElementControl]@{
            Container = $groupBox
            Object = $buttons
        }
    }

<#
.LINK
Url: <https://stackoverflow.com/questions/560581/how-to-autosize-and-right-align-gridviewcolumn-data-in-wpf>
Retrieved: 2023_03_16
#>
    static [ScriptBlock] $SetColumnPreferredSize = {
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

    [PageElementControl] NewTable(
        [String]
        $Text,

        [PsCustomObject[]]
        $Rows,

        [Switch]
        $Asterized,

        [Int]
        $Margin
    ) {
        $groupBox = [Controls]::NewControl('GroupBox')
        $groupBox.Header = $Text

        $stackPanel = [Controls]::NewControl('StackPanel')
        $groupBox.AddChild($stackPanel)

        $textBox = [Controls]::NewControl('TextBox')
        $textBox.Margin = $Margin
        $stackPanel.AddChild($textBox)

        [Controls]::SetWriteableText($textBox)

        $label = [Controls]::NewControl('Label')
        $label.Content = 'Find in table:'
        $stackPanel.AddChild($label)

        # karlr (2023_03_14)
        $grid = [Controls]::NewControl('Grid')

        $asterism = if ($Asterized) {
            [Controls]::Asterize($grid)
        } else {
            $grid
        }

        $grid.Margin = $Margin
        $listView = [Controls]::NewControl('ListView')
        $listView.HorizontalAlignment = 'Stretch'
        $grid.AddChild($listView)
        $stackPanel.AddChild($asterism)
        $gridView = [Controls]::NewControl('GridView')

        if ($Rows.Count -gt 0) {
            $header = $Rows[0]

            foreach ($property in $header.PsObject.Properties) {
                $column = [Controls]::NewControl('GridViewColumn')
                $column.Header = $property.Name
                $column.DisplayMemberBinding =
                    [System.Windows.Data.Binding]::new($property.Name)
                $gridView.Columns.Add($column)
            }
        }

        $listView.View = $gridView

        foreach ($row in $Rows) {
            [void]$listView.Items.Add($row)
        }

        $stackPanel.Add_Loaded($this.NewClosure(
            [PsCustomObject]@{
                GridView = $gridView
                Resize = [Controls]::SetColumnPreferredSize
            },
            { & $Parameters.Resize $Parameters.GridView }
        ))

        $textBox.Add_TextChanged($this.NewClosure(
            [PsCustomObject]@{
                TextBox = $textBox
                ListView = $listView
                GridView = $gridView
                Rows = $Rows
            },
            {
                $Parameters.ListView.Items.Clear()
                $text = $Parameters.TextBox.Text

                $items = if ([String]::IsNullOrEmpty($text)) {
                    $Parameters.Rows
                } else {
                    $Parameters.Rows | where {
                        $_.PsObject.Properties.Value -like "*$text*"
                    }
                }

                foreach ($item in $items) {
                    [void]$Parameters.ListView.Items.Add($item)
                }
            }
        ))

        return [PageElementControl]@{
            Container = $groupBox
            Object = $listView
        }
    }

    [PageElementControl] NewOkCancelButtons() {
        $BUTTON_WIDTH = 50

        $okButton = [Controls]::NewControl('Button')
        $okButton.Width = $BUTTON_WIDTH
        $okButton.Margin = $this.Preferences.Margin
        $okButton.Content = 'OK'

        $cancelButton = [Controls]::NewControl('Button')
        $cancelButton.Width = $BUTTON_WIDTH
        $cancelButton.Margin = $this.Preferences.Margin
        $cancelButton.Content = 'Cancel'

        $endButtons = [Controls]::NewControl('WrapPanel')
        $endButtons.AddChild($okButton)
        $endButtons.AddChild($cancelButton)
        $endButtons.HorizontalAlignment = 'Center'

        return [PageElementControl]@{
            Container = $endButtons
            Object = [PsCustomObject]@{
                OkButton = $okButton
                CancelButton = $cancelButton
            }
        }
    }

    [System.Collections.IList] ShowTable(
        [String]
        $Text,

        [PsCustomObject[]]
        $Rows
    ) {
        $main = $this.NewMain()
        $tableControl = $this.NewTable($Text, $Rows)
        $endButtons = $this.NewOkCancelButtons()

        $okAction = $this.NewClosure(
            $main.Window,
            {
                $Parameters.DialogResult = $true
                $Parameters.Close()
            }
        )

        $cancelAction = $this.NewClosure(
            $main.Window,
            {
                $Parameters.DialogResult = $false
                $Parameters.Close()
            }
        )

        $endButtons.Object.OkButton.Add_Click($okAction)
        $endButtons.Object.CancelButton.Add_Click($cancelAction)

        $main.Grid.AddChild($tableControl.Container)
        $main.Grid.AddChild($endButtons.Container)

        $parameters = [PsCustomObject]@{
            OkAction = $okAction
            CancelAction = $cancelAction
        }

        $main.Window.Add_PreViewKeyDown($this.Closure(
            $parameters,
            {
                if ($_.Key -eq 'Enter') {
                    & $Parameters.OkAction
                    $_.Handled = $true
                    return
                }

                if ($_.Key -eq 'Escape') {
                    & $Parameters.CancelAction
                    $_.Handled = $true
                    return
                }
            }
        ))

        if (-not $main.Window.ShowDialog()) {
            return [System.Collections.Generic.List[String]]::new()
        }

        return $tableControl.Object.SelectedItems
    }

    [String[]] ShowFileDialog(
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
    ) {
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

        if ($openFile.ShowDialog() -eq
            [System.Windows.Forms.DialogResult]::OK
        ) {
            if ($Directory) {
                return [System.IO.Path]::GetDirectoryName(
                    $openFile.FileName
                )
            }

            if ($Multiselect) {
                return $openFile.FileNames
            }

            return $openFile.FileName
        }

        return ""
    }

    [String] ShowMonthCalendar() {
        $main = $this.NewMain()
        $calendar = [Controls]::NewControl('Calendar')
        $calendar.DisplayMode = 'Month'
        $textBox = [Controls]::NewControl('TextBox')
        $textBox.Width = $this.Preferences.Width
        $textBox.Margin = $this.Preferences.Margin

        [Controls]::SetWriteableText(
            $textBox,
            $this.Preferences.DateFormat
        )

        $label = [Controls]::NewControl('Label')
        $label.Content = 'Format:'
        $endButtons = $this.NewOkCancelButtons()

        $okAction = $this.NewClosure(
            $main.Window,
            {
                $Parameters.DialogResult = $true
                $Parameters.Close()
            }
        )

        $cancelAction = $this.NewClosure(
            $main.Window,
            {
                $Parameters.DialogResult = $false
                $Parameters.Close()
            }
        )

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

        $main.Window.Add_PreViewKeyDown($this.NewClosure(
            $parameters,
            {
                if ($_.Key -eq 'Enter') {
                    & $Parameters.OkAction
                    $_.Handled = $true
                    return
                }

                if ($_.Key -eq 'Escape') {
                    & $Parameters.CancelAction
                    $_.Handled = $true
                    return
                }
            }
        ))

        if (-not $main.Window.ShowDialog()) {
            return ""
        }

        $dates = $calendar.SelectedDates

        if ($dates.Count -eq 0) {
            if ($null -eq $textBox.Text) {
                return Get-Date
            }

            return Get-Date -Format $textBox.Text
        }

        $item = $dates[0]

        return $(if ($null -eq $textBox.Text) {
            $item.ToString()
        } else {
            $item.ToString($textBox.Text)
        })
    }
}

