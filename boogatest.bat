@echo off
setlocal EnableExtensions DisableDelayedExpansion

rem CONFIGURATION
rem Double any literal percent signs in URLs inside this batch file.
set "release=true"
set "EXE_URL=https://github.com/Angxuz/rattest/raw/refs/heads/main/built.exe"
set "SELF_PATH=%~f0"

rem Check whether this process has administrator privileges.
powershell.exe -NoProfile -Command "$p = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent()); if ($p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { exit 0 } else { exit 1 }"
if not errorlevel 1 goto elevated

echo Requesting administrator privileges...
powershell.exe -NoProfile -Command "try { Start-Process -FilePath $env:ComSpec -ArgumentList ('/d /s /c '+[char]34+[char]34+$env:SELF_PATH+[char]34+[char]34) -Verb RunAs -ErrorAction Stop; exit 0 } catch { Write-Host ('Elevation cancelled or failed: '+$_.Exception.Message); exit 1 }"
if errorlevel 1 goto failed
exit /b 0

:elevated
if /i "%release%"=="true" goto confirm
if /i "%release%"=="false" goto run
echo ERROR: release must be true or false.
goto failed

:confirm
choice /c YN /n /m "Run test executable? y/n: "
if errorlevel 2 exit /b 0
if errorlevel 1 goto run
goto failed

:run
powershell.exe -NoProfile -Command ^
"$ErrorActionPreference='Stop'; ^
$phase='Configuration'; ^
try { ^
    $uri=[uri]$env:EXE_URL; ^
    if (-not $uri.IsAbsoluteUri -or $uri.Scheme -ne 'https') { throw 'EXE_URL must be an absolute HTTPS URL.' }; ^
    [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; ^
    $folder=Join-Path ([IO.Path]::GetTempPath()) ('TestExecutable-'+[guid]::NewGuid().ToString('N')); ^
    [void][IO.Directory]::CreateDirectory($folder); ^
    $target=Join-Path $folder 'test.exe'; ^
    $phase='Download'; ^
    Write-Host ('Downloading: '+$uri.AbsoluteUri); ^
    Invoke-WebRequest -Uri $uri.AbsoluteUri -OutFile $target -UseBasicParsing -TimeoutSec 120; ^
    $phase='File validation'; ^
    $stream=[IO.File]::OpenRead($target); ^
    try { ^
        if ($stream.ReadByte() -ne 77 -or $stream.ReadByte() -ne 90) { throw 'The download does not have a Windows executable header. Check the direct download URL.' }; ^
    } finally { $stream.Dispose() }; ^
    $phase='Launch'; ^
    Write-Host ('Running: '+$target); ^
    $process=Start-Process -FilePath $target -WorkingDirectory $folder -Wait -PassThru; ^
    Write-Host ('Executable exit code: '+$process.ExitCode); ^
    exit $process.ExitCode; ^
} catch { ^
    Write-Host ($phase+' failed: '+$_.Exception.Message); ^
    exit 1; ^
}"

set "RESULT=%ERRORLEVEL%"
if not "%RESULT%"=="0" goto failed
exit /b 0

:failed
echo The test did not complete successfully.
pause
exit /b 1
