#Requires -Assembly PresentationFramework

. $PsScriptRoot\Controls.ps1
. $PsScriptRoot\Progress.ps1
. $PsScriptRoot\OverflowLayout.ps1
. $PsScriptRoot\Layout.ps1
. $PsScriptRoot\Type.ps1

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
        $Logger,

        [ProgressWriter]
        $Progress
    )

    $controls = @{}
    $lineNames = @()
    $statusLine = $null
    $builder = $null

    foreach ($lineName in $AddLines) {
        if ($lineName -in $lineNames) {
            continue
        }

        $line = [Controls]::NewControl('Label')

        if ($lineName -eq 'StatusLine') {
            $statusLine = $line

            $builder = [Controls]::new(
                $Preferences,
                $statusLine,
                $Logger
            )

            $builder.SetStatus('Idle')
        }

        $lineNames += @($lineName)
        $controls.Add("__$($lineName)__", $line)
    }

    if ($null -eq $builder) {
        $builder = [Controls]::new(
            $Preferences,
            $null,
            $Logger
        )
    }

    $script:mainPanel = $null

    # todo: verify that these two pipes need to be in separate statements
    $newMenuSpecs = $MenuSpecs `
        | Get-QformLayout `
            -Window $Window `
            -Builder $builder `
            -Progress $Progress

    $newMenuSpecs `
        | foreach {
            $script:mainPanel = & $AddToMainPanel `
                -MainPanel $script:mainPanel `
                -Control $_.Container `
                -Builder $builder

            $controls.Add($_.Name, $_.Object)

            # Objects added to $mainPanel reach end of life at
            # this point unless $mainPanel is given a scope of
            # 'Script'
        }

    # Resolve a possible race condition
    while ($null -eq $script:mainPanel.Container) {}

    $fillLayout = [Controls]::NewControl('StackPanel')
    $fillLayout.AddChild($script:mainPanel.Container)

    foreach ($lineName in $lineNames) {
        $fillLayout.AddChild($controls["__$($lineName)__"])
    }

    return [PsCustomObject]@{
        FillLayout = $fillLayout
        Controls = $controls
        MenuSpecs = $newMenuSpecs
        Builder = $builder
    }
}

class Page {
    [String] $Name = ''
    [Hashtable] $Controls = @{}
    [PsCustomObject[]] $MenuSpecs = @()
    [Controls] $Builder = $null
    $FillLayout = $null

    hidden static [ScriptBlock] $BuildMultipanelPage = {
        Param($MainPanel, $Control, $Builder)

        return Add-ControlToMultipanel `
            -Multipanel $MainPanel `
            -Control $Control `
            -Builder $Builder
    }

    hidden static [ScriptBlock] $BuildScrollPanelPage = {
        Param($MainPanel, $Control, $Builder)

        return Add-ControlToScrollPanel `
            -ScrollPanel $MainPanel `
            -Control $Control `
            -Builder $Builder
    }

    hidden [void] Init(
        [System.Windows.Window] $Window,
        [PsCustomObject] $Preferences,
        [PsCustomObject[]] $MenuSpecs,
        [String] $Type,
        [String] $Name,
        [Logger] $Logger,
        [ProgressWriter] $Progress
    ) {
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

        # The page has a name implies that it's part of a multi-page layout
        # and a Page Line needs to be provided.
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
            -Logger $Logger `
            -Progress $Progress

        $this.Name = $Name
        $this.Controls = $what.Controls
        $this.FillLayout = $what.FillLayout
        $this.MenuSpecs = $what.MenuSpecs
        $this.Builder = $what.Builder
    }

    Page(
        [System.Windows.Window] $Window,
        [PsCustomObject] $Preferences,
        [PsCustomObject[]] $MenuSpecs,
        [String] $Type,
        [String] $Name,
        [Logger] $Logger
    ) {
        $this.Init(
            $Window,
            $Preferences,
            $MenuSpecs,
            $Type,
            $Name,
            $Logger,
            $null
        )
    }

    Page(
        [System.Windows.Window] $Window,
        [PsCustomObject] $Preferences,
        [PsCustomObject[]] $MenuSpecs,
        [String] $Type,
        [String] $Name,
        [Logger] $Logger,
        [ProgressWriter] $Progress
    ) {
        $this.Init(
            $Window,
            $Preferences,
            $MenuSpecs,
            $Type,
            $Name,
            $Logger,
            $Progress
        )
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
    $Logger = $null

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

        [Controls]::AddTabItem(
            $Qform.TabControl,
            $Page.FillLayout,
            $Page.Name
        )
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
        $this.TabControl = [Controls]::NewControl('TabControl')
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
        $itemTotal = if ($null -eq $StartingIndex) {
            @($PageInfo).Count
        }
        else {
            @($PageInfo) |
                foreach { $_.Count } |
                measure -Sum |
                foreach { $_.Sum }
        }

        $progress = [ProgressWriter]::new(
            0, 0, $itemTotal + 3, "Building Quickform"
        )

        $progress.Next({ 'New main window' })
        $this.Logger = [Logger]::ToConsole()
        $this.Main = [Controls]::NewMain($this.Logger)
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
                '',
                $this.Logger,
                $progress
            )

            $this.AddPage($page)
        }
        else {
            $this.DefaultIndex =
                if ($StartingIndex -gt (-$PageInfo.Count - 1) -and
                    $StartingIndex -lt $PageInfo.Count
                ) {
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
                    $item.Name,
                    $this.Logger,
                    $progress
                )

                $this.AddPage($page)
            }

            if (-not $IsTabControl -and
                $null -ne $this.Pages -and
                $this.Pages.Count -gt 0
            ) {
                $closure = $this.Logger.NewClosure(
                    $this,
                    {
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
                                }
                                else {
                                    $Parameters.Next()
                                }

                                $Parameters.SetPage($Parameters.CurrentIndex)
                            }
                        }
                    }
                )

                $this.Main.Window.Add_KeyDown($closure)
            }
        }

        [void] $this.MySetIndex.Invoke($this, $this.DefaultIndex)
        $this.Main.Window.Title = $Preferences.Caption
        $this.InitKeyBindings()
        $progress.Complete()
    }

    hidden [void] InitKeyBindings() {
        $prefs = $this.
            Pages[$this.MyIndex.Invoke($this)[0]].
            Builder.
            Preferences

        if ($prefs.EnterToConfirm) {
            $this.Main.Window.Add_KeyDown(
                $this.Logger.NewClosure({
                    if ($_.Key -eq 'Enter') {
                        $this.DialogResult = $true
                        $this.Close()
                    }
                })
            )
        }

        if ($prefs.EscapeToCancel) {
            $this.Main.Window.Add_KeyDown(
                $this.Logger.NewClosure({
                    if ($_.Key -eq 'Escape') {
                        $this.DialogResult = $false
                        $this.Close()
                    }
                })
            )
        }

        $helpMessage =
            "$PsScriptRoot/../res/text.json" |
            Get-Item |
            Get-Content |
            ConvertFrom-Json |
            foreach { $_.Help }

        $helpMessage = $helpMessage -Join "`r`n"

        $closure = $this.Logger.NewClosure(
            $helpMessage,
            {
                $isKeyCombo =
                    $_.Key -eq
                    [System.Windows.Input.Key]::OemQuestion -and
                    $_.KeyboardDevice.Modifiers -eq
                    [System.Windows.Input.ModifierKeys]::Control

                if ($isKeyCombo) {
                    [System.Windows.MessageBox]::Show(
                        $Parameters,
                        'Help'
                    )

                    $_.Handled = $true
                }
            }
        )

        $this.Main.Window.Add_KeyDown($closure)
    }

    [Boolean] ShowDialog() {
        $this.SetPage($this.MyIndex.Invoke($this)[0])
        return $this.Main.Window.ShowDialog()
    }
}

