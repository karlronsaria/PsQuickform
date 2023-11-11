. "$PsScriptRoot\..\Controls.ps1"

Add-ControlsTypes

. "$PsScriptRoot\..\NumberSlider.ps1"

$script:statusLine = New-Object System.Windows.Controls.Label
$script:statusLine.HorizontalContentAlignment = 'Center'
$script:statusLine.Foreground = 'DarkRed'
$script:statusLine.Content = ''

$status_Idle = { $script:statusLine.Content = '' }
$status_MaxReached = { $script:statusLine.Content = 'Maximum value reached' }
$status_MinReached = { $script:statusLine.Content = 'Minimum value reached' }

$stackPanel = New-Object System.Windows.Controls.StackPanel
$stackPanel.Margin = 5

$slider1 = [NumberSlider]::new(0, -999, 999, 1)
$slider1.Margin = 5
$slider1.OnIdle += @($status_Idle)
$slider1.OnMaxReached += @($status_MaxReached)
$slider1.OnMinReached += @($status_MinReached)
$slider1.Text = '40'

$row = Get-ControlsAsterized `
    -Control $slider1

$slider2 = [NumberSlider]::new(20, 10, 50, 5)
$slider2.Margin = 5
$slider2.OnIdle += @($status_Idle)
$slider2.OnMaxReached += @($status_MaxReached)
$slider2.OnMinReached += @($status_MinReached)

$stackPanel.AddChild($row)
$stackPanel.AddChild($slider2)
$stackPanel.AddChild($statusLine)

$main = New-ControlsMain
$main.Grid.AddChild($stackPanel)
[void]$main.Window.ShowDialog()

return [PsCustomObject]@{
    Values = @(
        $slider1.Value
        $slider2.Value
    )
    AfterWindowHeight = $main.Window.Height
}

