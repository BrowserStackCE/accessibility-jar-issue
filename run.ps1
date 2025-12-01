# Run Cucumber with BrowserStack javaagent using an args file (PowerShell)
# Usage: Open PowerShell, cd to project root and run: .\run.ps1
# Usage:
#   .\run.ps1                # runs both no-agent (sanity) and agent runs (default)
#   .\run.ps1 -SkipNoAgent   # run only the agent-enabled JVM

param(
    [switch]$SkipNoAgent
)

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

# use explicit mvn-produced classpath (match mac behavior) instead of wildcard to avoid ordering/duplicate issues
$cp = $cp.Trim()
$cpLine = "target\classes;$cp"
Write-Host "Using explicit classpath length: $($cpLine.Length)"
# warn if browserstack sdk appears multiple times on the classpath
$bsEntries = $cpLine -split ';' | Where-Object { $_ -match 'browserstack-java-sdk' }
if ($bsEntries.Count -gt 1) { Write-Host "WARNING: browserstack-java-sdk appears multiple times on classpath:`n$($bsEntries -join "`n")" }

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
if (-not $SkipNoAgent) {
    $noAgentPath = Join-Path (Get-Location) 'args-noagent.txt'
    (Get-Content $argsPath) | Where-Object { $_ -notmatch '^-javaagent' } | Set-Content $noAgentPath -Encoding ascii
    Write-Host "Running no-agent test... (logs -> run-noagent.log)"
    # temporarily allow non-terminating native command failures so Java stderr doesn't stop the script
    $oldErrorAction = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $noAgentArgs = @('-cp', $cpLine, 'com.browserstack.tests.RunCucumberTest')
        Write-Host "Invoking Java (no-agent) with args: $($noAgentArgs -join ' ')"
        & $java @noAgentArgs 2>&1 | Tee-Object run-noagent.log
    } catch [System.Exception] {
        # log the exception but continue so we can inspect logs and exit code
        Write-Host "Java process raised an exception: $($_.Exception.Message)"
    } finally {
        $ErrorActionPreference = $oldErrorAction
    }
    $noAgentExit = $LASTEXITCODE
    Write-Host "no-agent exit code: $noAgentExit"
} else {
    Write-Host "Skipping no-agent run (SkipNoAgent specified)"
}

# run agent-enabled JVM
Write-Host "Running agent-enabled JVM... (logs -> run-agent.log)"
# run directly with explicit -javaagent and classpath (keeps behavior consistent)
# temporarily allow non-terminating native command failures for the agent run as well
$oldErrorAction = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
try {
    $argsConfigPath = (Join-Path (Get-Location) 'browserstack.yml')
    # build explicit argument array to avoid PowerShell token-splitting issues
    $agentArgs = @(
        "-javaagent:$BROWSERSTACK_JAR",
        "-Dbrowserstack.config=$argsConfigPath",
        "-Dbrowserstack.framework=selenium",
        "-Dbrowserstack.accessibility=true",
        "-Dcucumber.publish.quiet=true",
        '-cp', $cpLine,
        'com.browserstack.tests.RunCucumberTest'
    )
    Write-Host "Invoking Java (agent) with args: $($agentArgs -join ' ')"
    & $java @agentArgs 2>&1 | Tee-Object run-agent.log
} catch [System.Exception] {
    Write-Host "Java agent run raised an exception: $($_.Exception.Message)"
} finally {
    $ErrorActionPreference = $oldErrorAction
}
$agentExit = $LASTEXITCODE
Write-Host "agent exit code: $agentExit"

# helpful hints if agent fails due to CLI
if ($agentExit -ne 0) {
    Write-Host "If you see SdkCLI initialization errors, try: (1) delete $env:USERPROFILE\\.browserstack\\cli to force re-download, or (2) keep -Dbrowserstack.disableCli=true as a temporary workaround."
}

exit $agentExit
