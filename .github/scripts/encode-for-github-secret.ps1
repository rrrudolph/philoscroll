param(
  [Parameter(Mandatory = $true, Position = 0)]
  [string]$Path
)

$resolved = Resolve-Path -LiteralPath $Path
$bytes = [IO.File]::ReadAllBytes($resolved)
$encoded = [Convert]::ToBase64String($bytes)
Write-Output $encoded
