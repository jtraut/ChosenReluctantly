# Headless test runner for the gdUnit4 suite.
# Usage: powershell -File tools\run_tests.ps1
# Resolves the Godot 4 binary from $env:GODOT_BIN, or from "godot"/"godot_console" on PATH.
#
# Must use the console-subsystem Godot binary (Godot_v*_console.exe), not the
# windowed one. PowerShell's "&" does not reliably wait on a GUI-subsystem
# process or receive its stdout, which silently made this script "pass" even
# when a test failed. See docs/DECISIONS.md.

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

# Prefer the console-subsystem sibling binary if one exists alongside $godot,
# so stdout/exit-code handling is reliable regardless of which path was given.
if ($godot -notmatch "_console\.exe$") {
    $consoleSibling = $godot -replace "\.exe$", "_console.exe"
    if (Test-Path $consoleSibling) {
        $godot = $consoleSibling
    } else {
        Write-Warning "Using the windowed Godot binary ('$godot'); exit code may be unreliable. Point GODOT_BIN at the '_console.exe' build instead."
    }
}

Push-Location $root
try {
    & $godot --path . -s --remote-debug tcp://127.0.0.1:0 res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests -c
    exit $LASTEXITCODE
} finally {
    Pop-Location
}
