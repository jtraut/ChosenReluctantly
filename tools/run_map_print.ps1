# Prints a seed's branching map as text (MAP1-A debug helper), or sweeps seeds 1..N for generation failures.
# Usage: powershell -File tools\run_map_print.ps1 [-Seed 7] [-Route]      one map: rooms, columns, edges, wave ids, path-rule scores
#        powershell -File tools\run_map_print.ps1 -Sweep 1000             generate seeds 1..N, print failures, the attempts histogram and the time
# -Merchant turns the merchant on first (data/merchant_on.json, MAP2-B: the shipped data has it off); -Set values apply on top of it.
# -From N starts the sweep at seed N (seeds N .. N+Sweep-1). -Set "types.rest.weight=20" overrides one config value for this run (repeatable).
# -Route also prints the `first` route (lowest column) as node ids. Exit code 1 when a map breaks a rule or fails to generate.
# Resolves the Godot 4 binary the same way tools/run_tests.ps1 does.

param(
    [int]$Seed = 1,
    [int]$Sweep = 0,
    [int]$From = 1,
    [switch]$Route,
    [switch]$Merchant,
    [string[]]$Set = @()
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
}

Push-Location $root
try {
    $extra = @("--seed=$Seed")
    if ($Sweep -gt 0) { $extra = @("--sweep=$Sweep", "--from=$From") }
    if ($Route) { $extra += "--route=first" }
    if ($Merchant) { $extra += "--merchant" }
    foreach ($s in $Set) { $extra += "--set=$s" }
    & $godot --headless --path . -s res://tools/map_print.gd -- @extra
    exit $LASTEXITCODE
} finally {
    Pop-Location
}
