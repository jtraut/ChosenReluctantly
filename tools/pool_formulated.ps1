# SIM2a-1: pools the "FORMULATED RUN" lines of one or more wave-sim logs into the per-class, per-preset 36-run summary (report only, no gate).
# Usage: powershell -File tools\pool_formulated.ps1 log1.txt log2.txt ...   (e.g. the three seeds 1/13/25 x 12 runs of one class and preset)
# A run line: FORMULATED RUN profile=formulated class=rogue preset=human seed=1 outcome=won act=3 room=15 deck=20 status=burn status_share=0.30 self=charge self_share=0.20 top_tag=Melee gold=45 spent=240 removals=2 relics=6
# (SIM2a-4: route=formulated|first|... and off=none|shop|removal|removal+shop are in the line and the group name; older logs without them pool as '-'.)
# (SIM2a-2: profile = formulated | plan | report. "report" is the flag-off row: the same behaviour as no flag, with the lines printed.) Groups by profile, class and preset.
param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Logs)
function Get-Median([double[]]$v) { if ($v.Count -eq 0) { return 0 }; $s = $v | Sort-Object; $m = [int][math]::Floor($s.Count / 2); if ($s.Count % 2 -eq 1) { return $s[$m] } else { return ($s[$m - 1] + $s[$m]) / 2 } }
$runs = @()
foreach ($log in $Logs) {
    foreach ($line in (Get-Content $log)) {
        if ($line -match '^FORMULATED RUN ') {
            $o = @{ profile = '?'; route = '-'; off = '-'; self = 'none'; self_share = '0'; spent = '0'; removals = '0'; relics = '0' }
            foreach ($pair in ($line.Substring(15) -split ' ')) { $kv = $pair -split '=', 2; if ($kv.Count -eq 2) { $o[$kv[0]] = $kv[1] } }
            $runs += [pscustomobject]$o
        }
    }
}
if ($runs.Count -eq 0) { Write-Host "no FORMULATED RUN lines found"; exit 1 }
foreach ($group in ($runs | Group-Object { "$($_.profile) / $($_.class) / $($_.preset) / route $($_.route) / off $($_.off)" })) {
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
    $selfStat = ($g | Group-Object self | Sort-Object Count -Descending | ForEach-Object { "$($_.Name): $($_.Count)" }) -join ', '
    $selfShare = Get-Median ($g | ForEach-Object { [double]$_.self_share })
    $spent = Get-Median ($g | ForEach-Object { [double]$_.spent })
    $spentMean = ($g | ForEach-Object { [double]$_.spent } | Measure-Object -Average).Average
    $remTotal = ($g | ForEach-Object { [double]$_.removals } | Measure-Object -Sum).Sum
    $remMean = ($g | ForEach-Object { [double]$_.removals } | Measure-Object -Average).Average
    $relicMed = Get-Median ($g | ForEach-Object { [double]$_.relics })
    Write-Host ("  FORMULATED POOLED ({0}): {1} of {2} run(s) won | deaths by act {3} | deaths by act and run room {4} | deck size median {5:N1} | dominant status share median {6:N2} | dominant status {7} | dominant self status {11} share median {12:N2} | leftover gold median {8:N0} mean {9:N1} | gold spent at merchants median {13:N0} mean {14:N1} | merchant removals total {15:N0} mean {16:N2} | relics median {17:N1} | top tags {10}" -f $group.Name, $won, $g.Count, $byAct, $deaths, $deck, $share, $stat, $gold, $goldMean, $tags, $selfStat, $selfShare, $spent, $spentMean, $remTotal, $remMean, $relicMed)
}
