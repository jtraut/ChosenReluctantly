# Windowed screenshot capture of the real game (needs a renderer; headless cannot capture).
# Usage: powershell -File tools\capture_screenshot.ps1 [-Preset reward_screen] [-After "3.0,5.0"] [-Out screenshots\shot.png] [-Scenario hp_bars] [-Resolution 1920x1080] [-TrueSize 2560x1440] [-Extra "--run-seed=7"] [-Class wizard] [-Actions "0.5:dodge"] [-AtBossAttack volley]
# A normal launch is a run (RunMain): use -Scenario "" to capture it. With a scenario you get the endless arena.
# Resolves Godot like tools\run_tests.ps1 (GODOT_BIN, else godot_console/godot on PATH, preferring *_console.exe).
param(
    [string]$Preset = "",    # a named capture from tools\capture_presets.json (reward_screen, removal_screen, boss_smash, bd1_*, ...); explicit parameters below override it
    [string]$After = "3.0",
    [string]$Out = "screenshots\shot.png",
    [string]$Scenario = "hp_bars",
    [string]$Resolution = "1280x720",
    [string]$TrueSize = "",  # e.g. "2560x1440": render in an oversized SubViewport (not clamped to the monitor)
    [string]$Class = "",     # rogue|wizard: with a scenario, play it as that class (its own deck, HP, dodge charges); passed as --class=
    [string]$Actions = "",   # scripted taps "<seconds>:<input action>[,...]", e.g. "0.5:dodge,0.9:dodge" (passed as --press=)
    [string]$AtBossAttack = "", # e.g. "volley": -After times count from the moment a boss starts winding up that attack
    [string[]]$Extra = @()   # more user args, e.g. "--run-room=10","--run-clear-after=2" (Milestone 3a run launch args)
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

if ($Preset) {
    $presetFile = Join-Path $PSScriptRoot "capture_presets.json"
    $presets = Get-Content -Raw $presetFile | ConvertFrom-Json
    $entry = $presets.PSObject.Properties[$Preset]
    if (-not $entry) {
        Write-Error ("Unknown -Preset '{0}'. Known presets: {1}" -f $Preset, (($presets.PSObject.Properties.Name) -join ", "))
        exit 2
    }
    $entry = $entry.Value
    if (-not $PSBoundParameters.ContainsKey("After") -and $entry.after) { $After = [string]$entry.after }
    if (-not $PSBoundParameters.ContainsKey("Scenario")) { $Scenario = [string]$entry.scenario }
    if (-not $PSBoundParameters.ContainsKey("Class") -and $entry.class) { $Class = [string]$entry.class }
    if (-not $PSBoundParameters.ContainsKey("AtBossAttack") -and $entry.at_boss_attack) { $AtBossAttack = [string]$entry.at_boss_attack }
    if (-not $PSBoundParameters.ContainsKey("Actions") -and $entry.actions) { $Actions = [string]$entry.actions }
    if (-not $PSBoundParameters.ContainsKey("Extra") -and $entry.extra) { $Extra = @($entry.extra) }
    if (-not $PSBoundParameters.ContainsKey("Out")) { $Out = "screenshots\$Preset.png" }
}
if (-not [System.IO.Path]::IsPathRooted($Out)) { $Out = Join-Path $root $Out }
$userArgs = @("--screenshot-after=$After", "--screenshot-out=$Out")
if ($Scenario) { $userArgs += "--scenario=$Scenario" }
if ($Class) { $userArgs += "--class=$Class" }
if ($Actions) { $userArgs += "--press=$Actions" }
if ($AtBossAttack) { $userArgs += "--at-boss-attack=$AtBossAttack" }
$userArgs += ($Extra | ForEach-Object { $_ -split "," } | Where-Object { $_ })  # "-File" passes "a","b" as one comma string, so split it
if ($TrueSize -and -not $Scenario) { $userArgs += "--run" }  # VpCapture hosts RunMain only with --run

Push-Location $root
try {
    if ($TrueSize) {
        # tools/VpCapture.tscn hosts Main in a SubViewport of exactly this size; same scenario/capture args.
        & $godot --path . res://tools/VpCapture.tscn -- "--size=$TrueSize" @userArgs
    } else {
        & $godot --path . --resolution $Resolution -- @userArgs
    }
    exit $LASTEXITCODE
} finally {
    Pop-Location
}
