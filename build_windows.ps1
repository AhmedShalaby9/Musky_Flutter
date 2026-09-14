$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath $PSScriptRoot

Write-Host 'Building Musky Windows release...'
flutter build windows --release

$release = Join-Path $PSScriptRoot 'build\windows\x64\runner\Release'
$archive = Join-Path $PSScriptRoot 'musky-client-windows.zip'

if (-not (Test-Path (Join-Path $release 'musky.exe'))) {
    throw "Build output was not found: $release\musky.exe"
}

if (Test-Path $archive) {
    Remove-Item -LiteralPath $archive -Force
}

Compress-Archive -Path (Join-Path $release '*') -DestinationPath $archive -CompressionLevel Optimal
Write-Host "Package created: $archive"
