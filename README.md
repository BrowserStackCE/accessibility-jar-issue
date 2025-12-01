# BrowserStack accessibility test runner

This repository includes two convenient runners that reproduce the same Java classpath and BrowserStack agent behavior across macOS and Windows.

Prerequisites

- JDK installed
- Maven on PATH
- A BrowserStack account (username + access key)

Required environment variables (set before running)

- `BROWSERSTACK_USERNAME` — your BrowserStack username
- `BROWSERSTACK_ACCESS_KEY` — your BrowserStack access key

Set them in your shell before running (examples)

- macOS / zsh
  - export BROWSERSTACK_USERNAME=your_user
  - export BROWSERSTACK_ACCESS_KEY=your_key

- Windows PowerShell (session)
  - $env:BROWSERSTACK_USERNAME = 'your_user'
  - $env:BROWSERSTACK_ACCESS_KEY = 'your_key'

Running on macOS (zsh)

- The `test.sh` script builds the Maven classpath and launches the JVM with the BrowserStack javaagent (replicates the working mac behavior):

  ./test.sh

Running on Windows PowerShell

- The `run.ps1` script builds an explicit Maven classpath (cp.txt) and runs two JVMs by default (a no-agent sanity run, then an agent-enabled run). To run only the agent-enabled JVM use the `-SkipNoAgent` switch.

Examples

- Run both sanity + agent runs (default):
  powershell -NoProfile -ExecutionPolicy Bypass -File .\run.ps1

- Run only agent-enabled JVM:
  powershell -NoProfile -ExecutionPolicy Bypass -File .\run.ps1 -SkipNoAgent

Java selection

- `run.ps1` prefers `JAVA_HOME` if set. You can set it in PowerShell:
  - $env:JAVA_HOME = 'C:\Program Files\Java\jdk-17'

- Alternatively pass custom candidate paths to `run.ps1`:
  .\run.ps1 -JavaCandidates 'C:\path\to\java.exe','D:\other\java\bin\java.exe'

Troubleshooting checklist (quick)

- If accessibility scans are not appearing, inspect these logs:
  - `run-agent.log` (console capture)
  - `log/browserstack-javaagent.log` (agent details)
  - `log/automation.log` (automation subsystem)

- Common causes
  - Duplicate or wrong classpath ordering: `run.ps1` uses the explicit Maven-built `cp.txt` to avoid this. Confirm `cp.txt` exists and contains all jars.
  - Agent bootstrap (SdkCLI) problems on Windows: if you see SdkCLI initialization errors, delete `%USERPROFILE%\.browserstack\cli` and re-run so the CLI re-downloads. If Windows blocks execution, run `Unblock-File` on the downloaded binary.
  - Temporary workaround: add `-Dbrowserstack.disableCli=true` to the JVM args (not recommended long-term).
  - Accessibility requires Chrome sessions. Ensure your StepDefs/capabilities request `browserName: chrome`.

If you still have issues, attach:
- `run-agent.log`, `log/browserstack-javaagent.log`, and the printed `args` lines from the script. I will review and provide the exact fix.
