# Convert aimodels.conf to v2rayN format
# Usage: Run .\convert_to_v2rayn.ps1 in PowerShell

$confFile = "d:\MyWorkSpace\MyHub\public\others\aimodels.conf"
$jsonFile = "d:\MyWorkSpace\MyHub\public\others\aimodels_v2rayn.json"

if (-not (Test-Path $confFile)) {
    Write-Error "File not found: $confFile"
    exit 1
}

$content = Get-Content $confFile
$domainSuffixRules = @()
$domainRules = @()

foreach ($line in $content) {
    if ($line -match '^DOMAIN-SUFFIX,(.+),PROXY$') {
        $domainSuffixRules += $matches[1]
    } elseif ($line -match '^DOMAIN,(.+),PROXY$') {
        $domainRules += $matches[1]
    }
}

$rules = @()

if ($domainSuffixRules.Count -gt 0) {
    $rules += @{
        port = ""
        outboundTag = "proxy"
        domain = $domainSuffixRules
        enabled = $true
        remarks = "AI Models Domain Suffix"
    }
}

if ($domainRules.Count -gt 0) {
    $rules += @{
        port = ""
        outboundTag = "proxy"
        domain = $domainRules
        enabled = $true
        remarks = "AI Models Domain"
    }
}

$rules | ConvertTo-Json -Depth 10 | Set-Content $jsonFile

Write-Host "Conversion completed!"
Write-Host "Input file: $confFile"
Write-Host "Output file: $jsonFile"
Write-Host "Domain suffix rules: $($domainSuffixRules.Count)"
Write-Host "Full domain rules: $($domainRules.Count)"
