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
$cpTempFile = [System.IO.Path]::GetTempFileName()
try {
    & mvn dependency:build-classpath "-Dmdep.outputFile=$cpTempFile" -q 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to build classpath. Exit code: $LASTEXITCODE"
        exit 1
    }
    $cpOutput = Get-Content $cpTempFile -Raw
    $cpOutput = $cpOutput.Trim()
} finally {
    Remove-Item $cpTempFile -ErrorAction SilentlyContinue
}
$CLASSPATH = "target\classes;$cpOutput"
Write-Host "Classpath length: $($CLASSPATH.Length)"

# Get absolute path to browserstack.yml
$configPath = Join-Path (Get-Location) "browserstack.yml"

# Create argument file to avoid Windows command line length limit
$argFile = ".\mvn-exec-args.txt"
$argFileContent = "-javaagent:`"$BROWSERSTACK_JAR`" -Dbrowserstack.config=`"$configPath`" -Dbrowserstack.framework=selenium -Dbrowserstack.accessibility=true -Dcucumber.publish.quiet=true -cp `"$CLASSPATH`" com.browserstack.tests.RunCucumberTest"
Set-Content -Path $argFile -Value $argFileContent -NoNewline

Write-Host "Running mvn exec:exec with argument file..."
Write-Host "Argument file: $argFile"

# Run mvn exec:exec with argument file
& mvn exec:exec `
    -Dexec.executable="java" `
    "-Dexec.args=@$argFile"

$exitCode = $LASTEXITCODE
Write-Host "Exit code: $exitCode"

exit $exitCode
