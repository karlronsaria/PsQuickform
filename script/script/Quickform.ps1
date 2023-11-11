. $PsScriptRoot\Controls.ps1
. $PsScriptRoot\CommandInfo.ps1
. $PsScriptRoot\Qform.ps1

<#
    .SYNOPSIS
    Shows a Quickform menu.

    .PARAMETER InputObject
    An object containing the specifications for a Quickform menu.
    Should match the JSON:

        {
            Preferences: [],
            MenuSpecs: []
        }

    .PARAMETER MenuSpecs
    Any number of objects containing the specifications for a control in a
    Quickform menu.
    Must match the JSON:

        {
            Name: "",
            Type: "",
            ...
        }

    .PARAMETER Preferences
    An object containing the specifications for customizing the look and
    default behavior of a Quickform menu.

    .PARAMETER CommandName
    The name of a PowerShell function or cmdlet.

    .PARAMETER ParameterSetName
    The name of a ParameterSet used by a PowerShell function or cmdlet. Can be
    procured from a call to 'Get-Command'.

    Example:

        $cmdInfo = Get-Command Get-Item
        $parameterSetNames = $cmdInfo.ParameterSets | foreach { $_.Name }

        Show-QformMenu `
            -CommandName $cmdInfo.Name `
            -ParameterSetName $parameterSetNames[0]

        Show-QformMenu `
            -CommandInfo $cmdInfo `
            -ParameterSetName $cmdInfo.DefaultParameterSet

    .PARAMETER IncludeCommonParameters
    Indicates that the CommonParameters should be included in the Quickform
    menu.

    See about_CommonParameters

    .PARAMETER IgnoreLists
    Indicates that array types should be handled using single-value controls,
    such as Fields, rather than using a ListBox.

    .PARAMETER AnswersAsHashtable
    Indicates that the menu answers returned should be given in hashtable
    form.

    .PARAMETER StartingIndex
    The index for the starting page, if the form has multiple pages.

    .OUTPUTS
        PsCustomObject
            An object containing Quickform menu answers.
            Matches the JSON:

                {
                    Confirm: <Bool>,
                    MenuAnswers: {}
                }
#>
function Show-QformMenu {
    [OutputType([PsCustomObject])]
    [CmdletBinding(DefaultParameterSetName = 'BySingleObject')]
    Param(
        [Parameter(
            ParameterSetName = 'BySingleObject',
            ValueFromPipeline = $true)]
        [PsCustomObject]
        $InputObject,

        [Parameter(
            ParameterSetName = 'BySeparateObjects')]
        [ValidateScript(
            {
                $valid = $true

                foreach ($type in $_.PsObject.Properties.Type) {
                    $valid = $valid -and ( `
                        $type -in `
                            (Get-QformResource -Type MenuSpec).Name `
                    )
                }

                return $valid
            }
        )]
        [PsCustomObject[]]
        $MenuSpecs,

        [PsCustomObject]
        $Preferences,

        [Parameter(
            ParameterSetName = 'ByCommandName',
            Position = 0)]
        [String]
        $CommandName,

        [Parameter(
            ParameterSetName = 'ByCommandName')]
        [String]
        $ParameterSetName,

        [Parameter(
            ParameterSetName = 'ByCommandName')]
        [Switch]
        $IncludeCommonParameters,

        [Parameter(
            ParameterSetName = 'ByCommandName')]
        [Switch]
        $IgnoreLists,

        [Switch]
        $AnswersAsHashtable,

        [Nullable[Int]]
        $StartingIndex
    )

    Begin {
        function Convert-MsExcelInfoToPageInfo {
            Param(
                [PsCustomObject]
                $InputObject,

                [PsCustomObject]
                $Preferences
            )

            $pageInfo = foreach ($sheet in $InputObject.Sheets) {
                [PsCustomObject]@{
                    Name = $sheet.Name
                    MenuSpecs = @([PsCustomObject]@{
                        Name = 'Table'
                        Rows = $sheet.Rows
                    })
                }
            }

            $Preferences.Caption = $InputObject.FileName

            return [PsCustomObject]@{
                Preferences = $Preferences
                PageInfo = $pageInfo
            }
        }

        $list = @()
    }

    Process {
        switch ($PsCmdlet.ParameterSetName) {
            'BySingleObject' {
                $list += @($InputObject)
            }
        }
    }

    End {
        switch ($PsCmdlet.ParameterSetName) {
            'BySingleObject' {
                switch ($list.Count) {
                    0 {
                        $Preferences = Get-QformPreference `
                            -Preferences $Preferences

                        return Get-QformMenu `
                            -Preferences $Preferences
                    }

                    1 {
                        $obj = $list[0]

                        $prefs = Get-QformPreference `
                            -Preferences $obj.Preferences `
                            -Reference $Preferences

                        $Preferences = Get-QformPreference `
                            -Preferences $prefs

                        $pageInfo = $obj.MenuSpecs
                        $properties = $obj.PsObject.Properties.Name
                        $isTabControl = $false

                        if ($null -eq $pageInfo `
                            -and $properties -contains 'FileName' `
                            -and $properties -contains 'Sheets')
                        {
                            $info = Convert-MsExcelInfoToPageInfo `
                                -InputObject $obj `
                                -Preferences $Preferences

                            $Preferences = $info.Preferences
                            $pageInfo = $info.PageInfo
                            $isTabControl = $true
                        }

                        if ($null -eq $pageInfo) {
                            $pageInfo = $list
                        }

                        return Get-QformMenu `
                            -PageInfo $pageInfo `
                            -Preferences $Preferences `
                            -AnswersAsHashtable:$AnswersAsHashtable `
                            -IsTabControl:$isTabControl `
                            -StartingIndex $StartingIndex
                   }

                    default {
                        $Preferences = Get-QformPreference `
                            -Preferences $Preferences

                        return Get-QformMenu `
                            -PageInfo $list `
                            -Preferences $Preferences `
                            -AnswersAsHashtable:$AnswersAsHashtable `
                            -IsTabControl:$isTabControl `
                            -StartingIndex $StartingIndex
                    }
                }
            }

            'BySeparateObjects' {
                $Preferences = Get-QformPreference `
                    -Preferences $Preferences

                return Get-QformMenu `
                    -PageInfo $MenuSpecs `
                    -Preferences $Preferences `
                    -AnswersAsHashtable:$AnswersAsHashtable
            }

            'ByCommandName' {
                return Show-QformMenuForCommand `
                    -CommandName $CommandName `
                    -ParameterSetName $ParameterSetName `
                    -IncludeCommonParameters:$IncludeCommonParameters `
                    -IgnoreLists:$IgnoreLists `
                    -AnswersAsHashtable:$AnswersAsHashtable `
                    -StartingIndex $StartingIndex
            }
        }
    }
}

<#
    .SYNOPSIS
    Gets Quickform menu specs for a PowerShell function or cmdlet.

    .PARAMETER CommandName
    The name of a PowerShell function or cmdlet.

    .PARAMETER CommandInfo
    An object containing PowerShell function or cmdlet information, typically
    procured from a call to 'Get-Command'.

    Example:

        $cmdInfo = Get-Command Get-Item
        ConvertTo-QformMenuSpec -CommandInfo $cmdInfo
        $cmdInfo | ConvertTo-QformMenuSpec

    .PARAMETER ParameterSetName
    The name of a ParameterSet used by a PowerShell function or cmdlet. Can be
    procured from a call to 'Get-Command'.

    Example:

        $cmdInfo = Get-Command Get-Item
        $parameterSetNames = $cmdInfo.ParameterSets | foreach { $_.Name }

        ConvertTo-QformMenuSpec `
            -CommandName $cmdInfo.Name `
            -ParameterSetName $parameterSetNames[0]

        ConvertTo-QformMenuSpec `
            -CommandInfo $cmdInfo `
            -ParameterSetName $cmdInfo.DefaultParameterSet

    .PARAMETER ParameterSet
    An object containing parameter information associated with a single
    ParameterSet used by a PowerShell function or cmdlet. Can be procured from
    a call to 'Get-Command'.

    Example:

        $cmdInfo = Get-Command Get-Item
        $parameterSet = $cmdInfo.ParameterSets | where Name -eq 'LiteralPath'
        ConvertTo-QformMenuSpec -ParameterSet $parameterSet

    .PARAMETER IncludeCommonParameters
    Indicates that the CommonParameters should be included in the Quickform menu.

    See about_CommonParameters

    .INPUTS
        PsCustomObject
            Pipeline accepts command info.

    .OUTPUTS
        PsCustomObject
            An object containing Quickform menu specs.
#>
function ConvertTo-QformMenuSpec {
    [OutputType([PsCustomObject])]
    [CmdletBinding(DefaultParameterSetName = 'ByCommandName')]
    Param(
        [Parameter(
            ParameterSetName = 'ByCommandName',
            Position = 0)]
        [String]
        $CommandName,

        [Parameter(
            ParameterSetName = 'ByCommandInfo',
            ValueFromPipeline = $true)]
        [System.Management.Automation.CommandInfo]
        $CommandInfo,

        [Parameter(
            ParameterSetName = 'ByParameterSet')]
        $ParameterSet,

        [Switch]
        $IncludeCommonParameters
    )

    DynamicParam {
        if ($PsCmdlet.ParameterSetName -like 'ByCommand*') {
            $paramDictionary = `
                New-Object `
                System.Management.Automation.RuntimeDefinedParameterDictionary
            $attributeCollection = `
                New-Object `
                System.Collections.ObjectModel.Collection[System.Attribute]
            $attribute = `
                New-Object `
                System.Management.Automation.ParameterAttribute
            $attribute.DontShow = $false

            $attributeCollection.Add($attribute)

            $param = `
                New-Object `
                System.Management.Automation.RuntimeDefinedParameter( `
                    'ParameterSetName', `
                    [String], `
                    $attributeCollection `
                )

            $paramDictionary.Add('ParameterSetName', $param)
            return $paramDictionary
        }
    }

    Process {
        switch ($PsCmdlet.ParameterSetName) {
            'ByCommandName' {
                $CommandInfo = Get-Command -Name $CommandName

                if ($PsBoundParameters.ParameterSetName) {
                    $ParameterSet = $CommandInfo.ParameterSets | Where-Object {
                        $_.Name -like $PsBoundParameters.ParameterSetName
                    }

                    return ConvertTo-QformMenuSpec `
                        -ParameterSet $ParameterSet `
                        -IncludeCommonParameters:$IncludeCommonParameters
                }

                return ConvertTo-QformMenuSpec `
                    -CommandInfo $CommandInfo `
                    -IncludeCommonParameters:$IncludeCommonParameters
            }

            'ByCommandInfo' {
                if ($PsBoundParameters.ParameterSetName) {
                    $ParameterSet = $CommandInfo.ParameterSets | Where-Object {
                        $_.Name -like $PsBoundParameters.ParameterSetName
                    }

                    return ConvertTo-QformMenuSpec `
                        -ParameterSet $ParameterSet `
                        -IncludeCommonParameters:$IncludeCommonParameters
                }

                return $CommandInfo.Parameters.Keys | ForEach-Object {
                    $CommandInfo.Parameters[$_]
                } | Where-Object {
                    $IncludeCommonParameters `
                        -or -not (Test-IsCommonParameter -ParameterInfo $_)
                } | ForEach-Object {
                    ConvertTo-QformParameter -ParameterInfo $_
                }
            }

            'ByParameterSet' {
                return $ParameterSet.Parameters | Where-Object {
                    $IncludeCommonParameters `
                        -or -not (Test-IsCommonParameter -ParameterInfo $_)
                } | ForEach-Object {
                    ConvertTo-QformParameter -ParameterInfo $_
                }
            }
        }
    }
}

<#
    .SYNOPSIS
    Runs a given PowerShell function or cmdlet by procuring argument values from
    a Quickform menu.

    .PARAMETER CommandName
    The name of a PowerShell function or cmdlet.

    .PARAMETER CommandInfo
    An object containing PowerShell function or cmdlet information, typically
    procured from a call to 'Get-Command'.

    Example:

        $cmdInfo = Get-Command Get-Item
        Invoke-QformCommand -CommandInfo $cmdInfo
        $cmdInfo | Invoke-QformCommand

    .PARAMETER ParameterSetName
    The name of a ParameterSet used by a PowerShell function or cmdlet. Can be
    procured from a call to 'Get-Command'.

    Example:

        $cmdInfo = Get-Command Get-Item
        $parameterSetNames = $cmdInfo.ParameterSets | foreach { $_.Name }

        Invoke-QformCommand `
            -CommandInfo $cmdInfo `
            -ParameterSetName $parameterSetNames[0]

    .PARAMETER IncludeCommonParameters
    Indicates that the CommonParameters should be included in the Quickform menu.

    See about_CommonParameters

    .PARAMETER PassThru
    Indicates that Quickform menu specs should be returned along with the menu
    answers.

    .PARAMETER IgnoreLists
    Indicates that array types should be handled using single-value controls,
    such as Fields, rather than using a ListBox.

    .PARAMETER AnswersAsHashtable
    Indicates that the menu answers returned should be given in hashtable form.

    .INPUTS
        PsCustomObject
            Pipeline accepts command info.

    .OUTPUTS
        any
            The return value of whatever command is called by this cmdlet.

        PsCustomObject
            When PassThru is active, an object containing Quickform menu
            answers, a command call string, and the return value of whatever
            command is called by this cmdlet.
            Matches the JSON:

                {
                    Confirm: <Bool>,
                    MenuAnswers: {},
                    CommandString: "",
                    Value: <any>
                }
#>
function Invoke-QformCommand {
    [OutputType([Object])]
    [OutputType([PsCustomObject])]
    [CmdletBinding(DefaultParameterSetName = 'ByCommandName')]
    Param(
        [Parameter(
            ParameterSetName = 'ByCommandName',
            Position = 0)]
        [String]
        $CommandName,

        [Parameter(
            ParameterSetName = 'ByCommandInfo',
            ValueFromPipeline = $true)]
        [System.Management.Automation.CommandInfo]
        $CommandInfo,

        [String]
        $ParameterSetName,

        [Switch]
        $IncludeCommonParameters,

        [Switch]
        $PassThru,

        [Switch]
        $IgnoreLists,

        [Switch]
        $AnswersAsHashtable
    )

    Process {
        if ($AnswersAsHashtable -and -not $PassThru) {
            Write-Warning ((Get-ThisFunctionName) `
                + ": AnswersAsHashtable has no effect unless PassThru is specified.")
        }

        $quickform = [PsCustomObject]@{
            Confirm = $false
            MenuAnswers = @{}
        }

        switch ($PsCmdlet.ParameterSetName) {
            'ByCommandName' {
                $quickform = Show-QformMenuForCommand `
                    -CommandName $CommandName `
                    -ParameterSetName:$ParameterSetName `
                    -IncludeCommonParameters:$IncludeCommonParameters `
                    -IgnoreLists:$IgnoreLists

                $CommandInfo = Get-Command `
                    -Name $CommandName
            }

            'ByCommandInfo' {
                $quickform = Show-QformMenuForCommand `
                    -CommandInfo $CommandInfo `
                    -ParameterSetName:$ParameterSetName `
                    -IncludeCommonParameters:$IncludeCommonParameters `
                    -IgnoreLists:$IgnoreLists

                $CommandName = $CommandInfo.Name
            }
        }

        $table = $quickform.MenuAnswers | ConvertTo-Hashtable

        $params = $table | Get-NonEmptyTable `
            -RemoveEmptyString

        $value = if ($quickform.Confirm) {
            & $CommandName @params
        } else {
            $null
        }

        if ($PassThru) {
            if ($AnswersAsHashtable) {
                $quickform.MenuAnswers = $table
            }

            $quickform | Add-Member `
                -MemberType NoteProperty `
                -Name Value `
                -Value $value

            return $quickform
        }

        return $value
    }
}

<#
    .SYNOPSIS
    Creates a Quickform new menu.

    .PARAMETER PageInfo
    Any number of objects containing the specifications for a control in a
    Quickform menu.
    Must match the JSON:

        {
            Name: "",
            Type: "",
            ...
        }

    .PARAMETER Preferences
    An object containing the specifications for customizing the look and
    default behavior of a Quickform menu.

    .PARAMETER AnswersAsHashtable
    Indicates that the menu answers returned should be given in hashtable
    form.

    .PARAMETER IsTabControl
    Indicates that multiple pages should be handled using a form with tabs
    rather than a form that resets for each page turn.

    .PARAMETER StartingIndex
    The index of the default page to show once the form is displayed. A value
    less than 0 indicates a single-page form.

    .INPUTS
        PsCustomObject
            Pipeline accepts any number of Quickform menu specs.

    .OUTPUTS
        PsCustomObject
            An object containing Quickform menu answers.
            Matches the JSON:

                {
                    Confirm: <Bool>,
                    MenuAnswers: {}
                }
#>
function Get-QformMenu {
    [OutputType([PsCustomObject])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline = $true)]
        [PsCustomObject[]]
        $PageInfo,

        [PsCustomObject]
        $Preferences,

        [Switch]
        $IsTabControl,

        [Switch]
        $AnswersAsHashtable,

        [Nullable[Int]]
        $StartingIndex
    )

    Begin {
        $myPageInfo = @()
    }

    Process {
        $myPageInfo += @($PageInfo)
    }

    End {
        $myPreferences = Get-QformPreference `
            -Preferences $Preferences

        $form = [Qform]::new(
            $myPreferences,
            $myPageInfo,
            [Boolean]$IsTabControl,
            $StartingIndex
        )

        $confirm = $form.ShowDialog()

        $answers = $form.MenuSpecs() `
            | Start-QformEvaluate `
                -Controls $form.Controls() `
            | Get-NonEmptyObject `
                -RemoveEmptyString

        if ($AnswersAsHashtable) {
            $answers = $answers | ConvertTo-Hashtable
        }

        return [PsCustomObject]@{
            Confirm = $confirm
            MenuAnswers = $answers
        }
    }
}

function Start-QformEvaluate {
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline = $true)]
        [PsCustomObject[]]
        $MenuSpecs,

        [Hashtable]
        $Controls
    )

    Begin {
        $out = [PsCustomObject]@{}
    }

    Process {
        foreach ($item in $MenuSpecs) {
            # todo: attempt cleaner solution
            $value = switch ($item.Type) {
                'Check' {
                    [PsCustomObject]@{
                        Items = $Controls[$item.Name].IsChecked
                    }
                }

                'Field' {
                    [PsCustomObject]@{
                        Items = $Controls[$item.Name].Text
                    }
                }

                'Enum' {
                    $obj = $Controls[$item.Name]

                    switch ($obj.As) {
                        'RadioPanel' {
                            $buttons = $obj.Object

                            [PsCustomObject]@{
                                Items =
                                    if ($buttons) {
                                        $buttons.Keys | Where-Object {
                                            $buttons[$_].IsChecked
                                        }
                                    } else {
                                        $null
                                    }
                            }
                        }

                        'DropDown' {
                            [PsCustomObject]@{
                                Items = $obj.Object.SelectedItem
                            }
                        }
                    }

                    # # karlr (2023_04_17)
                    # # - consider removing
                    # if ($temp -eq 'None') {
                    #     $null
                    # }
                    # else {
                    #     $temp
                    # }
                }

                'Numeric' {
                    [PsCustomObject]@{
                        Items = $Controls[$item.Name].Value
                    }
                }

                'List' {
                    [PsCustomObject]@{
                        Items = $Controls[$item.Name].Items
                    }
                }

                'Table' {
                    [PsCustomObject]@{
                        Items = $Controls[$item.Name].SelectedItems
                    }
                }
            }

            $out | Add-Member `
                -MemberType NoteProperty `
                -Name $item.Name `
                -Value $value.Items
        }
    }

    End {
        return $out
    }
}

<#
    .SYNOPSIS
    Converts menu answers into the parameter-argument list of a command call
    string.

    .PARAMETER MenuAnswers
    An object containing the key-value pairs set by a Quickform menu.

    .OUTPUTS
        System.String
            The parameter-argument-list portion of a command call string.
#>
function ConvertTo-QformString {
    [OutputType([String])]
    Param(
        [PsCustomObject]
        $MenuAnswers
    )

    $outStr = ""

    foreach ($property in $MenuAnswers.PsObject.Properties) {
        $name = $property.Name
        $value = $property.Value

        if ($null -eq $value) {
            continue
        }

        $outStr += switch -Regex ($value.GetType().Name) {
            'String' {
                if (-not [String]::IsNullOrEmpty($value)) {
                    " -$name `"$value`""
                }
            }

            'Bool.*' {
                if ($value) {
                    " -$name"
                }
            }

            'Int.*|Decimal|Float|Double' {
                " -$name $value"
            }

            '.*\[\]' {
                " -$name $(($value | % { "`""$_"`"" }) -join ', ')"
            }
        }
    }

    return $outStr
}

<#
    .SYNOPSIS
    Shows a menu with controls matching the parameters of a given function or
    cmdlet.

    .PARAMETER CommandName
    The name of a PowerShell function or cmdlet.

    .PARAMETER CommandInfo
    An object containing PowerShell function or cmdlet information, typically
    procured from a call to 'Get-Command'.

    Example:

        $cmdInfo = Get-Command Get-Item
        ConvertTo-QformMenuSpec -CommandInfo $cmdInfo
        $cmdInfo | ConvertTo-QformMenuSpec

    .PARAMETER ParameterSetName
    The name of a ParameterSet used by a PowerShell function or cmdlet. Can be
    procured from a call to 'Get-Command'.

    Example:

        $cmdInfo = Get-Command Get-Item

        $parameterSetNames = $cmdInfo.ParameterSets | foreach { $_.Name }
        Show-QformMenuForCommand -ParameterSetName $parameterSetNames[0]

        Show-QformMenuForCommand -ParameterSetName $cmdInfo.DefaultParameterSet

    .PARAMETER IncludeCommonParameters
    Indicates that the CommonParameters should be included in the Quickform
    menu.

    See about_CommonParameters

    .PARAMETER IgnoreLists
    Indicates that array types should be handled using single-value controls,
    such as Fields, rather than using a ListBox.

    .PARAMETER AnswersAsHashtable
    Indicates that the menu answers returned should be given in hashtable
    form.

    .PARAMETER StartingIndex
    The index for the starting page, if the form has multiple pages.

    .INPUTS
        PsCustomObject
            Pipeline accepts command info.

    .OUTPUTS
        PsCustomObject
            An object containing Quickform menu answers and a command call
            string.
            Matches the JSON:

                {
                    Confirm: <Bool>,
                    MenuAnswers: {},
                    CommandString: ""
                }
#>
function Show-QformMenuForCommand {
    [OutputType([PsCustomObject])]
    [CmdletBinding(DefaultParameterSetName = 'ByCommandName')]
    Param(
        [Parameter(
            ParameterSetName = 'ByCommandName',
            Position = 0)]
        [String]
        $CommandName,

        [Parameter(
            ParameterSetName = 'ByCommandInfo',
            ValueFromPipeline = $true)]
        [System.Management.Automation.CommandInfo]
        $CommandInfo,

        [String]
        $ParameterSetName,

        [Switch]
        $IncludeCommonParameters,

        [Switch]
        $IgnoreLists,

        [Switch]
        $AnswersAsHashtable,

        [Nullable[Int]]
        $StartingIndex
    )

    Process {
        switch ($PsCmdlet.ParameterSetName) {
            'ByCommandName' {
                $CommandInfo = Get-Command -Name $CommandName
            }

            'ByCommandInfo' {
                $CommandName = $CommandInfo.Name
            }
        }

        if (-not $CommandInfo) {
            return
        }

        $preferences = Get-QformPreference `
            -Preferences ([PsCustomObject]@{
                Caption = "Command: $CommandName"
            })

        $info = Convert-CommandInfoToPageInfo `
            -CommandInfo $CommandInfo `
            -ParameterSetName $ParameterSetName `
            -IncludeCommonParameters:$IncludeCommonParameters `
            -IgnoreLists:$IgnoreLists `
            -StartingIndex $StartingIndex

        $formResult = Get-QformMenu `
            -PageInfo $info.PageInfo `
            -Preferences $preferences `
            -IsTabControl `
            -AnswersAsHashtable:$AnswersAsHashtable `
            -StartingIndex $info.StartingIndex

        $parameterString = ConvertTo-QformString `
            -MenuAnswers $formResult.MenuAnswers

        return [PsCustomObject]@{
            Confirm = $formResult.Confirm
            MenuAnswers = $formResult.Answers
            CommandString = "$CommandName$parameterString"
        }
    }
}

