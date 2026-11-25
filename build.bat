@echo off
setlocal
set "FASM=C:\Program Files\fasmw17330\FASM.EXE"
set "INCLUDE=C:\Program Files\fasmw17330\INCLUDE"
cd /d "%~dp0"
if not exist build mkdir build
"%FASM%" src\unknown_alcohol.asm build\UnknownAlcohol.dll
if errorlevel 1 exit /b 1
echo Built build\UnknownAlcohol.dll
