# start-manage-dev.ps1

# 1) Détecter l'IPv4 locale (hors 127.0.0.1 et 169.254.*)
$ip = (Get-NetIPAddress -AddressFamily IPv4 `
        | Where-Object { $_.IPAddress -ne '127.0.0.1' -and $_.IPAddress -notlike '169.254.*' } `
        | Sort-Object -Property InterfaceMetric, SkipAsSource `
        | Select-Object -First 1 -ExpandProperty IPAddress)

if (-not $ip) { Write-Error "Impossible de détecter une IPv4 locale"; exit 1 }

# 2) Construire l’URL JDBC proprement (utiliser ${ip} ou une variable séparée)
$dbUrl = "jdbc:sqlserver://${ip}:1433;databaseName=MAXDB90;sendStringParametersAsUnicode=false;selectMethod=cursor;encrypt=true;trustServerCertificate=true;loginTimeout=30"

Write-Host "[INFO] IPv4 détectée : $ip"
Write-Host "[INFO] URL JDBC     : $dbUrl"

# 3) Nettoyer l'ancien conteneur
podman rm -f manage-dev-container 2>$null | Out-Null

# 4) Démarrer le conteneur (note: --env "NAME=VALUE")
podman run -d --name manage-dev-container `
  --workdir / `
  -p 7777:7777 `
  -p 9080:9080 `
  -p 9443:9443 `
  --env "MXE_DB_VENDOR=mssql" `
  --env "MXE_DB_DRIVER=com.microsoft.sqlserver.jdbc.SQLServerDriver" `
  --env "MXE_DB_URL=$dbUrl" `
  --env "MXE_DB_USER=maximo" `
  --env "MXE_DB_PASSWORD=P@ssword123" `
  localhost/manage-dev:latest

# 5) Vérifier ce que voit le conteneur
Write-Host "`n[INFO] MXE_DB_URL vu par le conteneur :"
podman exec -it manage-dev-container printenv MXE_DB_URL
