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
# -Route first|relic|safe|random (needs -Run; --sim-route=, MAP1-B): the runs walk the branching map (forced on for this process) and the bot follows that route:
#   first = the lowest column, relic = the most relics by MapRules.relic_estimate, safe = the fewest elite-like nodes and the most rests, random = seeded. -Map alone = the map with the first route (--sim-map).
#   Prints a route line per run (nodes, fights, elites, relic stages and their chest sizes, gold, relics) and a ROUTE SUMMARY (wins, relics and gold per run, chest sizes seen). data/map.json now ships the map on, so a plain -Run follows the map too (the first route); -NoMap (--sim-no-map) pins the straight run (the pre-MAP1 numbers).
# -Acts N (needs the map, --sim-acts=, MAP3-B): the runs have N acts (data/map.json `acts`, 3, when absent). -Acts 1 is the MAP2 one-act run (the mini-boss-free numbers); more acts report each act's clear rate, time, HP, relics and gold (ACT lines and ACTS TOTAL).
# -Merchant (needs the map: -Route or -Map; --sim-merchant, MAP2-B): turn the merchant on for this process (data/merchant_on.json is merged into data/map.json and run.json: weight 8, relic_route [6, 8]).
#   The bots then visit merchant nodes on their route: the `relic` route buys relics first (cheapest first), then a removal, then a card; `safe`, `first` and `random` buy a removal, then a card, and no relics (MerchantPolicy).
#   The run line and the ROUTE SUMMARY add gold spent, relics bought and removals.
# -BotProfile formulated (needs -Run; --sim-profile=, SIM2a-1): the build-aware drafter. Card rewards and relic offers and give-ups are scored against the deck's archetype (src/debug/DraftPolicy.gd, read from card data, never ids) and combat casts with PlanPolicy (implies -Plan).
#   Routing and merchants stay as -Route says. Prints a "FORMULATED RUN ..." line per run and a FORMULATED SUMMARY; tools\pool_formulated.ps1 pools several logs. Without the flag nothing changes.
# -FormulatedOff "shop,removal" (needs -BotProfile formulated; --sim-formulated-off=, SIM2a-4): hands the named formulated decisions back to today's policy, to measure what each is worth. Parts: shop (the merchant buys), removal (every removal list); "shop,removal" = both. Unknown part = exit 2 with the valid names; ignored with a warning under another profile.
#   The FORMULATED RUN / DEATH lines carry route=<-Route policy> and off=none|shop|removal|removal+shop (older logs have neither; tools\pool_formulated.ps1 pools them as '-' and groups by both).
# Log files (TL3a): every run writes its engine log to logs\sim\wave_sim-<time>-<pid>.log (gitignored, newest 60 kept) and never to user://logs, so a sim cannot rotate out a played game's log (tools\sim_log.ps1).
# -Run also prints the damage the player's side dealt by source (light, heavy, each slot type, each status, each relic) per run and over all runs with the fingerprint spread, relic pick/skip/swap counts, and BOSS TIMES with timed-out boss fights listed apart.
# -StartRoom N (needs -Run): start every run at room N (10 = the boss) with the starter deck and full HP (--start-room).
# -BotPreset <name> (SIM1; --bot-preset=): the human-like bot settings from data/bot_presets.json (off = the perfect bot, the default; human = the SIM1 preset). An unknown name exits nonzero with the valid names.
#   -BotDelay <s>, -BotAimError <degrees>, -BotHesitation <s> (--bot-delay= etc.) override one number of the preset, for sweeps. Seeded: the same -Seed repeats exactly.
# -Run plays whole seeded runs (Milestone 3a): -Seed is the first run seed, -Runs the number of runs, -RoomTimeout sim seconds before a room counts as a soft lock.
# -Shots <dir> (needs -Run; --watch-shots=, TL2 watch-the-bot mode): runs WINDOWED (no --headless) and saves screenshots under <dir>\<class>-seed<N>\ plus a text log, log.txt, there: each map pick, reward / relic / shop / event / rest choice (the real
#   screens), each act's end screen, the boss (and at half HP), each new biggest crowd of 4+ enemies (a numbered NN-crowded-fight.png, never overwritten) and the end screen. Use -BotPreset human to watch a human-like bot. A relative <dir> is taken from the folder you run this in.
#   A bare --watch-shots (no folder) is refused with a message. CROWD and BOSS lines quote the run-wide room number and the act-local one; "HP at end" is the player's current HP on a loss.
#   The same lines are printed as "WATCH ..." in the console. Watching at -Scale 1 is real time (a three-act run is about half an hour); -Scale 3 or 4 is faster (it drops --fixed-fps, so the run does not repeat exactly from its seed).
# Fails on a failed check OR any ERROR / SCRIPT ERROR / WARNING line in the engine output.
param([int]$Seed = 1, [int]$Seconds = 90, [int]$Runs = 1, [double]$Scale = 1, [switch]$God, [switch]$Idle, [switch]$Run, [int]$RoomTimeout = 240, [string]$Deck = "", [switch]$LightHeavyOnly, [string]$Class = "", [switch]$WizardNoKite, [switch]$BossLog, [switch]$DodgePellets, [int]$StartRoom = 0, [switch]$Plan, [string]$Relics = "", [int]$RelicCap = 0, [string]$Swap = "", [switch]$NoRelics, [string]$Route = "", [switch]$Map, [switch]$NoMap, [switch]$Merchant, [int]$Acts = 0, [string]$BotPreset = "", [double]$BotDelay = -1, [double]$BotAimError = -1, [double]$BotHesitation = -1, [string]$Shots = "", [string]$BotProfile = "", [string]$FormulatedOff = "", [switch]$DecisionLog, [switch]$NoVsync, [switch]$LegacyCadence)

. "$PSScriptRoot/sim_log.ps1"
. "$PSScriptRoot/job_guard.ps1"
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
if ($LegacyCadence) { $extra += "--legacy-cadence" }
if ($DecisionLog) { $extra += "--decision-log" }
if ($Deck) { $extra += "--sim-deck=$Deck" }
if ($LightHeavyOnly) { $extra += "--light-heavy-only" }
if ($Class) { $extra += "--sim-class=$Class" }
if ($WizardNoKite) { $extra += "--wizard-no-kite" }
if ($BossLog) { $extra += "--boss-log" }
if ($DodgePellets) { $extra += "--dodge-pellets" }
if ($Plan) { $extra += "--plan" }
if ($BotProfile) { $extra += "--sim-profile=$BotProfile" }
if ($FormulatedOff) { $extra += "--sim-formulated-off=$FormulatedOff" }
if ($Relics) { $extra += "--sim-relics=$Relics" }
if ($RelicCap -gt 0) { $extra += "--sim-relic-cap=$RelicCap" }
if ($NoRelics) { $extra += "--sim-no-relics" }
if ($Swap) { $extra += "--sim-swap=$Swap" }
if ($Route) { $extra += "--sim-route=$Route" }
if ($Map) { $extra += "--sim-map" }
if ($NoMap) { $extra += "--sim-no-map" }
if ($Merchant) { $extra += "--sim-merchant" }
if ($Acts -gt 0) { $extra += "--sim-acts=$Acts" }
if ($BotPreset) { $extra += "--bot-preset=$BotPreset" }
if ($BotDelay -ge 0) { $extra += "--bot-delay=$BotDelay" }
if ($BotAimError -ge 0) { $extra += "--bot-aim-error=$BotAimError" }
if ($BotHesitation -ge 0) { $extra += "--bot-hesitation=$BotHesitation" }
if ($Shots) {
    if (-not $Run) { Write-Error "-Shots needs -Run (it watches whole runs)"; exit 2 }
    $shotsFull = if ([System.IO.Path]::IsPathRooted($Shots)) { $Shots } else { Join-Path (Get-Location).Path $Shots }
    $extra += "--watch-shots=$shotsFull"
}
if ($StartRoom -gt 0) { $extra += "--start-room=$StartRoom" }
if ($Run) { $extra += "--run"; $extra += "--room-timeout=$RoomTimeout" }
# TL4: join a kill-on-close job so a hard-killed wrapper takes the Godot child with it (tools/job_guard.ps1).
$null = Add-KillOnCloseJob
Push-Location $root
try {
    # BD3a: lines are printed as they arrive (a 12-run -Run takes 12 minutes or more, and the old Out-String buffered all of it, which looked like a hang).
    $lines = New-Object System.Collections.Generic.List[string]
    $headless = @("--headless")
    if ($Shots) { $headless = @() }  # TL2: a window is needed to take screenshots
    if ($NoVsync) { $headless += "--disable-vsync" }  # TL4: windowed A/B only; lets the frame rate run uncapped
    & $godot @headless @fixedFps @(Get-ToolLogArgs "wave_sim") --path . res://tools/WaveSim.tscn -- @extra 2>&1 | ForEach-Object { $text = "$_"; $lines.Add($text); Write-Host $text }
    $code = $LASTEXITCODE
    $out = $lines -join "`n"
    $bad = ($out -split "`n") | Where-Object { $_ -cmatch '^\s*(SCRIPT )?ERROR:|^\s*WARNING:' }
    if ($bad) { Write-Host "Engine errors/warnings in output:"; $bad | ForEach-Object { Write-Host $_ }; exit 1 }
    exit $code
} finally {
    Pop-Location
}
