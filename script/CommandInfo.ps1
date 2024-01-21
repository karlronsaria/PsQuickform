function Get-FieldValidators {
    [CmdletBinding(DefaultParameterSetName = 'ByInputObject')]
    Param(
        [Parameter(
            ParameterSetName = 'ByParameterInfo'
        )]
        [System.Management.Automation.CommandParameterInfo]
        $ParameterInfo,

        [Parameter(
            ParameterSetName = 'ByCommandInfo',
            ValueFromPipeline = $true
        )]
        [System.Management.Automation.CommandInfo]
        $CommandInfo,

        [Parameter(
            ParameterSetName = 'ByCommandName'
        )]
        [String]
        $CommandName
    )

    Process {
        switch ($PsCmdlet.ParameterSetName) {
            'ByParameterInfo' {
                $isEnum =
                    $ParameterInfo.
                        ParameterType.
                        PsObject.
                        Properties.
                        Name -contains 'BaseType' -and
                    $ParameterInfo.
                        ParameterType.
                        BaseType.
                        Name -eq 'Enum'

                if ($isEnum) {
                    [PsCustomObject]@{
                        Type = 'Enum'
                        Values = $ParameterInfo.ParameterType.GetFields()
                    }
                }

                foreach ($attribute in $ParameterInfo.Attributes) {
                    switch ($attribute.TypeId.Name) {
                        'ValidateSetAttribute' {
                            [PsCustomObject]@{
                                Type = 'ValidSet'
                                Values = $attribute.ValidValues
                            }
                        }

                        'ValidateRangeAttribute' {
                            [PsCustomObject]@{
                                Type = 'ValidRange'
                                Minimum = $attribute.MinRange
                                Maximum = $attribute.MaxRange
                            }
                        }

                        'ValidateCountAttribute' {
                            [PsCustomObject]@{
                                Type = 'ValidCount'
                                Minimum = $attribute.MinLength
                                Maximum = $attribute.MaxLength
                            }
                        }

                        'ValidateLengthAttribute' {
                            [PsCustomObject]@{
                                Type = 'ValidLength'
                                Minimum = $attribute.MinLength
                                Maximum = $attribute.MaxLength
                            }
                        }
                    }
                }
            }

            'ByCommandInfo' {
                $parameters = $CommandInfo.Parameters.Keys | foreach {
                    $CommandInfo.Parameters[$_]
                }

                foreach ($parameter in $parameters) {
                    [PsCustomObject]@{
                        Name = $parameter.Name
                        Parameter = $parameter
                        Fields = Get-FieldValidators `
                            -ParameterInfo $parameter
                    }
                }
            }

            'ByCommandName' {
                return Get-Command $CommandName | Get-FieldValidators
            }
        }
    }
}

function Test-IsCommonParameter {
    Param(
        [System.Management.Automation.CommandParameterInfo]
        $ParameterInfo
    )

    return $ParameterInfo.Name -in $(
        [System.Management.Automation.Internal.CommonParameters].
            DeclaredMembers |
            where { $_.MemberType -eq 'Property' } |
            foreach { $_.Name }
    )
}

