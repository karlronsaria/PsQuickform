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

