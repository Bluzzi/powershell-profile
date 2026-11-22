<#
  .SYNOPSIS
  Install and import the module if it is not installed, or import it directly if it is already installed.
#>
function Save-Module {
  param (
    [Parameter(Mandatory = $True)]
    [string] $ModuleName
  )

  # Fast path: import directly. Get-Module -ListAvailable would scan every directory
  # in $env:PSModulePath, which is noticeable at shell startup.
  Import-Module -Name $ModuleName -ErrorAction SilentlyContinue

  if (!(Get-Module -Name $ModuleName -ErrorAction SilentlyContinue)) {
    Install-Module -Name $ModuleName -Force
    Import-Module -Name $ModuleName
  }
}