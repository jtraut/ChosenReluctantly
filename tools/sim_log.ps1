# TL3a: log isolation for tool runs. Dot-source this and add (Get-ToolLogArgs "name") to the Godot command line.
# Godot's --log-file <path> (4.7.2, "instead of the default location defined by the project") sends the engine log to
# <repo>\logs\sim\<name>-<time>-<pid>.log (gitignored by "/logs/") and writes NOTHING to user://logs, so agent sims and
# tests can't rotate the director's game log out of Godot's 5-file window. A plain "godot --path ." still logs to user://logs.
# Keeps the newest 60 files here. This keeps evidence only: it does not fix the shared .godot import cache.
function Get-ToolLogArgs([string]$Name, [string]$Root = (Split-Path -Parent $PSScriptRoot)) {
    $dir = Join-Path $Root "logs\sim"
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    try { Get-ChildItem $dir -Filter *.log | Sort-Object LastWriteTime -Descending | Select-Object -Skip 60 | Remove-Item -Force -ErrorAction SilentlyContinue } catch { }
    $stamp = (Get-Date).ToString("yyyyMMddTHHmmss")
    return @("--log-file", (Join-Path $dir "$Name-$stamp-$PID.log"))
}
