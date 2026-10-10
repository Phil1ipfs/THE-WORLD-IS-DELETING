$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Push-Location -LiteralPath $projectRoot
try {
    New-Item -ItemType Directory -Force -Path 'build' | Out-Null
    & '.tools/rojo/rojo.exe' build default.project.json -o build/FloatingRealms.rbxlx
    if ($LASTEXITCODE -ne 0) { throw 'Rojo build failed' }
} finally { Pop-Location }
