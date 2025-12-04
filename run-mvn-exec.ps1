# Run Cucumber tests using mvn exec:exec with BrowserStack javaagent
# Usage: powershell -NoProfile -ExecutionPolicy Bypass -File .\run-mvn-exec.ps1

$ErrorActionPreference = 'Stop'

Write-Host "==== run-mvn-exec.ps1 starting ===="
Write-Host "Current dir: $(Get-Location)"

# Find BrowserStack SDK jar in local Maven repo
$repo = Join-Path $env:USERPROFILE ".m2\repository"
$bsJar = Get-ChildItem -Path $repo -Filter "*browserstack-java-sdk*.jar" -Recurse -File -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $bsJar) { 
    Write-Error "BrowserStack JAR not found under $repo"; 
    exit 1 
}
$BROWSERSTACK_JAR = $bsJar.FullName
Write-Host "Found BROWSERSTACK_JAR: $BROWSERSTACK_JAR"

# Build classpath using Maven
Write-Host "Building classpath with Maven..."
$cpOutput = & mvn dependency:build-classpath -Dmdep.outputFile=/dev/stdout -q 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to build classpath"
    exit 1
}
$CLASSPATH = "target\classes;$cpOutput"
Write-Host "Classpath length: $($CLASSPATH.Length)"

# Get absolute path to browserstack.yml
$configPath = Join-Path (Get-Location) "browserstack.yml"

# Build exec.args string with proper escaping
$execArgs = "-javaagent:`"$BROWSERSTACK_JAR`" -Dbrowserstack.config=`"$configPath`" -Dbrowserstack.framework=selenium -Dbrowserstack.accessibility=true -Dcucumber.publish.quiet=true -cp `"$CLASSPATH`" com.browserstack.tests.RunCucumberTest"

Write-Host "Running mvn exec:exec..."
Write-Host "Exec args: $execArgs"

# Run mvn exec:exec
& mvn exec:exec `
    -Dexec.executable="java" `
    "-Dexec.args=$execArgs"

$exitCode = $LASTEXITCODE
Write-Host "Exit code: $exitCode"

exit $exitCode
