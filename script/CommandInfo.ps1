function Get-FieldValidators {
    [CmdletBinding(DefaultParameterSetName = 'ByInputObject')]
    Param(
        [Parameter(ParameterSetName = 'ByParameterInfo')]
        $ParameterInfo,

        [Parameter(ParameterSetName = 'ByCommandInfo', ValueFromPipeline = $true)]
        [System.Management.Automation.CommandInfo]
        $CommandInfo,

        [Parameter(ParameterSetName = 'ByCommandName')]
        [String]
        $CommandName
    )

    Process {
        switch ($PsCmdlet.ParameterSetName) {
            'ByParameterInfo' {
                $isEnum = $ParameterInfo.ParameterType.PsObject.Properties.Name `
                    -contains 'BaseType' `
                    -and $ParameterInfo.ParameterType.BaseType.Name `
                    -eq 'Enum'

                if ($isEnum) {
                    [PsCustomObject]@{
                        Type = 'Enum';
                        Values = $ParameterInfo.ParameterType.GetFields();
                    }
                }

                foreach ($attribute in $ParameterInfo.Attributes) {
                    switch ($attribute.TypeId.Name) {
                        'ValidateSetAttribute' {
                            [PsCustomObject]@{
                                Type = 'ValidSet';
                                Values = $attribute.ValidValues;
                            }
                        }

                        'ValidateRangeAttribute' {
                            [PsCustomObject]@{
                                Type = 'ValidRange';
                                Minimum = $attribute.MinRange;
                                Maximum = $attribute.MaxRange;
                            }
                        }

                        'ValidateCountAttribute' {
                            [PsCustomObject]@{
                                Type = 'ValidCount';
                                Minimum = $attribute.MinLength;
                                Maximum = $attribute.MaxLength;
                            }
                        }

                        'ValidateLengthAttribute' {
                            [PsCustomObject]@{
                                Type = 'ValidLength';
                                Minimum = $attribute.MinLength;
                                Maximum = $attribute.MaxLength;
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
                        Name = $parameter.Name;
                        Parameter = $parameter;
                        Fields = Get-FieldValidators -ParameterInfo $parameter;
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
        $ParameterInfo
    )

    # link
    # - url: <https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_commonparameters?view=powershell-7.2>
    # - retrieved: 2022_02_28
    $names = @(
        'Debug'
        'ErrorAction'
        'ErrorVariable'
        'InformationAction'
        'InformationVariable'
        'OutVariable'
        'OutBuffer'
        'PipelineVariable'
        'Verbose'
        'WarningAction'
        'WarningVariable'

        # karlr 2023_11_19
        'ProgressAction'
    )

    return $names -contains $ParameterInfo.Name
}

