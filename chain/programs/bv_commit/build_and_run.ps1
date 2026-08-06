$ErrorActionPreference = "Stop"
$Leo = $env:LEO_BIN
if (-not $Leo) {
  foreach ($c in @(
    "$PSScriptRoot\..\..\..\tools\leo\leo.exe",
    "C:\tools\leo\leo.exe",
    "$env:USERPROFILE\.cargo\bin\leo.exe"
  )) {
    if (Test-Path $c) { $Leo = $c; break }
  }
}
if (-not $Leo) { throw "leo.exe not found. Run tools/install_leo.ps1" }
Set-Location $PSScriptRoot
Write-Host "Using $Leo"
& $Leo --version
& $Leo build
if ($LASTEXITCODE -ne 0) { throw "leo build failed" }
# Smoke vector (fields are placeholders — replace with FieldMapper output)
& $Leo run commit_battle `
  1field 2field 3field `
  42u64 1u8 3u8 `
  4field 1u32
