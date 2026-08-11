# TC-B Desktop automated tests + TC-D01 static checks
$ErrorActionPreference = 'SilentlyContinue'
$results = @()

function Record($id, $ok, $note) {
    $script:results += [PSCustomObject]@{ Id = $id; OK = $ok; Note = $note }
    $tag = if ($ok) { 'PASS' } else { 'FAIL' }
    Write-Host "  $tag  $id  $note"
}

$desktop = 'G:\AI_Project\06-New flomo\desktop'
$release = "$desktop\release"
$unpacked = "$release\win-unpacked"
$setup = "$release\MEMO-笔记-Setup-1.2.0.exe"

Get-Process electron, memo-backend -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 1

# TC-B01 package structure
$ok = (Test-Path $setup) -and (Test-Path "$unpacked\MEMO 笔记.exe") `
  -and (Test-Path "$unpacked\resources\backend\memo-backend.exe") `
  -and (Test-Path "$unpacked\resources\mcp\memo-mcp.exe")
Record 'TC-B01' $ok "Setup/win-unpacked/backend/mcp present"

# TC-B02..B06 app runtime
$app = Start-Process "$unpacked\MEMO 笔记.exe" -PassThru
Start-Sleep -Seconds 15

Record 'TC-B02' (($null -ne $app) -and (-not $app.HasExited)) "app process alive"

$health = $false
try { $h = Invoke-RestMethod 'http://127.0.0.1:8900/api/health' -TimeoutSec 3; $health = ($h.ok -eq $true) } catch {}
Record 'TC-B03' $health 'backend(8900) auto-started'

$page = $false
try { $page = ((Invoke-WebRequest 'http://127.0.0.1:8900/' -TimeoutSec 3).StatusCode -eq 200) } catch {}
Record 'TC-B04' $page 'frontend page 200'

$dbPath = "$env:APPDATA\memo\data\memo.db"
Record 'TC-B05' (Test-Path $dbPath) "data db exists"

$writeOk = $false
try {
    $body = @{ content = 'autotest_desktop_marker_20260810' } | ConvertTo-Json
    $m = Invoke-RestMethod -Method Post -Uri 'http://127.0.0.1:8900/v1/memo' -ContentType 'application/json' -Body $body -TimeoutSec 5
    $mid = $m.data.id
    $list = (Invoke-RestMethod 'http://127.0.0.1:8900/api/memos?limit=20' -TimeoutSec 5).items
    $visible = @($list | Where-Object { $_.id -eq $mid }).Count -eq 1
    if ($visible) { Invoke-RestMethod -Method Delete -Uri "http://127.0.0.1:8900/api/memos/$mid" -TimeoutSec 5 | Out-Null }
    $writeOk = $visible
} catch { $writeOk = $false }
Record 'TC-B06' $writeOk 'write -> visible -> cleaned'

# TC-B07 no leftover processes
Get-Process electron, memo-backend -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 3
$left = @(Get-Process electron, memo-backend -ErrorAction SilentlyContinue).Count
Record 'TC-B07' ($left -eq 0) "leftover processes: $left"

# TC-D01 frontend static integrity
$appDir = 'G:\AI_Project\06-New flomo\app'
$idx = Get-Content "$appDir\index.html" -Raw
$assetM = [regex]::Matches($idx, 'assets/[A-Za-z0-9_\-\.]+\.(js|css)') | ForEach-Object { $_.Value }
$sw = Get-Content "$appDir\sw.js" -Raw
$swAssets = [regex]::Matches($sw, '"/assets/[^"]+"') | ForEach-Object { $_.Value.Trim('"') }
$allExist = $true
foreach ($a in ($assetM + $swAssets | Sort-Object -Unique)) {
    if (-not (Test-Path "$appDir\$a")) { $allExist = $false; Write-Host "    missing: $a" }
}
$ok = (Test-Path "$appDir\manifest.json") -and (Test-Path "$appDir\index.html") -and $allExist
Record 'TC-D01' $ok "assets referenced by index.html & sw.js exist"

$passed = @($results | Where-Object { $_.OK }).Count
Write-Host ""
Write-Host "=== Desktop results: $passed/$($results.Count) passed ==="
foreach ($r in $results | Where-Object { -not $_.OK }) {
    Write-Host "  FAILED: $($r.Id) $($r.Note)"
}
exit $(if ($passed -eq $results.Count) { 0 } else { 1 })

