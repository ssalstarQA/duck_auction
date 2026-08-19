@echo off
chcp 65001 >nul
cd /d C:\dev\projects\duck_auction

echo ================================================
echo  flutterfire configure 실행 (덕옥션)
echo  진행 내용은 ffconfig_log.txt 에도 저장됩니다.
echo  창을 닫지 말고, 끝나면 클로드에게 알려주세요.
echo ================================================
echo.

echo === STEP 1: flutterfire_cli 설치/갱신 ===
echo === STEP 1: flutterfire_cli activate === > ffconfig_log.txt 2>&1
call dart pub global activate flutterfire_cli >> ffconfig_log.txt 2>&1
type ffconfig_log.txt

echo.
echo === STEP 2: configure (android, ios, web) ===
echo. >> ffconfig_log.txt 2>&1
echo === STEP 2: flutterfire configure === >> ffconfig_log.txt 2>&1
call dart pub global run flutterfire_cli:flutterfire configure --project=duck-auction --platforms=android,ios,web --yes >> ffconfig_log.txt 2>&1

echo.
echo ---------- 결과 (ffconfig_log.txt) ----------
type ffconfig_log.txt
echo ---------------------------------------------
echo.
echo ===== 완료. 이 창을 닫지 말고 클로드에게 "돌렸어" 라고 알려주세요. =====
pause
