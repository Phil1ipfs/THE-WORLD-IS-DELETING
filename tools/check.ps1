param([switch]$Format, [switch]$SkipEndurance)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Push-Location -LiteralPath $projectRoot
try {
    function Invoke-Check {
        param([string]$Executable, [string[]]$Arguments)
        & $Executable @Arguments
        if ($LASTEXITCODE -ne 0) { throw ('Check failed: ' + $Executable + ' (exit ' + $LASTEXITCODE + ')') }
    }
    $required = @('.tools/stylua/stylua.exe', '.tools/selene/selene.exe', '.tools/luau/luau.exe', '.tools/luau/luau-analyze.exe', '.tools/luau/luau-compile.exe', '.tools/rojo/rojo.exe', '.tools/lune/lune.exe')
    foreach ($tool in $required) { if (-not (Test-Path -LiteralPath $tool)) { throw ('Missing tool. Run tools/bootstrap.ps1: ' + $tool) } }
    $formatArgs = @('src', 'tests', 'tools')
    if (-not $Format) { $formatArgs = @('--check') + $formatArgs }
    Invoke-Check '.tools/stylua/stylua.exe' $formatArgs
    Invoke-Check '.tools/selene/selene.exe' @('src')
    Invoke-Check '.tools/luau/luau-analyze.exe' @('src/shared')
    $files = @(Get-ChildItem -Path 'src', 'tests', 'tools' -Recurse -Filter '*.luau' | Select-Object -ExpandProperty FullName)
    Invoke-Check '.tools/luau/luau-compile.exe' (@('--null') + $files)
    Invoke-Check '.tools/luau/luau.exe' @('tests/core.spec.luau')
    New-Item -ItemType Directory -Force -Path 'build' | Out-Null
    Invoke-Check '.tools/rojo/rojo.exe' @('build', 'default.project.json', '-o', 'build/FloatingRealms.rbxlx')
    Invoke-Check '.tools/rojo/rojo.exe' @('sourcemap', 'default.project.json', '-o', 'build/sourcemap.json')
    Invoke-Check '.tools/lune/lune.exe' @('run', 'tools/integration.spec.luau')
    Invoke-Check '.tools/lune/lune.exe' @('run', 'tools/exploration.spec.luau')
    Invoke-Check '.tools/lune/lune.exe' @('run', 'tools/items-powers.spec.luau')
    Invoke-Check '.tools/lune/lune.exe' @('run', 'tools/seal.spec.luau')
    Invoke-Check '.tools/lune/lune.exe' @('run', 'tools/client.spec.luau')
    Invoke-Check '.tools/lune/lune.exe' @('run', 'tools/dragon.spec.luau')
    Invoke-Check '.tools/lune/lune.exe' @('run', 'tools/dragon-client.spec.luau')
    Invoke-Check '.tools/lune/lune.exe' @('run', 'tools/storm.spec.luau')
    Invoke-Check '.tools/lune/lune.exe' @('run', 'tools/disasters.spec.luau')
    Invoke-Check '.tools/lune/lune.exe' @('run', 'tools/gameplay.spec.luau')
    Invoke-Check '.tools/lune/lune.exe' @('run', 'tools/visuals.spec.luau')
    Invoke-Check '.tools/lune/lune.exe' @('run', 'tools/menu-ocean.spec.luau')
    Invoke-Check '.tools/lune/lune.exe' @('run', 'tools/expansion.spec.luau')
    Invoke-Check '.tools/lune/lune.exe' @('run', 'tools/bootstrap.spec.luau')
    if (-not $SkipEndurance) { Invoke-Check '.tools/lune/lune.exe' @('run', 'tools/endurance.spec.luau') }
    Write-Output 'ALL AVAILABLE CHECKS PASSED. Roblox Studio validation remains pending.'
} finally { Pop-Location }
