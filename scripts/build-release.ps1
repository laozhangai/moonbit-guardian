param(
  [ValidateSet("windows-x64", "linux-x64")]
  [string]$Platform = "windows-x64"
)

$ErrorActionPreference = "Stop"
$pluginRoot = Split-Path -Parent $PSScriptRoot
$coreRoot = Join-Path $pluginRoot "core"

if (-not (Get-Command clang -ErrorAction SilentlyContinue)) {
  $vswhere = "C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe"
  if (Test-Path -LiteralPath $vswhere) {
    $installation = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Llvm.Clang -property installationPath
    if ($installation) {
      $devCmd = Join-Path $installation "Common7\Tools\VsDevCmd.bat"
      $environment = & cmd.exe /d /s /c "`"$devCmd`" -no_logo -arch=x64 -host_arch=x64 && set"
      foreach ($line in $environment) {
        if ($line -match "^([^=]+)=(.*)$") {
          [System.Environment]::SetEnvironmentVariable($matches[1], $matches[2], "Process")
        }
      }
    }
  }
}

$moonBin = Join-Path $env:USERPROFILE ".moon\bin"
if (Test-Path -LiteralPath (Join-Path $moonBin "moon.exe")) {
  $env:Path = "$moonBin;$env:Path"
}
if (-not (Get-Command clang -ErrorAction SilentlyContinue)) {
  throw "clang was not found. Install LLVM/Clang or Visual Studio Build Tools with the Clang component."
}

Push-Location $coreRoot
try {
  moon update
  moon check --deny-warn --target native
  moon test --target native
  moon build cmd/server --target native --release

  $binaryPath = Join-Path $coreRoot "_build\native\release\build\cmd\server\server.exe"
  if (-not (Test-Path -LiteralPath $binaryPath)) {
    throw "The native cmd/server build output was not found."
  }

  $destination = Join-Path $pluginRoot ("dist/" + $Platform)
  New-Item -ItemType Directory -Path $destination -Force | Out-Null
  $name = if ($Platform -eq "windows-x64") {
    "moonbit-guardian-server.exe"
  } else {
    "moonbit-guardian-server"
  }
  Copy-Item -LiteralPath $binaryPath -Destination (Join-Path $destination $name) -Force
} finally {
  Pop-Location
}
