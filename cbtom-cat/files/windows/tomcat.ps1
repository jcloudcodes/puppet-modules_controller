param(
    [string]$TomcatVersion,
    [string]$TomcatUrl,
    [string]$InstallDir,
    [string]$ServiceName,
    [string]$JavaHome
)

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$package = "apache-tomcat-$TomcatVersion"
$zipPath = "C:\temp\$package-windows-x64.zip"
$extractRoot = "C:\temp\tomcat-extract"
$preserveDirName = 'tomcat-java'

if (!(Test-Path "C:\temp")) {
    New-Item -Path "C:\temp" -ItemType Directory -Force | Out-Null
}

Invoke-WebRequest -Uri $TomcatUrl -OutFile $zipPath

if (Test-Path $extractRoot) {
    Remove-Item -Path $extractRoot -Recurse -Force
}

Expand-Archive -Path $zipPath -DestinationPath $extractRoot -Force

$expandedDir = Get-ChildItem -Path $extractRoot -Directory | Where-Object { $_.Name -like "$package*" } | Select-Object -First 1
if (-not $expandedDir) {
    throw "Expanded Tomcat directory for $package was not found"
}

if (!(Test-Path $InstallDir)) {
    New-Item -Path $InstallDir -ItemType Directory -Force | Out-Null
}

Get-ChildItem -Path $InstallDir -Force | Where-Object { $_.Name -ne $preserveDirName } | ForEach-Object {
    Remove-Item -Path $_.FullName -Recurse -Force
}

Get-ChildItem -Path $expandedDir.FullName -Force | ForEach-Object {
    Move-Item -Path $_.FullName -Destination $InstallDir -Force
}

$serviceBat = Join-Path $InstallDir "bin\service.bat"
if (Test-Path $serviceBat) {
    $env:CATALINA_HOME = $InstallDir
    $env:CATALINA_BASE = $InstallDir
    $env:JRE_HOME      = $JavaHome
    $env:JAVA_HOME     = $JavaHome

    Push-Location (Join-Path $InstallDir 'bin')
    try {
        & .\service.bat install $ServiceName
        if ($LASTEXITCODE -ne 0) {
            throw "Tomcat service install failed with exit code $LASTEXITCODE"
        }
    }
    finally {
        Pop-Location
    }
}
else {
    throw "Tomcat service installer not found at $serviceBat"
}

if (-not (Get-Service -Name $ServiceName -ErrorAction SilentlyContinue)) {
    throw "Tomcat service '$ServiceName' was not created successfully"
}
