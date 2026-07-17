@echo off
cd /d %~dp0
start "" chrome "http://localhost:7357"
C:\flutter\bin\flutter.bat run -d web-server --web-hostname=localhost --web-port=7357
pause
