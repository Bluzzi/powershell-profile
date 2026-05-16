function Restore-Postgres {
  param(
    # Docker tag of PostgreSQL:
    [string]$PostgresVersion = "latest"
  )

  # Get or create the backup directory:
  $profileDirectory = [System.IO.Path]::GetDirectoryName($PROFILE)
  $backupDirectory = Join-Path $profileDirectory "PostgresBackups"
  if (-not (Test-Path $backupDirectory)) {
    New-Item -ItemType Directory -Path $backupDirectory | Out-Null
  }

  # Select the backup file from backup directory:
  $files = Get-ChildItem -Path $backupDirectory -Filter "*.dump"

  if ($files.Count -eq 0) {
    throw "No backup files found"
  }

  Write-Host "Available backups:"
  for ($i = 0; $i -lt $files.Count; $i++) {
    Write-Host "[$i] $($files[$i].Name)"
  }

  $choice = Read-Host "Select backup index"
  $file = $files[$choice].Name

  # Check if the file exists:
  $filePath = Join-Path $backupDirectory $file
  if (-not (Test-Path $filePath)) {
    throw "Backup file not found: $filePath"
  }

  # Run `pg_restore` with Docker:
  docker run --rm `
    -v "${backupDirectory}:/backups" `
    "postgres:$PostgresVersion" `
    pg_restore `
      --verbose `
      --clean `
      --if-exists `
      --no-owner `
      --no-privileges `
      --dbname=$env:POSTGRESQL_TO_RESTORE_URL `
      "/backups/$file"
}