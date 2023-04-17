# wish
- I wish
  - Table had key bindings
    - for
      - if row fields procured from a document
        - [ ] Open or Goto
        - [ ] Preview
  - for
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

