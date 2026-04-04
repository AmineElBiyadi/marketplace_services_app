@echo off
echo.
echo === DIAGNOSTIC PRESTO ===
echo.

:: 1. GIT
where git >nul 2>&1
if %errorlevel% equ 0 ( echo [OK] Git present ) else ( echo [NON] Git MANQUANT )

:: 2. JAVA
where java >nul 2>&1
if %errorlevel% equ 0 ( echo [OK] Java present ) else ( echo [NON] Java MANQUANT )

:: 3. NODE
where node >nul 2>&1
if %errorlevel% equ 0 ( echo [OK] Node present ) else ( echo [NON] Node MANQUANT )

:: 4. ANDROID STUDIO
if exist "C:\Program Files\Android\Android Studio\bin\studio64.exe" ( 
    echo [OK] Android Studio present 
) else ( 
    echo [NON] Android Studio MANQUANT 
)

:: 5. FLUTTER (Utilise CALL pour ne pas quitter le script)
call flutter --version >nul 2>&1
if %errorlevel% equ 0 ( 
    echo [OK] Flutter present 
) else ( 
    echo [NON] Flutter MANQUANT 
)

echo.
echo --------------------------------------------------------
echo Si un element est [NON], suivez le guide d'installation.txt.
echo --------------------------------------------------------
echo.
pause
