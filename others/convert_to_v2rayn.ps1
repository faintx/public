# 将 aimodels.conf 转换为 v2rayN 格式
# 使用方法：在 PowerShell 中运行 .\convert_to_v2rayn.ps1

$confFile = "d:\MyWorkSpace\MyHub\public\others\aimodels.conf"
$jsonFile = "d:\MyWorkSpace\MyHub\public\others\aimodels_v2rayn.json"

if (-not (Test-Path $confFile)) {
    Write-Error "找不到文件: $confFile"
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

Write-Host "转换完成！"
Write-Host "输入文件: $confFile"
Write-Host "输出文件: $jsonFile"
Write-Host "域名后缀规则数: $($domainSuffixRules.Count)"
Write-Host "完整域名规则数: $($domainRules.Count)"
