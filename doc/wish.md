# wish
- I wish
  - Enum answer would
    - [ ] preserve ordinal information
    - [ ] but behave differently for cmdlet forms
  - Table had key bindings
    - for
      - if row fields procured from a document
        - [ ] Open or Goto
        - [ ] Preview
  - for
    - [x] Drop-down type
    - [ ] Name inference
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

