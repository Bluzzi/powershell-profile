# The zoxide init script is cached so that a shell startup only spawns `zoxide
# --version` instead of running `zoxide init` and parsing its full output.
# The cache is invalidated when the zoxide version changes.
$zoxideCachePath = "$env:TEMP\zoxide-init-pwsh.ps1"
$zoxideVersion = (zoxide --version 2>$null)

if ($zoxideVersion -and (Test-Path $zoxideCachePath) -and (Get-Content $zoxideCachePath -TotalCount 1) -eq "# $zoxideVersion") {
  . $zoxideCachePath
} else {
  $zoxideInit = (zoxide init powershell | Out-String)
  "# $zoxideVersion`n$zoxideInit" | Out-File -FilePath $zoxideCachePath -Force
  Invoke-Expression $zoxideInit
}
