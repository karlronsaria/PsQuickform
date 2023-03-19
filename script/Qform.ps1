#Requires -Assembly PresentationFramework

. $PsScriptRoot\Controls.ps1

<#
    .SYNOPSIS
    Identifies the menu control type used to process a given PowerShell type.

    .PARAMETER TypeName
    The name of a PowerShell type.

    .OUTPUTS
        System.String
            The accepted name of a Quickform menu control.

        System.Collections.Hashtable
            When no TypeName is specified, a table containing all pairs of
            PowerShell type patterns and their respective Quickform menu
            controls. Pattern '_' means default.
#>
function Get-QformControlType {
    [OutputType([String])]
    [OutputType([Hashtable])]
    Param(
        [String]
        $TypeName,

        [Switch]
        $IgnoreLists
    )

    $defaultName = '_'
    $listPattern = '.*\[\]$'

    $table = [PsCustomObject]@{
        '^PsCustomObject\[\]$' = 'Table'
        $listPattern = 'List'
        '^String$' = 'Field'
        '^Int.*$' = 'Numeric'
        '^Decimal$' = 'Numeric'
        '^Double$' = 'Numeric'
        '^Float$' = 'Numeric'
        '^Switch.*$' = 'Check'
        '^Bool.*$' = 'Check'
        $defaultName = 'Field'
    }

    if ([String]::IsNullOrWhiteSpace($TypeName)) {
        return $table
    }

    foreach ($property in $table.PsObject.Properties) {
        if ($TypeName -match $property.Name) {
            if ($IgnoreLists -and $property.Name -eq $listPattern) {
                continue
            }

            return $property.Value
        }
    }

    return $table.$defaultName
}

function ConvertTo-QformParameter {
    Param(
        $ParameterInfo,

        [Switch]
        $IgnoreLists
    )

    $type = $ParameterInfo.ParameterType
    $validators = Get-FieldValidators -ParameterInfo $ParameterInfo
    $validatorType = $null

    $obj = [PsCustomObject]@{
        Name = $ParameterInfo.Name
        Type = ''
    }

    if ($validators) {
        $validatorType = $validators.Type

        switch ($validatorType) {
            'Enum' {
                $obj.Type = 'Enum'

                $values = $validators.Values.Name | Where-Object {
                    $_ -ne 'value__'
                }

                $obj | Add-Member `
                    -MemberType NoteProperty `
                    -Name Symbols `
                    -Value ($values | ForEach-Object {
                        [PsCustomObject]@{
                            Name = $_
                        }
                    })
            }

            'ValidSet' {
                $obj.Type = 'Enum'
                $values = $validators.Values

                $obj | Add-Member `
                    -MemberType NoteProperty `
                    -Name Symbols `
                    -Value ($values | ForEach-Object {
                        [PsCustomObject]@{
                            Name = $_
                        }
                    })
            }

            'ValidRange' {
                $obj.Type = 'Numeric'

                $obj | Add-Member `
                    -MemberType NoteProperty `
                    -Name Minimum `
                    -Value $validators.Minimum

                $obj | Add-Member `
                    -MemberType NoteProperty `
                    -Name Maximum `
                    -Value $validators.Maximum
            }

            'ValidCount' {
                $obj | Add-Member `
                    -MemberType NoteProperty `
                    -Name MinCount `
                    -Value $validators.Minimum

                $obj | Add-Member `
                    -MemberType NoteProperty `
                    -Name MaxCount `
                    -Value $validators.Maximum
            }

            'ValidLength' {
                $obj | Add-Member `
                    -MemberType NoteProperty `
                    -Name MinLength `
                    -Value $validators.Minimum

                $obj | Add-Member `
                    -MemberType NoteProperty `
                    -Name MaxLength `
                    -Value $validators.Maximum
            }
        }
    }

    if ($obj.Type -eq '') {
        $obj.Type = Get-QformControlType `
            -TypeName $type.Name `
            -IgnoreLists:$IgnoreLists
    }

    return $obj
}

<#
    .SYNOPSIS
    Gets a list of valid names associated with a certain resource object.
    Call

        Get-QformResource -Type Object

    to get a list of available resource types.

    .PARAMETER Type
    A type of resource.

    .INPUTS
        System.String[]
            Pipeline accepts any number of resource types.

    .OUTPUTS
        PsCustomObject[]
            All properties associated with a given resource type.
#>
function Get-QformResource {
    Param(
        [Parameter(ValueFromPipeline = $true)]
        [ValidateSet('Object', 'Preference', 'MenuSpec')]
        [String[]]
        $Type
    )

    Begin {
        $masterObj = Get-Content `
            -Path "$PsScriptRoot/../res/properties.json" `
        | ConvertFrom-Json
    }

    Process {
        foreach ($item in $Type) {
            $masterObj."$($Type)s"
        }
    }
}

<#
    .SYNOPSIS
    Builds a set of Quickform menu preferences using a set of supplemental
    default values.

    .PARAMETER Preferences
    An object containing the specifications for customizing the look and default
    behavior of a Quickform menu.

    .INPUTS
        PsCustomObject
            Pipeline accepts Quickform menu preferences.

    .OUTPUTS
        PsCustomObject
            An object containing Quickform menu preferences.
#>
function Get-QformPreference {
    [OutputType([PsCustomObject])]
    [CmdletBinding(DefaultParameterSetName = 'BuildNewObject')]
    Param(
        [Parameter(
            ParameterSetName = 'BuildNewObject',
            ValueFromPipeline = $true
        )]
        [PsCustomObject]
        $Preferences,

        [Parameter(
            ParameterSetName = 'QueryValues'
        )]
        [ArgumentCompleter(
            {
                (Get-QformResource -Type Preference).Name
            }
        )]
        [ValidateScript(
            {
                $_ -in (Get-QformResource -Type Preference).Name
            }
        )]
        [String[]]
        $Name
    )

    Begin {
        $defaultPreferences =
            Get-Content "$PsScriptRoot/../res/preference.json" `
                | ConvertFrom-Json
    }

    Process {
        switch ($PsCmdlet.ParameterSetName) {
            'BuildNewObject' {
                if (-not $Preferences) {
                    return $defaultPreferences.PsObject.Copy()
                }

                $myPreferences = $defaultPreferences.PsObject.Copy()
                $names = $Preferences.PsObject.Properties.Name

                if ($Preferences) {
                    $myProperties = $myPreferences `
                        | Get-Member `
                        | Where-Object {
                            $_.MemberType -like 'NoteProperty'
                        }

                    foreach ($property in $names) {
                        if ($property -notin $myProperties.Name) {
                            $myPreferences | Add-Member `
                                -MemberType 'NoteProperty' `
                                -Name $property `
                                -Value $Preferences.$property
                        }
                        else {
                            $myPreferences.$property = $Preferences.$property
                        }
                    }
                }

                return $myPreferences
            }

            'QueryValues' {
                foreach ($item in $Name) {
                    [PsCustomObject]@{
                        Name = $item
                        Value = $defaultPreferences.$item
                    }
                }
            }
        }
    }
}

class Page {
    $Name = ''
    $Preferences = @{}
    $MenuSpecs = @()

    Page(
        [PsCustomObject] $Preferences,
        [PsCustomObject[]] $MenuSpecs
    ) {
        $this.Preferences = $Preferences
        $this.MenuSpecs = $MenuSpecs
    }

    Page(
        $ParameterSet,
        $Preferences,
        [Switch] $IncludeCommonParameters,
        [Switch] $IgnoreLists
    ) {
        $this.Preferences = $Preferences.PsObject.Copy()
        $this.Name = $ParameterSet.Name
        $this.MenuSpecs = $ParameterSet.Parameters | Where-Object {
            $IncludeCommonParameters `
                -or -not (Test-IsCommonParameter -ParameterInfo $_)
        } | ForEach-Object {
            ConvertTo-QformParameter `
                -ParameterInfo $_ `
                -IgnoreLists:$IgnoreLists
        }
    }
}

function Set-QformLayout {
    [OutputType([Hashtable])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline = $true)]
        [PsCustomObject[]]
        $MenuSpecs,

        [PsCustomObject]
        $PageControl,

        [System.Windows.Window]
        $Window,

        [System.Windows.Controls.Label]
        $StatusLine,

        [PsCustomObject]
        $Preferences
    )

    Begin {
        $controlTable = @{}
        $script:mandates = @()
    }

    Process {
        foreach ($item in $MenuSpecs) {
            $default = Get-PropertyOrDefault `
                -InputObject $item `
                -Name 'Default'

            $text = Get-PropertyOrDefault `
                -InputObject $item `
                -Name 'Text' `
                -Default $item.Name

            $mandatory = $false

            $value = switch ($item.Type) {
                'Check' {
                    Add-ControlsCheckBox `
                        -PageControl $PageControl `
                        -Text $text `
                        -Default $default `
                        -Preferences $Preferences
                }

                'Field' {
                    $maxLength = $item | Get-PropertyOrDefault `
                        -Name MaxLength;
                    $mandatory = $item | Get-PropertyOrDefault `
                        -Name Mandatory `
                        -Default $false;

                    Add-ControlsFieldBox `
                        -PageControl $PageControl `
                        -Text $text `
                        -Mandatory:$mandatory `
                        -MaxLength $maxLength `
                        -Default $default `
                        -Preferences $Preferences
                }

                'Enum' {
                    $mandatory = $item | Get-PropertyOrDefault `
                        -Name Mandatory `
                        -Default $false;

                    Add-ControlsRadioBox `
                        -PageControl $PageControl `
                        -Text $text `
                        -Mandatory:$mandatory `
                        -Symbols $item.Symbols `
                        -Default $default `
                        -Preferences $Preferences

                    # Mandatory enumerations are self-managed. They either do
                    # or don't implement 'None'.
                    $mandatory = $false
                }

                'Numeric' {
                    $places = $item | Get-PropertyOrDefault `
                        -Name DecimalPlaces `
                        -Default $Preferences.NumericDecimalPlaces;
                    $min = $item | Get-PropertyOrDefault `
                        -Name Minimum `
                        -Default $Preferences.NumericMinimum;
                    $max = $item | Get-PropertyOrDefault `
                        -Name Maximum `
                        -Default $Preferences.NumericMaximum;
                    $mandatory = $item | Get-PropertyOrDefault `
                        -Name Mandatory `
                        -Default $false;

                    Add-ControlsSlider `
                        -PageControl $PageControl `
                        -Text $text `
                        -Mandatory:$mandatory `
                        -DecimalPlaces $places `
                        -Minimum $min `
                        -Maximum $max `
                        -Default $default `
                        -StatusLine $StatusLine `
                        -Preferences $Preferences
                }

                'List' {
                    $maxCount = $item | Get-PropertyOrDefault `
                        -Name MaxCount;
                    $maxLength = $item | Get-PropertyOrDefault `
                        -Name MaxLength;
                    $mandatory = $item | Get-PropertyOrDefault `
                        -Name Mandatory `
                        -Default $false;

                    Add-ControlsListBox `
                        -PageControl $PageControl `
                        -Text $text `
                        -Mandatory:$mandatory `
                        -MaxCount $maxCount `
                        -MaxLength $maxLength `
                        -Default $default `
                        -StatusLine $StatusLine `
                        -Preferences $Preferences
                }

                'Table' {
                    $mandatory = $item | Get-PropertyOrDefault `
                        -Name Mandatory `
                        -Default $false;
                    $rows = $item | Get-PropertyOrDefault `
                        -Name Rows `
                        -Default @()

                    Add-ControlsTable `
                        -PageControl $PageControl `
                        -Text $text `
                        -Mandatory:$mandatory `
                        -Rows $rows `
                        -Preferences $Preferences
                }
            }

            $controlTable.Add($item.Name, $value)

            if ($mandatory) {
                $script:mandates += @([PsCustomObject]@{
                    Type = $item.Type
                    Control = $value
                })
            }
        }
    }

    End {
        $endButtons = Add-ControlsOkCancelButtons `
            -PageControl $PageControl `
            -Preferences $Preferences

        $endButtons.CancelButton.Add_Click(( `
            New-Closure `
                -InputObject $Window `
                -ScriptBlock {
                    $InputObject.DialogResult = $false
                    $InputObject.Close()
                } `
        ))

        $action = if ($script:mandates.Count -eq 0) {
            New-Closure `
                -InputObject $Window `
                -ScriptBlock {
                    $InputObject.DialogResult = $true
                    $InputObject.Close()
                }
        } else {
            $parameters = [PsCustomObject]@{
                Window = $Window
                Mandates = $mandates
                StatusLine = $StatusLine
            }

            New-Closure `
                -InputObject $parameters `
                -ScriptBlock {
                    $mandatesSet = $true

                    foreach ($object in $InputObject.Mandates) {
                        $itemIsSet = switch -Regex ($object.Type) {
                            'List' {
                                $object.Items.Count -gt 0
                            }

                            'Table' {
                                $object.Control.SelectedItems.Count -gt 0
                            }

                            'Field|Numeric' {
                                -not [String]::IsNullOrEmpty(
                                    $object.Control.Text
                                )
                            }

                            default {
                                -not [String]::IsNullOrEmpty(
                                    $object.Control.Content
                                )
                            }
                        }

                        $mandatesSet = $mandatesSet -and $itemIsSet
                    }

                    if ($mandatesSet) {
                        $InputObject.Window.DialogResult = $true
                        $InputObject.Window.Close()
                    }
                    else {
                        . $PsScriptRoot\Controls.ps1

                        Set-ControlsStatus `
                            -StatusLine $InputObject.StatusLine `
                            -LineName 'MandatoryValuesNotSet'
                    }
                }
        }

        $endButtons.OkButton.Add_Click($action)
        $controlTable.Add('__EndButtons__', $endButtons)

        foreach ($key in $controlTable.Keys) {
            $PageControl.Controls.Add($key, $controlTable[$key])
        }

        return $PageControl
    }
}

function Set-QformMainLayout {
    Param(
        [PsCustomObject]
        $MainForm,

        [PsCustomObject[]]
        $MenuSpecs,

        [PsCustomObject]
        $Preferences,

        [ValidateSet('StatusLine', 'PageLine')]
        [String[]]
        $AddLines = @('StatusLine')
    )

    $MainForm.Grid.Children.Clear()

    $pageControl = New-ControlsMultilayout `
        -Preferences $Preferences

    $lineNames = @()
    $statusLine = $null

    foreach ($lineName in $AddLines) {
        if ($lineName -in $lineNames) {
            continue
        }

        $line = New-Control Label

        if ($lineName -eq 'StatusLine') {
            $statusLine = $line
        }

        $lineNames += @($lineName)
        $pageControl.Controls.Add("__$($lineName)__", $line)
    }

    # todo
    $pageControl = $MenuSpecs | Set-QformLayout `
        -Window $MainForm.Window `
        -PageControl $pageControl `
        -StatusLine $statusLine `
        -Preferences $Preferences

    $MainForm.Window.Title = $Preferences.Caption

    # Resolve a possible race condition
    while ($null -eq $pageControl.Multilayout) { }

# todo: start somewhere around here

    $fillLayout = New-Control StackPanel
    $fillLayout.AddChild($pageControl.Multilayout)

    foreach ($lineName in $lineNames) {
        $fillLayout.AddChild($pageControl.Controls["__$($lineName)__"])
    }

    if ('StatusLine' -in $lineNames) {
        Set-ControlsStatus `
            -StatusLine $statusLine `
            -LineName 'Idle'
    }

    $MainForm.Grid.AddChild($fillLayout)

    return [PsCustomObject]@{
        MainForm = $MainForm
        PageControl = $pageControl
        StatusLine = $statusLine
    }
}

class Qform {
    $Main
    $PageControl
    $CurrentIndex = $null
    $DefaultIndex = $null
    $Pages = @()
    $InfoLines = @('PageLine', 'StatusLine')
    $PageLine = $false

    static [Int] FindDefaultParameterSet($CommandInfo) {
        $index = 0

        $name = $CommandInfo | Get-PropertyOrDefault `
            -Name DefaultParameterSet `
            -Default ''

        if (-not $name) {
            return -1
        }

        while ( `
            $index -lt $CommandInfo.ParameterSets.Count `
            -and $CommandInfo.ParameterSets[$index].Name -ne $name `
        ) { $index++ }

        return $index
    }

    static [String] GetPageLine($Index, $Count, $Name) {
        return "ParameterSet $($Index + 1) of $Count`: $Name"
    }

    [void] Next() {
        $this.CurrentIndex =
            if ($this.CurrentIndex -ge $this.Pages.Count - 1) {
                0
            } else {
                $this.CurrentIndex + 1
            }
    }

    [void] Previous() {
        $this.CurrentIndex =
            if ($this.CurrentIndex -le 0) {
                $this.Pages.Count - 1
            } else {
                $this.CurrentIndex - 1
            }
    }

    [void] SetPage([Int] $Index) {
        $page = $this.Pages[$Index]

        $page.Preferences = Get-QformPreference `
            -Preferences $page.Preferences

        $pageInfo = Set-QformMainLayout `
            -MainForm $this.Main `
            -MenuSpecs $page.MenuSpecs `
            -Preferences $page.Preferences `
            -AddLines $this.InfoLines

        $this.PageControl = $pageInfo.PageControl

        if ($this.PageLine) {
            $control = $this.PageControl.Controls['__PageLine__']
            $control.Content =
                [Qform]::GetPageLine($Index, $this.Pages.Count, $page.Name)
            $control.HorizontalAlignment = 'Center'
        }

        $this.Main.Window.Focus()
    }

    Qform(
        [PsCustomObject] $Preferences,
        [PsCustomObject[]] $MenuSpecs
    ) {
        $this.PageLine = $false
        $this.InfoLines = @('StatusLine')
        $this.CurrentIndex =
            $this.DefaultIndex = 0

        $myPrefs = $Preferences.PsObject.Copy()

        $this.Pages = @(
            [Page]::new(
                $myPrefs,
                $MenuSpecs
            )
        )

        $this.Main = New-ControlsMain `
            -Preferences $myPrefs

        $this.InitKeyDownEventHandlers()
    }

    Qform(
        [PsCustomObject] $Preferences,
        $CommandInfo,
        [String] $ParameterSetName,
        [Boolean] $IncludeCommonParameters,
        [Boolean] $IgnoreLists
    ) {
        $this.PageLine = $true
        $myPrefs = $Preferences.PsObject.Copy()
        $parameterSets = $CommandInfo.ParameterSets

        if ($ParameterSetName) {
            $parameterSets = $parameterSets | Where-Object {
                $_.Name -like $ParameterSetName
            }
        }

        # TODO: consider revising as failable type
        if (-not $parameterSets) {
            throw "No parameter sets could be found $(
                if ($ParameterSetName) { "matching '$ParameterSetName' " }
            )for command name '$($CommandInfo.Name)'"
        }

        $index = [Qform]::FindDefaultParameterSet($CommandInfo)

        $this.CurrentIndex =
        $this.DefaultIndex =
            if ($index -ge 0 -and $index -lt $parameterSets.Count) {
                $index
            } else {
                0
            }

        $this.Pages = $parameterSets | ForEach-Object {
            [Page]::new(
                $_,
                $myPrefs.PsObject.Copy(),
                $IncludeCommonParameters,
                $IgnoreLists
            )
        }

        if ($null -eq $this.Pages -or $this.Pages.Count -eq 0) {
            $this.Main = Get-QformMenu
        }
        else {
            $this.Main = New-ControlsMain `
                -Preferences $myPrefs

            # issue: Event handler fails to update variable from outer scope
            # link:
            # - url: https://stackoverflow.com/questions/55403528/why-wont-variable-update
            # - retreived: 2022_03_02

            $closure = New-Closure `
                -InputObject $this `
                -ScriptBlock {
                    $refresh = $false
                    $isKeyCombo = [System.Windows.Input.Keyboard]::Modifiers `
                        -and [System.Windows.Input.ModifierKeys]::Alt

# todo: switch to tab control
# start
                    if ($isKeyCombo) {
                        if ([System.Windows.Input.Keyboard]::IsKeyDown(
                            'Right'
                        )) {
                            $InputObject.Next()
                            $refresh = $true
                        }

                        if ([System.Windows.Input.Keyboard]::IsKeyDown(
                            'Left'
                        )) {
                            $InputObject.Previous()
                            $refresh = $true
                        }
                    }

                    if ($refresh) {
                        $InputObject.SetPage($InputObject.CurrentIndex)
                    }
# end
                }

            $this.Main.Window.Add_KeyDown($closure)
        }

        $this.InitKeyDownEventHandlers()
    }

    [void] InitKeyDownEventHandlers() {
        $myPrefs = $this.Pages[$this.CurrentIndex].Preferences

        if ($myPrefs.EnterToConfirm) {
            $this.Main.Window.Add_KeyDown({
                if ($_.Key -eq 'Enter') {
                    $this.DialogResult = $true
                    $this.Close()
                }
            })
        }

        if ($myPrefs.EscapeToCancel) {
            $this.Main.Window.Add_KeyDown({
                if ($_.Key -eq 'Escape') {
                    $this.DialogResult = $false
                    $this.Close()
                }
            })
        }

        $helpMessage = ( `
            Get-Content `
                "$PsScriptRoot/../res/text.json" `
                | ConvertFrom-Json `
        ).Help

        $helpMessage = $helpMessage -Join "`r`n"

        $closure = New-Closure `
            -InputObject $helpMessage `
            -ScriptBlock {
                $isKeyCombo =
                    $_.Key -eq [System.Windows.Input.Key]::OemQuestion `
                    -and $_.KeyboardDevice.Modifiers `
                        -eq [System.Windows.Input.ModifierKeys]::Control

                if ($isKeyCombo) {
                    [System.Windows.MessageBox]::Show($InputObject, 'Help')
                }
            }

        $this.Main.Window.Add_KeyDown($closure)
    }

    [Boolean] ShowDialog() {
        $this.SetPage($this.CurrentIndex)
        return $this.Main.Window.ShowDialog()
    }
}

