@echo off
set "command=cd %~dp0"
set "command=%command%; Import-Module .\Quickform.psm1"

@echo on
sudo powershell -NoExit -Command %command%

