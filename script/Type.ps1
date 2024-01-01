# New: all return:
#   - controlsType
#     - container
#     - object

. $PsScriptRoot\Controls.ps1

$script:default = [PsCustomObject]@{
    Type = 'Script'
    ContentHasAny = {
        -not [String]::IsNullOrEmpty(
            $_.Control.Content
        )
    }
    TextHasAny = {
        -not [String]::IsNullOrEmpty(
            $_.Control.Text
        )
    }
}

$types = [PsCustomObject]@{
Default = $script:default.PsObject.Copy()
Table = [PsCustomObject]@{
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
        HasAny = {
            $_.Control.SelectedItems.Count -gt 0
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
        HasAny = {
            $_.Control.Items.Count -gt 0
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
        HasAny = { $true }
        GetValue = {
            # This is a filter script block, not a function script block.
            # Filters need to specify 'Script' scope, because filter commands
            # like 'ForEach-Object' and 'Where-Object' share scope with the
            # outer block. Otherwise, binding an '$item' in this block will
            # affect other '$item' bindings outside the block.

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

            [PsCustomObject]@{
                Container = $control.Container
                Object = [PsCustomObject]@{
                    As = $as
                    To = $to
                    Object = $control.Object
                    Symbols = $params['Symbols']
                }
            }
        }
    }
}
}

