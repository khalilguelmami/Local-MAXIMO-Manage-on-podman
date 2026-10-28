# Maximo Manage on Podman: a local developer sandbox

Run IBM Maximo Manage in a single Podman container on your laptop (Windows or Linux), to write and debug customizations without waiting for OpenShift builds and rollouts.

> **What this is:** a personal development sandbox for **Manage**, built from the Manage images that your MAS cluster already produced.
>
> **What this is not:** a way to run MAS without OpenShift. You still need a MAS environment (and a valid entitlement) to get the images. Other MAS applications (Monitor, Health, Predict…) are deployed by operators on MAS core and are not covered. Not a supported deployment model, not for production.

## How it works

1. **Pull** the Manage `-admin` and `-all` images from the OpenShift internal registry of your MAS cluster.
2. **Rebuild** the Maximo EAR from the `-admin` image with the development deployment descriptors (`web-dev.xml`), so Manage uses its own native login instead of OIDC through MAS core.
3. **Build** a runtime image from the `-all` server bundle: expanded EAR (classes and JSPs can be replaced in place), development `server.xml`, `MXE_MASDEPLOYED=0`, Liberty started in **debug mode**.
4. **Run** it against a SQL Server database reachable from the Podman VM.

## Prerequisites

- Access to a MAS cluster with Manage deployed, and `oc` logged in to it
- Podman installed and running (on Windows: `podman machine start`)
- PowerShell
- A SQL Server database restored from a backup of your development environment, **from the same Manage version as the images**
- The Maximo crypto keys of the environment the database comes from

Give the Podman machine enough memory for Manage (for example `podman machine set --memory 12288`). The first start takes several minutes.

## Quick start

```powershell
podman machine start
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

# 1. Local settings: database credentials and crypto keys
Copy-Item manage-dev.env.example manage-dev.env
notepad manage-dev.env

# 2. Pull the images, build the local image and start it (first time)
.\install-and-deploy-manage.ps1 `
  -RegistryRoute default-route-openshift-image-registry.apps.<cluster-domain> `
  -MasInstance <mas-instance-id> `
  -Workspace <manage-workspace-id>

# 3. Next times: just restart the container
.\start-manage-dev.ps1
```

Then open **http://localhost:9080/maximo** and log in with a native Maximo user from your database.

| Port | Use |
|---|---|
| 9080 | HTTP |
| 9443 | HTTPS |
| 7777 | Liberty remote debug (attach your IDE) |

## Configuration (`manage-dev.env`)

| Variable | Description |
|---|---|
| `MXE_DB_NAME`, `MXE_DB_PORT` | SQL Server database name and port |
| `MXE_DB_USER`, `MXE_DB_PASSWORD` | Database credentials |
| `MXE_SECURITY_CRYPTO_KEY`, `MXE_SECURITY_CRYPTOX_KEY` (and `OLD_` variants) | Crypto keys of the source environment |

`manage-dev.env` is in `.gitignore`. **Never commit credentials or crypto keys.**

The JDBC URL is built automatically with the host IPv4 address, because inside the Podman VM `localhost` is not your host.

## Useful commands

```powershell
podman ps -a                          # container status
podman logs -f manage-dev-container   # live logs
podman exec -it manage-dev-container bash
```

## Troubleshooting

- **Encrypted values do not decrypt / login fails:** the crypto keys do not match the database.
- **Database connection refused:** check the SQL Server port is reachable from the Podman VM (firewall, TCP enabled) and the IP shown by the script.
- **Image or class errors after a MAS update:** rebuild the local image and refresh the database backup together, they must stay on the same Manage version.
- **Pull fails with a certificate error:** the scripts use `--tls-verify=false` by default for lab clusters with a self-signed registry route. On a real cluster, trust the registry CA and use `-TlsVerify`.

> ⚠️ `podman system prune -a` removes **all** unused images, including `manage-admin-dev` and `manage-all-dev`. You would have to pull them from the cluster again.

## Tested with

MAS 9.x Manage images on Windows 11 with Podman (Linux VM) and SQL Server.

## More

Background, design choices and the traps I hit: [Running Maximo Manage locally with Podman](https://community.ibm.com/community/user/discussion/running-maximo-manage-locally-with-podman-a-developer-sandbox-without-the-openshift-wait) on IBM TechXchange.

Feedback and pull requests are welcome.
