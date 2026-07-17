@echo off
title Duck Auction Local Server

cd /d C:\dev\projects\duck_auction

C:\flutter\bin\flutter.bat run ^
-d web-server ^
--web-hostname=0.0.0.0 ^
--web-port=7357

pause