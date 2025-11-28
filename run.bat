@echo off
setlocal ENABLEDELAYEDEXPANSION

rem Find the first browserstack-java-sdk JAR in the local Maven repo
set "BROWSERSTACK_JAR="
for /f "delims=" %%I in ('dir /b /s "%USERPROFILE%\.m2\repository\*browserstack-java-sdk*.jar" 2^>nul') do (
  set "BROWSERSTACK_JAR=%%I"
  goto :found
)
:found
if "%BROWSERSTACK_JAR%"=="" (
  echo BrowserStack JAR not found in %USERPROFILE%\.m2\repository
  pause
  exit /b 1
)

rem Resolve dependency classpath into a temporary file (Windows format uses ; separators)
mvn dependency:build-classpath -Dmdep.outputFile=cp.txt -q
if errorlevel 1 (
  echo mvn dependency:build-classpath failed
  pause
  exit /b 1
)

rem Read the generated classpath and prepend target\classes
set /p DEP_CLASSPATH=<cp.txt
set "CLASSPATH=target\classes;%DEP_CLASSPATH%"

echo %CLASSPATH%

rem Run the app with the BrowserStack javaagent
java -javaagent:"%BROWSERSTACK_JAR%" -Dcucumber.publish.quiet=true -cp "%CLASSPATH%" com.browserstack.tests.RunCucumberTest

endlocal
