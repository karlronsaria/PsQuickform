# Requires source Controls.ps1
# Requires source CommandInfo.ps1

function New-QuickformPreferences {
    Param(
        [PsCustomObject]
        $Preferences
    )

    $myPreferences = $script:DEFAULT_PREFERENCES

    if ($Preferences) {
        foreach ($property in $Preferences.PsObject.Properties.Name) {
            $myPreferences.$property = $Preferences.$property
        }
    }

    return $myPreferences
}

function Get-QuickformObject {
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline = $true)]
        [PsCustomObject]
        $InputObject,

        [Switch]
        $AsHashtable
    )

    if ($null -eq $InputObject) {
        return New-QuickformObject
    }

    return $InputObject.Controls `
        | New-QuickformObject `
            -Preferences $InputObject.Preferences `
            -AsHashtable:$AsHashtable
}

function Set-QuickformLayout {
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline = $true)]
        [PsCustomObject[]]
        $Control,

        [PsCustomObject]
        $Layouts,

        [PsCustomObject]
        $Preferences
    )

    Begin {
        $controls = @{}
    }

    Process {
        foreach ($item in $Control) {
            $default = Get-PropertyOrDefault `
                -InputObject $item `
                -Name 'Default'

            $text = Get-PropertyOrDefault `
                -InputObject $item `
                -Name 'Text' `
                -Default $item.Name

            $value = switch ($item.Type) {
                'Check' {
                    Add-ControlsCheckBox `
                        -Layouts $Layouts `
                        -Text $text `
                        -Default $default `
                        -Preferences $Preferences
                }

                'Field' {
                    $minLength = $item | Get-PropertyOrDefault `
                        -Name MinLength;
                    $maxLength = $item | Get-PropertyOrDefault `
                        -Name MaxLength;

                    Add-ControlsFieldBox `
                        -Layouts $Layouts `
                        -Text $text `
                        -MinLength $minLength `
                        -MaxLength $maxLength `
                        -Default $default `
                        -Preferences $Preferences
                }

                'Enum' {
                    $mandatory = $item | Get-PropertyOrDefault `
                        -Name Mandatory `
                        -Default $false;

                    Add-ControlsRadioBox `
                        -Layouts $Layouts `
                        -Text $text `
                        -Symbols $item.Symbols `
                        -Mandatory:$mandatory `
                        -Default $default `
                        -Preferences $Preferences
                }

                'Numeric' {
                    $places = $item | Get-PropertyOrDefault `
                        -Name DecimalPlaces;
                    $min = $item | Get-PropertyOrDefault `
                        -Name Minimum `
                        -Default $script:DEFAULT_SLIDER_MINIMUM;
                    $max = $item | Get-PropertyOrDefault `
                        -Name Maximum `
                        -Default $script:DEFAULT_SLIDER_MAXIMUM;
                    $asFloat = $item | Get-PropertyOrDefault `
                        -Name AsFloat `
                        -Default $false;

                    Add-ControlsSlider `
                        -Layouts $Layouts `
                        -Text $text `
                        -DecimalPlaces $places `
                        -Minimum $min `
                        -Maximum $max `
                        -AsFloat:$asFloat `
                        -Default $default `
                        -Preferences $Preferences
                }
            }

            $controls.Add($item.Name, $value)
        }
    }

    End {
        $endButtons = Add-ControlsOkCancelButtons `
            -Layouts $Layouts `
            -Preferences $Preferences

        $controls.Add('EndButtons__', $endButtons)
        $Layouts.Controls = $controls
        return $controls
    }
}

function Start-QuickformEvaluate {
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline = $true)]
        [PsCustomObject[]]
        $Control,

        [PsCustomObject]
        $Layouts
    )

    Begin {
        $out = [PsCustomObject]@{}
        $controls = $Layouts.Controls
    }

    Process {
        foreach ($item in $Control) {
            $value = switch ($item.Type) {
                'Check' {
                    $tempValue = $controls[$item.Name].Checked;

                    switch ($myPreferences.ConfirmType) {
                        'TrueOrFalse' {
                            $tempValue
                        }

                        'AllowOrDeny' {
                            switch ($tempValue) {
                                'True' { 'Allow' }
                                'False' { 'Deny' }
                            }
                        }
                    }
                }

                'Field' {
                    $controls[$item.Name].Text
                }

                'Enum' {
                    $buttons = $controls[$item.Name];

                    $temp = if ($buttons) {
                        $buttons.Keys | where {
                            $buttons[$_].Checked
                        }
                    } else {
                        $null
                    };

                    if ($temp -eq 'None') {
                        $null
                    }
                    else {
                        $temp
                    }
                }

                'Numeric' {
                    if ($controls[$item.Name].Text) {
                        $controls[$item.Name].Value
                    } else {
                        $null
                    }
                }
            }

            $out | Add-Member `
                -MemberType NoteProperty `
                -Name $item.Name `
                -Value $value
        }
    }

    End {
        return $out
    }
}

function Set-QuickformMainLayout {
    Param(
        [PsCustomObject]
        $Layouts,

        [System.Windows.Forms.Form]
        $MainForm,

        [PsCustomObject[]]
        $Control,

        [PsCustomObject]
        $Preferences
    )

    $MainForm.Controls.Clear()

    $Layouts = New-ControlsMultilayout `
        -Preferences $Preferences

    $Layouts.Controls = $Control | Set-QuickformLayout `
        -Layouts $Layouts `
        -Preferences $Preferences

    $MainForm.Text = $Preferences.Title

    while ($null -eq $Layouts.Multilayout) { }

    $MainForm.Controls.Add($Layouts.Multilayout)
    return $Layouts
}

function New-QuickformObject {
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline = $true)]
        [PsCustomObject[]]
        $Control,

        [PsCustomObject]
        $Preferences,

        [Switch]
        $AsHashtable
    )

    Begin {
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName System.Drawing

        $myPreferences = New-QuickformPreferences `
            -Preferences $Preferences

        $form = New-ControlsMain `
            -Preferences $myPreferences

        $list = @()
    }

    Process {
        $list += @($Control)
    }

    End {
        $layouts = [PsCustomObject]@{
            MultiLayout = $null;
            Sublayouts = @();
            Controls = @{};
        }

        $layouts = Set-QuickformMainLayout `
            -Layouts $layouts `
            -MainForm $form `
            -Control $list `
            -Preferences $myPreferences

        $confirm = switch ($form.ShowDialog()) {
            'OK' { $true }
            'Cancel' { $false }
        }

        $out = $list | Start-QuickformEvaluate `
            -Layouts $layouts

        if ($AsHashtable) {
            $table = @{}

            foreach ($property in $out.PsObject.Properties.Name) {
                $table[$property] = $out.$property
            }

            $out = $table
        }

        return [PsCustomObject]@{
            Confirm = $confirm;
            FormResult = $out;
        }
    }
}

function Get-QuickformControlType {
    Param(
        [String]
        $TypeName
    )

    $controlType = switch -Wildcard ($TypeName) {
        'String' { 'Field' }
        'Int*' { 'Numeric' }
        'Float' { 'Numeric' }
        'Double' { 'Numeric' }
        'Switch*' { 'Check' }
        'Bool*' { 'Check' }
        default { 'Field' }
    }

    return $controlType
}

function ConvertTo-QuickformParameter {
    Param(
        $ParameterInfo
    )

    $type = $ParameterInfo.ParameterType
    $validators = Get-FieldValidators -ParameterInfo $ParameterInfo
    $validatorType = $null

    $obj = [PsCustomObject]@{
        Name = $ParameterInfo.Name;
        Type = '';
    }

    if ($validators) {
        $validatorType = $validators.Type

        switch ($validatorType) {
            'Enum' {
                $obj.Type = 'Enum'

                $values = $validators.Values.Name | where {
                    $_ -ne 'value__'
                }

                $obj | Add-Member `
                    -MemberType NoteProperty `
                    -Name Symbols `
                    -Value ($values | foreach {
                        [PsCustomObject]@{
                            Name = $_;
                        }
                    })
            }

            'ValidSet' {
                $obj.Type = 'Enum'
                $values = $validators.Values

                $obj | Add-Member `
                    -MemberType NoteProperty `
                    -Name Symbols `
                    -Value ($values | foreach {
                        [PsCustomObject]@{
                            Name = $_;
                        }
                    })
            }

            'ValidRange' {
                $obj.Type = 'Numeric'

                $obj | Add-Member `
                    -MemberType NoteProperty `
                    -Name Minimum `
                    -Value $validators.Minimum

                $obj | Add-Member `
                    -MemberType NoteProperty `
                    -Name Maximum `
                    -Value $validators.Maximum
            }

            'ValidCount' {
                $obj | Add-Member `
                    -MemberType NoteProperty `
                    -Name MinCount `
                    -Value $validators.Minimum

                $obj | Add-Member `
                    -MemberType NoteProperty `
                    -Name MaxCount `
                    -Value $validators.Maximum
            }

            'ValidLength' {
                $obj | Add-Member `
                    -MemberType NoteProperty `
                    -Name MinLength `
                    -Value $validators.Minimum

                $obj | Add-Member `
                    -MemberType NoteProperty `
                    -Name MaxLength `
                    -Value $validators.Maximum
            }
        }
    }

    if ($obj.Type -eq '') {
        $obj.Type = Get-QuickformControlType `
            -TypeName $type.Name
    }

    return $obj
}

function ConvertTo-QuickformCommand {
    Param(
        [Parameter(ParameterSetName = 'ByCommandInfo')]
        [System.Management.Automation.CommandInfo]
        $CommandInfo,

        [Parameter(ParameterSetName = 'ByParameterSet')]
        $ParameterSet,

        [Switch]
        $IncludeCommonParameters
    )

    switch ($PsCmdlet.ParameterSetName) {
        'ByCommandInfo' {
            return $CommandInfo.Parameters.Keys | foreach {
                $CommandInfo.Parameters[$_]
            } | where {
                $IncludeCommonParameters `
                    -or -not (Test-IsCommonParameter -ParameterInfo $_)
            } | foreach {
                ConvertTo-QuickformParameter -ParameterInfo $_
            }
        }

        'ByParameterSet' {
            return $ParameterSet.Parameters | where {
                $IncludeCommonParameters `
                    -or -not (Test-IsCommonParameter -ParameterInfo $_)
            } | foreach {
                ConvertTo-QuickformParameter -ParameterInfo $_
            }
        }
    }
}

function Get-Quickform {
    [CmdletBinding(DefaultParameterSetName = 'ByCommandName')]
    Param(
        [Parameter(ParameterSetName = 'ByCommandName', Position = 0)]
        [String]
        $CommandName,

        [Parameter(ParameterSetName = 'ByCommandInfo', ValueFromPipeline = $true)]
        [System.Management.Automation.CommandInfo]
        $CommandInfo,

        [String]
        $ParameterSetName,

        [Switch]
        $IncludeCommonParameters,

        [Switch]
        $AsHashtable
    )

    function Get-NextIndex {
        Param([Int] $Index, [Int] $Count)

        $Index = if ($Index -ge ($Count - 1)) {
            0
        } else {
            $Index + 1
        }

        return $Index
    }

    function Get-PreviousIndex {
        Param([Int] $Index, [Int] $Count)

        $Index = if ($Index -le 0) {
            $Count - 1
        } else {
            $Index - 1
        }

        return $Index
    }

    if ($PsCmdlet.ParameterSetName -eq 'ByCommandName') {
        $CommandInfo = Get-Command -Name $CommandName
    }

    if (-not $CommandInfo) {
        return
    }

    $paramSets = if ($ParameterSetName) {
        $CommandInfo.ParameterSets | where {
            $_.Name -like $ParameterSetName
        }
    } else {
        $CommandInfo.ParameterSets
    }

    $defaultParamSet = $CommandInfo | Get-PropertyOrDefault `
        -Name DefaultParameterSet `
        -Default $paramSets[0]

    $currentIndex = 0

    while ($currentIndex -lt $paramSets.Count `
        -and $paramSets[$currentIndex].Name -ne $defaultParamSet)
    {
        $currentIndex = $currentIndex + 1
    }

    $index = 1

    $what = [PsCustomObject]@{
        ParameterSets = $paramSets | foreach {
            [PsCustomObject]@{
                Name = $_.Name;
                Index = $index;
                Preferences = [PsCustomObject]@{
                    Title = "Command: $CommandName $([Char] 0x2014) " `
                          + "ParameterSet $index`: $($_.Name)";
                };
                Controls = $_.Parameters | where {
                    $IncludeCommonParameters `
                        -or -not (Test-IsCommonParameter -ParameterInfo $_)
                } | foreach {
                    ConvertTo-QuickformParameter -ParameterInfo $_
                };
            }

            $index = $index + 1
        };
        CurrentParameterSetIndex = $currentIndex;
    }

    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $script:paramSet = $what.ParameterSets[$what.CurrentParameterSetIndex]

    if ($null -eq $script:paramSet) {
        return New-QuickformObject
    }

    $script:myPreferences = New-QuickformPreferences `
        -Preferences $paramSet.Preferences

    $script:form = New-ControlsMain `
        -Preferences $myPreferences

    $script:controls = $paramset.Controls

    $script:layouts = [PsCustomObject]@{
        MultiLayout = $null;
        Sublayouts = @();
        Controls = @{};
    }

    $script:layouts = Set-QuickformMainLayout `
        -Layouts $layouts `
        -MainForm $form `
        -Control $controls `
        -Preferences $myPreferences

    # Issue: Event handler fails to update variable from outer scope
    # Link: https://stackoverflow.com/questions/55403528/why-wont-variable-update
    # Retreived: 2022_03_02

    $script:form.add_KeyDown({
        $refresh = $false

        if (-not [System.Windows.Forms.Control]::ModifierKeys `
            -contains [System.Windows.Forms.Keys]::Alt)
        {
            return
        }

        switch ($_.KeyCode) {
            'Right' {
                $what.CurrentParameterSetIndex = Get-NextIndex `
                    -Index $what.CurrentParameterSetIndex `
                    -Count $what.ParameterSets.Count

                $refresh = $true
            }

            'Left' {
                $what.CurrentParameterSetIndex = Get-PreviousIndex `
                    -Index $what.CurrentParameterSetIndex `
                    -Count $what.ParameterSets.Count

                $refresh = $true
            }
        }

        if ($refresh) {
            $script:paramSet = $what.ParameterSets[$what.CurrentParameterSetIndex]

            $script:myPreferences = New-QuickformPreferences `
                -Preferences $paramSet.Preferences

            $script:controls = $paramset.Controls

            $script:layouts = Set-QuickformMainLayout `
                -Layouts $script:layouts `
                -MainForm $script:form `
                -Control $script:controls `
                -Preferences $script:myPreferences

            Set-ControlsCenterScreen `
                -Control $script:form

            $this.Focus()
        }
    })

    $confirm = switch ($script:form.ShowDialog()) {
        'OK' { $true }
        'Cancel' { $false }
    }

    $script:controls = `
        $what.ParameterSets[$what.CurrentParameterSetIndex].Controls

    $out = $script:controls | Start-QuickformEvaluate `
        -Layouts $script:layouts

    if ($AsHashtable) {
        $table = @{}

        foreach ($property in $out.PsObject.Properties.Name) {
            $table[$property] = $out.$property
        }

        $out = $table
    }

    return [PsCustomObject]@{
        Confirm = $confirm;
        FormResult = $out;
    }
}

function Start-Quickform {
    [CmdletBinding(DefaultParameterSetName = 'ByCommandName')]
    Param(
        [Parameter(ParameterSetName = 'ByCommandName', Position = 0)]
        [String]
        $CommandName,

        [Parameter(ParameterSetName = 'ByCommandInfo', ValueFromPipeline = $true)]
        [System.Management.Automation.CommandInfo]
        $CommandInfo,

        [String]
        $ParameterSetName,

        [Switch]
        $IncludeCommonParameters,

        [Switch]
        $AsHashtable
    )

    $quickform = [PsCustomObject]@{
        Confirm = $false;
        FormResult = @{};
    }

    switch ($PsCmdlet.ParameterSetName) {
        'ByCommandName' {
            $quickform = Get-Quickform `
                -CommandName $CommandName `
                -ParameterSetName:$ParameterSetName `
                -IncludeCommonParameters:$IncludeCommonParameters `
                -AsHashtable

            $CommandInfo = Get-Command `
                -Name $CommandName
        }

        'ByCommandInfo' {
            $quickform = Get-Quickform `
                -CommandInfo $CommandInfo `
                -ParameterSetName:$ParameterSetName `
                -IncludeCommonParameters:$IncludeCommonParameters `
                -AsHashtable

            $CommandName = $CommandInfo.Name
        }
    }

    $params = $quickform.FormResult | Get-TrimTable `
        -RemoveEmptyString

    if ($quickform.Confirm) {
        # # OLD (2022_03_02_211308)
        # Invoke-Expression "$CommandName `@params"

        & $CommandName @params
    }
}

