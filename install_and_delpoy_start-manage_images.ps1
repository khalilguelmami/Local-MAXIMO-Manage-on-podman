# --- settings ---
$NS    = "mas-masdemo-manage"
$ROUTE = "default-route-openshift-image-registry.apps.sno-mas9.sinorfi.com"
 
# ensure login to the same host we'll pull from
$TOKEN = oc whoami -t
podman login --tls-verify=false -u kubeadmin -p $TOKEN $ROUTE | Out-Null
 
# 1) Get images from the "maxinst" pod (usually has the -admin image with digest)
$PODNAME = (oc get pods -n $NS -o jsonpath="{range .items[*]}{.metadata.name}{' '}{end}" | `
  Select-String -Pattern "maxinst").ToString().Split()[0]
$POD_IMAGES = oc get pod $PODNAME -n $NS -o jsonpath="{.spec.containers[*].image}"
 
# 2) Get images from deployments (to discover the -all bundle)
$DEPLOY_IMAGES = oc get deploy -n $NS -o jsonpath="{range .items[*]}{.spec.template.spec.containers[*].image}{' '}{end}"
 
# 3) Keep only internal-registry Manage app images (-admin / -all)
$all = @($POD_IMAGES, $DEPLOY_IMAGES) -join " "
$wanted = ($all -split "\s+") |
  Where-Object {
    $_ -match '^image-registry\.openshift-image-registry\.svc:5000/' `
    -and ($_ -match '/mas-masdemo-manage/masdemo-masdev-(admin|all)@sha256:')
  } | Select-Object -Unique
 
"=== Manage images found in cluster ==="
$wanted | ForEach-Object { $_ }
 
if ($wanted.Count -eq 0) { throw "No manage -admin/-all images found in $NS. Check the namespace or deployment names." }
 
# 4) Pull each via the ROUTE host (swap service host -> route)
foreach ($img in $wanted) {
  $imgRoute = $img -replace '^image-registry\.openshift-image-registry\.svc:5000', $ROUTE
  Write-Host "Pulling $imgRoute"
  podman pull --tls-verify=false $imgRoute
 
  if ($imgRoute -match '-admin(@|:)') { podman tag $imgRoute manage-admin-dev }
  if ($imgRoute -match '-all(@|:)')   { podman tag $imgRoute manage-all-dev   }
}
 
"=== Local images ==="
podman images

# Build the local image tagged 'manage-dev'
podman build -t manage-dev .

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


# Run the container with required options
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

Write-Host "`n[INFO] MXE_DB_URL vu par le conteneur :"
podman exec -it manage-dev-container printenv MXE_DB_URL