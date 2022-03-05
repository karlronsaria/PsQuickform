function Get-PropertyOrDefault {
    Param(
        [Parameter(ValueFromPipeline = $true)]
        [PsCustomObject]
        $InputObject,

        [String]
        $Name,

        $Default = $null
    )

    if ($InputObject.PsObject.Properties.Name -contains $Name) {
        return $InputObject.$Name
    }

    return $Default
}

function Get-TrimTable {
    Param(
        [Parameter(ValueFromPipeline = $true)]
        [Hashtable]
        $InputObject,

        [Switch]
        $RemoveEmptyString
    )

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

function Get-TrimObject {
    Param(
        [Parameter(ValueFromPipeline = $true)]
        [PsCustomObject]
        $InputObject,

        [Switch]
        $RemoveEmptyString
    )

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

function ConvertTo-Hashtable {
    Param(
        [Parameter(ValueFromPipeline = $true)]
        [PsCustomObject]
        $InputObject
    )

    $table = @{}

    foreach ($property in $InputObject.PsObject.Properties.Name) {
        $table[$property] = $InputObject.$property
    }

    return $table
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

