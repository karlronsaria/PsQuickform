#Requires -Assembly PresentationFramework

. $PsScriptRoot\Controls.ps1
. $PsScriptRoot\OverflowLayout.ps1

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
    [String] $Name = ''
    [Hashtable] $Controls = @{}
    [PsCustomObject[]] $MenuSpecs = @()
    $FillLayout = $null
    $StatusLine = $null

    hidden static [ScriptBlock] $BuildMultipanelPage = {
        Param($MainPanel, $Control, $Preferences)

        return Add-ControlToMultipanel `
            -Multipanel $MainPanel `
            -Control $Control `
            -Preferences $Preferences
    }

    hidden static [ScriptBlock] $BuildScrollPanelPage = {
        Param($MainPanel, $Control, $Preferences)

        return Add-ControlToScrollPanel `
            -ScrollPanel $MainPanel `
            -Control $Control `
            -Preferences $Preferences
    }

    Page(
        [System.Windows.Window] $Window,
        [PsCustomObject] $Preferences,
        [PsCustomObject[]] $MenuSpecs,
        [String] $Type
    ) {
        $this.MenuSpecs = $MenuSpecs

        $Preferences = Get-QformPreference `
            -Preferences $Preferences.PsObject.Copy()

        $buildPage = switch ($Type) {
            'Multipanel' {
                [Page]::BuildMultipanelPage
            }
            'ScrollPanel' {
                [Page]::BuildScrollPanelPage
            }
        }

        $what = Get-QformMainLayout `
            -Window $Window `
            -MenuSpecs $MenuSpecs `
            -Preferences $Preferences `
            -AddLines @('StatusLine') `
            -AddToMainPanel $buildPage

        $this.Controls = $what.Controls
        $this.FillLayout = $what.FillLayout
        $this.StatusLine = $what.StatusLine
    }

    Page(
        [System.Windows.Window] $Window,
        $ParameterSet,
        $Preferences,
        [Switch] $IncludeCommonParameters,
        [Switch] $IgnoreLists,
        [String] $Type
    ) {
        $this.Name = $ParameterSet.Name

        $this.MenuSpecs = $ParameterSet.Parameters | Where-Object {
            $IncludeCommonParameters `
                -or -not (Test-IsCommonParameter -ParameterInfo $_)
        } | ForEach-Object {
            ConvertTo-QformParameter `
                -ParameterInfo $_ `
                -IgnoreLists:$IgnoreLists
        }

        $Preferences = Get-QformPreference `
            -Preferences $Preferences.PsObject.Copy()

        $buildPage = switch ($Type) {
            'Multipanel' {
                [Page]::BuildMultipanelPage
            }
            'ScrollPanel' {
                [Page]::BuildScrollPanelPage
            }
        }

        $what = Get-QformMainLayout `
            -Window $Window `
            -MenuSpecs $this.MenuSpecs `
            -Preferences $Preferences `
            -AddLines @('StatusLine', 'PageLine') `
            -AddToMainPanel $buildPage

        $this.Controls = $what.Controls
        $this.FillLayout = $what.FillLayout
        $this.StatusLine = $what.StatusLine
    }
}

function Get-QformLayout {
    [OutputType([Hashtable])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline = $true)]
        [PsCustomObject[]]
        $MenuSpecs,

        [System.Windows.Window]
        $Window,

        [System.Windows.Controls.Label]
        $StatusLine,

        [PsCustomObject]
        $Preferences
    )

    Begin {
        $mandates = @()
        $list = @()
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

            $what = switch ($item.Type) {
                'Check' {
                    New-ControlsCheckBox `
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

                    New-ControlsFieldBox `
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

                    New-ControlsRadioBox `
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

                    New-ControlsSlider `
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

                    New-ControlsListBox `
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
                        -Default @();

                    New-ControlsTable `
                        -Text $text `
                        -Mandatory:$mandatory `
                        -Rows $rows `
                        -Preferences $Preferences
                }
            }

            if ($mandatory) {
                $mandates += @([PsCustomObject]@{
                    Type = $item.Type
                    Control = $what.Object
                })
            }

            $list += @([PsCustomObject]@{
                Name = $item.Name
                Container = $what.Container
                Object = $what.Object
            })
        }
    }

    End {
        $what = New-ControlsOkCancelButtons `
            -Preferences $Preferences

        $list += @([PsCustomObject]@{
            Name = '__EndButtons__'
            Container = $what.Container
            Object = $what.Object
        })

        $endButtons = $what.Object

        $endButtons.CancelButton.Add_Click(( `
            New-Closure `
                -InputObject $Window `
                -ScriptBlock {
                    $InputObject.DialogResult = $false
                    $InputObject.Close()
                } `
        ))

        $action = if ($mandates.Count -eq 0) {
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
                                $object.Control.Items.Count -gt 0
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
        return $list
    }
}

function Get-QformMainLayout {
    Param(
        [System.Windows.Window]
        $Window,

        [PsCustomObject[]]
        $MenuSpecs,

        [PsCustomObject]
        $Preferences,

        [ValidateSet('StatusLine', 'PageLine')]
        [String[]]
        $AddLines = @('StatusLine'),

        [ScriptBlock]
        $AddToMainPanel
    )

    $controls = @{}
    $lineNames = @()
    $statusLine = $null

    foreach ($lineName in $AddLines) {
        if ($lineName -in $lineNames) {
            continue
        }

        $line = New-Control Label

        if ($lineName -eq 'StatusLine') {
            $statusLine = $line

            Set-ControlsStatus `
                -StatusLine $statusLine `
                -LineName 'Idle'
        }

        $lineNames += @($lineName)
        $controls.Add("__$($lineName)__", $line)
    }

    $mainPanel = $null

    $MenuSpecs `
        | Get-QformLayout `
            -Window $Window `
            -StatusLine $statusLine `
            -Preferences $Preferences `
        | foreach {
            $mainPanel = & $AddToMainPanel `
                -MainPanel $mainPanel `
                -Control $_.Container `
                -Preferences $Preferences

            $controls.Add($_.Name, $_.Object)
        }

    $container = $mainPanel.Container

    # Resolve a possible race condition
    while ($null -eq $container) { }

    $fillLayout = New-Control StackPanel
    $fillLayout.AddChild($container)

    foreach ($lineName in $lineNames) {
        $fillLayout.AddChild($controls["__$($lineName)__"])
    }

    return [PsCustomObject]@{
        FillLayout = $fillLayout
        Controls = $controls
        StatusLine = $statusLine
    }
}

class Qform {
    $Main = $null
    $CurrentIndex = $null
    $DefaultIndex = $null
    $Pages = @()
    $InfoLines = @('PageLine', 'StatusLine')
    $PageLine = $false
    $Caption = ''
    $TabControl = $null

    hidden static [ScriptBlock] $UpdateGrid = {
        Param([Qform] $Qform, [Int] $Index)
        $Qform.Main.Grid.Children.Clear()
        $Qform.Main.Grid.AddChild($Qform.Pages[$Index].FillLayout)
    }

    hidden static [ScriptBlock] $UpdateTabControl = {
        Param([Qform] $Qform, [Int] $Index)
        $Qform.TabControl.SelectedIndex = $Index
    }

    hidden static [ScriptBlock] $AddPageToGrid = {
        Param([Qform] $Qform, [Page] $Page)
        $Qform.Pages += @($Page)
    }

    hidden static [ScriptBlock] $AddPageToTabControl = {
        Param([Qform] $Qform, [Page] $Page)
        $Qform.Pages += @($Page)

        Add-ControlsTabItem `
            -TabControl $Qform.TabControl `
            -Control $Page.FillLayout `
            -Header $Page.Name
    }

    hidden [ScriptBlock] $MyUpdate
    hidden [ScriptBlock] $MyAddPage

    hidden [void] InitTabControl() {
        $this.PageLine = $false
        $this.TabControl = New-Control TabControl
        $this.AddToMainGrid($this.TabControl)
        $this.MyUpdate = [Qform]::UpdateTabControl
        $this.MyAddPage = [Qform]::AddPageToTabControl
    }

    hidden [void] InitRefreshControl() {
        $this.PageLine = $this.PageLine
        $this.MyUpdate = [Qform]::UpdateGrid
        $this.MyAddPage = [Qform]::AddPageToGrid
    }

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

    [Hashtable] Controls() {
        return $this.Pages[$this.CurrentIndex].Controls
    }

    [PsCustomObject[]] MenuSpecs() {
        return $this.Pages[$this.CurrentIndex].MenuSpecs
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

    [void] AddToMainGrid($Control) {
        $this.Main.Grid.AddChild($Control)
    }

    [void] Update([Int] $Index) {
        $this.MyUpdate.Invoke($this, $Index)
    }

    [void] AddPage([Page] $Page) {
        $this.MyAddPage.Invoke($this, $Page)
    }

    hidden [void] SetPageLine() {
        $page = $this.Pages[$this.CurrentIndex]
        $control = $page.Controls['__PageLine__']
        $control.HorizontalAlignment = 'Center'

        $control.Content =
            [Qform]::GetPageLine(
                $this.CurrentIndex,
                $this.Pages.Count,
                $page.Name
            )
    }

    [void] SetPage([Int] $Index) {
        $this.Update($Index)

        if ($this.PageLine) {
            $this.SetPageLine()
        }

        $this.Main.Window.Focus()
    }

    static [Qform] SinglePage(
        [PsCustomObject] $Preferences,
        [PsCustomObject[]] $MenuSpecs
    ) {
        return [Qform]::new($Preferences, $MenuSpecs, $false)
    }

    static [Qform] CmdletGridForm(
        [PsCustomObject] $Preferences,
        $CommandInfo,
        [String] $ParameterSetName,
        [Boolean] $IncludeCommonParameters,
        [Boolean] $IgnoreLists
    ) {
        return [Qform]::new(
            $Preferences,
            $CommandInfo,
            $ParameterSetName,
            $IncludeCommonParameters,
            $IgnoreLists,
            $false
        )
    }

    static [Qform] CmdletTabForm(
        [PsCustomObject] $Preferences,
        $CommandInfo,
        [String] $ParameterSetName,
        [Boolean] $IncludeCommonParameters,
        [Boolean] $IgnoreLists
    ) {
        return [Qform]::new(
            $Preferences,
            $CommandInfo,
            $ParameterSetName,
            $IncludeCommonParameters,
            $IgnoreLists,
            $true
        )
    }

    Qform(
        [PsCustomObject] $Preferences,
        [PsCustomObject[]] $MenuSpecs,
        [Boolean] $IsTabControl
    ) {
        $this.PageLine = $false
        $this.CurrentIndex =
            $this.DefaultIndex = 0

        $this.Main = New-ControlsMain

        if ($IsTabControl) {
            $this.InitTabControl()
        }
        else {
            $this.InitRefreshControl()
        }

        $page = [Page]::new(
            $this.Main.Window,
            $Preferences.PsObject.Copy(),
            $MenuSpecs,
            'ScrollPanel'
        )

        $this.AddPage($page)
        $this.Main.Window.Title = $Preferences.Caption
        $this.InitKeyBindings()
    }

    Qform(
        [PsCustomObject] $Preferences,
        $CommandInfo,
        [String] $ParameterSetName,
        [Boolean] $IncludeCommonParameters,
        [Boolean] $IgnoreLists,
        [Boolean] $IsTabControl
    ) {
        $this.PageLine = $true
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

        $this.Main = New-ControlsMain

        if ($IsTabControl) {
            $this.InitTabControl()
        }
        else {
            $this.InitRefreshControl()
        }

        foreach ($parameterSet in $parameterSets) {
            $page = [Page]::new(
                $this.Main.Window,
                $parameterSet,
                $Preferences,
                $IncludeCommonParameters,
                $IgnoreLists,
                'ScrollPanel'
            )

            $this.AddPage($page)
        }

        if ($null -ne $this.Pages -and $this.Pages.Count -gt 0) {
            $closure = New-Closure `
                -InputObject $this `
                -ScriptBlock {
                    $refresh = $false
                    $isKeyCombo = [System.Windows.Input.Keyboard]::Modifiers `
                        -and [System.Windows.Input.ModifierKeys]::Alt

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
                }

            $this.Main.Window.Add_KeyDown($closure)
        }

        $this.Main.Window.Title = $Preferences.Caption
        $this.InitKeyBindings()
    }

    hidden [void] InitKeyBindings() {
        $prefs = $this.Pages[$this.CurrentIndex].Preferences

        if ($prefs.EnterToConfirm) {
            $this.Main.Window.Add_KeyDown({
                if ($_.Key -eq 'Enter') {
                    $this.DialogResult = $true
                    $this.Close()
                }
            })
        }

        if ($prefs.EscapeToCancel) {
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

