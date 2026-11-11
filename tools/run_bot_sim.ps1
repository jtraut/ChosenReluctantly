# Headless bot-sim stub. Usage: powershell -File tools\run_bot_sim.ps1 [-Rooms 20] [-Seed 1] [-Plan] [-Deck <debug deck>]
# -Swap "old=new" (needs -Plan and -Deck): replaces one copy of card old by new in the preset deck before the run (checked against the deck rules), for removal-pain checks.
# -Plan: the plan-aware policy (PlanPolicy) plays the card slots; -Deck (needs -Plan) loads a debug deck, for example rogue-kindling.
# Resolves the Godot 4 binary the same way tools/run_tests.ps1 does, and
# prefers the console-subsystem binary for a reliable exit code (see
# docs/DECISIONS.md).

param(
    [int]$Rooms = 20,
    [int]$Seed = 1,
    [switch]$Plan,
    [string]$Deck = "",
    [string]$Swap = "",
    [string]$BotPreset = ""
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
    $extra = @("--rooms=$Rooms", "--seed=$Seed")
    if ($Plan) { $extra += "--plan" }
    if ($Deck) { $extra += "--deck=$Deck" }
    if ($Swap) { $extra += "--swap=$Swap" }
    if ($BotPreset) { $extra += "--bot-preset=$BotPreset" }
    $out = & $godot --headless --path . -s res://tools/bot_sim.gd -- @extra 2>&1 | Out-String
    $code = $LASTEXITCODE
    Write-Host $out
    # qa (Slice 5): the sim used to print "Bot-sim OK" and exit 0 while the script had failed to compile
    # (SCRIPT ERROR: Identifier not found: Juice). Any engine error or warning line is a failure.
    $bad = ($out -split "`n") | Where-Object { $_ -cmatch '^\s*(SCRIPT )?ERROR:|^\s*WARNING:' }
    if ($bad) { Write-Host "Engine errors/warnings in output (bot-sim FAILED):"; $bad | Select-Object -First 10 | ForEach-Object { Write-Host $_ }; exit 1 }
    exit $code
} finally {
    Pop-Location
}
