@echo off
setlocal ENABLEDELAYEDEXPANSION

echo ==== run.bat starting ====
echo Current dir: %CD%
echo PATH: %PATH%
echo USERPROFILE: %USERPROFILE%

rem Find the first browserstack-java-sdk JAR in the local Maven repo
set "BROWSERSTACK_JAR="
for /f "delims=" %%I in ('dir /b /s "%USERPROFILE%\.m2\repository\*browserstack-java-sdk*.jar" 2^>nul') do (
  set "BROWSERSTACK_JAR=%%I"
  goto :found
)
:found
if "%BROWSERSTACK_JAR%"=="" (
  echo ERROR: BrowserStack JAR not found in %USERPROFILE%\.m2\repository
  echo Make sure Maven has downloaded browserstack-java-sdk and that %USERPROFILE% is correct.
  pause
  exit /b 1
)
echo Found BROWSERSTACK_JAR: "%BROWSERSTACK_JAR%"

rem Remove any existing cp.txt so mvn will recreate it (avoids "Skipped writing" confusion)
if exist cp.txt (
  del /f /q cp.txt
  echo Deleted previous cp.txt
)

rem Resolve dependency classpath into a temporary file (Windows format uses ; separators)
echo Running: mvn dependency:build-classpath -Dmdep.outputFile=cp.txt
call mvn dependency:build-classpath -Dmdep.outputFile=cp.txt

if not exist cp.txt (
  echo ERROR: cp.txt not created by mvn. Check mvn output.
  pause
  exit /b 1
)

echo --- cp.txt contents ---
type cp.txt
echo --- end cp.txt ---

rem Read the generated classpath and prepend target\classes
set /p DEP_CLASSPATH=<cp.txt
if "%DEP_CLASSPATH%"=="" (
  echo ERROR: dependency classpath is empty
  pause
  exit /b 1
)
set "CLASSPATH=target\classes;%DEP_CLASSPATH%"

echo Final CLASSPATH (truncated): %CLASSPATH:~0,200%...

rem Verify java is available
where java 2>nul || echo WARNING: 'java' not found on PATH - java must be on PATH to run the app

echo Building Java argfile to avoid command-line length limits
if exist args.txt del /f /q args.txt

echo -javaagent:"%BROWSERSTACK_JAR%">>args.txt
echo -Dcucumber.publish.quiet=true>>args.txt
echo -cp "%CLASSPATH%">>args.txt
echo com.browserstack.tests.RunCucumberTest>>args.txt
echo --- args.txt contents ---
type args.txt
echo --- end args.txt ---

echo About to run: java @args.txt

rem Run java using the argfile so long classpaths are supported
java @args.txt
if errorlevel 1 (
  echo ERROR: java process exited with code %ERRORLEVEL%
) else (
  echo java finished successfully
)

rem optional: del /f /q args.txt

echo ==== run.bat finished ====
pause
endlocal
