# TL3b: resolves a -AtBossAttack name for tools\capture_screenshot.ps1 against data/bosses.json.
# A name is an attack id (smash, slam, volley, charge, ...) or the attack's label as a snake_case name ("Ground pound" -> ground_pound -> slam).
# Returns @{ Id = <attack id or "">; Valid = <every accepted name, ids first, then label names that differ> }.
function Resolve-BossAttack {
    param([string]$Name, [string]$BossesFile)
    $bosses = (Get-Content -Raw $BossesFile | ConvertFrom-Json).bosses
    $ids = New-Object System.Collections.Generic.List[string]
    $aliases = [ordered]@{}
    foreach ($boss in $bosses.PSObject.Properties) {
        if (-not $boss.Value.attacks) { continue }
        foreach ($attack in $boss.Value.attacks.PSObject.Properties) {
            if (-not $ids.Contains($attack.Name)) { $ids.Add($attack.Name) }
            $label = [string]$attack.Value.label
            if ($label) {
                $alias = ($label.ToLowerInvariant() -replace "[^a-z0-9]+", "_").Trim("_")
                if ($alias -ne $attack.Name) { $aliases[$alias] = $attack.Name }
            }
        }
    }
    $valid = @($ids) + @($aliases.Keys | ForEach-Object { "$_ (= $($aliases[$_]))" })
    $id = ""
    if ($ids.Contains($Name)) { $id = $Name }
    elseif ($aliases.Contains($Name)) { $id = $aliases[$Name] }
    return @{ Id = $id; Valid = $valid }
}
