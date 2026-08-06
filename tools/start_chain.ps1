# Start wallet-bridge (:8788) + Node Sidecar (8787 or 8790) with Leo
$ErrorActionPreference = "Stop"
$Root = Split-Path $PSScriptRoot -Parent
$Node = if (Test-Path "C:\tools\node-v22.17.0-win-x64\node.exe") {
  "C:\tools\node-v22.17.0-win-x64\node.exe"
} else { "node" }
$Leo = if ($env:LEO_BIN) { $env:LEO_BIN } elseif (Test-Path "C:\tools\leo\leo.exe") { "C:\tools\leo\leo.exe" } else { Join-Path $Root "tools\leo\leo.exe" }
$env:LEO_BIN = $Leo
# Prefer 8790 if 8787 is occupied by a stale non-sidecar listener
$SidecarPort = if ($env:SIDECAR_PORT) { $env:SIDECAR_PORT } else {
  $useAlt = $false
  try {
    $r = Invoke-WebRequest -Uri "http://127.0.0.1:8787/health" -UseBasicParsing -TimeoutSec 1
    if ($r.Content -notmatch "bv-sidecar") { $useAlt = $true }
  } catch { }
  if ($useAlt) { "8790" } else { "8787" }
}
$env:SIDECAR_PORT = $SidecarPort
$env:Path = "$(Split-Path $Node -Parent);$(Split-Path $Leo -Parent);$env:Path"

Write-Host "Leo: $Leo"
& $Leo --version
Write-Host "Starting wallet-bridge :8788 ..."
Start-Process -FilePath $Node -ArgumentList "server.mjs" -WorkingDirectory (Join-Path $Root "chain\wallet-bridge") -WindowStyle Hidden
Start-Sleep 1
Write-Host "Starting sidecar :$SidecarPort ..."
Start-Process -FilePath $Node -ArgumentList "server.mjs" -WorkingDirectory (Join-Path $Root "chain\sidecar") -WindowStyle Hidden
Start-Sleep 2
Write-Host "Health:"
curl.exe -s "http://127.0.0.1:$SidecarPort/health"
Write-Host ""
curl.exe -s http://127.0.0.1:8788/health
Write-Host ""
Write-Host "Client: CHAIN_SIDECAR_URL=http://127.0.0.1:$SidecarPort  CHAIN_MOCK=false"
Write-Host "Fund: cd chain\wallet-bridge && npm run fund-hint"
Write-Host "Docs: chain\SETUP_ALEO.md"
