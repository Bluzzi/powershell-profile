$script:ProfileGitFirstPrompt = $true
$script:ProfileGitLoadAttempted = $false
$script:ProfileGitReady = $false

function Initialize-ProfileGit {
  if ($script:ProfileGitLoadAttempted) { return }
  $script:ProfileGitLoadAttempted = $true

  Save-Module posh-git
  if (-not (Get-Module -Name posh-git)) { return }

  $GitPromptSettings.BeforeStatus.ForegroundColor = [ConsoleColor]::DarkGray
  $GitPromptSettings.BeforeStatus.Text = "["
  $GitPromptSettings.AfterStatus.ForegroundColor = [ConsoleColor]::DarkGray
  $GitPromptSettings.AfterStatus.Text = "]"
  $GitPromptSettings.BranchColor.ForegroundColor = [ConsoleColor]::Green
  $script:ProfileGitReady = $true
}

# posh-git registers its own completers when loaded. Complete the current request
# here as well, since PowerShell has already selected this script block for it.
if ($PSVersionTable.PSVersion.Major -ge 6) {
  Register-ArgumentCompleter -Native -CommandName git, tgit, gitk -ScriptBlock {
    param($wordToComplete, $commandAst, $cursorPosition)

    Initialize-ProfileGit
    if ($script:ProfileGitReady) {
      $length = $cursorPosition - $commandAst.Extent.StartOffset
      Expand-GitCommand $commandAst.ToString().PadRight($length).Substring(0, $length)
    }
  }
}

function prompt {
  $path = (Get-Location).Path

  if ($script:ProfileGitFirstPrompt) {
    $script:ProfileGitFirstPrompt = $false
    return "$path > "
  }

  Initialize-ProfileGit
  if (-not $script:ProfileGitReady) { return "$path > " }

  $arrow = Write-Prompt " > " -ForegroundColor ([ConsoleColor]::White)
  $gitDirectory = if ($GitPromptSettings.EnablePromptStatus) { Get-GitDirectory }

  if (-not $gitDirectory) {
    return "$($path)$($arrow)"
  }

  # Use the same repository name as Get-GitStatus without calculating the status twice.
  $repoName = Split-Path (Split-Path $gitDirectory -Parent) -Leaf
  $repoRelativePath = Write-Prompt ($path -replace ".*?($repoName.*)", '$1') -ForegroundColor ([ConsoleColor]::White)
  
  return "$($repoRelativePath)$(Write-VcsStatus)$($arrow)"
}
