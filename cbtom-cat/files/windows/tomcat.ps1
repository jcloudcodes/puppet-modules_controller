param(
    [string]$TomcatVersion,
    [string]$TomcatUrl,
    [string]$InstallDir,
    [string]$ServiceName,
    [string]$JavaHome,
    [string]$VersionFile
)

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$package = "apache-tomcat-$TomcatVersion"
$zipPath = "C:\temp\$package-windows-x64.zip"
$extractRoot = "C:\temp\tomcat-extract"
$preserveDirNames = @('tomcat-java', 'webapps')

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

if (Get-Service -Name $ServiceName -ErrorAction SilentlyContinue) {
    Stop-Service -Name $ServiceName -Force -ErrorAction SilentlyContinue
    $service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
    if ($service) {
        $service.WaitForStatus('Stopped', (New-TimeSpan -Seconds 30))
    }
    Start-Sleep -Seconds 2
    & sc.exe delete $ServiceName | Out-Null
    for ($i = 0; $i -lt 15; $i++) {
        if (-not (Get-Service -Name $ServiceName -ErrorAction SilentlyContinue)) {
            break
        }
        Start-Sleep -Seconds 2
    }
    Start-Sleep -Seconds 3
}

Get-ChildItem -Path $InstallDir -Force | Where-Object { $_.Name -notin $preserveDirNames } | ForEach-Object {
    Remove-Item -Path $_.FullName -Recurse -Force
}

$expandedWebapps = Join-Path $expandedDir.FullName 'webapps'
$installWebapps = Join-Path $InstallDir 'webapps'

Get-ChildItem -Path $expandedDir.FullName -Force | Where-Object { $_.Name -ne 'webapps' } | ForEach-Object {
    Move-Item -Path $_.FullName -Destination $InstallDir -Force
}

if (!(Test-Path $installWebapps) -and (Test-Path $expandedWebapps)) {
    Move-Item -Path $expandedWebapps -Destination $InstallDir -Force
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

Set-Content -Path $VersionFile -Value $TomcatVersion -Force
