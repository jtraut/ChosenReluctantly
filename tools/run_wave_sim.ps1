# Headless wave-density bot-sim (Slice 5a). Plays the real Main scene with a bot at the
# data/waves.json density and reports crashes, NaN, soft locks and rough frame cost.
# Usage: powershell -File tools\run_wave_sim.ps1 [-Seed 1] [-Seconds 90] [-Runs 3] [-Scale 3] [-God] [-Idle] [-Run] [-Deck <debug deck name>] [-LightHeavyOnly] [-Class <character id>] [-WizardNoKite] [-BossLog] [-DodgePellets]
# -Class rogue|wizard plays the whole runs (-Run) as that character (passed as --sim-class=).
# -WizardNoKite: a ranged class (the Wizard) walks in like the Rogue bot instead of kiting at a stand-off (--wizard-no-kite).
# -BossLog (needs -Run): per boss attack, how often it was thrown, how often it hit and the HP it cost (--boss-log); prints a line per run and a summary.
# -DodgePellets (needs -Run): the bot also steps out of and rolls through enemy projectiles in flight (--dodge-pellets, default off: it changes run results).
# -Plan: the plan-aware card policy (PlanPolicy, BD1): casts a payoff when its condition is live or after a 1.5 s hold, swaps a card that cannot pay off soon, spends Movement offensively; off = the standard random card presses (hashes unchanged). Works in the arena and with -Run.
# -Relics "a+b" (needs -Run; --sim-relics=): every run starts holding those relics. -RelicCap N (--sim-relic-cap=): a lower relic cap, to reach the give-one-up step in a short run.
# -NoRelics (--sim-no-relics): relics.enabled false for this process: today's run exactly (no relic room, a card offer after the elite).
# -Swap "old=new" (needs -Run; --sim-swap=): replace one copy of card old by new in the starting deck (checked against the deck rules), e.g. -Deck rogue-kindling -Swap fire_kindling=fire_ember_whatever, for removal-pain runs.
# -Route first|relic|safe|random (needs -Run; --sim-route=, MAP1-B): the runs walk the branching map (forced on for this process; data/map.json stays off) and the bot follows that route:
#   first = the lowest column, relic = the most relics by MapRules.relic_estimate, safe = the fewest elite-like nodes and the most rests, random = seeded. -Map alone = the map with the first route (--sim-map).
#   Prints a route line per run (nodes, fights, elites, relic stages and their chest sizes, gold, relics) and a ROUTE SUMMARY (wins, relics and gold per run, chest sizes seen). Without -Route/-Map the run is the straight run, unchanged.
# -Run also prints the damage the player's side dealt by source (light, heavy, each slot type, each status, each relic) per run and over all runs with the fingerprint spread, relic pick/skip/swap counts, and BOSS TIMES with timed-out boss fights listed apart.
# -StartRoom N (needs -Run): start every run at room N (10 = the boss) with the starter deck and full HP (--start-room).
# -Run plays whole seeded runs (Milestone 3a): -Seed is the first run seed, -Runs the number of runs, -RoomTimeout sim seconds before a room counts as a soft lock.
# Fails on a failed check OR any ERROR / SCRIPT ERROR / WARNING line in the engine output.
param([int]$Seed = 1, [int]$Seconds = 90, [int]$Runs = 1, [double]$Scale = 1, [switch]$God, [switch]$Idle, [switch]$Run, [int]$RoomTimeout = 240, [string]$Deck = "", [switch]$LightHeavyOnly, [string]$Class = "", [switch]$WizardNoKite, [switch]$BossLog, [switch]$DodgePellets, [int]$StartRoom = 0, [switch]$Plan, [string]$Relics = "", [int]$RelicCap = 0, [string]$Swap = "", [switch]$NoRelics, [string]$Route = "", [switch]$Map)

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
if ($Plan) { $extra += "--plan" }
if ($Relics) { $extra += "--sim-relics=$Relics" }
if ($RelicCap -gt 0) { $extra += "--sim-relic-cap=$RelicCap" }
if ($NoRelics) { $extra += "--sim-no-relics" }
if ($Swap) { $extra += "--sim-swap=$Swap" }
if ($Route) { $extra += "--sim-route=$Route" }
if ($Map) { $extra += "--sim-map" }
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
