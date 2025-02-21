#Requires -Assembly PresentationFramework

. $PsScriptRoot\Controls.ps1

function New-ControlsScrollPanel {
    Param(
        [Controls]
        $Builder
    )

    $scrollViewer = [Controls]::NewControl('ScrollViewer')
    $scrollViewer.VerticalScrollBarVisibility =
        [System.Windows.Controls.ScrollBarVisibility]::Auto

    # link
    # - url: <https://stackoverflow.com/questions/1927540/how-to-get-the-size-of-the-current-screen-in-wpf>
    # - retrieved: 2022-08-28
    $scrollViewer.MaxHeight =
        [System.Windows.SystemParameters]::WorkArea.Height - 200

    $childPanel = [Controls]::NewControl('StackPanel')
    $childPanel.MinWidth = $Builder.Preferences.Width
    $childPanel.MaxWidth = [Double]::PositiveInfinity
    $childPanel.Orientation = 'Vertical'
    $childPanel.Margin = $Builder.Preferences.Margin

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

        [Controls]
        $Builder
    )

    if ($null -eq $ScrollPanel) {
        $ScrollPanel = New-ControlsScrollPanel `
            -Builder $Builder
    }

    # link
    # - url: <https://stackoverflow.com/questions/3401636/measuring-controls-created-at-runtime-in-wpf>
    # - retrieved: 2022-08-28
    $Control.Measure([System.Windows.Size]::new(
        [Double]::PositiveInfinity,
        [Double]::PositiveInfinity
    ))

    $Control.Height = $Control.DesiredSize.Height
    $Control.Margin = $Builder.Preferences.Margin

    $ScrollPanel.ChildPanel.AddChild($Control)

    return $ScrollPanel
}

function New-ControlsMultipanel {
    Param(
        [Controls]
        $Builder
    )

    $container = [Controls]::NewControl('StackPanel')
    $container.MaxWidth = [Double]::PositiveInfinity
    $container.Orientation = 'Horizontal'
    $container.Margin = $Builder.Preferences.Margin

    # link
    # - url: <https://stackoverflow.com/questions/1927540/how-to-get-the-size-of-the-current-screen-in-wpf>
    # - retrieved: 2022-08-28
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

        [Controls]
        $Builder
    )

    if ($null -eq $Multipanel) {
        $Multipanel = New-ControlsMultipanel `
            -Builder $Builder
    }

    $nextHeight = if ($null -ne $Control) {
        # link
        # - url: <https://stackoverflow.com/questions/3401636/measuring-controls-created-at-runtime-in-wpf>
        # - retrieved: 2022-08-28
        $Control.Measure([System.Windows.Size]::new(
            [Double]::PositiveInfinity,
            [Double]::PositiveInfinity
        ))

        $Control.Height = $Control.DesiredSize.Height
        $Control.Margin = $Builder.Preferences.Margin

        $Multipanel.CurrentHeight +
            $Control.DesiredSize.Height +
            (2 * $Builder.Preferences.Margin)
    }

    $needNewSublayout =
        $null -eq $Control `
        -or $Multipanel.Container.Children.Count -eq 0 `
        -or $nextHeight -gt $Builder.Preferences.Height `
        -or $nextHeight -gt $Multipanel.MaxHeight

    if ($needNewSublayout) {
        $layout = $Builder.NewLayout()
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

