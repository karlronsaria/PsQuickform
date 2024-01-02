#Requires -Assembly PresentationFramework

class NumberSlider : System.Windows.Controls.DockPanel {
    $InitialValue = $null;
    $Minimum = $null;
    $Maximum = $null;
    $Step = $null;
    $Type = [Int];

    [ScriptBlock[]] $OnMaxReached = @()
    [ScriptBlock[]] $OnMinReached = @()
    [ScriptBlock[]] $OnIdle = @()

    [String] GetText() {
        return $this.Field.Text
    }

    [void] SetText([String] $Text) {
        $this.Field.Text = $Text

        if ($this.Field.IsFocused) {
            $this.Field.Select($this.Field.Text.Length, 0)
        }
    }

    [void] Add_TextChanged([ScriptBlock] $ScriptBlock) {
        $this.Field.Add_TextChanged($ScriptBlock)
    }

    hidden [System.Windows.Controls.Primitives.RepeatButton] $UpButton;
    hidden [System.Windows.Controls.Primitives.RepeatButton] $DownButton;
    hidden [System.Windows.Controls.TextBox] $Field;
    hidden [String] $PreviousText = '';

    hidden [void] ChangeText() {
        $myInt = $null

        $valid = [String]::IsNullOrEmpty($this.Field.Text) `
            -or $this.Type::TryParse($this.Field.Text, [Ref]$myInt)

        if ($valid) {
            $this.PreviousText = [String]$myInt
            return
        }

        $this.Field.Text = $this.PreviousText
    }

    hidden [void] Up() {
        $myInt = $this.Field.Text -as $this.Type
        $this.SetText([String]($myInt + $this.Step))
    }

    hidden [void] Down() {
        $myInt = $this.Field.Text -as $this.Type
        $this.SetText([String]($myInt - $this.Step))
    }

    hidden [void] SetToMinimum() {
        $this.SetText([String]$this.Minimum)
    }

    hidden [void] SetToMaximum() {
        $this.SetText([String]$this.Maximum)
    }

    hidden [ScriptBlock] $ctrlup_action = { }
    hidden [ScriptBlock] $ctrldown_action = { }

    NumberSlider($InitialValue, $Minimum, $Maximum, $Step) {
        $this.Type = $InitialValue.GetType()
        $this.InitialValue = $InitialValue
        $this.Minimum = $Minimum
        $this.Maximum = $Maximum
        $this.Step = $Step

        $fontSize = 4
        $buttonWidth = 20

        $this.VerticalAlignment = 'Top'

        $this.UpButton = New-Object System.Windows.Controls.Primitives.RepeatButton
        $this.UpButton.HorizontalContentAlignment = 'Center'
        $this.UpButton.FontSize = $fontSize
        $this.UpButton.Content = [Char]0x25B2 # "▲"
        $this.UpButton.IsTabStop = $false
        $this.UpButton.Width = $buttonWidth

        $this.DownButton = New-Object System.Windows.Controls.Primitives.RepeatButton
        $this.DownButton.HorizontalContentAlignment = 'Center'
        $this.DownButton.FontSize = $fontSize
        $this.DownButton.Content = [Char]0x25BC # "▼"
        $this.DownButton.IsTabStop = $false
        $this.DownButton.Width = $buttonWidth

        $this.Field = New-Object System.Windows.Controls.TextBox
        $this.Field.VerticalContentAlignment = 'Center'
        $this.Field.HorizontalContentAlignment = 'Right'

        $stackPanel = New-Object System.Windows.Controls.StackPanel
        $stackPanel.AddChild($this.UpButton)
        $stackPanel.AddChild($this.DownButton)
        $this.AddChild($stackPanel)
        $this.AddChild($this.Field)

        $this.Add_SizeChanged({
            $this.UpButton.Height = $this.Height/2
            $this.DownButton.Height = $this.Height/2
        })

        $this | Add-Member `
            -MemberType ScriptProperty `
            -Name Text `
            -Value `
                { $this.Field.Text } `
                { Param($Arg) $this.SetText($Arg) }

        $this | Add-Member `
            -MemberType ScriptProperty `
            -Name Value `
            -Value {
                if ([String]::IsNullOrEmpty($this.Field.Text)) {
                    $null
                }
                else {
                    $this.Field.Text -as $this.Type
                }
            }

        if ($null -ne $this.InitialValue) {
            $this.Field.Text = $this.InitialValue
        }

        function New-Closure {
            Param(
                [ScriptBlock]
                $ScriptBlock,

                $InputObject
            )

            return & { Param($InputObject) $ScriptBlock.GetNewClosure() } $InputObject
        }

        $closure = New-Closure `
            -InputObject $this `
            -ScriptBlock {
                $InputObject.ChangeText()
                $InputObject.OnIdle | foreach { $_.Invoke() }
            }

        $this.Field.Add_TextChanged($closure)

        $this.Field.Add_GotFocus({
            $this.Select($this.Text.Length, 0)
        })

        $closure = New-Closure { $InputObject.Up() } $this
        $this.UpButton.Add_Click($closure)

        $closure = New-Closure { $InputObject.Down() } $this
        $this.DownButton.Add_Click($closure)

        if ($null -eq $this.Maximum) {
            $this.ctrlup_action =
                New-Closure { $InputObject.Up() } $this
        }
        else {
            $this.ctrlup_action =
                New-Closure { $InputObject.SetToMaximum() } $this

            $closure = New-Closure `
                -InputObject $this `
                -ScriptBlock {
                    if (
                        ($InputObject.GetText() -as $InputObject.Type) `
                        -gt $InputObject.Maximum
                    ) {
                        $InputObject.Field.Text = $InputObject.Maximum
                        $InputObject.OnMaxReached | foreach { $_.Invoke() }
                    }
                }

            $this.Field.Add_TextChanged($closure)
        }

        if ($null -eq $Minimum) {
            $this.ctrldown_action =
                New-Closure { $InputObject.Down() } $this
        }
        else {
            $this.ctrldown_action =
                New-Closure { $InputObject.SetToMinimum() } $this

            $closure = New-Closure `
                -InputObject $this `
                -ScriptBlock {
                    if (
                        ($InputObject.GetText() -as $InputObject.Type) `
                        -lt $InputObject.Minimum
                    ) {
                        $InputObject.Field.Text = $InputObject.Minimum
                        $InputObject.OnMinReached | foreach { $_.Invoke() }
                    }
                }

            $this.Field.Add_TextChanged($closure)
        }

        $closure = New-Closure `
            -InputObject $this `
            -ScriptBlock {
                if ([System.Windows.Input.Keyboard]::Modifiers `
                    -eq [System.Windows.Input.ModifierKeys]::Control)
                {
                    switch ($_.Key) {
                        'Up' {
                            Invoke-Command $InputObject.ctrlup_action
                        }

                        'Down' {
                            Invoke-Command $InputObject.ctrldown_action
                        }
                    }

                    return
                }

                switch ($_.Key) {
                    'Up' {
                        Invoke-Command { $InputObject.Up() }
                    }

                    'Down' {
                        Invoke-Command { $InputObject.Down() }
                    }
                }
            }

        $this.Field.Add_PreviewKeyDown($closure)
    }
}

