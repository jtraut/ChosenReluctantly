# BD3a offer report: Fire share of card offers and Burn-dependent share of relic offers, with and without the D43 status lean (headless, pure; no fights).
# Usage: powershell -File tools\run_offer_report.ps1 [-Seeds 1000] [-Offers 18] [-Lean 0.25] [-Class rogue]
# -Lean overrides rewards.status_lean for the "lean on" rows (default: data/run.json). The "lean off" rows always use 0.
param([int]$Seeds = 1000, [int]$Offers = 18, [double]$Lean = -1, [string]$Class = "rogue")

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
    $extra = @("--seeds=$Seeds", "--offers=$Offers", "--class=$Class")
    if ($Lean -ge 0) { $extra += "--lean=$Lean" }
    & $godot --headless --path . -s res://tools/offer_report.gd -- @extra
    exit $LASTEXITCODE
} finally {
    Pop-Location
}
