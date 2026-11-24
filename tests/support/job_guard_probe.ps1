# Test stand-in for a tool wrapper (tests/unit/tl4_job_guard_test.gd): joins the kill-on-close job, starts a long-lived child, records its pid, then waits.
param([string]$PidFile)
. "$PSScriptRoot/../../tools/job_guard.ps1"
if (-not (Add-KillOnCloseJob)) { exit 3 }
$child = Start-Process -PassThru -WindowStyle Hidden powershell -ArgumentList '-NoProfile', '-Command', 'Start-Sleep 120'
Set-Content -Path $PidFile -Value $child.Id
Start-Sleep 120
