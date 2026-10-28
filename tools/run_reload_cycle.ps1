# Real scene-reload soak (death -> game over -> restart_arena, repeated). See tools/reload_cycle.gd.
# Usage: powershell -File tools\run_reload_cycle.ps1 [-Cycles 5]
# Fails on a failed check OR any ERROR / SCRIPT ERROR / WARNING line in the engine output.
param([int]$Cycles = 5)

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

Push-Location $root
try {
    $out = & $godot --headless --path . res://tools/ReloadCycle.tscn -- "--cycles=$Cycles" 2>&1 | Out-String
    $code = $LASTEXITCODE
    Write-Host $out
    $bad = ($out -split "`n") | Where-Object { $_ -match "ERROR|WARNING" }
    if ($bad) { Write-Host "Engine errors/warnings in output:"; $bad | ForEach-Object { Write-Host $_ }; exit 1 }
    exit $code
} finally {
    Pop-Location
}
