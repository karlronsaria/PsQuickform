function Select-QformImagePreview {
    Param(
        [String]
        $Caption,

        [Parameter(ValueFromPipeline = $true)]
        [Alias('Path')]
        [String[]]
        $FilePath
    )

    Begin {
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName presentationFramework

        $moduleLoc = "$(Get-ProfileLocation)\Modules\PsQuickform\script\"

        'Other', 'Closure', 'NumberSlider', 'Controls' |
        foreach {
            . "$moduleLoc\$_.ps1"
        }

        $progActivity = 'Gathering image files'
        $imageWidth = 150
        $cardWidth = 180
        $cardHeight = 250
        $labelWidth = 45
        $files = @()
    }

    Process {
        $files += @($FilePath) |
            where { $_ } |
            Get-Item
    }

    End {
        if (@($files).Count -eq 0) {
            return
        }

        $builder = [Controls]::new()
        $global:main = $builder.NewMain()
        $global:main.Window.Title = $Caption

        $scrollViewer = [Controls]::NewControl('ScrollViewer')
        $scrollViewer.VerticalScrollBarVisibility = 'Auto'

        # link
        # - url: <https://stackoverflow.com/questions/1927540/how-to-get-the-size-of-the-current-screen-in-wpf>
        # - retrieved: 2022_08_28
        $scrollViewer.MaxHeight =
            [System.Windows.SystemParameters]::WorkArea.Height - 200

        $childPanel = [Controls]::NewControl('WrapPanel')
        $childPanel.MinWidth = $builder.Preferences.Width
        $childPanel.MaxWidth = [Double]::PositiveInfinity
        $childPanel.Margin = $builder.Preferences.Margin

        $scrollViewer.AddChild($childPanel)

        $scrollPanel = [PsCustomObject]@{
            Container = $scrollViewer
            ChildPanel = $childPanel
        }

        $bitArray = @()

        foreach ($i in (0 .. ($files.Count - 1))) {
            Write-Progress `
                -Id 1 `
                -Activity $progActivity `
                -Status $files[$i].Name `
                -PercentComplete (100 * $i / @($files).Count)

            $image = [System.Windows.Controls.Image]::new()
            $image.Width = $imageWidth
            $uri = $files[$i].FullName
            $bitmap = [System.Windows.Media.Imaging.BitmapImage]::new()
            $bitmap.BeginInit()
            $bitmap.UriSource = $uri
            $bitmap.DecodePixelWidth = $imageWidth
            $bitmap.EndInit()
            $image.Source = $bitmap

            $label = [System.Windows.Controls.Label]::new()
            $name = $files[$i].Name

            $name =
                if ($name.Length -gt $labelWidth) {
                    "$($name.Substring(0, $labelWidth - 4)) ..."
                }
                else {
                    $name
                }

            $label.Content = $name
            $label.HorizontalContentAlignment = 'Center'

            $checkbox = [System.Windows.Controls.CheckBox]::new()
            $checkbox.HorizontalContentAlignment = 'Center'
            $bitArray += @($checkbox)

            $header = [Controls]::NewControl('StackPanel')
            $header.VerticalAlignment = 'Center'
            $header.Orientation = 'Horizontal'

            $header.AddChild($checkbox)
            $header.AddChild($label)

            $stack = [System.Windows.Controls.StackPanel]::new()
            $stack.MinWidth = $cardWidth
            $stack.MaxWidth = $cardWidth
            $stack.MinHeight = $cardHeight
            $stack.MaxHeight = $cardHeight
            $stack.HorizontalAlignment = 'Center'
            $stack.AddChild($header)
            $stack.AddChild($image)

            $scrollPanel.ChildPanel.AddChild($stack)
        }

        Write-Progress `
            -Id 1 `
            -Activity $progActivity `
            -Complete

        $dialogButtons = $builder.NewOkCancelButtons()

        $okAction = $builder.NewClosure(
            $main.Window,
            {
                $Parameters.DialogResult = $true
                $Parameters.Close()
            }
        )

        $cancelAction = $builder.NewClosure(
            $main.Window,
            {
                $Parameters.DialogResult = $false
                $Parameters.Close()
            }
        )

        $main.Window.Add_KeyDown($builder.NewClosure({
            if ($_.Key -eq 'Enter') {
                $this.DialogResult = $true
                $this.Close()
            }

            if ($_.Key -eq 'Escape') {
                $this.DialogResult = $false
                $this.Close()
            }
        }))

        $dialogButtons.Object.OkButton.Add_Click($okAction)
        $dialogButtons.Object.CancelButton.Add_Click($cancelAction)

        $global:main.Grid.AddChild($scrollPanel.Container)
        $global:main.Grid.AddChild($dialogButtons.Container)
        $result = $global:main.Window.ShowDialog()

        $images = 0 .. ($files.Count - 1) |
            where {
                $bitArray[$_].IsChecked
            } |
            foreach {
                [PsCustomObject]@{
                    Index = $_
                    File = $files[$_]
                }
            }

        return [PsCustomObject]@{
            Confirm = $result
            Images = $images
        }
    }
}

