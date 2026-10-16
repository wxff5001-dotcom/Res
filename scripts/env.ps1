<#
    Dot-source this to put the tree's own depot_tools on PATH and point the
    build at the locally installed Visual Studio:

        . .\scripts\env.ps1

    gn.ps1 and ninja.ps1 do this for you; you only need it when invoking
    gn.exe / ninja.exe by hand.
#>

$TreeRoot = Split-Path $PSScriptRoot -Parent

# The tree's own depot_tools, with auto-update disabled (.disable_auto_update)
# so the pinned gn / ninja / Python are never swapped out underneath a build.
$DepotTools = Join-Path $TreeRoot "depot_tools"
if (($env:PATH -split ';') -notcontains $DepotTools) {
    $env:PATH = "$DepotTools;$env:PATH"
}

# //.gn sets script_executable = "python3", which GN resolves on PATH at
# `gn gen` time and bakes into build.ninja -- so the wrong interpreter here is
# a generation-time mistake that no amount of fixing PATH later will undo; the
# build directory has to be re-generated.
#
# depot_tools' root does not carry python3.exe (its shim is
# python-bin\python3.bat), so adding the root alone leaves GN to find whatever
# Python the machine has. Picking up a system Python 3.8 makes //build/rust's
# rustc_wrapper.py die with "unsupported operand type(s) for |: 'dict' and
# 'dict'" -- dict | dict needs 3.9+. Point at the bootstrap interpreter
# (3.11) explicitly instead. restore_toolchain.ps1 restores it.
$BootstrapPython = (Resolve-Path (Join-Path $DepotTools "bootstrap-*_bin\python3\bin") `
                        -ErrorAction SilentlyContinue | Select-Object -First 1).Path
if ($BootstrapPython) {
    if (($env:PATH -split ';') -notcontains $BootstrapPython) {
        $env:PATH = "$BootstrapPython;$env:PATH"
    }
} else {
    Write-Warning ("depot_tools' bootstrap Python is missing -- run scripts\restore_toolchain.ps1. " +
                   "Generating now would bake this machine's Python into build.ninja.")
}

# Use the Visual Studio installed on this machine rather than the hermetic
# toolchain package, which is only downloadable by Google employees.
$env:DEPOT_TOOLS_WIN_TOOLCHAIN = "0"
$env:DEPOT_TOOLS_UPDATE = "0"

$GnExe    = Join-Path $TreeRoot "buildtools\win\gn.exe"
$NinjaExe = Join-Path $TreeRoot "third_party\ninja\ninja.exe"
