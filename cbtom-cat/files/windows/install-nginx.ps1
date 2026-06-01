param(
    [string]$NginxVersion,
    [string]$NginxUrl,
    [string]$NginxHome,
    [string]$VersionFile
)

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$tempDir = 'C:\temp'
$zipPath = Join-Path $tempDir "nginx-$NginxVersion.zip"
$extractRoot = Join-Path $tempDir 'nginx-extract'

if (!(Test-Path $tempDir)) {
    New-Item -Path $tempDir -ItemType Directory -Force | Out-Null
}

Invoke-WebRequest -Uri $NginxUrl -OutFile $zipPath

if (Test-Path $extractRoot) {
    Remove-Item -Path $extractRoot -Recurse -Force
}

Expand-Archive -Path $zipPath -DestinationPath $extractRoot -Force

$expandedDir = Get-ChildItem -Path $extractRoot -Directory | Where-Object { $_.Name -like "nginx-*" } | Select-Object -First 1
if (-not $expandedDir) {
    throw "Expanded Nginx directory for version $NginxVersion was not found"
}

if (Get-Process -Name nginx -ErrorAction SilentlyContinue) {
    & (Join-Path $NginxHome 'nginx.exe') -s quit
    Start-Sleep -Seconds 3
}

if (!(Test-Path $NginxHome)) {
    New-Item -Path $NginxHome -ItemType Directory -Force | Out-Null
}

Get-ChildItem -Path $NginxHome -Force -ErrorAction SilentlyContinue | ForEach-Object {
    Remove-Item -Path $_.FullName -Recurse -Force
}

Get-ChildItem -Path $expandedDir.FullName -Force | ForEach-Object {
    Move-Item -Path $_.FullName -Destination $NginxHome -Force
}

Set-Content -Path $VersionFile -Value $NginxVersion -Force
