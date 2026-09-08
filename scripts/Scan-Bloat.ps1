<#
.SYNOPSIS
    Scan-only mode - reports installed bloat, changes nothing.
.EXAMPLE
    .\Scan-Bloat.ps1
    .\Scan-Bloat.ps1 -ExportCsv report.csv
#>
[CmdletBinding()]
param([string]$ExportCsv, [string]$ExportJson)

$HelperDir = Join-Path $PSScriptRoot 'helpers'
'BloatData','Get-SystemInfo','Write-RemovalLog','Get-BloatInventory','Get-DriverInfo' |
    ForEach-Object { . (Join-Path $HelperDir "$_.ps1") }

$sys = Get-SystemInfo
Write-Host ''
Write-Host "  $($sys.ProductName) $($sys.DisplayVer) | Build $($sys.Build) | $($sys.Architecture) | Winget: $($sys.HasWinget)" -ForegroundColor Cyan
Write-Host ''

$inv = @(Get-BloatInventory -SystemInfo $sys)
if (-not $inv.Count) { Write-Host '  No bloat found.' -ForegroundColor Green; return }

$inv | Group-Object Category | ForEach-Object {
    Write-Host ""
    Write-Host "  $($_.Name)  ($($_.Count))" -ForegroundColor White
    $_.Group | ForEach-Object {
        $c = switch ($_.Risk) { 'SAFE'{'Green'} 'REVIEW'{'Yellow'} 'DANGER'{'Red'} }
        Write-Host ("     {0,-6} {1}" -f $_.Risk, $_.Display) -ForegroundColor $c
    }
}

$mb = [math]::Round((($inv | Measure-Object SizeBytes -Sum).Sum)/1MB,0)
Write-Host ''
Write-Host "  Total: $($inv.Count) items, ~$mb MB recoverable" -ForegroundColor Cyan
Write-Host '  Nothing was changed. Run Remove-Bloat.ps1 to clean up.' -ForegroundColor DarkGray

$drv = @(Get-DriverInfo)
if ($drv.Count) {
    Write-Host ''
    Write-Host "  Driver-related programs found ($($drv.Count)) - these are PROTECTED and never removed:" -ForegroundColor DarkYellow
    $drv | ForEach-Object { Write-Host "     $($_.Name)" -ForegroundColor DarkGray }
}

if ($ExportCsv)  { $inv | Export-Csv $ExportCsv -NoTypeInformation -Encoding UTF8; Write-Host "  CSV : $ExportCsv" }
if ($ExportJson) { $inv | ConvertTo-Json -Depth 4 | Set-Content $ExportJson -Encoding UTF8; Write-Host "  JSON: $ExportJson" }
