@echo off
setlocal EnableDelayedExpansion
REM ============================================================
REM  Script de build APK release DoctAgri
REM
REM  Usage :
REM    1. Copie .env.example vers .env (a la racine du repo)
REM    2. Renseigne SUPABASE_URL et SUPABASE_ANON_KEY dans .env
REM    3. Lance : build_apk.bat
REM
REM  Le fichier .env est gitignored et NE DOIT JAMAIS etre committe.
REM ============================================================

REM -- Chargement des variables depuis .env ----------------------
cd /d "%~dp0"

if not exist ".env" (
    echo [DoctAgri] ERREUR : fichier .env introuvable.
    echo Copie .env.example vers .env puis renseigne tes cles Supabase.
    pause
    exit /b 1
)

REM Parse .env en ignorant commentaires et lignes vides.
for /f "usebackq tokens=1,* delims==" %%A in (".env") do (
    set "_k=%%A"
    set "_v=%%B"
    REM Ignore lignes commencant par # ou ;
    if not "!_k:~0,1!"=="#" if not "!_k:~0,1!"==";" if not "!_k!"=="" (
        set "!_k!=!_v!"
    )
)

if "%SUPABASE_URL%"=="" (
    echo [DoctAgri] ERREUR : SUPABASE_URL manquante dans .env
    pause
    exit /b 1
)
if "%SUPABASE_ANON_KEY%"=="" (
    echo [DoctAgri] ERREUR : SUPABASE_ANON_KEY manquante dans .env
    pause
    exit /b 1
)

REM -- Environnement Java / Gradle ------------------------------
REM JDK 21 WEPoll/UDS : TEMP/TMP sans espaces (override local OK).
if "%JAVA_HOME%"=="" set "JAVA_HOME=C:\Users\HP VICTUS\AppData\Local\Programs\Eclipse Adoptium\jdk-21.0.9.10-hotspot"
set "TEMP=C:\GradleTemp"
set "TMP=C:\GradleTemp"
if not exist "C:\GradleTemp" mkdir "C:\GradleTemp"

REM -- Build ----------------------------------------------------
echo [DoctAgri] Build APK release en cours...

flutter build apk --release ^
  --dart-define=SUPABASE_URL=%SUPABASE_URL% ^
  --dart-define=SUPABASE_ANON_KEY=%SUPABASE_ANON_KEY%

if %ERRORLEVEL% EQU 0 (
    echo.
    echo [DoctAgri] BUILD REUSSI !
    echo APK : %~dp0build\app\outputs\flutter-apk\app-release.apk
) else (
    echo.
    echo [DoctAgri] BUILD ECHOUE - voir les logs ci-dessus
)
pause
endlocal
