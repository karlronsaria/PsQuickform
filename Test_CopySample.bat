@echo off
set "modulePath=%~dp0"
set "workingDir=%~1"

setlocal EnableDelayedExpansion

set "command="

if "%~1" EQU "" (
    set "command=cd %modulePath%"
) else (
    set "command=sudo powershell -Command Copy-Item -Recurse '%modulePath%sample' '%workingDir%'"
    set "command=!command!; cd '%workingDir%'"
)

set "command=!command!; Import-Module %~dp0.\PsQuickform.psm1"
set "command=sudo powershell -NoExit -Command !command!"

echo !command!
!command!

endlocal
