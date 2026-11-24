# Test driver: starts job_guard_probe.ps1, hard-kills it, and prints CHILD_KILLED when its child died with it (else CHILD_SURVIVED or NO_CHILD).
param([string]$PidFile)
Remove-Item $PidFile -ErrorAction SilentlyContinue
$wrapper = Start-Process -PassThru -WindowStyle Hidden powershell -ArgumentList '-NoProfile', '-File', (Join-Path $PSScriptRoot "job_guard_probe.ps1"), '-PidFile', $PidFile
$childId = 0
for ($i = 0; $i -lt 100 -and $childId -eq 0; $i++) {
    Start-Sleep -Milliseconds 100
    if (Test-Path $PidFile) { $text = (Get-Content $PidFile -ErrorAction SilentlyContinue); if ($text) { $childId = [int]$text } }
}
if ($childId -eq 0) { Stop-Process -Id $wrapper.Id -Force -ErrorAction SilentlyContinue; "NO_CHILD"; exit 0 }
Stop-Process -Id $wrapper.Id -Force
Start-Sleep -Seconds 2
if (Get-Process -Id $childId -ErrorAction SilentlyContinue) { Stop-Process -Id $childId -Force; "CHILD_SURVIVED" } else { "CHILD_KILLED" }
