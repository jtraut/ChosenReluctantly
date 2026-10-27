# Headless bot-sim stub. Usage: powershell -File tools\run_bot_sim.ps1 [-Rooms 20]
# Resolves the Godot 4 binary the same way tools/run_tests.ps1 does, and
# prefers the console-subsystem binary for a reliable exit code (see
# docs/DECISIONS.md).

param(
    [int]$Rooms = 20
)

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
    if (Test-Path $consoleSibling) {
        $godot = $consoleSibling
    }
}

Push-Location $root
try {
    & $godot --headless --path . -s res://tools/bot_sim.gd -- "--rooms=$Rooms"
    exit $LASTEXITCODE
} finally {
    Pop-Location
}
