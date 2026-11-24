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
REM Verifier si JAVA_HOME est defini, sinon verifier si java.exe est dans le PATH.
if "%JAVA_HOME%"=="" (
    where java >nul 2>nul
    if errorlevel 1 (
        echo [DoctAgri] AVERTISSEMENT : JAVA_HOME n'est pas defini et java.exe est introuvable dans le PATH.
        echo Veuillez installer un JDK (17 ou 21) ou definir la variable JAVA_HOME.
    )
)
REM Repertoire temporaire sans espace pour eviter les soucis de socket Gradle WEPoll/UDS sous Windows.
if not exist "%SystemDrive%\GradleTemp" mkdir "%SystemDrive%\GradleTemp" 2>nul
if exist "%SystemDrive%\GradleTemp" (
    set "TEMP=%SystemDrive%\GradleTemp"
    set "TMP=%SystemDrive%\GradleTemp"
)

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
