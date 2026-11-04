# Headless wave-density bot-sim (Slice 5a). Plays the real Main scene with a bot at the
# data/waves.json density and reports crashes, NaN, soft locks and rough frame cost.
# Usage: powershell -File tools\run_wave_sim.ps1 [-Seed 1] [-Seconds 90] [-Runs 3] [-Scale 3] [-God] [-Idle] [-Run] [-Deck <debug deck name>] [-LightHeavyOnly] [-Class <character id>] [-WizardNoKite] [-BossLog] [-DodgePellets]
# -Class rogue|wizard plays the whole runs (-Run) as that character (passed as --sim-class=).
# -WizardNoKite: a ranged class (the Wizard) walks in like the Rogue bot instead of kiting at a stand-off (--wizard-no-kite).
# -BossLog (needs -Run): per boss attack, how often it was thrown, how often it hit and the HP it cost (--boss-log); prints a line per run and a summary.
# -DodgePellets (needs -Run): the bot also steps out of and rolls through enemy projectiles in flight (--dodge-pellets, default off: it changes run results).
# -StartRoom N (needs -Run): start every run at room N (10 = the boss) with the starter deck and full HP (--start-room).
# -Run plays whole seeded runs (Milestone 3a): -Seed is the first run seed, -Runs the number of runs, -RoomTimeout sim seconds before a room counts as a soft lock.
# Fails on a failed check OR any ERROR / SCRIPT ERROR / WARNING line in the engine output.
param([int]$Seed = 1, [int]$Seconds = 90, [int]$Runs = 1, [double]$Scale = 1, [switch]$God, [switch]$Idle, [switch]$Run, [int]$RoomTimeout = 240, [string]$Deck = "", [switch]$LightHeavyOnly, [string]$Class = "", [switch]$WizardNoKite, [switch]$BossLog, [switch]$DodgePellets, [int]$StartRoom = 0)

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
if ($Deck) { $extra += "--sim-deck=$Deck" }
if ($LightHeavyOnly) { $extra += "--light-heavy-only" }
if ($Class) { $extra += "--sim-class=$Class" }
if ($WizardNoKite) { $extra += "--wizard-no-kite" }
if ($BossLog) { $extra += "--boss-log" }
if ($DodgePellets) { $extra += "--dodge-pellets" }
if ($StartRoom -gt 0) { $extra += "--start-room=$StartRoom" }
if ($Run) { $extra += "--run"; $extra += "--room-timeout=$RoomTimeout" }
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
