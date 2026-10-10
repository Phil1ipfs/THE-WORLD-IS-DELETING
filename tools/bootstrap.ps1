$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$toolRoot = Join-Path $projectRoot '.tools'
New-Item -ItemType Directory -Force -Path $toolRoot | Out-Null
$packages = @(
    @{ Name = 'rojo'; Version = '7.7.1'; Url = 'https://github.com/rojo-rbx/rojo/releases/download/v7.7.1/rojo-7.7.1-windows-x86_64.zip' },
    @{ Name = 'stylua'; Version = '2.5.2'; Url = 'https://github.com/JohnnyMorganz/StyLua/releases/download/v2.5.2/stylua-windows-x86_64.zip' },
    @{ Name = 'luau'; Version = '0.741'; Url = 'https://github.com/luau-lang/luau/releases/download/0.741/luau-windows.zip' },
    @{ Name = 'selene'; Version = '0.32.0'; Url = 'https://github.com/Kampfkarren/selene/releases/download/0.32.0/selene-0.32.0-windows.zip' },
    @{ Name = 'lune'; Version = '0.10.5'; Url = 'https://github.com/lune-org/lune/releases/download/v0.10.5/lune-0.10.5-windows-x86_64.zip' }
)
foreach ($package in $packages) {
    $destination = Join-Path $toolRoot $package.Name
    if (Test-Path -LiteralPath (Join-Path $destination ($package.Name + '.exe'))) { continue }
    $archive = Join-Path $toolRoot ($package.Name + '.zip')
    Invoke-WebRequest -Uri $package.Url -OutFile $archive
    Expand-Archive -LiteralPath $archive -DestinationPath $destination -Force
    Write-Output ('Installed ' + $package.Name + ' ' + $package.Version)
}
