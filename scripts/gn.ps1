[CmdletBinding()]
param([Parameter(ValueFromRemainingArguments)][string[]]$Args_)
. (Join-Path $PSScriptRoot 'env.ps1')
Push-Location $TreeRoot
try {
    & $GnExe @Args_
    exit $LASTEXITCODE
} finally {
    Pop-Location
}
