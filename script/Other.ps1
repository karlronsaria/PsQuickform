function Get-PropertyOrDefault {
    Param(
        [Parameter(ValueFromPipeline = $true)]
        [PsCustomObject]
        $InputObject,

        [String]
        $Name,

        $Default = $null
    )

    Process {
        if ($InputObject.PsObject.Properties.Name -contains $Name) {
            return $InputObject.$Name
        }

        return $Default
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

            (-not $RemoveEmptyString -or '' -ne $value) `
                -and $null -ne $value
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

            (-not $RemoveEmptyString -or '' -ne $value) `
                -and $null -ne $value
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
    Link: https://stackoverflow.com/questions/3689543/is-there-a-way-to-retrieve-a-powershell-function-name-from-within-a-function
    Link: https://stackoverflow.com/users/7407752/jakobii
    Retrieved: 2022_03_05
#>
function Get-ThisFunctionName {
    Param(
        [Int]
        $StackIndex = 1
    )

    return [String]$(Get-PsCallStack)[$StackIndex].FunctionName
}

