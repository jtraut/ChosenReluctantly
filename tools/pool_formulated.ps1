# SIM2a-1: pools the "FORMULATED RUN" lines of one or more wave-sim logs into the per-class, per-preset 36-run summary (report only, no gate).
# Usage: powershell -File tools\pool_formulated.ps1 log1.txt log2.txt ...   (e.g. the three seeds 1/13/25 x 12 runs of one class and preset)
# A run line: FORMULATED RUN class=rogue preset=human seed=1 outcome=won act=3 room=15 deck=20 status=burn status_share=0.30 top_tag=Melee gold=45
param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Logs)
function Get-Median([double[]]$v) { if ($v.Count -eq 0) { return 0 }; $s = $v | Sort-Object; $m = [int][math]::Floor($s.Count / 2); if ($s.Count % 2 -eq 1) { return $s[$m] } else { return ($s[$m - 1] + $s[$m]) / 2 } }
$runs = @()
foreach ($log in $Logs) {
    foreach ($line in (Get-Content $log)) {
        if ($line -match '^FORMULATED RUN ') {
            $o = @{}
            foreach ($pair in ($line.Substring(15) -split ' ')) { $kv = $pair -split '=', 2; if ($kv.Count -eq 2) { $o[$kv[0]] = $kv[1] } }
            $runs += [pscustomobject]$o
        }
    }
}
if ($runs.Count -eq 0) { Write-Host "no FORMULATED RUN lines found"; exit 1 }
foreach ($group in ($runs | Group-Object { "$($_.class) / $($_.preset)" })) {
    $g = $group.Group
    $won = ($g | Where-Object { $_.outcome -eq 'won' }).Count
    $deaths = ($g | Where-Object { $_.outcome -ne 'won' } | Group-Object { "act $($_.act) room $($_.room)" } | Sort-Object Name | ForEach-Object { "$($_.Name): $($_.Count)" }) -join ', '
    $byAct = ($g | Where-Object { $_.outcome -ne 'won' } | Group-Object { "act $($_.act)" } | Sort-Object Name | ForEach-Object { "$($_.Name): $($_.Count)" }) -join ', '
    $tags = ($g | Group-Object top_tag | Sort-Object Count -Descending | ForEach-Object { "$($_.Name): $($_.Count)" }) -join ', '
    $stat = ($g | Group-Object status | Sort-Object Count -Descending | ForEach-Object { "$($_.Name): $($_.Count)" }) -join ', '
    $deck = Get-Median ($g | ForEach-Object { [double]$_.deck })
    $share = Get-Median ($g | ForEach-Object { [double]$_.status_share })
    $gold = Get-Median ($g | ForEach-Object { [double]$_.gold })
    $goldMean = ($g | ForEach-Object { [double]$_.gold } | Measure-Object -Average).Average
    Write-Host ("  FORMULATED POOLED ({0}): {1} of {2} run(s) won | deaths by act {3} | deaths by act and run room {4} | deck size median {5:N1} | dominant status share median {6:N2} | dominant status {7} | leftover gold median {8:N0} mean {9:N1} | top tags {10}" -f $group.Name, $won, $g.Count, $byAct, $deaths, $deck, $share, $stat, $gold, $goldMean, $tags)
}
