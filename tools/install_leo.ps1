# Install Leo 4.4.0 (Windows x64) into tools/leo or C:\tools\leo
$ErrorActionPreference = "Stop"
$Version = "leo-lang-v4.4.0"
$Rel = "$Version-x86_64-pc-windows-msvc.zip"
$Urls = @(
  "https://ghproxy.net/https://github.com/ProvableHQ/leo/releases/download/$Version/$Rel",
  "https://github.com/ProvableHQ/leo/releases/download/$Version/$Rel"
)
$Dest = Join-Path $PSScriptRoot "leo"
$Alt = "C:\tools\leo"
New-Item -ItemType Directory -Force -Path $Dest | Out-Null
New-Item -ItemType Directory -Force -Path $Alt | Out-Null
$Zip = Join-Path $Alt $Rel
$ok = $false
foreach ($Url in $Urls) {
  Write-Host "Downloading $Url ..."
  try {
    curl.exe -L --connect-timeout 30 --retry 5 --retry-all-errors -o $Zip $Url
    if ((Test-Path $Zip) -and (Get-Item $Zip).Length -gt 1000000) { $ok = $true; break }
  } catch {
    Write-Host "mirror failed: $_"
  }
}
if (-not $ok) {
  throw "Download failed or file too small. Place leo.exe manually under C:\tools\leo"
}
Write-Host "Extracting..."
python -c "import zipfile; z=zipfile.ZipFile(r'$Zip'); z.extractall(r'$Alt'); z.extractall(r'$Dest'); print('ok', z.namelist()[:5])"
$Leo = Join-Path $Alt "leo.exe"
& $Leo --version
$Shim = Join-Path $PSScriptRoot "leo.cmd"
@"
@echo off
"$Leo" %*
"@ | Set-Content $Shim -Encoding ASCII
Write-Host "Installed. Shim: $Shim"
Write-Host "Next: cd chain\programs\bv_commit && leo build"
