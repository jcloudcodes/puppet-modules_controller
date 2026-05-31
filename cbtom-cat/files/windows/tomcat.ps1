param(
    [string]$TomcatVersion,
    [string]$TomcatUrl,
    [string]$InstallDir,
    [string]$ServiceName
)

$package = "apache-tomcat-$TomcatVersion"
$zipPath = "C:\temp\$package-windows-x64.zip"

if (!(Test-Path "C:\temp")) {
    New-Item -Path "C:\temp" -ItemType Directory -Force | Out-Null
}

Invoke-WebRequest -Uri $TomcatUrl -OutFile $zipPath

if (Test-Path $InstallDir) {
    Remove-Item -Path $InstallDir -Recurse -Force
}

Expand-Archive -Path $zipPath -DestinationPath "C:\" -Force

$expandedDir = Get-ChildItem -Path "C:\" -Directory | Where-Object { $_.Name -like "$package*" } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($expandedDir) {
    Rename-Item -Path $expandedDir.FullName -NewName (Split-Path $InstallDir -Leaf)
}

$serviceBat = Join-Path $InstallDir "bin\service.bat"
if (Test-Path $serviceBat) {
    & $serviceBat install $ServiceName
}
