#Requires -Assembly PresentationFramework

function Set-ControlsTheme {
    Param(
        $Control
    )

    $Control.SetResourceReference(
        [System.Windows.Controls.Control]::BackgroundProperty,
        [System.Windows.SystemColors]::DesktopBrushKey
    )

    if ($Control.PsObject.Properties.Name -contains 'Foreground') {
        $Control.Foreground = 'White'
    }
}

function New-Control {
    Param(
        [String]
        $TypeName
    )

    $control = New-Object "System.Windows.Controls.$TypeName"
    Set-ControlsTheme $control
    return $control
}

