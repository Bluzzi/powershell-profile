<#
  .SYNOPSIS
  Securely resets a USB disk using DiskPart.

  .DESCRIPTION
  This function wipes and reinitializes a USB disk. It supports two modes:
  - Fast mode: runs 'clean' to remove partition table only.
  - Full mode: runs 'clean all' to overwrite all sectors.

  The function can prompt the user for disk, label, and mode, or accept them as parameters.

  .PARAMETER DiskNumber
  Optional. Specifies the disk number to reset. If omitted, the user is prompted.

  .PARAMETER Label
  Optional. Specifies the volume label for the USB drive. Defaults to 'USB' if left empty.

  .PARAMETER Mode
  Optional. Chooses the reset method: 'Fast' or 'Full'. If omitted, the user is prompted.

  .EXAMPLE
  Reset-UsbDisk

  Prompts the user for all inputs.

  .EXAMPLE
  Reset-UsbDisk -DiskNumber 3 -Label "MYDRIVE" -Mode Full

  Performs a full wipe on disk 3.
#>
function Reset-UsbDisk {
  [CmdletBinding()]
  param(
    [Parameter(Position=0)]
    [int]$DiskNumber,

    [Parameter(Position=1)]
    [string]$Label,

    [Parameter(Position=2)]
    [ValidateSet("Fast", "Full", IgnoreCase = $true)]
    [string]$Mode
  )

  Write-Host "=============================================="
  Write-Host "USB Disk Reset Utility"
  Write-Host "==============================================`n"

  # Display disk list
  $diskList = Get-Disk | Select-Object Number, FriendlyName, Size, BusType
  $diskList | Format-Table -AutoSize

  # Prompt for disk number if not provided
  if (-not $PSBoundParameters.ContainsKey('DiskNumber')) {
    $DiskNumber = Read-Host "`nEnter the disk number to reset"
  }

  # Prompt for mode if not provided
  if (-not $PSBoundParameters.ContainsKey('Mode')) {
    Write-Host "`nSelect reset mode:" -ForegroundColor Cyan
    Write-Host "  Fast  - Removes partition table only (DiskPart 'clean')."
    Write-Host "  Full  - Overwrites ALL sectors (DiskPart 'clean all'). Slower but safer."`n

    $Mode = Read-Host "Choose mode (Fast/Full)"
  }

  # Prompt for label if not provided
  if (-not $PSBoundParameters.ContainsKey('Label')) {
    $Label = Read-Host "Enter volume label (default: USB)"
    if ([string]::IsNullOrWhiteSpace($Label)) { $Label = "USB" }
  }

  # Confirm
  Write-Host "`n*** WARNING ***" -ForegroundColor Yellow

  if ($Mode -eq "Full") {
    Write-Host "You selected FULL WIPE (clean all). This overwrites ALL sectors and can take a long time." -ForegroundColor Red
  } else {
    Write-Host "You selected FAST WIPE (clean). This removes partitions but does not overwrite data." -ForegroundColor Yellow
  }

  Write-Host "The ENTIRE contents of disk $DiskNumber will be erased." -ForegroundColor Yellow
  Read-Host "Press ENTER to confirm or CTRL+C to cancel"

  # Build DiskPart script
  $cleanCommand = if ($Mode -eq 'Full') { 'clean all' } else { 'clean' }

  $diskpartScript = @"
select disk $DiskNumber
attributes disk clear readonly
$cleanCommand
convert mbr
create partition primary
format fs=fat32 quick label="$Label"
assign
exit
"@

  # Execute DiskPart
  $diskpartScript | diskpart.exe

  Write-Host "`n=============================================="
  Write-Host "DONE! USB disk reset completed using mode: $Mode"
  Write-Host "Label applied: '$Label'"
  Write-Host "=============================================="
}
