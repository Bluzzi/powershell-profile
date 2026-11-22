function Open-Pelico {
  param (
    [Parameter(Mandatory = $True)]
    [ValidateSet('App', 'Ibis', 'Flamingo', 'Shoebill')]
    [string] $Target
  )

  switch ($Target) {
    'App' {
      $URL = "$env:PELICO_URL/ui"
    }

    'Ibis' {
      $URL = "$env:PELICO_URL/ibis/api/playground"
    }

    'Flamingo' {
      $URL = "$env:PELICO_URL/flamingo/api/graphql"
    }

    'Shoebill' {
      $URL = "$env:PELICO_URL/shoebill/api/graphql/graphql"
    }

    Default {
      Write-Host "Website does not exist."
      return
    }
  }

  Start-Process $URL
}

