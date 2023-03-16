. "$PsScriptRoot\..\Controls.ps1"

$what = @(
    [PsCustomObject]@{
        "Id" = 1
        "First" = "Me!!!"
        "Last" = "999_99_99"
    },
    [PsCustomObject]@{
        "Id" = 2
        "First" = "Sus"
        "Last" = "Ihr Oth"
    }
)

Add-ControlsTypes
Open-ControlsTable `
    -Text 'What?' `
    -Rows $what
