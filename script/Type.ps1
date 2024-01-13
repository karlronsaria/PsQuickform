# New: all return:
#   - controlsType
#     - container
#     - object

. $PsScriptRoot\Controls.ps1

$script:default = [PsCustomObject]@{
    Type = 'Script'
    ContentHasAny = {
        -not [String]::IsNullOrEmpty(
            $_.Content
        )
    }
    TextHasAny = {
        -not [String]::IsNullOrEmpty(
            $_.Text
        )
    }
    GetEventObject = { $_ }
}

$types = [PsCustomObject]@{
Default = $script:default.PsObject.Copy()
Events = [PsCustomObject]@{
    CheckBox = 'Checked'
    RadioButton = 'Checked'
    TextBox = 'TextChanged'
    ListView = 'SelectionChanged'
    ListBox = 'LayoutUpdated'
    NumberSlider = 'TextChanged'
    GroupBox = 'Checked'
    PSCustomObject = 'Checked'
    ComboBox = 'TextChanged'
}
Table = [PsCustomObject]@{
    View = [PsCustomObject]@{
        HasAny = $default.ContentHasAny
        GetValue = {
            $_.Content
        }
        New = {
            [OutputType('PageElementControl')]
            Param ($Item, $Pref, $Label, $Text, $Default, $Mandatory)

            New-ControlsLabel `
                -Text $Text `
                -Default $Default
        }
        PostProcess = {
            Param ($PageInfo, $Controls, $Types, $ItemName)

            $getAccessor = {
                Param(
                    [PsCustomObject[]]
                    $PageInfo,

                    [Hashtable]
                    $Controls,

                    [PsCustomObject]
                    $Types,

                    [String]
                    $ElementName
                )

                $type = $PageInfo |
                    where { $_.Name -eq $ElementName } |
                    foreach { $_.Type }

                return $Controls[$ElementName] |
                    foreach $Types.Table.$type.GetValue
            }

            $expression = $PageInfo |
                where { $_.Name -eq $ItemName } |
                Get-PropertyOrDefault `
                    -Name Expression

            $bindings = @()

            [Regex]::Matches($expression, "\<[^\<\>]+\>") | foreach {
                $name = $_.Value -replace "^\<|\>$", ""

                $what =
@"
& `$InputObject.GetAccessor -PageInfo `$InputObject.PageInfo -Controls `$InputObject.Controls -Types `$InputObject.Types -ElementName $name
"@

                $expression = $expression -replace $_, "`$($what)"
                $bindings += @($name)
            }

            $closure = New-Closure `
                -InputObject ([PsCustomObject]@{
                    PageInfo = $PageInfo
                    Controls = $Controls
                    Types = $Types
                    ItemName = $ItemName
                    Expression = "`"$expression`""
                    GetAccessor = $getAccessor
                }) `
                -ScriptBlock {
                    $InputObject.Controls[$InputObject.ItemName].Content =
                        iex $InputObject.Expression
                }

            foreach ($binding in $bindings) {
                $control = $Controls[$binding]
                $eventName = $Types.Events.($control.GetType().Name)
                $control."Add_$eventName"($closure)
            }
        }
    }
    Check = [PsCustomObject]@{
        DataTypes = @(
            [Boolean]
            [Switch]
        )
        GetEventObject = $default.GetEventObject
        HasAny = { $true }
        GetValue = {
            $_.IsChecked
        }
        New = {
            [OutputType('PageElementControl')]
            Param ($Item, $Pref, $Label, $Text, $Default, $Mandatory)

            New-ControlsCheckBox `
                -Text $Text `
                -Default $Default
        }
    }
    Field = [PsCustomObject]@{
        DataTypes = @(
            [String]
        )
        GetEventObject = $default.GetEventObject
        HasAny = $script:default.TextHasAny
        GetValue = {
            $_.Text
        }
        New = {
            [OutputType('PageElementControl')]
            Param ($Item, $Pref, $Label, $Text, $Default, $Mandatory)

            $maxLength = $Item | Get-PropertyOrDefault `
                -Name MaxLength

            New-ControlsFieldBox `
                -Text $Text `
                -Mandatory:$Mandatory `
                -MaxLength $maxLength `
                -Default $Default `
                -Preferences $Pref
        }
    }
    Script = [PsCustomObject]@{
        DataTypes = @(
            [String]
        )
        GetEventObject = $default.GetEventObject
        HasAny = $script:default.TextHasAny
        GetValue = {
            if ([String]::IsNullOrWhiteSpace($_.Text)) {
                ""
            }
            else {
                Invoke-Expression $_.Text
            }
        }
        New = {
            [OutputType('PageElementControl')]
            Param ($Item, $Pref, $Label, $Text, $Default, $Mandatory)

            $maxLength = $InputObject.Item | Get-PropertyOrDefault `
                -Name MaxLength

            New-ControlsFieldBox `
                -Text $Text `
                -Mandatory:$Mandatory `
                -MaxLength $maxLength `
                -Default $Default `
                -Preferences $Pref `
                -CodeBlockStyle
        }
    }
    Table = [PsCustomObject]@{
        DataTypes = @(
            [PsCustomObject]
            [PsCustomObject[]]
        )
        GetEventObject = $default.GetEventObject
        HasAny = {
            $_.SelectedItems.Count -gt 0
        }
        GetValue = {
            $_.SelectedItems
        }
        New = {
            [OutputType('PageElementControl')]
            Param ($Item, $Pref, $Label, $Text, $Default, $Mandatory)

            $rows = $Item | Get-PropertyOrDefault `
                -Name Rows `
                -Default @()

            New-ControlsTable `
                -Text $Text `
                -Mandatory:$Mandatory `
                -Rows $rows `
                -Margin $Prefs.Margin
        }
    }
    List = [PsCustomObject]@{
        DataTypes = @(
            [String[]]
            [Object[]]
        )
        GetEventObject = $default.GetEventObject
        HasAny = {
            $_.Items.Count -gt 0
        }
        GetValue = {
            $_.Items
        }
        New = {
            [OutputType('PageElementControl')]
            Param ($Item, $Pref, $Label, $Text, $Default, $Mandatory)

            $maxCount = $Item | Get-PropertyOrDefault `
                -Name MaxCount
            $maxLength = $Item | Get-PropertyOrDefault `
                -Name MaxLength

            New-ControlsListBox `
                -Text $Text `
                -Mandatory:$Mandatory `
                -MaxCount $maxCount `
                -MaxLength $maxLength `
                -Default $Default `
                -StatusLine $Label `
                -Preferences $Pref
        }
    }
    Numeric = [PsCustomObject]@{
        DataTypes = @(
            [Int]
            [Int16]
            [Int32]
            [Int64]
            [Single]
            [Float]
            [Double]
            [Decimal]
        )
        HasAny = $script:default.TextHasAny
        GetValue = {
            $_.Value
        }
        GetEventObject = $default.GetEventObject
        New = {
            [OutputType('PageElementControl')]
            Param ($Item, $Pref, $Label, $Text, $Default, $Mandatory)

            $places = $item | Get-PropertyOrDefault `
                -Name DecimalPlaces `
                -Default $Pref.NumericDecimalPlaces
            $min = $item | Get-PropertyOrDefault `
                -Name Minimum `
                -Default $Pref.NumericMinimum
            $max = $item | Get-PropertyOrDefault `
                -Name Maximum `
                -Default $Pref.NumericMaximum

            New-ControlsSlider `
                -Text $Text `
                -Mandatory:$Mandatory `
                -DecimalPlaces $places `
                -Minimum $min `
                -Maximum $max `
                -Default $Default `
                -StatusLine $Label `
                -Preferences $Pref
        }
    }
    Enum = [PsCustomObject]@{
        DataTypes = @(
            [String[]]
            [Enum]
        )
        GetEventObject = { @($_.Object.Values)[0] }
        HasAny = { $true }
        GetValue = {
            # This is a filter script block, not a function script block.
            # Filter bindings need to specify 'Script' scope, because filter
            # commands like 'ForEach-Object' and 'Where-Object' share their
            # scope with the outer block. Otherwise, binding an '$item' in
            # this block will affect other '$item' bindings outside the
            # block.

            $script:item = $_

            return $(switch ($script:item.As) {
                'RadioPanel' {
                    $script:buttons = $script:item.Object

                    if (-not $script:buttons) {
                        return
                    }

                    foreach (
                        $name in $script:buttons.Keys |
                        where { $script:buttons[$_].IsChecked }
                    ) {
                        switch ($script:item.To) {
                            'Key' { $name }

                            'Value' {
                                $script:item.Symbols |
                                where { $_.Name -eq $name } |
                                foreach { $_.Text }
                            }

                            'Pair' {
                                $script:item.Symbols |
                                where { $_.Name -eq $name }
                            }
                        }
                    }
                }

                'DropDown' {
                    foreach ($index in $script:item.Object.SelectedIndex) {
                        $script:symbol = $script:item.Symbols[$index]

                        switch ($script:item.To) {
                            'Key' {
                                $script:symbol.Name
                            }

                            'Value' {
                                $script:symbol.Text
                            }

                            'Pair' {
                                $script:symbol
                            }
                        }
                    }
                }
            })
        }
        New = {
            [OutputType('PageElementControl')]
            Param ($Item, $Pref, $Label, $Text, $Default, $Mandatory)

            $as = $Item | Get-PropertyOrDefault `
                -Name As `
                -Default 'RadioPanel'
            $to = $Item | Get-PropertyOrDefault `
                -Name To `
                -Default 'Key'
            $symbols = $Item | Get-PropertyOrDefault `
                -Name Symbols `
                -Default @{}

            $params = @{
                Text = $Text
                Mandatory = $Mandatory
                Symbols =
                    $symbols |
                    foreach -Begin {
                        $count = 0
                    } -Process {
                        $newSymbol =
                            Get-ControlsNameAndText $_

                        [PsCustomObject]@{
                            Id = ++$count
                            Name = $newSymbol.Name
                            Text = $newSymbol.Text
                        }
                    }
                Default = $Default
            }

            $control = switch ($as) {
                'RadioPanel' {
                    New-ControlsRadioBox @params
                }

                'DropDown' {
                    New-ControlsDropDown @params
                }
            }

            $object = [PsCustomObject]@{
                As = $as
                To = $to
                Object = $control.Object
                Symbols = $params['Symbols']
            }

            switch ($as) {
                'RadioPanel' {
                    $object | Add-Member `
                        -MemberType 'ScriptMethod' `
                        -Name 'Add_Checked' `
                        -Value (
                            New-Closure `
                                -InputObject $control.Object.Values `
                                -ScriptBlock {
                                    Param([ScriptBlock] $Handle)

                                    $InputObject | foreach {
                                        $_.Add_Checked($Handle)
                                    }
                                }
                        )
                }
            }

            [PsCustomObject]@{
                Container = $control.Container
                Object = $object
            }
        }
    }
}
}

