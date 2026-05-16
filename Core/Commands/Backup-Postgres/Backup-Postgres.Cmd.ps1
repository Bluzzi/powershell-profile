function Backup-Postgres {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Name
  )

  # Get or create the backup directory:
  $profileDirectory = [System.IO.Path]::GetDirectoryName($PROFILE)
  $backupDirectory = Join-Path $profileDirectory "PostgresBackups"
  if (-not (Test-Path $backupDirectory)) {
    New-Item -ItemType Directory -Path $backupDirectory | Out-Null
  }

  # Generate filename for the backup:
  $date = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
  $file = "$Name`_$date.dump"

  # Run `pg_dump` with Docker:
  docker run --rm `
    -v "${backupDirectory}:/backups" `
    postgres:latest `
    pg_dump `
      --format=custom `
      --verbose `
      --no-owner `
      --no-privileges `
      --file="/backups/$file" `
      $env:POSTGRESQL_TO_BACKUP_URL
}