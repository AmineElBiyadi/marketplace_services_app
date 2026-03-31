@echo off
:: ============================================================
::  setup_presto.bat - Version de Debug Robustee
:: ============================================================

setlocal EnableDelayedExpansion

echo.
echo ############################################################
echo #       PRESTO - Script d'installation (Windows)       #
echo ############################################################
echo.

:: 1. Verifier les droits Administrateur
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [ERREUR] Ce script doit etre lance en tant qu'ADMINISTRATEUR.
    echo Clic droit sur le fichier -> "Executer en tant qu'administrateur"
    echo.
    pause
    exit /b 1
)
echo [OK] Droits administrateur confirmes.

:: 2. Verifier winget
echo [1/8] Verification de winget...
winget --version >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERREUR] 'winget' est introuvable.
    echo Installation de 'App Installer' requise depuis le Microsoft Store.
    pause
    exit /b 1
)
echo [OK] winget est present.

:: 3. Installer Git
echo [2/8] Verification de Git...
where git >nul 2>&1
if %errorlevel% neq 0 (
    echo Installation de Git...
    winget install --id Git.Git -e --source winget --silent --accept-source-agreements --accept-package-agreements
    if %errorlevel% neq 0 (echo Erreur installation Git. & pause)
) else (
    echo [OK] Git est deja present.
)

:: 4. Installer Java JDK 17
echo [3/8] Verification de Java JDK 17...
:: On teste si java existe Et si c'est la version 17
java -version 2>&1 | findstr "17" >nul 2>&1
if %errorlevel% neq 0 (
    echo [INFO] Java 17 non detecte. Tentative d'installation...
    winget install --id Microsoft.OpenJDK.17 -e --source winget --accept-source-agreements --accept-package-agreements
    if %errorlevel% neq 0 (
        echo [ATTENTION] L'installation auto a echoue. 
        echo Vous devrez peut-etre l'installer manuellement.
    ) else (
        echo [OK] Java JDK 17 installe.
    )
) else (
    echo [OK] Java JDK 17 est deja present.
)

:: 5. Installer Node.js
echo [4/8] Verification de Node.js...
where node >nul 2>&1
if %errorlevel% neq 0 (
    echo [INFO] Node.js non detecte. Installation...
    winget install --id OpenJS.NodeJS.LTS -e --source winget --silent --accept-source-agreements --accept-package-agreements
) else (
    echo [OK] Node.js deja present.
)

:: 6. Installer Flutter
echo [5/8] Verification de Flutter...
where flutter >nul 2>&1
if %errorlevel% neq 0 (
    echo [INFO] Flutter non detecte dans le PATH.
    if exist "%USERPROFILE%\flutter\bin\flutter.bat" (
        echo [INFO] Flutter trouve dans %USERPROFILE%\flutter. Ajout au PATH...
        setx PATH "%PATH%;%USERPROFILE%\flutter\bin" /M
        set "PATH=%PATH%;%USERPROFILE%\flutter\bin"
    ) else (
        echo Telechargement de Flutter (veuillez patienter)...
        powershell -Command "Invoke-WebRequest -Uri 'https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_latest.zip' -OutFile '%TEMP%\flutter.zip'"
        echo Extraction vers %USERPROFILE%\flutter...
        powershell -Command "Expand-Archive -Path '%TEMP%\flutter.zip' -DestinationPath '%USERPROFILE%' -Force"
        setx PATH "%PATH%;%USERPROFILE%\flutter\bin" /M
        set "PATH=%PATH%;%USERPROFILE%\flutter\bin"
    )
) else (
    echo [OK] Flutter est deja present.
)

:: 7. Licences Android
echo [6/8] Licences Android...
echo Tapez 'y' a chaque question si demande.
call flutter doctor --android-licenses

:: 8. Projet Presto
echo [7/8] Configuration du projet...
set REPO_DIR=%USERPROFILE%\marketplace_services_app
if not exist "%REPO_DIR%" (
    echo Clonage du projet...
    git clone https://github.com/AmineElBiyadi/marketplace_services_app.git "%REPO_DIR%"
) else (
    echo Dossier projet deja present.
)

:: 9. Dependances
echo [8/8] Installation des dependances...
if exist "%REPO_DIR%\service_app" (
    cd /d "%REPO_DIR%\service_app"
    call flutter pub get
    if not exist ".env" (copy ".env.example" ".env")
)

echo.
echo ############################################################
echo #        INSTALLATION TERMINEE !                       #
echo ############################################################
echo.
echo IMPORTANT : Fermez cette fenetre et ouvrez un NOUVEAU terminal.
echo.
pause
