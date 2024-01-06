dir $PsScriptRoot\..\*.ps1 | foreach { . $_ }

Get-Command Add-ControlsTypes |
    query Definition |
    foreach { iex $_ }

Add-Type -AssemblyName PresentationFramework

function Get-What {
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

                                # Pages |
                                # where { $_.Name -eq 'Hostname' } |
                                # foreach { $_.Type }

        # $closure = New-Closure `
        #     -InputObject ([PsCustomObject]@{
        #         Controls = $form.Controls()
        #         Pages = $form.MenuSpecs()
        #         Types = $types
        #     }) `
        #     -ScriptBlock {
        #         $InputObject.Controls['MyViewLabel'].Content =
        #             "What: ($(
        #                 $InputObject.Controls['Hostname'] |
        #                 foreach $InputObject.
        #                     Types.
        #                     Table.'Field'.GetValue
        #             ))"
        #     }





        $myField = $form.Controls()['Hostname']
        $myEnum = $form.Controls()['ClientSize']
        $myLabel = $form.Controls()['MyViewLabel']

        $getAccessor = {
            Param(
                $Qform,

                [PsCustomObject]
                $Types,

                [String]
                $ElementName
            )

            $element = ($Qform.Controls())[$ElementName]

            $type = $Qform.MenuSpecs() |
                where { $_.Name -eq $ElementName } |
                foreach { $_.Type }

            return $element |
                foreach $Types.Table.$type.GetValue
        }

        $expression =
            "What: (<Hostname>: <Username>) The: (<ClientSize>) Cores: (<NumberOfCpus>)"

        $captures = [Regex]::Matches($expression, "\<[^\<\>]+\>")
        $bindings = @()

        foreach ($capture in $captures) {
            $name = $capture.Value -replace "^\<|\>$", ""

            $what =
@"
& `$InputObject.GetAccessor -Qform `$InputObject.Qform -Types `$InputObject.Types -ElementName $name
"@

            $expression = $expression -replace $capture, "`$($what)"
            $bindings += @($name)
        }

        $closure = New-Closure `
            -InputObject ([PsCustomObject]@{
                Qform = $form
                Types = $types
                What = "`"$expression`""
                GetAccessor = $getAccessor
            }) `
            -ScriptBlock {
                ($InputObject.Qform.Controls())['MyViewLabel'].Content =
                    iex $InputObject.What
            }

        foreach ($binding in $bindings) {
            $script:control = $form.Controls()[$binding]

            $type = ($form.MenuSpecs() |
                where { $_.Name -eq $binding }).
                Type

            # $script:control.GetType().Name

            $eventName = $types.Events.($script:control.GetType().Name)
            $script:control."Add_$eventName"($closure)

            # $element = $types.Table.$type
            # $script:eventObject = $script:control |
            #     foreach $element.GetEventObject
            # $eventName = $types.Events.($script:eventObject.GetType().Name)
            # $script:eventObject."Add_$eventName"($closure)
        }

        # $eventObject = $control |
        #     foreach $types.Table.$(($form.MenuSpecs() |
        #     where { $_.Name -eq 'ClientSize' }).
        #     Type).GetEventObject

        # $eventName = $types.Events.($eventObject.GetType().Name)

        # $eventObject.
        # "Add_$eventName"($closure)

        # $form.
        #     Controls()['ClientSize'].
        #     Object.
        #     Values[0].
        #     "Add_$('Checked')"($closure)

        # $form.
        #     Controls()['ClientSize'].
        #     Object.
        #     Values[0].
        #     "Add_$('Checked')"($closure)

        # $object[$object.Keys[0]].Add_Checked($closure)
        # $form.Controls()['NumberOfCpus'].Add_TextChanged($closure)

        $myLabel.Content = 'HWAT!'

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

$what = dir "$PsScriptRoot\myform.json" |
    cat |
    ConvertFrom-Json

Get-What `
    -PageInfo $what.MenuSpecs `
    -Preferences $what.Preferences







