# Lightweight Git prompt, drop-in replacement for posh-git's prompt integration:
# - renders exactly the same output as posh-git's Write-VcsStatus with the settings
#   that were previously applied in this file (symbols, counts and colors),
# - a single "git status" process per prompt (the exact same command posh-git runs),
# - no git process at all when the current location is not inside a repository.
# Git tab-completion still comes from posh-git, loaded lazily on the first <Tab>
# on a git command instead of at every shell startup.

$script:GitPromptConfig = @{
  BeforeStatus         = @{ Text = '['; ForegroundColor = [ConsoleColor]::DarkGray }
  AfterStatus          = @{ Text = ']'; ForegroundColor = [ConsoleColor]::DarkGray }
  BranchColor          = [ConsoleColor]::Green
  AheadSymbol          = @{ Text = [char]0x2191; ForegroundColor = [ConsoleColor]::Green }    # ↑
  BehindSymbol         = @{ Text = [char]0x2193; ForegroundColor = [ConsoleColor]::Red }      # ↓
  BehindAndAheadSymbol = @{ Text = [char]0x2195; ForegroundColor = [ConsoleColor]::Yellow }   # ↕
  IdenticalSymbol      = [char]0x2261 # ≡
  GoneSymbol           = [char]0x00D7  # ×
  DelimStatus          = @{ Text = ' |'; ForegroundColor = [ConsoleColor]::Yellow }
  IndexColor           = [ConsoleColor]::DarkGreen
  WorkingColor         = [ConsoleColor]::DarkRed
  LocalWorkingSymbol   = @{ Text = '!'; ForegroundColor = [ConsoleColor]::DarkRed }
  LocalStagedSymbol    = @{ Text = '~'; ForegroundColor = [ConsoleColor]::Cyan }
}

# ConsoleColor → ANSI/VT foreground code (posh-git's own mapping).
$script:AnsiForegroundCodes = @('30', '34', '32', '36', '31', '35', '33', '37', '90', '94', '92', '96', '91', '95', '93', '97')

$script:SupportsVirtualTerminal = $Host.UI.SupportsVirtualTerminal -or ($env:ConEmuANSI -eq 'ON')

$script:GitAvailable = $null
$script:PoshGitCompletionLoaded = $false

function Write-GitSpan {
  # Renders a piece of the prompt with a foreground color, like posh-git's Write-Prompt:
  # ANSI/VT sequences when the host supports virtual terminal, Write-Host otherwise.
  param(
    [string] $Text,
    [ConsoleColor] $ForegroundColor
  )

  if (!$Text) { return '' }

  if ($script:SupportsVirtualTerminal) {
    return "$([char]27)[$($script:AnsiForegroundCodes[[int]$ForegroundColor])m$Text$([char]27)[39m"
  }

  Write-Host -NoNewline -Object $Text -ForegroundColor $ForegroundColor
  return ''
}

function Get-GitPromptDirectory {
  # Walks up from the current location to the nearest .git entry (directory, or file
  # for worktrees and submodules). No git process is spawned.
  if ($env:GIT_DIR) { return $env:GIT_DIR.Trim() }

  $dir = (Get-Location).ProviderPath

  while ($dir) {
    $gitDir = Join-Path $dir '.git'

    if (Test-Path -LiteralPath $gitDir) {
      if (Test-Path -LiteralPath $gitDir -PathType Leaf) {
        $content = Get-Content -LiteralPath $gitDir -TotalCount 1
        if ($content -match '^gitdir: (.+)$') { $gitDir = $Matches[1] }
      }

      return $gitDir
    }

    $parent = Split-Path -Path $dir -Parent
    if ($parent -eq $dir) { return $null }
    $dir = $parent
  }

  return $null
}

function Get-GitPromptStatus {
  # Collects the branch, upstream and change counts from a single
  # "git status --short --branch" process (the exact same command posh-git runs),
  # parsing it with the same rules as posh-git's Get-GitStatus.
  param([string] $GitDir)

  $status = @{
    Branch = ''
    Upstream = ''
    AheadBy = 0
    BehindBy = 0
    UpstreamGone = $false
    IndexAdded = 0
    IndexModified = 0
    IndexDeleted = 0
    IndexUnmerged = 0
    WorkingAdded = 0
    WorkingModified = 0
    WorkingDeleted = 0
    WorkingUnmerged = 0
  }

  $previousEncoding = [Console]::OutputEncoding
  [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
  try {
    $output = git --no-optional-locks -c core.quotepath=false -c color.status=false status -unormal --short --branch 2>$null
  } finally {
    [Console]::OutputEncoding = $previousEncoding
  }

  foreach ($line in @($output)) {
    if (!$line) { continue }

    if ($line -match '^(?<index>[^#])(?<working>.) ') {
      switch ($Matches.index) {
        'A' { $status.IndexAdded++; break }
        'M' { $status.IndexModified++; break }
        'R' { $status.IndexModified++; break }
        'C' { $status.IndexModified++; break }
        'D' { $status.IndexDeleted++; break }
        'U' { $status.IndexUnmerged++; break }
      }

      switch ($Matches.working) {
        '?' { $status.WorkingAdded++; break }
        'A' { $status.WorkingAdded++; break }
        'M' { $status.WorkingModified++; break }
        'D' { $status.WorkingDeleted++; break }
        'U' { $status.WorkingUnmerged++; break }
      }
    }
    elseif ($line -match '^## (?<branch>\S+?)(?:\.\.\.(?<upstream>\S+))?(?: \[(?:ahead (?<ahead>\d+))?(?:, )?(?:behind (?<behind>\d+))?(?<gone>gone)?\])?$') {
      $status.Branch = $Matches.branch
      $status.Upstream = $Matches.upstream
      $status.AheadBy = [int]$Matches.ahead
      $status.BehindBy = [int]$Matches.behind
      $status.UpstreamGone = [string]$Matches.gone -eq 'gone'
    }
    elseif ($line -match '^## No commits yet on (?<branch>\S+)$') {
      $status.Branch = $Matches.branch
    }
  }

  $status.HasIndex = ($status.IndexAdded + $status.IndexModified + $status.IndexDeleted + $status.IndexUnmerged) -gt 0
  $status.HasWorking = ($status.WorkingAdded + $status.WorkingModified + $status.WorkingDeleted + $status.WorkingUnmerged) -gt 0
  $status.BranchName = Get-GitPromptBranchName -Status $status -GitDir $GitDir

  return $status
}

function Get-GitPromptBranchName {
  # Resolves the branch display name, including the ongoing-operation suffixes
  # (|REBASE, |MERGING...) that posh-git appends, and detached HEAD (short sha).
  param([hashtable] $Status, [string] $GitDir)

  $name = ''
  $suffix = ''
  $step = ''
  $total = ''

  if (Test-Path -LiteralPath "$GitDir/rebase-merge") {
    $suffix = (Test-Path -LiteralPath "$GitDir/rebase-merge/interactive") ? '|REBASE-i' : '|REBASE-m'
    $name = Get-Content -LiteralPath "$GitDir/rebase-merge/head-name" -TotalCount 1
    $step = Get-Content -LiteralPath "$GitDir/rebase-merge/msgnum" -TotalCount 1
    $total = Get-Content -LiteralPath "$GitDir/rebase-merge/end" -TotalCount 1
  }
  elseif (Test-Path -LiteralPath "$GitDir/rebase-apply") {
    $step = Get-Content -LiteralPath "$GitDir/rebase-apply/next" -TotalCount 1
    $total = Get-Content -LiteralPath "$GitDir/rebase-apply/last" -TotalCount 1
    $suffix = (Test-Path -LiteralPath "$GitDir/rebase-apply/rebasing") ? '|REBASE'
      : ((Test-Path -LiteralPath "$GitDir/rebase-apply/applying") ? '|AM' : '|AM/REBASE')
  }
  elseif (Test-Path -LiteralPath "$GitDir/MERGE_HEAD") { $suffix = '|MERGING' }
  elseif (Test-Path -LiteralPath "$GitDir/CHERRY_PICK_HEAD") { $suffix = '|CHERRY-PICKING' }
  elseif (Test-Path -LiteralPath "$GitDir/REVERT_HEAD") { $suffix = '|REVERTING' }
  elseif (Test-Path -LiteralPath "$GitDir/BISECT_LOG") { $suffix = '|BISECTING' }

  if ($step -and $total) { $suffix += " $step/$total" }

  if ($name) {
    $branch = $name
  }
  elseif ($Status.Branch) {
    $branch = $Status.Branch
  }
  else {
    # Detached HEAD: posh-git tries symbolic-ref then "git describe"; the default
    # DescribeStyle resolves to the tags pointing at HEAD, then falls back on
    # parsing .git/HEAD (short sha). The result is wrapped in parentheses.
    $branch = git --no-optional-locks tag --points-at HEAD 2>$null

    if (!$branch) {
      $head = Get-Content -LiteralPath "$GitDir/HEAD" -TotalCount 1 -ErrorAction SilentlyContinue
      if ($head -match '^ref: (.+)$') { $branch = $Matches[1] }
      elseif ($head -and $head.Length -ge 7) { $branch = $head.Substring(0, 7) + '...' }
      else { $branch = 'unknown' }
    }

    $branch = "($branch)"
  }

  return "$branch$suffix"
}

function Write-GitPromptStatus {
  # Renders the status exactly like posh-git's Write-VcsStatus with the default
  # $GitPromptSettings and the overrides previously applied in this file.
  param([hashtable] $Status)

  $config = $script:GitPromptConfig

  # posh-git colors the branch name with the ahead/behind symbol colors when diverged.
  $branchColor = $config.BranchColor
  if ($Status.BehindBy -ge 1 -and $Status.AheadBy -ge 1) {
    $branchColor = $config.BehindAndAheadSymbol.ForegroundColor
  }
  elseif ($Status.BehindBy -ge 1) {
    $branchColor = $config.BehindSymbol.ForegroundColor
  }
  elseif ($Status.AheadBy -ge 1) {
    $branchColor = $config.AheadSymbol.ForegroundColor
  }

  $prompt = ' '
  $prompt += Write-GitSpan -Text $config.BeforeStatus.Text -ForegroundColor $config.BeforeStatus.ForegroundColor
  $prompt += Write-GitSpan -Text $Status.BranchName -ForegroundColor $branchColor

  $branchStatusText = ''
  if (!$Status.Upstream) {
    # No upstream: posh-git displays nothing (BranchUntrackedText is empty by default).
  }
  elseif ($Status.UpstreamGone) {
    $branchStatusText = $config.GoneSymbol
  }
  elseif ($Status.AheadBy -eq 0 -and $Status.BehindBy -eq 0) {
    $branchStatusText = $config.IdenticalSymbol
  }
  elseif ($Status.BehindBy -ge 1 -and $Status.AheadBy -ge 1) {
    $branchStatusText = "$($config.BehindSymbol.Text)$($Status.BehindBy) $($config.AheadSymbol.Text)$($Status.AheadBy)"
  }
  elseif ($Status.BehindBy -ge 1) {
    $branchStatusText = "$($config.BehindSymbol.Text)$($Status.BehindBy)"
  }
  elseif ($Status.AheadBy -ge 1) {
    $branchStatusText = "$($config.AheadSymbol.Text)$($Status.AheadBy)"
  }

  if ($branchStatusText) {
    $prompt += Write-GitSpan -Text " $branchStatusText" -ForegroundColor $branchColor
  }

  if ($Status.HasIndex) {
    $prompt += Write-GitSpan -Text " +$($Status.IndexAdded)" -ForegroundColor $config.IndexColor
    $prompt += Write-GitSpan -Text " ~$($Status.IndexModified)" -ForegroundColor $config.IndexColor
    $prompt += Write-GitSpan -Text " -$($Status.IndexDeleted)" -ForegroundColor $config.IndexColor
    if ($Status.IndexUnmerged) {
      $prompt += Write-GitSpan -Text " !$($Status.IndexUnmerged)" -ForegroundColor $config.IndexColor
    }

    if ($Status.HasWorking) {
      $prompt += Write-GitSpan -Text $config.DelimStatus.Text -ForegroundColor $config.DelimStatus.ForegroundColor
    }
  }

  if ($Status.HasWorking) {
    $prompt += Write-GitSpan -Text " +$($Status.WorkingAdded)" -ForegroundColor $config.WorkingColor
    $prompt += Write-GitSpan -Text " ~$($Status.WorkingModified)" -ForegroundColor $config.WorkingColor
    $prompt += Write-GitSpan -Text " -$($Status.WorkingDeleted)" -ForegroundColor $config.WorkingColor
    if ($Status.WorkingUnmerged) {
      $prompt += Write-GitSpan -Text " !$($Status.WorkingUnmerged)" -ForegroundColor $config.WorkingColor
    }
  }

  if ($Status.HasWorking) {
    $prompt += Write-GitSpan -Text " $($config.LocalWorkingSymbol.Text)" -ForegroundColor $config.LocalWorkingSymbol.ForegroundColor
  }
  elseif ($Status.HasIndex) {
    $prompt += Write-GitSpan -Text " $($config.LocalStagedSymbol.Text)" -ForegroundColor $config.LocalStagedSymbol.ForegroundColor
  }

  $prompt += Write-GitSpan -Text $config.AfterStatus.Text -ForegroundColor $config.AfterStatus.ForegroundColor

  return $prompt
}

function global:prompt {
  if (!$script:GitAvailable) {
    $script:GitAvailable = [bool](Get-Command git -ErrorAction SilentlyContinue)
  }

  $path = (Get-Location).Path
  $arrow = Write-GitSpan -Text ' > ' -ForegroundColor ([ConsoleColor]::White)

  # Not in a repository: no git process is spawned.
  $gitDir = $script:GitAvailable ? (Get-GitPromptDirectory) : $null
  if (!$gitDir) {
    return "$path$arrow"
  }

  $gitStatus = Get-GitPromptStatus -GitDir $gitDir
  $repoName = Split-Path -Path (Split-Path -Path $gitDir -Parent) -Leaf

  $repoRelativePath = Write-GitSpan -Text ($path -replace ".*?($repoName.*)", '$1') -ForegroundColor ([ConsoleColor]::White)

  return "$repoRelativePath$(Write-GitPromptStatus $gitStatus)$arrow"
}

# Git tab-completion (subcommands, branches, remotes...): posh-git is imported on the
# first <Tab> on a git command. The stub returns nothing so the completer registered by
# posh-git (also -Native) provides the completions without duplicates.
Register-ArgumentCompleter -CommandName git -Native -ScriptBlock {
  param($WordToComplete, $CommandAst, $CursorPosition)

  if (!$script:PoshGitCompletionLoaded) {
    $script:PoshGitCompletionLoaded = $true
    Save-Module posh-git
  }
}
