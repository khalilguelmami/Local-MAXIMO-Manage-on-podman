# install-and-deploy-manage.ps1
# Pulls the Manage -admin and -all images from your MAS cluster, builds the
# local manage-dev image, then starts it with start-manage-dev.ps1.
#
# Prerequisites: oc logged in to the MAS cluster, Podman running.
#
# Example:
#   .\install-and-deploy-manage.ps1 -RegistryRoute default-route-openshift-image-registry.apps.<cluster-domain> `
#                                   -MasInstance masdemo -Workspace masdev

param(
  [Parameter(Mandatory = $true)]
  [string]$RegistryRoute,            # external route of the OpenShift internal image registry
  [Parameter(Mandatory = $true)]
  [string]$MasInstance,              # MAS instance ID, e.g. masdemo
  [Parameter(Mandatory = $true)]
  [string]$Workspace,                # Manage workspace ID, e.g. masdev
  [string]$RegistryUser = "kubeadmin",
  [switch]$TlsVerify                 # use it if your registry certificate is trusted
)

$NS = "mas-$MasInstance-manage"
$tls = if ($TlsVerify) { "--tls-verify=true" } else { "--tls-verify=false" }

# Log in to the registry with the current oc token
$TOKEN = oc whoami -t
if (-not $TOKEN) { throw "No oc token. Run 'oc login' first." }
podman login $tls -u $RegistryUser -p $TOKEN $RegistryRoute | Out-Null

# 1) Images used by the maxinst pod (it usually carries the -admin image digest)
$PODNAME = (oc get pods -n $NS -o jsonpath="{range .items[*]}{.metadata.name}{' '}{end}" | `
  Select-String -Pattern "maxinst").ToString().Split()[0]
$POD_IMAGES = oc get pod $PODNAME -n $NS -o jsonpath="{.spec.containers[*].image}"

# 2) Images used by the deployments (to find the -all bundle)
$DEPLOY_IMAGES = oc get deploy -n $NS -o jsonpath="{range .items[*]}{.spec.template.spec.containers[*].image}{' '}{end}"

# 3) Keep only the internal-registry Manage images (-admin / -all)
$all = @($POD_IMAGES, $DEPLOY_IMAGES) -join " "
$pattern = "/$NS/$MasInstance-$Workspace-(admin|all)@sha256:"
$wanted = ($all -split "\s+") |
  Where-Object {
    $_ -match '^image-registry\.openshift-image-registry\.svc:5000/' -and $_ -match $pattern
  } | Select-Object -Unique

"=== Manage images found in the cluster ==="
$wanted | ForEach-Object { $_ }

if ($wanted.Count -eq 0) { throw "No Manage -admin/-all images found in $NS. Check the instance and workspace IDs." }

# 4) Pull each image through the external route and tag it locally
foreach ($img in $wanted) {
  $imgRoute = $img -replace '^image-registry\.openshift-image-registry\.svc:5000', $RegistryRoute
  Write-Host "Pulling $imgRoute"
  podman pull $tls $imgRoute

  if ($imgRoute -match '-admin(@|:)') { podman tag $imgRoute manage-admin-dev }
  if ($imgRoute -match '-all(@|:)')   { podman tag $imgRoute manage-all-dev   }
}

"=== Local images ==="
podman images

# 5) Build the local image
podman build -t manage-dev $PSScriptRoot

# 6) Start the container
& (Join-Path $PSScriptRoot "start-manage-dev.ps1")
