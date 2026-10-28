# start-manage-dev.ps1
# (Re)starts the local Manage container from the manage-dev image.
# Settings (database, crypto keys) are read from manage-dev.env.

param(
  [string]$EnvFile = (Join-Path $PSScriptRoot "manage-dev.env"),
  [string]$ContainerName = "manage-dev-container"
)

if (-not (Test-Path $EnvFile)) {
  Write-Error "Missing $EnvFile. Copy manage-dev.env.example to manage-dev.env and fill in your values."
  exit 1
}

# Read KEY=VALUE pairs (comments and empty lines ignored)
$cfg = @{}
Get-Content $EnvFile | Where-Object { $_ -match '^\s*[^#\s][^=]*=' } | ForEach-Object {
  $k, $v = $_ -split '=', 2
  $cfg[$k.Trim()] = $v.Trim()
}
$dbName = if ($cfg.MXE_DB_NAME) { $cfg.MXE_DB_NAME } else { "MAXDB90" }
$dbPort = if ($cfg.MXE_DB_PORT) { $cfg.MXE_DB_PORT } else { "1433" }

# 1) Detect the host IPv4 address (excluding 127.0.0.1 and 169.254.*).
#    The container runs in the Podman VM, so "localhost" would not reach the host database.
$ip = (Get-NetIPAddress -AddressFamily IPv4 `
        | Where-Object { $_.IPAddress -ne '127.0.0.1' -and $_.IPAddress -notlike '169.254.*' } `
        | Sort-Object -Property InterfaceMetric, SkipAsSource `
        | Select-Object -First 1 -ExpandProperty IPAddress)

if (-not $ip) { Write-Error "Could not detect a local IPv4 address"; exit 1 }

# 2) Build the JDBC URL
$dbUrl = "jdbc:sqlserver://${ip}:${dbPort};databaseName=${dbName};sendStringParametersAsUnicode=false;selectMethod=cursor;encrypt=true;trustServerCertificate=true;loginTimeout=30"

Write-Host "[INFO] Host IPv4 : $ip"
Write-Host "[INFO] JDBC URL  : $dbUrl"

# 3) Remove the previous container
podman rm -f $ContainerName 2>$null | Out-Null

# 4) Start the container
#    9080 = HTTP, 9443 = HTTPS, 7777 = Liberty remote debug
podman run -d --name $ContainerName `
  --workdir / `
  -p 7777:7777 `
  -p 9080:9080 `
  -p 9443:9443 `
  --env-file $EnvFile `
  --env "MXE_DB_VENDOR=mssql" `
  --env "MXE_DB_URL=$dbUrl" `
  localhost/manage-dev:latest

# 5) Check what the container sees
Write-Host "`n[INFO] MXE_DB_URL inside the container:"
podman exec $ContainerName printenv MXE_DB_URL

Write-Host "`n[INFO] Follow the logs with: podman logs -f $ContainerName"
Write-Host "[INFO] Then open http://localhost:9080/maximo"
