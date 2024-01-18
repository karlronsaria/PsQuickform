class Logger {
    [ScriptBlock[]] $Handlers = @()

    [void] Log($Exception) {
        foreach ($handler in $this.Handlers) {
            $Exception | foreach $handler
        }
    }

    [Logger] Add([ScriptBlock] $Log) {
        $this.Handlers += @($Log)
        return $this
    }

    Logger([ScriptBlock] $Log) {
        $this.Add($Log)
    }

    Logger() {}

    static [Logger] ToConsole() {
        return [Logger]::new({ $_ | Out-String | Write-Host })
    }

    hidden static [ScriptBlock]
    ConvertToTryCatchBlock([ScriptBlock] $ScriptBlock) {
        $ast = $ScriptBlock.Ast
        $param = $ast.ParamBlock.Extent.Text

        return $(
            [ScriptBlock]::Create(
                (@($param) + @(
                    'Begin', 'Process', 'End' |
                    where {
                        $null -ne $ast."$($_)Block"
                    } |
                    foreach {
                        $block = $ast.
                            "$($_)Block".
                            Statements.
                            Extent.
                            Text -join "`n"

                        "$_ { try {$block} catch { `$Logger.Log(`$_) } }"
                    }
                )) -join ' '
            )
        )
    }

    [ScriptBlock] GetNewClosure($Parameters, [ScriptBlock] $ScriptBlock) {
        $myScript = [Logger]::ConvertToTryCatchBlock($ScriptBlock)

        return & {
            Param($Parameters, $Logger)
            return $myScript.GetNewClosure()
        } $Parameters $this
    }

    [ScriptBlock] GetNewClosure([ScriptBlock] $ScriptBlock) {
        return $this.GetNewClosure($null, $ScriptBlock)
    }
}

<#
.LINK
Issue: Event handler fails to update variable from outer scope
Url: <https://stackoverflow.com/questions/55403528/why-wont-variable-update>
Retreived: 2022_03_02
#>
function New-Closure {
    [CmdletBinding(DefaultParameterSetName = 'Throwing')]
    Param(
        [ScriptBlock]
        $ScriptBlock,

        $Parameters,

        [Parameter(ParameterSetName = 'NonThrowing')]
        $Logger
    )

    return $(
        switch ($PsCmdlet.ParameterSetName) {
            'Throwing' {
                & {
Param($Parameters)
return $ScriptBlock.GetNewClosure()
} $Parameters
            }

            'NonThrowing' {
                & {
Param($Parameters, $Logger)
return $Logger.GetNewClosure($ScriptBlock, $Parameters)
} $Parameters $Logger
            }
        }
    )
}

