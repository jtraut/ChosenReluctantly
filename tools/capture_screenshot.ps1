# Windowed screenshot capture of the real game (needs a renderer; headless cannot capture).
# Usage: powershell -File tools\capture_screenshot.ps1 [-After "3.0,5.0"] [-Out screenshots\shot.png] [-Scenario hp_bars] [-Resolution 1920x1080]
# Resolves Godot like tools\run_tests.ps1 (GODOT_BIN, else godot_console/godot on PATH, preferring *_console.exe).
param(
    [string]$After = "3.0",
    [string]$Out = "screenshots\shot.png",
    [string]$Scenario = "hp_bars",
    [string]$Resolution = "1280x720"
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
    if (Test-Path $consoleSibling) { $godot = $consoleSibling }
    else { Write-Warning "Using the windowed Godot binary; exit code may be unreliable. Point GODOT_BIN at the '_console.exe' build." }
}

if (-not [System.IO.Path]::IsPathRooted($Out)) { $Out = Join-Path $root $Out }
$userArgs = @("--screenshot-after=$After", "--screenshot-out=$Out")
if ($Scenario) { $userArgs += "--scenario=$Scenario" }

Push-Location $root
try {
    & $godot --path . --resolution $Resolution -- @userArgs
    exit $LASTEXITCODE
} finally {
    Pop-Location
}
