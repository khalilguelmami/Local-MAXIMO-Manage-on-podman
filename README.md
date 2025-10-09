# Maximo Manage Deployment on Podman (No OpenShift)

This project provides scripts and guidance to deploy IBM Maximo Manage locally with Podman, using PowerShell—without needing OpenShift.

## Prerequisites

- IBM Maximo Manage images and entitlement.
- Podman installed and operational on Windows or Linux.
- PowerShell environment (Windows or via WSL/Terminal).

## Quick Start Guide

### 1. Environment Setup

```sh
podman machine start
```
Starts the Podman virtual machine environment for running Linux containers on non-Linux systems.

### 2. PowerShell Initialization

Open PowerShell in your project directory then run:

```sh
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```
Allows running scripts for this session without permanent changes to security policy.

### 3. Deploy Maximo Manage

Execute the provided deployment script:

```sh
.\install_and_delpoy_start-manage_images.ps1
```
This script pulls required images and starts Maximo Manage in Podman containers.

## Useful Podman Commands

- **Start Podman machine:**  
  `podman machine start`  

- **List all containers (including stopped):**  
  `podman ps -a`  

- **Purge unused containers, images, and networks:**  
  `podman system prune -a`  

- **View container logs (live):**  
  `podman logs -f manage-dev-container`  

## Troubleshooting

- Ensure Podman is running (`podman machine start`).
- Check image availability before deploying.
- Verify execution policy if script fails to start.
- Use `podman ps -a` to confirm container status.
- Stream container logs for error review (`podman logs -f <container-name>`).

## References

- IBM Docs: Podman setup and troubleshooting
- Example containerized Maximo environments

