# Headless test runner for the gdUnit4 suite.
# Usage: powershell -ExecutionPolicy Bypass -File tools\run_tests.ps1
# Resolves the Godot 4 binary from $env:GODOT_BIN, or from "godot" on PATH.

$root = Split-Path -Parent $PSScriptRoot

$godot = $env:GODOT_BIN
if (-not $godot) {
    $cmd = Get-Command godot -ErrorAction SilentlyContinue
    if ($cmd) { $godot = $cmd.Source }
}
if (-not $godot -or -not (Test-Path $godot)) {
    Write-Error "Godot 4 executable not found. Set GODOT_BIN to its full path, or add 'godot' to PATH."
    exit 1
}

Push-Location $root
try {
    & $godot --path . -s --remote-debug tcp://127.0.0.1:0 res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests -c
    exit $LASTEXITCODE
} finally {
    Pop-Location
}
