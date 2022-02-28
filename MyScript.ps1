function Get-FieldValidators {
    [CmdletBinding(DefaultParameterSetName = 'ByInputObject')]
    Param(
        [Parameter(ParameterSetName = 'ByParameterInfo')]
        [System.Management.Automation.ParameterMetadata]
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
                if ($ParameterInfo.ParameterType.Name -ne 'Object' -and $ParameterInfo.ParameterType.BaseType.Name -eq 'Enum') {
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
                $parameters = $CommandInfo.Parameters.Keys | % {
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


