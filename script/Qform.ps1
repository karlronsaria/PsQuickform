#Requires -Assembly PresentationFramework

. $PsScriptRoot\Controls.ps1
. $PsScriptRoot\OverflowLayout.ps1
. $PsScriptRoot\Layout.ps1

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
        [String] $Type,
        [String] $Name
    ) {
        $this.MenuSpecs = $MenuSpecs
        $this.Name = $Name

        $Preferences = Get-QformPreference `
            -Preferences $Preferences

        $buildPage = switch ($Type) {
            'Multipanel' {
                [Page]::BuildMultipanelPage
            }
            'ScrollPanel' {
                [Page]::BuildScrollPanelPage
            }
        }

        $addLines = if ([String]::IsNullOrEmpty($this.Name)) {
            @('StatusLine')
        } else {
            @('StatusLine', 'PageLine')
        }

        $what = Get-QformMainLayout `
            -Window $Window `
            -MenuSpecs $MenuSpecs `
            -Preferences $Preferences `
            -AddLines $addLines `
            -AddToMainPanel $buildPage

        $this.Controls = $what.Controls
        $this.FillLayout = $what.FillLayout
        $this.StatusLine = $what.StatusLine
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
        return [Qform]::new($Preferences, $MenuSpecs, $false, -1)
    }

    Qform(
        [PsCustomObject] $Preferences,
        [PsCustomObject[]] $PageInfo,
        [Boolean] $IsTabControl,
        [Int] $StartingIndex
    ) {
        $this.Main = New-ControlsMain
        $this.PageLine = $false

        if ($IsTabControl) {
            $this.InitTabControl()
        }
        else {
            $this.InitRefreshControl()
        }

        if ($null -eq $StartingIndex) {
            $this.CurrentIndex =
                $this.DefaultIndex = 0

            $page = [Page]::new(
                $this.Main.Window,
                $Preferences.PsObject.Copy(),
                $PageInfo,
                'Multipanel',
                ''
            )

            $this.AddPage($page)
        }
        else {
            $this.CurrentIndex =
            $this.DefaultIndex =
                if ($StartingIndex -ge 0 `
                    -and $StartingIndex -lt $PageInfo.Count)
                {
                    $StartingIndex
                } else {
                    0
                }

            foreach ($item in $PageInfo) {
                $Preferences = Get-QformPreference `
                    -Preferences $Preferences

                $page = [Page]::new(
                    $this.Main.Window,
                    $Preferences,
                    $item.MenuSpecs,
                    'ScrollPanel',
                    $item.Name
                )

                $this.AddPage($page)
            }

            if ($null -ne $this.Pages -and $this.Pages.Count -gt 0) {
                $closure = New-Closure `
                    -InputObject $this `
                    -ScriptBlock {
                        $refresh = $false
                        $isKeyCombo =
                            [System.Windows.Input.Keyboard]::Modifiers `
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
                    [System.Windows.MessageBox]::Show(
                        $InputObject,
                        'Help'
                    )
                }
            }

        $this.Main.Window.Add_KeyDown($closure)
    }

    [Boolean] ShowDialog() {
        $this.SetPage($this.CurrentIndex)
        return $this.Main.Window.ShowDialog()
    }
}

