function Get-PropertyOrDefault {
    Param(
        [Parameter(ValueFromPipeline = $true)]
        [PsCustomObject]
        $InputObject,

        [String]
        $Name,

        $Default = $null
    )

    End {
        if ($null -eq $InputObject) {
            return $Default
        }

        if ($InputObject.PsObject.Properties.Name -notcontains $Name) {
            return $Default
        }

        return $InputObject.$Name
    }
}

<#
    .SYNOPSIS
    Given a set of key-value pairs, either as a Hashtable or PsCustomObject,
    returns a new set with no unset (null or empty) values.

    .PARAMETER InputObject
    Input key-value pair object, to be sifted of empty values.

    .PARAMETER RemoveEmptyString
    Indicates that empty strings should be removed along with null values.

    .INPUTS
        any
            Accepts any type of input; expects a Hashtable or PsCustomObject.

    .OUTPUTS
        System.Collections.Hashtable
            When the input is a Hashtable, a Hashtable matching the input with all
            key-value pairs removed which have empty values.

        PsCustomObject
            When the input is a PsCustomObject, a PsCustomObject matching the
            input with all properties removed which have empty values.

        any
            Matches the input.
#>
function Get-NonEmpty {
    [OutputType([Hashtable])]
    [OutputType([PsCustomObject])]
    [OutputType([Object])]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline = $true)]
        $InputObject,

        [Switch]
        $RemoveEmptyString
    )

    Process {
        $what = switch ($InputObject.GetType().Name) {
            'Hashtable' {
                $InputObject | Get-NonEmptyTable `
                    -RemoveEmptyString:$RemoveEmptyString
            }

            'PsCustomObject' {
                $InputObject | Get-NonEmptyObject `
                    -RemoveEmptyString:$RemoveEmptyString
            }

            default {
                $InputObject
            }
        }

        return $what
    }
}

function Test-ValueIsNonEmpty {
    Param(
        $InputObject,

        [Switch]
        $RemoveEmptyString
    )

    if ($null -eq $InputObject) {
        return $false
    }

    return $(switch ($InputObject) {
        { $_ -is [String] } {
            -not $RemoveEmptyString -or $InputObject -ne ''
        }

        { $_ -is [System.Windows.Controls.ItemCollection] } {
            $InputObject.Count -gt 0
        }

        default {
            $true
        }
    })
}

function Get-NonEmptyTable {
    [OutputType([Hashtable])]
    Param(
        [Parameter(ValueFromPipeline = $true)]
        [Hashtable]
        $InputObject,

        [Switch]
        $RemoveEmptyString
    )

    Process {
        if ($null -eq $InputObject) {
            return
        }

        $table = @{}

        $InputObject.Keys | where {
            $name = $_;
            $value = $InputObject[$_];

            Test-ValueIsNonEmpty `
                -InputObject $value `
                -RemoveEmptyString:$RemoveEmptyString
        } | foreach {
            $table.Add($name, $value)
        }

        return $table
    }
}

function Get-NonEmptyObject {
    [OutputType([PsCustomObject])]
    Param(
        [Parameter(ValueFromPipeline = $true)]
        [PsCustomObject]
        $InputObject,

        [Switch]
        $RemoveEmptyString
    )

    Process {
        $obj = [PsCustomObject]@{}

        $InputObject.PsObject.Properties | where {
            $type = $_.MemberType;
            $name = $_.Name;
            $value = $_.Value;

            Test-ValueIsNonEmpty `
                -InputObject $value `
                -RemoveEmptyString:$RemoveEmptyString
        } | foreach {
            $obj | Add-Member `
                -MemberType $type `
                -Name $name `
                -Value $value
        }

        return $obj
    }
}

function ConvertTo-Hashtable {
    Param(
        [Parameter(ValueFromPipeline = $true)]
        [PsCustomObject]
        $InputObject
    )

    Process {
        $table = @{}

        foreach ($property in $InputObject.PsObject.Properties.Name) {
            $table[$property] = $InputObject.$property
        }

        return $table
    }
}

<#
    .SYNOPSIS
    By default, returns the name of the function that called it. Increasing
    StackIndex returns the name of the next function up in the call stack.

    .LINK
    Url: <https://stackoverflow.com/questions/3689543/is-there-a-way-to-retrieve-a-powershell-function-name-from-within-a-function>
    Url: <https://stackoverflow.com/users/7407752/jakobii>
    Retrieved: 2022-03-05
#>
function Get-ThisFunctionName {
    Param(
        [Int]
        $StackIndex = 1
    )

    return [String]$(Get-PsCallStack)[$StackIndex].FunctionName
}

<#
    .SYNOPSIS
    Invoke a command using an argument list, in a way that's forgiving of
    unmatched key-value pairs.

    .PARAMETER CommandName
    The name of a command.

    .PARAMETER ArgumentList
    A list of key-value pairs representing parameter-argument pairs in a command
    call.

    Examples by type:

        Hashtable

            $params = @{
                Source = '\src\myfile.txt'
                Destination = '\dst\mynewfile.txt'
                WhatIf = $true
                NotInParameters = 'Whatever'
            }

            Invoke-SplatCommand -CommandName Copy-Item -ArgumentList $params

        PsCustomObject

            $params = [PsCustomObject]@{
                Source = '\src\myfile.txt'
                Destination = '\dst\mynewfile.txt'
                WhatIf = $true
                NotInParameters = 'Whatever'
            }

            Invoke-SplatCommand -CommandName Copy-Item -ArgumentList $params

        Object[]

            $param = @(
                [PsCutomObject]@{
                    Name = 'Source'
                    Value = '\src\myfile.txt'
                },
                [PsCutomObject]@{
                    Name = 'Destination'
                    Value = '\dst\mynewfile.txt'
                },
                [PsCutomObject]@{
                    Name = 'WhatIf'
                    Value = $true
                },
                [PsCutomObject]@{
                    Name = 'NotInParameters'
                    Value = 'Whatever'
                }

        String

            $param = @"
            {
                "Source": "\src\myfile.txt",
                "Destination": "\dst\mynewfile.txt",
                "WhatIf": true,
                "NotInParameters": "Whatever"
            }
            "@

            Invoke-SplatCommand -CommandName Copy-Item -ArgumentList $params

    .PARAMETER ParameterSetName
    Specifies the particular parameter set the given ArgumentList should match up
    with.
#>
function Invoke-SplatCommand {
    [CmdletBinding()]
    Param(
        [ArgumentCompleter(
            {
                (Get-Command).Name
            }
        )]
        [ValidateScript(
            {
                $_ -in (Get-Command).Name
            }
        )]
        [String]
        $CommandName,

        $ArgumentList,

        [String]
        $ParameterSetName
    )

    if (-not $ArgumentList) {
        return & $CommandName
    }

    $cmdInfo = Get-Command `
        -Name $CommandName

    $parameters = if ($ParameterSetName) {
        $paremeterSet = $cmdInfo.ParameterSets `
            | where Name -eq $ParameterSetName

        $parameterSet.Parameters
    } else {
        $cmdInfo.Parameters
    }

    $table = @{}

    switch -Regex ($ArgumentList.GetType().Name) {
        '^Hashtable$' {
            $nonEmpty = $ArgumentList | Get-NonEmptyTable

            $nonEmpty.Keys `
                | where { $_ -in $parameters.Keys } `
                | foreach { $table.Add($_, $nonEmpty[$_]) }
        }

        '^PsCustomObject$' {
            $nonEmpty = $ArgumentList | Get-NonEmptyObject

            $nonEmpty.PsObject.Properties `
                | where { $_.Name -in $parameters.Keys } `
                | foreach { $table.Add($_.Name, $_.Value) }
        }

        '^.*Object\[\]$' {
            $nonEmpty = $ArgumentList `
                | where { $null -ne $_.Value }

            $nonEmpty `
                | where { $_.Name -in $parameters.Keys } `
                | foreach { $table.Add($_.Name, $_.Value) }
        }

        '^String(\[\])?' {
            $nonEmpty = $ArgumentList `
                | ConvertFrom-Json `
                | Get-NonEmptyObject

            $nonEmpty.PsObject.Properties `
                | where { $_.Name -in $parameters.Keys } `
                | foreach { $table.Add($_.Name, $_.Value) }
        }
    }

    & $CommandName @table
}

function ConvertTo-UpperCamelCase {
    Param(
        [String]
        $InputObject
    )

    if ([String]::IsNullOrWhiteSpace($InputObject)) {
        return $InputObject
    }

    $substrings =
        $InputObject.Split(' ') `
            | foreach {
                $_ -replace "(?:\W)+", ""
            } `
            | where {
                -not [String]::IsNullOrEmpty($_)
            } `
            | foreach {
                $firstChar = $_.Substring(0, 1).ToUpper()
                $tail =
                    if ($_.Length -gt 0) {
                        $_.Substring(1)
                    } else {
                        ""
                    }

                "$firstChar$tail"
            }

    return [String]::Join("", $substrings)
}

