Invoke-Expression (& {
  # $hook = if ($PSVersionTable.PSVersion.Major -lt 6) { 'prompt' } else { 'pwd' }
  
  # (zoxide init --hook $hook powershell | Out-String)

  Invoke-Expression (& { (zoxide init powershell | Out-String) })
})