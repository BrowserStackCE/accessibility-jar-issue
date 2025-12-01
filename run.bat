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

rem Resolve dependency classpath into a temporary file (Windows format uses ; separators)
echo Running: mvn dependency:build-classpath -Dmdep.outputFile=cp.txt
call mvn dependency:build-classpath -Dmdep.outputFile=cp.txt
if errorlevel 1 (
  echo ERROR: mvn dependency:build-classpath failed (is mvn on PATH?)
  where mvn 2>nul || echo 'where mvn' returned no result
  pause
  exit /b 1
)

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

echo About to run java with -javaagent
echo java -javaagent:"%BROWSERSTACK_JAR%" -Dcucumber.publish.quiet=true -cp "%CLASSPATH%" com.browserstack.tests.RunCucumberTest

rem Run the app with the BrowserStack javaagent
java -javaagent:"%BROWSERSTACK_JAR%" -Dcucumber.publish.quiet=true -cp "%CLASSPATH%" com.browserstack.tests.RunCucumberTest
if errorlevel 1 (
  echo ERROR: java process exited with code %ERRORLEVEL%
) else (
  echo java finished successfully
)

echo ==== run.bat finished ====
pause
endlocal
