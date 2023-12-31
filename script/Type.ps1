# New: all return:
#   - controlsType
#     - container
#     - object

$default =
[PsCustomObject]@{
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

$table =
[PsCustomObject]@{
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
            Param ($Item, $Pref, $Label, $Text, $Default, $Mandatory)

            . "$PsScriptRoot/Controls.ps1"

            New-ControlsCheckBox `
                -Text $Text `
                -Default $Default
        }
    }
    Field = [PsCustomObject]@{
        DataTypes = @(
            [String]
        )
        HasAny = $default.TextHasAny
        GetValue = {
            $_.Text
        }
        New = {
            Param ($Item, $Pref, $Label, $Text, $Default, $Mandatory)

            . "$PsScriptRoot/Controls.ps1"

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
        HasAny = $default.TextHasAny
        GetValue = {
            $text = $_.Text

            $(if ([String]::IsNullOrWhiteSpace($text)) {
                ""
            }
            else {
                Invoke-Expression $text
            })
        }
        New = {
            Param ($Item, $Pref, $Label, $Text, $Default, $Mandatory)

            . "$PsScriptRoot/Controls.ps1"

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
            Param ($Item, $Pref, $Label, $Text, $Default, $Mandatory)

            . "$PsScriptRoot/Controls.ps1"

            $rows = $Item | Get-PropertyOrDefault `
                -Name Rows `
                -Default @()

            New-ControlsTable `
                -Text $InputObject.Text `
                -Mandatory:$Mandatory `
                -Rows $rows `
                -Margin $Preferences.Margin
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
            Param ($Item, $Pref, $Label, $Text, $Default, $Mandatory)

            . "$PsScriptRoot/Controls.ps1"

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
        HasAny = $default.TextHasAny
        GetValue = {
            $_.Value
        }
        New = {
            Param ($Item, $Pref, $Label, $Text, $Default, $Mandatory)

            . "$PsScriptRoot/Controls.ps1"

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
            $item = $_

            switch ($item.As) {
                'RadioPanel' {
                    $buttons = $item.Object

                    if (-not $buttons) {
                        return
                    }

                    $($buttons.Keys |
                    where {
                        $buttons[$_].IsChecked
                    } |
                    foreach {
                        $name = $_

                        $(switch ($item.To) {
                            'Key' { $name }

                            'Value' {
                                $item.Symbols |
                                where { $_.Name -eq $name } |
                                foreach { $_.Text }
                            }

                            'Pair' {
                                $item.Symbols |
                                where { $_.Name -eq $name }
                            }
                        })
                    })
                }

                'DropDown' {
                    $($obj.Object.SelectedIndex |
                    foreach {
                        $index = $_
                        $symbol = $item.Symbols[$_]

                        $(switch ($item.To) {
                            'Key' {
                                $symbol.Name
                            }

                            'Value' {
                                $symbol.Text
                            }

                            'Pair' {
                                [PsCustomObject]@{
                                    Id = $index + 1
                                    Name = $symbol.Name
                                    Text = $symbol.Text
                                }
                            }
                        })
                    })
                }
            }
        }
        New = {
            Param ($Item, $Pref, $Label, $Text, $Default, $Mandatory)

            . "$PsScriptRoot/Controls.ps1"

            $as = $Item | Get-PropertyOrDefault `
                -Name As `
                -Default 'RadioPanel'
            $to = $Item | Get-PropertyOrDefault `
                -Name To `
                -Default 'Key'
            $symbols = $Item | Get-PropertyOrDefault `
                -Name Symbols `
                -Default @{}

            # todo: Why is this an [Ordered]?
            $params = [Ordered]@{
                Text = $Text
                Mandatory = $Mandatory
                Symbols =
                    $symbols |
                    foreach -Begin {
                        $count = 0
                    } -Process {
                        $newSymbol = Get-ControlsNameAndText $_

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












