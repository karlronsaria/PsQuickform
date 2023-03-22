#Requires -Assembly PresentationFramework

. $PsScriptRoot\Controls.ps1

function New-ControlsMultilayout {
    Param(
        [PsCustomObject]
        $Preferences
    )

    $multilayout = New-Control StackPanel
    $multilayout.MaxWidth = [Double]::PositiveInfinity
    $multilayout.Orientation = 'Horizontal'
    $multilayout.Margin = $Preferences.Margin

    # link
    # - url: https://stackoverflow.com/questions/1927540/how-to-get-the-size-of-the-current-screen-in-wpf
    # - retrieved: 2022_08_28
    $maxHeight =
        [System.Windows.SystemParameters]::WorkArea.Height - 200

    $pageControl = [PsCustomObject]@{
        Multilayout = $multilayout
        Sublayouts = @()
        Controls = @{}
        MaxHeight = $maxHeight
        CurrentHeight = 0
    }

    return Add-ControlToMultiLayout `
        -PageControl $pageControl `
        -Preferences $Preferences
}

function Add-ControlToMultilayout {
    Param(
        [PsCustomObject]
        $PageControl,

        [System.Windows.FrameworkElement]
        $Control,

        [PsCustomObject]
        $Preferences
    )

    $nextHeight = if ($null -ne $Control) {
        # link
        # - url: https://stackoverflow.com/questions/3401636/measuring-controls-created-at-runtime-in-wpf
        # - retrieved: 2022_08_28
        $Control.Measure([System.Windows.Size]::new(
            [Double]::PositiveInfinity,
            [Double]::PositiveInfinity
        ))

        $Control.Height = $Control.DesiredSize.Height
        $Control.Margin = $Preferences.Margin

        $PageControl.CurrentHeight `
            + $Control.DesiredSize.Height `
            + (2 * $Preferences.Margin)
    }

    $needNewSublayout =
        $null -eq $Control `
        -or $PageControl.Multilayout.Children.Count -eq 0 `
        -or $nextHeight -gt $Preferences.Height `
        -or $nextHeight -gt $PageControl.MaxHeight

    if ($needNewSublayout) {
        $layout = New-ControlsLayout `
            -Preferences $Preferences

        $PageControl.Multilayout.AddChild($layout)
        $PageControl.Sublayouts += @($layout)
        $PageControl.CurrentHeight = 0
    }

    if ($null -ne $Control) {
        $PageControl.Sublayouts[-1].AddChild($Control)
        $PageControl.CurrentHeight +=
            $Control.Height + (2 * $Control.Margin.Top)
    }

    return $PageControl
}

