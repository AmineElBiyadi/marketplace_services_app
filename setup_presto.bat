@echo off
REM ============================================================
REM  setup_presto.bat — Installation automatique de Presto
REM  Marketplace des Services Locaux (Flutter / Dart / Firebase)
REM  Nécessite : Windows 10/11, PowerShell 5+, droits Administrateur
REM ============================================================

echo.
echo ============================================================
echo    PRESTO ^— Script d'installation automatique (Windows)
echo ============================================================
echo.

REM ════════════════════════════════════════════════════════════
REM  [1/8] WINGET — Vérification
REM ════════════════════════════════════════════════════════════
echo -- [1/8] Verification de winget...
winget --version >nul 2>&1
if %errorlevel% neq 0 (
  echo   ERREUR : winget non disponible.
  echo   Installez "App Installer" depuis le Microsoft Store,
  echo   puis relancez ce script en tant qu'Administrateur.
  pause
  exit /b 1
)
echo   OK winget present.
echo.

REM ════════════════════════════════════════════════════════════
REM  [2/8] GIT
REM ════════════════════════════════════════════════════════════
echo -- [2/8] Git...
git --version >nul 2>&1
if %errorlevel% neq 0 (
  echo   Installation de Git...
  winget install --id Git.Git -e --source winget --silent
  echo   Git installe.
) else (
  echo   OK Git deja present.
)
echo.

REM ════════════════════════════════════════════════════════════
REM  [3/8] JAVA JDK 17
REM ════════════════════════════════════════════════════════════
echo -- [3/8] Java JDK 17...
java -version 2>&1 | findstr /i "version" | findstr "17" >nul 2>&1
if %errorlevel% neq 0 (
  echo   Installation de Java JDK 17...
  winget install --id Microsoft.OpenJDK.17 -e --source winget --silent
  echo   Java JDK 17 installe.
) else (
  echo   OK Java JDK 17 deja present.
)
echo.

REM ════════════════════════════════════════════════════════════
REM  [4/8] NODE.JS (v18+)
REM ════════════════════════════════════════════════════════════
echo -- [4/8] Node.js...
node --version >nul 2>&1
if %errorlevel% neq 0 (
  echo   Installation de Node.js 18...
  winget install --id OpenJS.NodeJS.LTS -e --source winget --silent
  echo   Node.js installe.
) else (
  echo   OK Node.js deja present.
)
echo.

REM ════════════════════════════════════════════════════════════
REM  [5/8] FLUTTER SDK
REM ════════════════════════════════════════════════════════════
echo -- [5/8] Flutter SDK...
flutter --version >nul 2>&1
if %errorlevel% neq 0 (
  echo   Telechargement du Flutter SDK...
  PowerShell -Command "Invoke-WebRequest -Uri 'https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_latest.zip' -OutFile '%TEMP%\flutter.zip'"
  echo   Extraction...
  PowerShell -Command "Expand-Archive -Path '%TEMP%\flutter.zip' -DestinationPath '%USERPROFILE%' -Force"
  echo   Ajout au PATH systeme...
  setx PATH "%PATH%;%USERPROFILE%\flutter\bin" /M
  set PATH=%PATH%;%USERPROFILE%\flutter\bin
  echo   Flutter SDK installe dans %USERPROFILE%\flutter
  echo   IMPORTANT : Fermez et rouvrez le terminal pour recharger le PATH.
) else (
  echo   OK Flutter deja present.
)
echo.

REM ════════════════════════════════════════════════════════════
REM  [6/8] LICENCES ANDROID
REM ════════════════════════════════════════════════════════════
echo -- [6/8] Licences Android (repondez y a chaque invite)...
flutter doctor --android-licenses
echo.

REM ════════════════════════════════════════════════════════════
REM  [7/8] PROJET PRESTO — Clone & dépendances
REM ════════════════════════════════════════════════════════════
echo -- [7/8] Clonage du projet Presto...
set REPO_DIR=%USERPROFILE%\marketplace_services_app

if exist "%REPO_DIR%\.git" (
  echo   Depot deja present. Mise a jour (git pull)...
  git -C "%REPO_DIR%" pull
) else (
  echo   Clonage du depot...
  git clone https://github.com/AmineElBiyadi/marketplace_services_app.git "%REPO_DIR%"
  echo   Depot clone dans %REPO_DIR%
)
echo.

REM ════════════════════════════════════════════════════════════
REM  [8/8] PACKAGES FLUTTER & .ENV
REM ════════════════════════════════════════════════════════════
echo -- [8/8] Installation des packages Flutter...
flutter pub get --directory="%REPO_DIR%\service_app"
echo   Packages installes.

if not exist "%REPO_DIR%\service_app\.env" (
  copy "%REPO_DIR%\service_app\.env.example" "%REPO_DIR%\service_app\.env"
  echo   Fichier .env cree a partir de .env.example.
) else (
  echo   Fichier .env deja present.
)

echo.
echo ============================================================
echo    Installation terminee avec succes !
echo.
echo    ETAPE MANUELLE REQUISE :
echo    Installer Android Studio depuis :
echo    https://developer.android.com/studio
echo    Puis relancer : flutter doctor --android-licenses
echo.
echo    Prochaine etape pour lancer l'application :
echo    cd %USERPROFILE%\marketplace_services_app\service_app
echo    flutter run
echo.
echo    La base de donnees Firebase est deja connectee.
echo ============================================================
pause
