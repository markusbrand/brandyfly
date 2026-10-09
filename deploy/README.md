# Deploying the Backend to the Home Server

The backend runs on the **Bosgame home server** (Ubuntu Server, x86_64, `192.168.0.152`).
It previously ran on a Raspberry Pi (`192.168.0.150`); the published image is multi-arch
(`linux/amd64` + `linux/arm64`), so it still runs on a Pi if needed.

The CI/CD pipeline builds the Docker image on every push to `main` and pushes it to `ghcr.io`.
A self-hosted GitHub Actions runner on the server then pulls the image and restarts the service.

## Architecture

```
GitHub push to main
       │
       ▼
build-and-push job (ubuntu-latest)
  → builds linux/amd64 + linux/arm64 image (cross-compiled, no QEMU)
  → pushes ghcr.io/markusbrand/brandyfly-backend:latest
       │
       ▼
deploy job (self-hosted runner, labels: self-hosted, Linux, X64)
  → docker compose pull
  → docker compose up -d --remove-orphans
```

Public access goes through the Cloudflare tunnel (`cloudflared` container on the server):
`https://brandyfly.brandstaetter.rocks` → `http://192.168.0.152:8090`.

## One-Time Server Setup (Ubuntu Server)

### 1 — Install Docker

```bash
sudo apt-get update
sudo apt-get install -y docker.io docker-compose-v2
sudo usermod -aG docker $USER
newgrp docker
```

Verify:
```bash
docker run --rm hello-world
docker compose version
```

### 2 — Authenticate with ghcr.io

Create a [GitHub Personal Access Token](https://github.com/settings/tokens) with the `read:packages`
scope, then log in:

```bash
echo "<YOUR_PAT>" | docker login ghcr.io -u markusbrand --password-stdin
```

### 3 — Install the GitHub Actions Self-Hosted Runner

Download the latest **Linux x64** runner from
**Settings → Actions → Runners → New self-hosted runner** on the GitHub repository page and follow
the shown commands (e.g. into `~/actions-runner-brandyfly`, runner name `bosgame-brandyfly`).
The default labels `self-hosted`, `Linux`, `X64` are what the `deploy` job targets — no custom
label is required.

Install and start as a systemd service so it survives reboots:

```bash
cd ~/actions-runner-brandyfly
sudo ./svc.sh install
sudo ./svc.sh start
```

Check its status:
```bash
sudo ./svc.sh status
```

> Only one online runner for this repository may carry the `self-hosted, Linux, X64` labels,
> otherwise deploys could land on another machine.

### 4 — Create the Environment File

```bash
mkdir -p ~/brandyfly/deploy
cp deploy/.env.example ~/brandyfly/deploy/.env
# Edit BRANDYFLY_HOST_PORT if 8090 is not available on the server
```

The deploy job copies `~/brandyfly/deploy/.env` into its checkout before starting the service.

### 5 — First Start

From a checkout of this repository on the server:

```bash
docker compose -f deploy/compose.yaml --env-file ~/brandyfly/deploy/.env up -d
```

Later deployments are done automatically by the `deploy` job. The compose project name is
`deploy` in both cases, so the job replaces the manually started container.

## Configuration

| Variable | Default | Description |
|---|---|---|
| `BRANDYFLY_HOST_PORT` | `8090` | Port exposed on the server host |
| `BRANDYFLY_LISTEN_ADDRESS` | `:8080` | Listen address inside the container |

Edit `~/brandyfly/deploy/.env` on the server to change these values, then redeploy (re-run the
`deploy` job or start compose manually as in step 5).

## Verifying the Deployment

On the server:
```bash
curl http://localhost:8090/healthz
# → {"status":"ok"}
docker image inspect ghcr.io/markusbrand/brandyfly-backend:latest --format '{{.Architecture}}'
# → amd64
```

From the local network:
```bash
curl http://192.168.0.152:8090/healthz
```

Via the Cloudflare tunnel:
```bash
curl https://brandyfly.brandstaetter.rocks/healthz
```

## Migrating to Another Server

1. Complete the one-time setup above on the new machine.
2. If the new machine has a different CPU architecture or OS, adjust the `deploy` job's
   `runs-on` labels in `.github/workflows/ci.yml` (and the image `platforms` if needed).
3. Point the Cloudflare tunnel public hostname to the new server's IP and port.
4. Remove the old runner under **Settings → Actions → Runners**.
