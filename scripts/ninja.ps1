[CmdletBinding()]
param([Parameter(ValueFromRemainingArguments)][string[]]$Args_)
. (Join-Path $PSScriptRoot 'env.ps1')
Push-Location $TreeRoot
try {
    & $NinjaExe @Args_
    exit $LASTEXITCODE
} finally {
    Pop-Location
}
