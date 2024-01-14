#Requires -Module Pester

. $PsScriptRoot/../script/Closure.ps1

Describe 'New-Closure' {
    Context 'Using a Logger' {
        It 'Uses bindings from both temporary and lexical scopes and logs to a variable' {
            $closure = New-Closure `
                -Parameters 'what' `
                -Logger ([Logger]::new({
Param($E)
Set-Variable -Scope 'Global' -Name 'MyErrorTest__' -Value ($E | Out-String)
})) `
                -ScriptBlock {
Param([String] $MyWhat)

"[$Parameters]: [$MyWhat]"

if ($MyWhat -eq 'hee') {
    throw
}
}

            $MyClosureTest__ = & $closure -MyWhat 'hee'

            $actual = "$MyClosureTest__`r`n$MyErrorTest__"

            $expected = @{
                5 = @"
[what]: [hee]
ScriptHalted
At line:3 char:5
+     throw
+     ~~~~~
    + CategoryInfo          : OperationStopped: (:) [], RuntimeException
    + FullyQualifiedErrorId : ScriptHalted
 

"@

                7 = @"
[what]: [hee]
Exception: 
Line |
   3 |      throw
     |      ~~~~~
     | ScriptHalted

"@
            }

            $actual | Should Be $expected[$PsVersionTable.PsVersion.Major]
        }
    }
}

