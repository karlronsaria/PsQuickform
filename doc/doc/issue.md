# issue

- [x] 2023_11_11_153220

  - ``Show-QformMenu`` fails on some PowerShell profiles
  - howto
    - pwsh

      ```powershell
      ./PsFrivolous/Get-Scripts.ps1 | % { . $_ }

      @"
      {
        "Preferences": {
          "Caption": "What"
        },
        "MenuSpecs": [
          {
            "Name": "MyWhat",
            "Type": "Field"
          }
        ]
      }
      "@ |
      ConvertFrom-Json |
      Show-QformMenu
      ```

  - actual
    - program hangs indefinitely and takes a long time to force-terminate


- [x] 2023_04_17_015015

  - actual
    ![2023_04_17_015102](./res/2023_04_17_015102.png)
    ```powershell
    C:\Users\karlr\Downloads\__POOL> .\MyScript.ps1

    Confirm MenuAnswers
    ------- -----------
       True
    ```

- [x] 2023_04_04_004414
  
  - when: calling ``Show-QformMenu`` with a set of specs containing a table
  - actual: truncated table
  - expected: all elements resize to fit table
  - cause
    - ``OverflowLayout#ScrollView`` type does not feature auto-resize
      - whereas ``OverflowLayout#Multipanel`` does
  - solution
    - temporary
      - use ``'Multipanel'`` setting in ``Page`` constructor for non-cmdlet-based menus
  - todo
    - [x] permanent solution for all overflow layout types

- [x] 2023_03_20_234805
  
  - where: ``Controls#Add-ControlsListBox``
    - no multiselect
      - comment: I'm not sure if multiselect would be a good idea.
    - key bindings fail to replicate Windows Explorer behavior
  - solution: cancel
    - good enough
