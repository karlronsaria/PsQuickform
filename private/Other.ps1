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

