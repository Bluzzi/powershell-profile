$profileDirectory = [System.IO.Path]::GetDirectoryName($PROFILE)
$envFilePath = Join-Path -Path $profileDirectory -ChildPath ".env"

if (Test-Path $envFilePath) {
  $envLines = [System.IO.File]::ReadAllLines($envFilePath)

  foreach ($line in $envLines) {
    # Split on the first '=' only, so values containing '=' are preserved.
    $name, $value = $line.Split('=', 2)

    if ([string]::IsNullOrWhiteSpace($name) || $name.Contains('#')) {
      continue
    }

    [System.Environment]::SetEnvironmentVariable($name, $value)
  }
}