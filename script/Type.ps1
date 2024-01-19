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
    Log = [PsCustomObject]@{
        DataTypes = @(
            [String]
        )
        HasAny = $script:default.TextHasAny
        GetValue = {
            $_.Text
        }
        New = {
            [OutputType([PageElementControl])]
            Param ($Item, [Controls] $Builder, $Text, $Default, $Mandatory)

            $maxLength = $Item | Get-PropertyOrDefault `
                -Name MaxLength

            return $([Controls]::NewFieldBox(
                $Text,
                $Mandatory,
                $maxLength,
                $Default,
                'DebugWindow'
            ))
        }
        PostProcess = {
            Param ($PageInfo, $Controls, $Types, $ItemName, $Logger)

            $closure = $Logger.NewClosure(
                [PsCustomObject]@{
                    Controls = $Controls
                    ItemName = $ItemName
                },
                {
                    Param($Exception)

                    $control = $Parameters.Controls[$Parameters.ItemName]
                    $control.Text =
                        "$($control.Text)`n`n$($Exception | Out-String)"
                }
            )

            $Logger.Add($closure)
        }
    }
    View = [PsCustomObject]@{
        HasAny = $default.ContentHasAny
        GetValue = {
            $_.Content
        }
        New = {
            [OutputType([PageElementControl])]
            Param ($Item, [Controls] $Builder, $Text, $Default, $Mandatory)

            $codeBlockStyle = $true

            return $($Builder.NewLabel($Text,
                $Mandatory,
                $Default,
                $codeBlockStyle
            ))
        }
        PostProcess = {
            Param ($PageInfo, $Controls, $Types, $ItemName, $Logger)

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
& `$Parameters.GetAccessor -PageInfo `$Parameters.PageInfo -Controls `$Parameters.Controls -Types `$Parameters.Types -ElementName $name
"@

                $expression = $expression -replace $_, "`$($what)"
                $bindings += @($name)
            }

            $closure = $Logger.NewClosure(
                [PsCustomObject]@{
                    PageInfo = $PageInfo
                    Controls = $Controls
                    Types = $Types
                    ItemName = $ItemName
                    Expression = "`"$expression`""
                    GetAccessor = $getAccessor
                    Logger = $Logger
                },
                {
                    try {
                        $Parameters.Controls[$Parameters.ItemName].Content =
                            iex $Parameters.Expression

                        # todo
                        Get-Item -What
                    }
                    catch {
                        $Parameters.Logger.Log($_)
                    }
                }
            )

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
        HasAny = { $true }
        GetValue = {
            $_.IsChecked
        }
        New = {
            [OutputType([PageElementControl])]
            Param ($Item, [Controls] $Builder, $Text, $Default, $Mandatory)

            return $Builder.NewCheckBox($Text, $Default)
        }
    }
    Field = [PsCustomObject]@{
        DataTypes = @(
            [String]
        )
        HasAny = $script:default.TextHasAny
        GetValue = {
            $_.Text
        }
        New = {
            [OutputType([PageElementControl])]
            Param ($Item, [Controls] $Builder, $Text, $Default, $Mandatory)

            $maxLength = $Item | Get-PropertyOrDefault `
                -Name MaxLength

            return $($Builder.NewFieldBox(
                $Text,
                $Mandatory,
                $maxLength,
                $Default
            ))
        }
    }
    Script = [PsCustomObject]@{
        DataTypes = @(
            [String]
        )
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
            [OutputType([PageElementControl])]
            Param ($Item, [Controls] $Builder, $Text, $Default, $Mandatory)

            $maxLength = $Item | Get-PropertyOrDefault `
                -Name MaxLength

            return $($Builder.NewFieldBox(
                $Text,
                $Mandatory,
                $maxLength,
                $Default,
                'CodeBlock'
            ))
        }
    }
    Table = [PsCustomObject]@{
        DataTypes = @(
            [PsCustomObject]
            [PsCustomObject[]]
        )
        HasAny = {
            $_.SelectedItems.Count -gt 0
        }
        GetValue = {
            $_.SelectedItems
        }
        New = {
            [OutputType([PageElementControl])]
            Param ($Item, [Controls] $Builder, $Text, $Default, $Mandatory)

            $rows = $Item | Get-PropertyOrDefault `
                -Name Rows `
                -Default @()

            return $($Builder.NewTable(
                $Text,
                $Mandatory,
                $rows
            ))
        }
    }
    List = [PsCustomObject]@{
        DataTypes = @(
            [String[]]
            [Object[]]
        )
        HasAny = {
            $_.Items.Count -gt 0
        }
        GetValue = {
            $_.Items
        }
        New = {
            [OutputType([PageElementControl])]
            Param ($Item, [Controls] $Builder, $Text, $Default, $Mandatory)

            $maxCount = $Item | Get-PropertyOrDefault `
                -Name MaxCount
            $maxLength = $Item | Get-PropertyOrDefault `
                -Name MaxLength

            return $($Builder.NewListBox(
                $Text,
                $Mandatory,
                $maxCount,
                $maxLength,
                $Default
            ))
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
        New = {
            [OutputType([PageElementControl])]
            Param ($Item, [Controls] $Builder, $Text, $Default, $Mandatory)

            $places = $item | Get-PropertyOrDefault `
                -Name DecimalPlaces `
                -Default $Pref.NumericDecimalPlaces
            $min = $item | Get-PropertyOrDefault `
                -Name Minimum `
                -Default $Pref.NumericMinimum
            $max = $item | Get-PropertyOrDefault `
                -Name Maximum `
                -Default $Pref.NumericMaximum

            return $($Builder.NewSlider(
                $Text,
                $Mandatory,
                $min,
                $max,
                $places,
                $Default
            ))
        }
    }
    Enum = [PsCustomObject]@{
        DataTypes = @(
            [String[]]
            [Enum]
        )
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
                'RadioBox' {
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
            [OutputType([PageElementControl])]
            Param ($Item, [Controls] $Builder, $Text, $Default, $Mandatory)

            $as = $Item | Get-PropertyOrDefault `
                -Name As `
                -Default 'RadioBox'
            $to = $Item | Get-PropertyOrDefault `
                -Name To `
                -Default 'Key'
            $symbols = $Item | Get-PropertyOrDefault `
                -Name Symbols `
                -Default @{}

            $mySymbols =
                $symbols |
                foreach -Begin {
                    $count = 0
                } -Process {
                    $newSymbol =
                        [Controls]::GetNameAndText($_)

                    [PsCustomObject]@{
                        Id = ++$count
                        Name = $newSymbol.Name
                        Text = $newSymbol.Text
                    }
                }

            $control = $Builder."New$($as)"($Text, $Mandatory, $mySymbols, $Default)

            $object = [PsCustomObject]@{
                As = $as
                To = $to
                Object = $control.Object
                Symbols = $mySymbols
            }

            switch ($as) {
                'RadioBox' {
                    $object | Add-Member `
                        -MemberType 'ScriptMethod' `
                        -Name 'Add_Checked' `
                        -Value (
                            # [!] This closure doesn't need a logger. It's
                            # only meant to connect all of the subelements'
                            # content-changed handlers and isn't subject
                            # to refactoring.
                            New-Closure `
                                -Parameters $control.Object.Values `
                                -ScriptBlock {
                                    Param([ScriptBlock] $Handle)

                                    $Parameters | foreach {
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

