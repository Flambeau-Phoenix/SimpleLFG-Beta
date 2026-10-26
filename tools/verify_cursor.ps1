param(
    [Parameter(Mandatory=$true)][string]$HashLink,
    [Parameter(Mandatory=$true)][string]$HashLinkSDK,
    [string]$LegacyHelper
)
$ErrorActionPreference = 'Stop'
Push-Location (Split-Path -Parent $PSScriptRoot)
try {
    cmake -S native/sfcursor -B build/sfcursor-build "-DHASHLINK_DIR=$HashLinkSDK"
    if ($LASTEXITCODE) { throw 'Standalone helper configure failed' }
    cmake --build build/sfcursor-build --config Release
    if ($LASTEXITCODE) { throw 'Standalone helper build failed' }
    ctest --test-dir build/sfcursor-build -C Release --output-on-failure
    if ($LASTEXITCODE) { throw 'Native helper suites failed' }
    haxe -cp src -cp tests -main CursorProbe -D hl-ver=1.16.0 -hl build/cursor-probe.hl
    if ($LASTEXITCODE) { throw 'Optional import probe compile failed' }
    # Separate directories avoid loading the installed game/helper and never call primitives.
    $modes = @('new','missing')
    if ($LegacyHelper) { $modes += 'legacy'; $LegacyHelper = (Resolve-Path -LiteralPath $LegacyHelper).Path }
    $HashLink = (Resolve-Path -LiteralPath $HashLink).Path
    foreach ($mode in $modes) {
        $dir = "build/cursor-probe-$mode"
        New-Item -ItemType Directory -Force $dir | Out-Null
        Copy-Item -LiteralPath build/cursor-probe.hl -Destination "$dir/probe.hl" -Force
        if ($mode -eq 'new') { Copy-Item -LiteralPath build/sfcursor-build/Release/sfcursor.hdll -Destination "$dir/sfcursor.hdll" -Force }
        if ($mode -eq 'legacy') { Copy-Item -LiteralPath $LegacyHelper -Destination "$dir/sfcursor.hdll" -Force }
        if ($mode -eq 'missing' -and (Test-Path -LiteralPath "$dir/sfcursor.hdll")) { throw 'Missing-helper probe directory unexpectedly contains a helper' }
        Push-Location $dir
        try {
            & $HashLink probe.hl $mode
            if ($LASTEXITCODE) { throw "Optional imports failed for $mode helper" }
        } finally { Pop-Location }
    }
} finally { Pop-Location }
