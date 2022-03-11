@echo off
set "modulePath=%~dp0"
set "workingDir=%~1"

if "%~1" EQU "" (
    set "command=cd %modulePath%"
) else (
    set "command=cd %workingDir%"
)

set "command=%command%; Import-Module %~dp0.\Quickform.psm1"

@echo on
sudo powershell -NoExit -Command %command%

