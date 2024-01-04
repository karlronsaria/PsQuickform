dir $PsScriptRoot\..\*.ps1 | foreach { . $_ }

Get-Command Add-ControlsTypes |
    query Definition |
    foreach { iex $_ }

# Add-Type -AssemblyName PresentationFramework

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

        $closure = New-Closure `
            -InputObject ([PsCustomObject]@{
                Qform = $form
                Types = $types
                ElementName = 'Hostname'
                GetAccessor = $getAccessor
            }) `
            -ScriptBlock {
                ($InputObject.Qform.Controls())['MyViewLabel'].Content =
                    "What: ($(
                        & $InputObject.GetAccessor `
                            -Qform $InputObject.Qform `
                            -Types $InputObject.Types `
                            -ElementName $InputObject.ElementName
                    ))"
            }

        $myField.Add_TextChanged($closure)

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







