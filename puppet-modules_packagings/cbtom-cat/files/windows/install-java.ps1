param(
    [Parameter(Mandatory = $true)]
    [string]$JavaUrl,

    [Parameter(Mandatory = $true)]
    [string]$ZipPath,

    [Parameter(Mandatory = $true)]
    [string]$ExtractRoot,

    [Parameter(Mandatory = $true)]
    [string]$JavaRoot,

    [Parameter(Mandatory = $true)]
    [string]$JavaHome,

    [Parameter(Mandatory = $true)]
    [string]$JavaLink
)

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

if (!(Test-Path 'C:\temp')) {
    New-Item -Path 'C:\temp' -ItemType Directory -Force | Out-Null
}

if (!(Test-Path $JavaRoot)) {
    New-Item -Path $JavaRoot -ItemType Directory -Force | Out-Null
}

if (!(Test-Path $ExtractRoot)) {
    New-Item -Path $ExtractRoot -ItemType Directory -Force | Out-Null
}

Invoke-WebRequest -Uri $JavaUrl -OutFile $ZipPath

if (Test-Path $ExtractRoot) {
    Remove-Item -Path $ExtractRoot -Recurse -Force
}

Expand-Archive -Path $ZipPath -DestinationPath $ExtractRoot -Force

$jdkDir = Get-ChildItem -Path $ExtractRoot -Directory | Select-Object -First 1
if (-not $jdkDir) {
    throw 'Corretto archive extraction failed'
}

if (Test-Path $JavaHome) {
    Remove-Item -Path $JavaHome -Recurse -Force
}

Move-Item -Path $jdkDir.FullName -Destination $JavaHome

if (Test-Path $JavaLink) {
    Remove-Item -Path $JavaLink -Recurse -Force
}

New-Item -Path $JavaLink -ItemType Junction -Target $JavaHome -Force | Out-Null
