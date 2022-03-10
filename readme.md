## Objects

### MenuSpecs

Any call for `MenuSpecs` in the module refers to a `PsCustomObject` that contains a list of specifications for the controls in a Quickform menu.

#### Types

##### Check

A boolean value, represented by a CheckBox. When procuring parameters from a PowerShell cmdlet or function, Switch parameters are handled using Checks.

Ex:
```json
{
    "Name": "ShowHiddenItems",
    "Type": "Check",
    "Text": "Show hidden items"
}
```

pic

##### Field

A string value, represented by a Label and TextBox. When procuring parameters from a PowerShell cmdlet or function, strings and most other types default to being handled using Fields.

Ex:
```json
{
    "Name": "NewHostname",
    "Type": "Field",
    "Text": "Enter a new hostname",
    "Mandatory": true,
    "MinLength": 6,
    "MaxLength": 20
}
```

pic

##### Enum

One of a set of accepted string values, represented by a RadioBox (a GroupBox containing sequence of mutually exclusive Radio buttons). When procuring parameters from a PowerShell cmdlet or function, enumerated types or string parameters with the `ValidateSet` attribute added are handled using Enums.

Ex:
```json
{
    "Name": "MultipleChoice_20",
    "Type": "Enum",
    "Text": "Question 20: Who wrote The Divine Comedy?",
    "Mandatory": true,
    "Symbols": [
        {
            "Name": "A",
            "Text": "A. William Shakespeare",
        },
        {
            "Name": "B",
            "Text": "B. Desiderius Erasmus"
        },
        {
            "Name": "C",
            "Text": "C. Geoffery Chaucer"
        },
        {
            "Name": "D",
            "Text": "D. Dante Alighieri"
        }
    ]
}
```

pic

When `Mandatory` is ommitted or set `false`, a 'None' button is added to the box and set by default.

Ex:
```json
{
    "Name": "ClientSize",
    "Type": "Enum",
    "Text": "Preferred client size",
    "Symbols": [
        {
            "Name": "Thin"
        },
        {
            "Name": "Personal"
        }
    ]
}
```

pic

##### Numeric

A numeric value, represented by a Label and a value slider (NumericUpDown). When procuring parameters from a PowerShell cmdlet or function, integral, floating-point, and decimal values are handled using Numerics.

Ex:
```json
{
    "Name": "TotalCount",
    "Type": "Numeric",
    "Text": "Total number of commands",
    "Minimum": 1,
    "Maximum": 9999
}
```

pic

#### Common Properties

### MenuAnswers

Ex:

JSON Input:

```json
{
    "MenuSpecs": [
        {
            "Name": "Hostname",
            "Type": "Field",
            "Text": "New hostname:"
        },
        {
            "Name": "ClientSize",
            "Type": "Enum",
            "Text": "Preferred client size",
            "Symbols": [
                {
                    "Name": "Personal"
                },
                {
                    "Name": "Thin"
                }
            ],
            "Mandatory": true
        },
        {
            "Name": "NumberOfCpus",
            "Type": "Numeric",
            "Text": "Number of CPUs:",
            "Minimum": 1,
            "Maximum": 9,
            "Default": 4
        },
        {
            "Name": "CreateVirtualDisk",
            "Type": "Check",
            "Text": "Create virtual disk",
            "Default": true
        }
    ]
}
```



pic

```powershell
Hostname ClientSize NumberOfCpus CreateVirtualDisk
-------- ---------- ------------ -----------------
myvm01   Personal              4              True
```

### Preferences

## Cmdlets


















