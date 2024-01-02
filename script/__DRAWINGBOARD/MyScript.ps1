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




        $myField = $form.Controls()['Hostname']
        $myEnum = $form.Controls()['ClientSize']
        $myLabel = $form.Controls()['MyViewLabel']

        $closure = New-Closure `
            -InputObject ([PsCustomObject]@{
                Controls = $form.Controls()
                Types = $types
            }) `
            -ScriptBlock {
                $InputObject.Controls['MyViewLabel'].Content =
                    "What: ($($InputObject.Controls['Hostname'] |
                        foreach $InputObject.Types.Table.'Field'.GetValue))"
            }

        $myField.Add_TextChanged($closure)

        # $myUpdate = New-Closure `
        #     -InputObject $form.Controls() `
        #     -ScriptBlock {
        #         return "what_-_$($InputObject['Hostname'].Text)"
        #     }

        # $myTextChange = New-Closure `
        #     -InputObject ([PsCustomObject]@{
        #         Label = $myLabel
        #         Update = $myUpdate
        #     }) `
        #     -ScriptBlock {
        #         $InputObject.Label.Text = "I just changed!" # & $InputObject.Update
        #     }

        # $myField.Add_TextChanged({
        #     $myLabel.Text = "I just changed!"  # & $myUpdate
        # })
        # $myField.Add_TextChanged($myTextChange)



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







