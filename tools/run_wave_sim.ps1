# Headless wave-density bot-sim (Slice 5a). Plays the real Main scene with a bot at the
# data/waves.json density and reports crashes, NaN, soft locks and rough frame cost.
# Usage: powershell -File tools\run_wave_sim.ps1 [-Seed 1] [-Seconds 90] [-Runs 3] [-Scale 3] [-God] [-Idle]
# Fails on a failed check OR any ERROR / SCRIPT ERROR / WARNING line in the engine output.
param([int]$Seed = 1, [int]$Seconds = 90, [int]$Runs = 1, [double]$Scale = 1, [switch]$God, [switch]$Idle)

$root = Split-Path -Parent $PSScriptRoot
$godot = $env:GODOT_BIN
if (-not $godot) {
    $cmd = Get-Command godot_console -ErrorAction SilentlyContinue
    if (-not $cmd) { $cmd = Get-Command godot -ErrorAction SilentlyContinue }
    if ($cmd) { $godot = $cmd.Source }
}
if (-not $godot -or -not (Test-Path $godot)) {
    Write-Error "Godot 4 executable not found. Set GODOT_BIN to its full path, or add 'godot'/'godot_console' to PATH."
    exit 1
}
if ($godot -notmatch "_console\.exe$") {
    $consoleSibling = $godot -replace "\.exe$", "_console.exe"
    if (Test-Path $consoleSibling) { $godot = $consoleSibling }
}

$fixedFps = @("--fixed-fps", "60")
if ($Scale -gt 1) {
    $fixedFps = @()
    Write-Host "Note: -Scale $Scale > 1 runs without --fixed-fps; the run will NOT repeat from its seed."
}
$extra = @("--seed=$Seed", "--seconds=$Seconds", "--runs=$Runs", "--scale=$Scale")
if ($God) { $extra += "--god" }
if ($Idle) { $extra += "--idle" }
Push-Location $root
try {
    $out = & $godot --headless @fixedFps --path . res://tools/WaveSim.tscn -- @extra 2>&1 | Out-String
    $code = $LASTEXITCODE
    Write-Host $out
    $bad = ($out -split "`n") | Where-Object { $_ -match "ERROR|WARNING" }
    if ($bad) { Write-Host "Engine errors/warnings in output:"; $bad | ForEach-Object { Write-Host $_ }; exit 1 }
    exit $code
} finally {
    Pop-Location
}
