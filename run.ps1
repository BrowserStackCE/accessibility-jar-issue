# Run Cucumber with BrowserStack javaagent using an args file (PowerShell)
# Usage: Open PowerShell, cd to project root and run: .\run.ps1

$ErrorActionPreference = 'Stop'

Write-Host "==== run.ps1 starting ===="
Write-Host "Current dir: $(Get-Location)"
Write-Host "USERPROFILE: $env:USERPROFILE"

# find java on PATH or common install locations
$java = (Get-Command java -ErrorAction SilentlyContinue).Source
if (-not $java) {
    $possible = @("C:\\Program Files\\Java\\jdk-17\\bin\\java.exe","C:\\Program Files\\OpenJDK\\jdk-17\\bin\\java.exe","C:\\Users\\Administrator\\Downloads\\openjdk-17.0.0.1+2_windows-x64_bin\\jdk-17.0.0.1\\bin\\java.exe")
    $java = $possible | Where-Object { Test-Path $_ } | Select-Object -First 1
}
if (-not $java) { Write-Error "java not found on PATH and no common JDK found. Install JDK17 or set java on PATH."; exit 1 }
Write-Host "Using java: $java"

# find BrowserStack SDK jar in local Maven repo
$repo = Join-Path $env:USERPROFILE ".m2\repository"
$bsJar = Get-ChildItem -Path $repo -Filter "*browserstack-java-sdk*.jar" -Recurse -File -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $bsJar) { Write-Error "BrowserStack JAR not found under $repo"; exit 1 }
$BROWSERSTACK_JAR = $bsJar.FullName
Write-Host "Found BROWSERSTACK_JAR: $BROWSERSTACK_JAR"

# ensure fresh cp.txt
if (Test-Path cp.txt) { Remove-Item -Force cp.txt; Write-Host "Deleted previous cp.txt" }

# run mvn dependency:build-classpath safely using Start-Process
$mvnCmd = (Get-Command mvn -ErrorAction SilentlyContinue).Source
if (-not $mvnCmd) { Write-Error "mvn not found on PATH"; exit 1 }
Write-Host "Running: mvn dependency:build-classpath -Dmdep.outputFile=cp.txt"
$proc = Start-Process -FilePath $mvnCmd -ArgumentList 'dependency:build-classpath','-Dmdep.outputFile=cp.txt' -NoNewWindow -Wait -PassThru
if ($proc.ExitCode -ne 0) { Write-Error "mvn dependency:build-classpath failed with exit code $($proc.ExitCode)"; exit $proc.ExitCode }
if (-not (Test-Path cp.txt)) { Write-Error "cp.txt not created by Maven"; exit 1 }

$cp = Get-Content -Raw -Path cp.txt
Write-Host "--- cp.txt length: $($cp.Length) ---"

# prefer wildcard lib if target\lib exists and contains jars
if ((Test-Path 'target\lib' -PathType Container) -and (Get-ChildItem 'target\lib' -Filter '*.jar' -Recurse -File | Select-Object -First 1)) {
    $cpLine = 'target\classes;target\lib\*'
    Write-Host "Using wildcard classpath: $cpLine"
} else {
    # use mvn-produced cp (already Windows ; separated)
    $cpLine = "target\classes;$cp"
    Write-Host "Using explicit classpath length: $($cpLine.Length)"
}

# create ASCII args.txt
$argsPath = Join-Path (Get-Location) 'args.txt'
if (Test-Path $argsPath) { Remove-Item -Force $argsPath }
$lines = @()
$lines += "-javaagent:`"$BROWSERSTACK_JAR`""
$lines += "-Dbrowserstack.config=`"$(Join-Path (Get-Location) 'browserstack.yml')`""
$lines += "-Dbrowserstack.framework=selenium"
$lines += "-Dbrowserstack.accessibility=true"
# temporary stability flag — remove when CLI fixed
#$lines += "-Dbrowserstack.disableCli=true"
$lines += "-Dcucumber.publish.quiet=true"
$lines += "-cp `"$cpLine`""
$lines += "com.browserstack.tests.RunCucumberTest"
Set-Content -Path $argsPath -Value $lines -Encoding ascii
Write-Host "Wrote $argsPath (len $((Get-Content $argsPath -Raw).Length))"

# run no-agent test to validate classpath & main
$noAgentPath = Join-Path (Get-Location) 'args-noagent.txt'
(Get-Content $argsPath) | Where-Object { $_ -notmatch '^-javaagent' } | Set-Content $noAgentPath -Encoding ascii
Write-Host "Running no-agent test... (logs -> run-noagent.log)"
# run directly with explicit classpath to avoid argfile parsing issues
& $java -cp "$cpLine" com.browserstack.tests.RunCucumberTest 2>&1 | Tee-Object run-noagent.log
Write-Host "no-agent exit code: $LASTEXITCODE"

# run agent-enabled JVM
Write-Host "Running agent-enabled JVM... (logs -> run-agent.log)"
# run directly with explicit -javaagent and classpath (keeps behavior consistent)
$argsConfigPath = (Join-Path (Get-Location) 'browserstack.yml')
& $java -javaagent:"$BROWSERSTACK_JAR" -Dbrowserstack.config="$argsConfigPath" -Dbrowserstack.framework=selenium -Dbrowserstack.accessibility=true -Dcucumber.publish.quiet=true -cp "$cpLine" com.browserstack.tests.RunCucumberTest 2>&1 | Tee-Object run-agent.log
Write-Host "agent exit code: $LASTEXITCODE"

# helpful hints if agent fails due to CLI
if ($LASTEXITCODE -ne 0) {
    Write-Host "If you see SdkCLI initialization errors, try: (1) delete $env:USERPROFILE\.browserstack\cli to force re-download, or (2) keep -Dbrowserstack.disableCli=true as a temporary workaround."
}

exit $LASTEXITCODE
