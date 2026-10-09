<#
.SYNOPSIS
    Install the Lumin CLI (lumin.exe) on Windows from https://github.com/pixionco/lumin.

.DESCRIPTION
    Downloads lumin-win-<arch>.zip from a GitHub release, checks its SHA-256 against the release's SHA256SUMS,
    installs lumin.exe and adds the folder to the user PATH.

        irm https://raw.githubusercontent.com/pixionco/lumin/master/install.ps1 | iex
        & ([scriptblock]::Create((irm https://raw.githubusercontent.com/pixionco/lumin/master/install.ps1))) -Version 1.2.0

    On Linux and macOS use install.sh.

.PARAMETER Version
    Release to install, e.g. 1.2.0. Default: $env:LUMIN_VERSION, else the latest release.

.PARAMETER InstallDir
    Folder for lumin.exe. Default: $env:LUMIN_INSTALL_DIR, else %LOCALAPPDATA%\Programs\lumin.

.PARAMETER NoModifyPath
    Do not add InstallDir to the user PATH.

.NOTES
    $env:LUMIN_DOWNLOAD_URL replaces the GitHub release URL with a mirror or proxy holding the same assets.
#>
[CmdletBinding()]
param(
    [string] $Version = $(if ($env:LUMIN_VERSION) { $env:LUMIN_VERSION } else { 'latest' }),
    [string] $InstallDir = $(if ($env:LUMIN_INSTALL_DIR) { $env:LUMIN_INSTALL_DIR } else { Join-Path $env:LOCALAPPDATA 'Programs\lumin' }),
    [switch] $NoModifyPath
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$repo = 'pixionco/lumin'

if ($PSVersionTable.PSEdition -eq 'Core' -and -not $IsWindows) {
    throw 'install.ps1 installs lumin on Windows; on Linux and macOS use install.sh.'
}
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

# x64 processes emulated on Windows ARM report AMD64; the processor identifier tells the truth.
$processorArchitecture = if ($env:PROCESSOR_IDENTIFIER -like 'ARM*') { 'ARM64' } elseif ($env:PROCESSOR_ARCHITEW6432) { $env:PROCESSOR_ARCHITEW6432 } else { $env:PROCESSOR_ARCHITECTURE }
$arch = switch ($processorArchitecture) {
    'AMD64' { 'x64' }
    'ARM64' { 'arm64' }
    default { throw "Unsupported architecture: $processorArchitecture" }
}

$archive = "lumin-win-$arch.zip"
$Version = $Version.TrimStart('v')
$base = if ($env:LUMIN_DOWNLOAD_URL) { $env:LUMIN_DOWNLOAD_URL.TrimEnd('/') } elseif ($Version -eq 'latest') { "https://github.com/$repo/releases/latest/download" } else { "https://github.com/$repo/releases/download/v$Version" }

$temp = Join-Path ([IO.Path]::GetTempPath()) ("lumin-" + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $temp | Out-Null
try {
    Write-Host "Downloading $base/$archive"
    Invoke-WebRequest -UseBasicParsing -Uri "$base/$archive" -OutFile (Join-Path $temp $archive)
    Invoke-WebRequest -UseBasicParsing -Uri "$base/SHA256SUMS" -OutFile (Join-Path $temp 'SHA256SUMS')

    $expected = Get-Content (Join-Path $temp 'SHA256SUMS') |
        ForEach-Object { $hash, $name = $_ -split '\s+', 2; if ($name -and $name.TrimStart('*') -eq $archive) { $hash } } |
        Select-Object -First 1
    if (-not $expected) { throw "$archive is not listed in SHA256SUMS" }
    $actual = (Get-FileHash -Algorithm SHA256 (Join-Path $temp $archive)).Hash
    if ($actual -ne $expected) { throw "Checksum mismatch for $archive (expected $expected, got $actual)" }

    Expand-Archive -Force -Path (Join-Path $temp $archive) -DestinationPath (Join-Path $temp 'extract')
    New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
    $exe = Join-Path $InstallDir 'lumin.exe'
    Copy-Item -Force -Path (Join-Path $temp 'extract\lumin.exe') -Destination $exe
}
finally {
    Remove-Item -Recurse -Force $temp -ErrorAction SilentlyContinue
}

Write-Host "Installed lumin $(& $exe --version) to $exe"

if (-not $NoModifyPath) {
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $entries = @($userPath -split ';' | Where-Object { $_ })
    if ($entries -notcontains $InstallDir) {
        [Environment]::SetEnvironmentVariable('Path', (($entries + $InstallDir) -join ';'), 'User')
        Write-Host "Added $InstallDir to your user PATH; open a new terminal to use lumin."
    }
    if (($env:Path -split ';') -notcontains $InstallDir) { $env:Path = "$env:Path;$InstallDir" }
}