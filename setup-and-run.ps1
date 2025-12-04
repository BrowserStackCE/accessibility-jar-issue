# Setup argument file and run mvn exec:exec with BrowserStack javaagent
# Usage: powershell -NoProfile -ExecutionPolicy Bypass -File .\setup-and-run.ps1

$ErrorActionPreference = 'Stop'

Write-Host "==== setup-and-run.ps1 starting ===="
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

# Create Java argument file with only javaagent and classpath (the long parts)
$argFile = ".\mvn-exec-args.txt"
Write-Host "Creating argument file: $argFile"
$argFileContent = @"
-javaagent:$BROWSERSTACK_JAR
-cp
$CLASSPATH
"@
Set-Content -Path $argFile -Value $argFileContent

Write-Host ""
Write-Host "Argument file created successfully: $argFile"
Write-Host ""
Write-Host "Now run the following command:"
Write-Host "  mvn exec:exec '-Dexec.executable=java' '-Dexec.args=@$argFile -Dbrowserstack.config=$configPath -Dbrowserstack.framework=selenium -Dbrowserstack.accessibility=true -Dcucumber.publish.quiet=true com.browserstack.tests.RunCucumberTest'"
Write-Host ""
