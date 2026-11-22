# The zoxide init script is cached so that a shell startup does not spawn zoxide at
# all. The cache header stores the zoxide executable path and its last write time:
# if the binary changed (update), the init script is regenerated once.
$zoxideCachePath = "$env:TEMP\zoxide-init-pwsh.ps1"

function Initialize-ZoxideCache {
  $zoxideCommand = Get-Command zoxide -ErrorAction SilentlyContinue
  if (!$zoxideCommand) { return }

  $zoxideExe = $zoxideCommand.Source
  $zoxideInit = (zoxide init powershell | Out-String)
  $header = "# {0}|{1}" -f $zoxideExe, (Get-Item $zoxideExe).LastWriteTimeUtc.Ticks
  "$header`n$zoxideInit" | Out-File -FilePath $zoxideCachePath -Force
  Invoke-Expression $zoxideInit
}

if (Test-Path $zoxideCachePath) {
  $zoxideHeader = Get-Content $zoxideCachePath -TotalCount 1
  $zoxideExe, $zoxideTicks = $zoxideHeader.Substring(2).Split('|', 2)

  if ($zoxideExe -and (Test-Path $zoxideExe) -and (Get-Item $zoxideExe).LastWriteTimeUtc.Ticks -eq [long]$zoxideTicks) {
    # The header is a comment, so the cached script can be dot-sourced as is.
    . $zoxideCachePath
  } else {
    Initialize-ZoxideCache
  }
} else {
  Initialize-ZoxideCache
}
