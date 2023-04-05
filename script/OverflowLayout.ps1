#Requires -Assembly PresentationFramework

. $PsScriptRoot\Controls.ps1

function New-ControlsScrollPanel {
    Param(
        [PsCustomObject]
        $Preferences
    )

    $scrollViewer = New-Control ScrollViewer
    $scrollViewer.VerticalScrollBarVisibility =
        [System.Windows.Controls.ScrollBarVisibility]::Auto

    # link
    # - url: https://stackoverflow.com/questions/1927540/how-to-get-the-size-of-the-current-screen-in-wpf
    # - retrieved: 2022_08_28
    $scrollViewer.MaxHeight =
        [System.Windows.SystemParameters]::WorkArea.Height - 200

    $childPanel = New-Control StackPanel
    $childPanel.MinWidth = $Preferences.Width
    $childPanel.MaxWidth = [Double]::PositiveInfinity
    $childPanel.Orientation = 'Vertical'
    $childPanel.Margin = $Preferences.Margin

    $scrollViewer.AddChild($childPanel)

    return [PsCustomObject]@{
        Container = $scrollViewer
        ChildPanel = $childPanel
    }
}

function Add-ControlToScrollPanel {
    Param(
        [PsCustomObject]
        $ScrollPanel,

        [System.Windows.FrameworkElement]
        $Control,

        [PsCustomObject]
        $Preferences
    )

    if ($null -eq $ScrollPanel) {
        $ScrollPanel = New-ControlsScrollPanel `
            -Preferences $Preferences
    }

    # link
    # - url: https://stackoverflow.com/questions/3401636/measuring-controls-created-at-runtime-in-wpf
    # - retrieved: 2022_08_28
    $Control.Measure([System.Windows.Size]::new(
        [Double]::PositiveInfinity,
        [Double]::PositiveInfinity
    ))

    $Control.Height = $Control.DesiredSize.Height
    $Control.Margin = $Preferences.Margin

    $ScrollPanel.ChildPanel.AddChild($Control)
    return $ScrollPanel
}

function New-ControlsMultipanel {
    Param(
        [PsCustomObject]
        $Preferences
    )

    $container = New-Control StackPanel
    $container.MaxWidth = [Double]::PositiveInfinity
    $container.Orientation = 'Horizontal'
    $container.Margin = $Preferences.Margin

    # link
    # - url: https://stackoverflow.com/questions/1927540/how-to-get-the-size-of-the-current-screen-in-wpf
    # - retrieved: 2022_08_28
    $maxHeight =
        [System.Windows.SystemParameters]::WorkArea.Height - 200

    return [PsCustomObject]@{
        Container = $container
        Sublayouts = @()
        MaxHeight = $maxHeight
        CurrentHeight = 0
    }
}

function Add-ControlToMultipanel {
    Param(
        [PsCustomObject]
        $Multipanel,

        [System.Windows.FrameworkElement]
        $Control,

        [PsCustomObject]
        $Preferences
    )

    if ($null -eq $Multipanel) {
        $Multipanel = New-ControlsMultipanel `
            -Preferences $Preferences
    }

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

        $Multipanel.CurrentHeight `
            + $Control.DesiredSize.Height `
            + (2 * $Preferences.Margin)
    }

    $needNewSublayout =
        $null -eq $Control `
        -or $Multipanel.Container.Children.Count -eq 0 `
        -or $nextHeight -gt $Preferences.Height `
        -or $nextHeight -gt $Multipanel.MaxHeight

    if ($needNewSublayout) {
        $layout = New-ControlsLayout `
            -Preferences $Preferences

        $Multipanel.Container.AddChild($layout)
        $Multipanel.Sublayouts += @($layout)
        $Multipanel.CurrentHeight = 0
    }

    if ($null -ne $Control) {
        $Multipanel.Sublayouts[-1].AddChild($Control)
        $Multipanel.CurrentHeight +=
            $Control.Height + (2 * $Control.Margin.Top)
    }

    return $Multipanel
}

