#Requires -Assembly PresentationFramework

. $PsScriptRoot\Controls.ps1
. $PsScriptRoot\OverflowLayout.ps1
. $PsScriptRoot\Layout.ps1
. $PsScriptRoot\Type.ps1

class Logger {
    [ScriptBlock[]] $Handlers = @()

    [void] Log($Exception) {
        foreach ($handler in $this.Handlers) {
            & $handler $Exception
        }
    }

    [void] Add([ScriptBlock] $Log) {
        $this.Handlers += @($Log)
    }

    Logger([ScriptBlock] $Log) {
        $this.Add($Log)
    }

    Logger() { }

    static [Logger] ToConsole() {
        return [Logger]::new({
            Param($Exception)
            Write-Host ($Exception | Out-String)
        })
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
        $AddToMainPanel,

        [Logger]
        $Logger
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

    $script:mainPanel = $null

    $newMenuSpecs = $MenuSpecs `
        | Get-QformLayout `
            -Window $Window `
            -StatusLine $statusLine `
            -Preferences $Preferences `
            -Logger $Logger

    $newMenuSpecs `
        | foreach {
            $script:mainPanel = & $AddToMainPanel `
                -MainPanel $script:mainPanel `
                -Control $_.Container `
                -Preferences $Preferences

            $controls.Add($_.Name, $_.Object)

            # Objects added to $mainPanel reach end of life at
            # this point unless $mainPanel is given a scope of
            # 'Script'
        }

    # Resolve a possible race condition
    while ($null -eq $script:mainPanel.Container) {}

    $fillLayout = New-Control StackPanel
    $fillLayout.AddChild($script:mainPanel.Container)

    foreach ($lineName in $lineNames) {
        $fillLayout.AddChild($controls["__$($lineName)__"])
    }

    return [PsCustomObject]@{
        FillLayout = $fillLayout
        Controls = $controls
        StatusLine = $statusLine
        MenuSpecs = $newMenuSpecs
    }
}

class Page {
    [String] $Name = ''
    [Hashtable] $Controls = @{}
    [PsCustomObject[]] $MenuSpecs = @()
    $FillLayout = $null
    $StatusLine = $null
    [Logger] $Logger

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
        $this.Logger = [Logger]::ToConsole()

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

        $addLines = if ([String]::IsNullOrEmpty($Name)) {
            @('StatusLine')
        } else {
            @('StatusLine', 'PageLine')
        }

        $what = Get-QformMainLayout `
            -Window $Window `
            -MenuSpecs $MenuSpecs `
            -Preferences $Preferences `
            -AddLines $addLines `
            -AddToMainPanel $buildPage `
            -Logger $this.Logger

        $this.Name = $Name
        $this.Controls = $what.Controls
        $this.FillLayout = $what.FillLayout
        $this.StatusLine = $what.StatusLine
        $this.MenuSpecs = $what.MenuSpecs
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

        if ($Index -lt 0) {
            $Index = $Qform.TabControl.Items.Count + $Index
        }

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

    hidden static [ScriptBlock] $TabControlIndex = {
        Param([Qform] $Qform)
        return $Qform.TabControl.SelectedIndex
    }

    hidden static [ScriptBlock] $GetCurrentIndex = {
        Param([Qform] $Qform)
        return $Qform.CurrentIndex
    }

    hidden static [ScriptBlock] $SetCurrentIndex = {
        Param([Qform] $Qform, [Int] $Index)

        while ($Qform.CurrentIndex -ne $Index) {
            $Qform.Next()
        }
    }

    hidden static [ScriptBlock] $SetSelectedTabIndex = {
        Param([Qform] $Qform, [Int] $Index)
        $Qform.TabControl.SelectedIndex = $Index
    }

    hidden [ScriptBlock] $MyUpdate
    hidden [ScriptBlock] $MyAddPage
    hidden [ScriptBlock] $MyIndex
    hidden [ScriptBlock] $MySetIndex

    hidden [void] InitTabControl() {
        $this.PageLine = $false
        $this.TabControl = New-Control TabControl
        $this.AddToMainGrid($this.TabControl)
        $this.MyUpdate = [Qform]::UpdateTabControl
        $this.MyAddPage = [Qform]::AddPageToTabControl
        $this.MyIndex = [Qform]::TabControlIndex
        $this.MySetIndex = [Qform]::SetSelectedTabIndex
    }

    hidden [void] InitRefreshControl() {
        $this.PageLine = $true
        $this.MyUpdate = [Qform]::UpdateGrid
        $this.MyAddPage = [Qform]::AddPageToGrid
        $this.MyIndex = [Qform]::GetCurrentIndex
        $this.MySetIndex = [Qform]::SetCurrentIndex
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
        return $this.Pages[$this.MyIndex.Invoke($this)[0]].Controls
    }

    [PsCustomObject[]] MenuSpecs() {
        return $this.Pages[$this.MyIndex.Invoke($this)[0]].MenuSpecs
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
        $page = $this.Pages[$this.MyIndex.Invoke($this)[0]]
        $control = $page.Controls['__PageLine__']

        if ($null -eq $control) {
            return
        }

        $control.HorizontalAlignment = 'Center'

        $control.Content =
            [Qform]::GetPageLine(
                $this.MyIndex.Invoke($this)[0],
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
        [Nullable[Int]] $StartingIndex
    ) {
        $this.Init(
            $Preferences,
            $PageInfo,
            $IsTabControl,
            $StartingIndex
        )
    }

    hidden [void] Init(
        [PsCustomObject] $Preferences,
        [PsCustomObject[]] $PageInfo,
        [Boolean] $IsTabControl,
        [Nullable[Int]] $StartingIndex
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
            $this.DefaultIndex =
                if (($StartingIndex -ge 0 `
                    -and $StartingIndex -lt $PageInfo.Count) `
                    -or ($StartingIndex -lt 0 `
                    -and $StartingIndex -gt (-$PageInfo.Count - 1)))
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

            if (-not $IsTabControl -and
                $null -ne $this.Pages -and
                $this.Pages.Count -gt 0
            ) {
                $closure = New-Closure `
                    -Parameters $this `
                    -ScriptBlock {
                        $refresh = $false
                        $keyboard = [System.Windows.Input.Keyboard]
                        $isKeyCombo =
                            $keyboard::Modifiers -and
                            [System.Windows.Input.ModifierKeys]::Control

                        if ($isKeyCombo) {
                            if ($keyboard::IsKeyDown('Tab')) {
                                $shiftDown =
                                    $keyboard::IsKeyDown('LeftShift') -or
                                    $keyboard::IsKeyDown('RightShift')

                                if ($shiftDown) {
                                    $Parameters.Previous()
                                    $refresh = $true
                                }
                                else {
                                    $Parameters.Next()
                                    $refresh = $true
                                }
                            }
                        }

                        if ($refresh) {
                            $Parameters.SetPage($Parameters.CurrentIndex)
                        }
                    }

                $this.Main.Window.Add_KeyDown($closure)
            }
        }

        [void] $this.MySetIndex.Invoke($this, $this.DefaultIndex)
        $this.Main.Window.Title = $Preferences.Caption
        $this.InitKeyBindings()
    }

    hidden [void] InitKeyBindings() {
        $prefs = $this.Pages[$this.MyIndex.Invoke($this)[0]].Preferences

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
            -Parameters $helpMessage `
            -ScriptBlock {
                $isKeyCombo =
                    $_.Key -eq [System.Windows.Input.Key]::OemQuestion `
                    -and $_.KeyboardDevice.Modifiers `
                        -eq [System.Windows.Input.ModifierKeys]::Control

                if ($isKeyCombo) {
                    [System.Windows.MessageBox]::Show(
                        $Parameters,
                        'Help'
                    )

                    $_.Handled = $true
                }
            }

        $this.Main.Window.Add_KeyDown($closure)
    }

    [Boolean] ShowDialog() {
        $this.SetPage($this.MyIndex.Invoke($this)[0])
        return $this.Main.Window.ShowDialog()
    }
}

