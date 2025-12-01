# Run Cucumber with BrowserStack javaagent using an args file (PowerShell)
# Usage: Open PowerShell, cd to project root and run: .\run.ps1

$ErrorActionPreference = 'Stop'

Write-Host "==== run.ps1 starting ===="
Write-Host "Current dir: $(Get-Location)"
Write-Host "USERPROFILE: $env:USERPROFILE"

# Find BrowserStack SDK jar in local Maven repo
$repo = Join-Path $env:USERPROFILE ".m2\repository"
$bsJar = Get-ChildItem -Path $repo -Filter "*browserstack-java-sdk*.jar" -Recurse -File -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $bsJar) {
    Write-Error "BrowserStack JAR not found under $repo"
    exit 1
}
$BROWSERSTACK_JAR = $bsJar.FullName
Write-Host "Found BROWSERSTACK_JAR: $BROWSERSTACK_JAR"

# Ensure cp.txt is regenerated
if (Test-Path cp.txt) { Remove-Item -Force cp.txt; Write-Host "Deleted previous cp.txt" }

Write-Host "Running: mvn dependency:build-classpath -Dmdep.outputFile=cp.txt"
$mvnProcess = Start-Process -FilePath mvn -ArgumentList 'dependency:build-classpath','-Dmdep.outputFile=cp.txt' -NoNewWindow -Wait -PassThru -ErrorAction Stop
if ($mvnProcess.ExitCode -ne 0) {
    Write-Error "mvn dependency:build-classpath failed with exit code $($mvnProcess.ExitCode)"
    exit $mvnProcess.ExitCode
}

if (-not (Test-Path cp.txt)) {
    Write-Error "cp.txt not created by Maven. Inspect mvn output above."
    exit 1
}

$cp = Get-Content -Raw -Path cp.txt
Write-Host "--- cp.txt length: $($cp.Length) ---"

# Build args file for java (@argfile) to avoid command-line truncation
$argsPath = Join-Path (Get-Location) 'args.txt'
if (Test-Path $argsPath) { Remove-Item -Force $argsPath }

$lines = @()
$lines += "-javaagent:`"$BROWSERSTACK_JAR`""
$lines += "-Dcucumber.publish.quiet=true"
$lines += "-cp `"target/classes;$cp`""
$lines += "com.browserstack.tests.RunCucumberTest"

# Write using ASCII (no BOM) — Java argfile expects plain text
Set-Content -Path $argsPath -Value $lines -Encoding ascii

Write-Host "--- args.txt preview (first 20 lines) ---"
Get-Content -Path $argsPath -TotalCount 20 | ForEach-Object { Write-Host $_ }
Write-Host "--- end args.txt ---"

# Show java presence
try { & java -version 2>&1 | ForEach-Object { Write-Host $_ } } catch { Write-Warning "'java' executable not found on PATH" }

# Run Java with the argfile
Write-Host "About to run: java @$argsPath"
$proc = Start-Process -FilePath java -ArgumentList "@$argsPath" -NoNewWindow -Wait -PassThru
Write-Host "Java exited with code $($proc.ExitCode)"

exit $proc.ExitCode
