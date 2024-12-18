$levels = 2

& "$('../' * $levels)Required.ps1"
. "$PsScriptRoot/$('../' * ($levels - 1))Closure.ps1"
. "$PsScriptRoot/$('../' * ($levels - 1))NumberSlider.ps1"
. "$PsScriptRoot/$('../' * ($levels - 1))Controls.ps1"
. "$PsScriptRoot/$('../' * ($levels - 1))Qform.ps1"

# $formInfo = Get-Content "$PsScriptRoot/$('../' * $levels)sample/myform.json" |
#     ConvertFrom-Json
# 
# return $formInfo.Preferences

$builder = [Controls]::new()
[void] $builder.Logger.Add({ $_ | Out-String | Write-Host })
$main = $builder.NewMain()

return $(
    [PsCustomObject]@{
        Builder = $builder
        Main = $main
    }
)
