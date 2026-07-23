@echo off
rem Startet das portable PC-Pruefprotokoll mit den erforderlichen Rechten.
setlocal
title PC-Pruefprotokoll
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0PC-Pruefung.ps1"
set "PC_CHECK_EXIT=%ERRORLEVEL%"
if not "%PC_CHECK_EXIT%"=="0" (
  echo.
  echo Die PC-Pruefung wurde mit Fehlercode %PC_CHECK_EXIT% beendet.
  echo Bitte pruefen Sie die angezeigte Fehlermeldung.
  pause
)
exit /b %PC_CHECK_EXIT%
