# wish
- I wish
  - [ ] String type could toggle Item List View
  - Enum answer would
    - [ ] preserve ordinal information
    - [ ] but behave differently for cmdlet forms
  - Table had key bindings
    - for
      - if row fields procured from a document
        - [ ] Open or Goto
        - [ ] Preview
  - for
    - [ ] Code block or Run box
    - [x] Drop-down type
    - [x] Name inference
      - ex
        ```powershell
        [PsCustomObject]@{
            Type = "Enum"
            Text = "What do?"
            Mandatory = $true
            Symbols = @(
                [PsCustomObject]@{
                    Text = "Copy Existing Workbook"
                },
                [PsCustomObject]@{
                    Text = "New Workbook"
                }
            )
        }
        ```
        to be read as
        ```powershell
        [PsCustomObject]@{
            Name = "WhatDo"
            Type = "Enum"
            Text = "What do?"
            Mandatory = $true
            Symbols = @(
                [PsCustomObject]@{
                    Name = "CopyExistingWorkbook"
                    Text = "Copy Existing Workbook"
                },
                [PsCustomObject]@{
                    Name = "NewWorkbook"
                    Text = "New Workbook"
                }
            )
        }
        ```

---
[← Go Back](../readme.md)
