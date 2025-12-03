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
$java = $null
# prefer JAVA_HOME if provided
if ($env:JAVA_HOME) {
    $candidate = Join-Path $env:JAVA_HOME 'bin\java.exe'
    if (Test-Path $candidate) {
        $java = $candidate
        Write-Host "Using java from JAVA_HOME: $java"
    } else {
        Write-Host "JAVA_HOME is set but $candidate not found"
    }
}

# next, try java on PATH
if (-not $java) {
    $cmd = Get-Command java -ErrorAction SilentlyContinue
    if ($cmd) { $java = $cmd.Source; Write-Host "Found java on PATH: $java" }
}

# fallback to common install locations if still not found
if (-not $java) {
    $possible = @("C:\\Program Files\\Java\\jdk-17\\bin\\java.exe","C:\\Program Files\\OpenJDK\\jdk-17\\bin\\java.exe","C:\\Users\\Administrator\\Downloads\\openjdk-17.0.0.1+2_windows-x64_bin\\jdk-17.0.0.1\\bin\\java.exe")
    $java = $possible | Where-Object { Test-Path $_ } | Select-Object -First 1
    if ($java) { Write-Host "Using java from known location: $java" }
}

if (-not $java) { Write-Error "java not found via JAVA_HOME, PATH or common locations. Install JDK17 or set java on PATH or set JAVA_HOME."; exit 1 }
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

# If this environment is a deployed machine (no target/classes), prefer a shaded jar if present
$useJarMode = $false
$appJar = $null
$shaded = Get-ChildItem -Path (Join-Path (Get-Location) 'target') -Filter '*-jar-with-dependencies.jar' -File -ErrorAction SilentlyContinue | Select-Object -First 1
if ($shaded) {
    $useJarMode = $true
    $appJar = $shaded.FullName
    Write-Host "Found shaded JAR, switching to jar mode: $appJar"
} else {
    # if no shaded jar and target\classes doesn't exist, warn the user
    if (-not (Test-Path 'target\classes')) {
        Write-Host "NOTICE: target\classes not found and no shaded jar present. Script will attempt to use the explicit Maven classpath which may not exist on deployed machines."
    }
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
if (-not $SkipNoAgent) {
    $noAgentPath = Join-Path (Get-Location) 'args-noagent.txt'
    (Get-Content $argsPath) | Where-Object { $_ -notmatch '^-javaagent' } | Set-Content $noAgentPath -Encoding ascii
    Write-Host "Running no-agent test... (logs -> run-noagent.log)"
    # temporarily allow non-terminating native command failures so Java stderr doesn't stop the script
    $oldErrorAction = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        if ($useJarMode) {
            # run fat-jar on the classpath (avoids needing Main-Class in manifest)
            Write-Host "Jar-mode: running app jar on -cp with main class (avoids missing Main-Class manifest)"
            # Warn about possible duplicate SDK bundled inside shaded jar
            Write-Host "NOTE: shaded jar may contain bundled dependencies (including BrowserStack SDK). If you see duplicate SLF4J bindings, rebuild the shaded jar excluding browserstack-java-sdk or remove duplicate copies from ~/.m2."
            $noAgentArgs = @('-Dcucumber.publish.quiet=true','-cp', $appJar, 'com.browserstack.tests.RunCucumberTest')
        } else {
            $noAgentArgs = @('-cp', $cpLine, 'com.browserstack.tests.RunCucumberTest')
        }
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
    if ($useJarMode) {
        $agentArgs = @(
            "-javaagent:$BROWSERSTACK_JAR",
            "-Dbrowserstack.config=$argsConfigPath",
            "-Dbrowserstack.framework=selenium",
            "-Dbrowserstack.accessibility=true",
            "-Dcucumber.publish.quiet=true",
            '-cp', $appJar,
            'com.browserstack.tests.RunCucumberTest'
        )
    } else {
        $agentArgs = @(
            "-javaagent:$BROWSERSTACK_JAR",
            "-Dbrowserstack.config=$argsConfigPath",
            "-Dbrowserstack.framework=selenium",
            "-Dbrowserstack.accessibility=true",
            "-Dcucumber.publish.quiet=true",
            '-cp', $cpLine,
            'com.browserstack.tests.RunCucumberTest'
        )
    }
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
