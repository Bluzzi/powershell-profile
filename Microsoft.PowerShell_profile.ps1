# Auto-load commands:
$CommandsPath = "$PSScriptRoot\Core\Commands"

foreach ($FolderPath in Get-ChildItem -Path $CommandsPath -Directory) {
  $FolderName = Split-Path -Path $FolderPath -Leaf

  if (!(Test-Path -Path "$FolderPath\$FolderName.Cmd.ps1" -PathType Leaf)) { continue }

  . "$FolderPath\$FolderName.Cmd.ps1"
}

foreach ($FilePath in Get-ChildItem -Path "$PSScriptRoot\Core\Functions" -File) {
  . $FilePath
}

# Auto-load configs:
foreach ($FilePath in Get-ChildItem -Path "$PSScriptRoot\Core\Configs" -File) {
  . $FilePath
}

# Auto-load extensions:
foreach ($FilePath in Get-ChildItem -Path "$PSScriptRoot\Core\Extensions" -File) {
  . $FilePath
}

# Import the Chocolatey Profile that contains the necessary code to enable
# tab-completions to function for `choco`.
# Be aware that if you are missing these lines from your profile, tab completion
# for `choco` will not function.
# See https://ch0.co/tab-completion for details.
$ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
if (Test-Path($ChocolateyProfile)) {
  Import-Module "$ChocolateyProfile"
}
