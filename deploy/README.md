# Deploying the Backend to the Raspberry Pi

The CI/CD pipeline builds a Docker image for `linux/arm64` on every push to `main` and pushes
it to `ghcr.io`. A self-hosted GitHub Actions runner on the Pi then pulls the image and restarts
the service automatically.

## Architecture

```
GitHub push to main
       │
       ▼
build-and-push job (ubuntu-latest)
  → builds linux/arm64 image
  → pushes ghcr.io/markusbrand/brandyfly-backend:latest
       │
       ▼
deploy job (self-hosted runner on Pi)
  → docker compose pull
  → docker compose up -d --remove-orphans
```

## One-Time Pi Setup

### 1 — Install Docker

```bash
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
newgrp docker
```

Verify:
```bash
docker run --rm hello-world
```

### 2 — Authenticate with ghcr.io

Create a [GitHub Personal Access Token](https://github.com/settings/tokens) with the `read:packages`
scope, then log in:

```bash
echo "<YOUR_PAT>" | docker login ghcr.io -u markusbrand --password-stdin
```

### 3 — Install the GitHub Actions Self-Hosted Runner

Download the latest runner from
**Settings → Actions → Runners → New self-hosted runner** on the GitHub repository page and follow
the shown commands. When prompted for labels, add `raspberry-pi` (in addition to the default `self-hosted`).

Install and start as a systemd service so it survives reboots:

```bash
cd ~/actions-runner
sudo ./svc.sh install
sudo ./svc.sh start
```

Check its status:
```bash
sudo ./svc.sh status
```

### 4 — Create the Environment File

```bash
mkdir -p ~/brandyfly/deploy
cp deploy/.env.example ~/brandyfly/deploy/.env
# Edit BRANDYFLY_HOST_PORT if 8090 is not available on your Pi
```

Port 8090 was chosen because it was verified free on the Pi. Change `BRANDYFLY_HOST_PORT` in
`~/brandyfly/deploy/.env` if you need a different port.

### 5 — First Start

```bash
cd ~/brandyfly
cp deploy/compose.yaml deploy/compose.yaml  # the runner checks out the repo automatically later
docker compose -f deploy/compose.yaml up -d
```

## Configuration

| Variable | Default | Description |
|---|---|---|
| `BRANDYFLY_HOST_PORT` | `8090` | Port exposed on the Pi host |
| `BRANDYFLY_LISTEN_ADDRESS` | `:8080` | Listen address inside the container |

Edit `~/brandyfly/deploy/.env` on the Pi to change these values, then restart with
`docker compose -f deploy/compose.yaml up -d`.

## Verifying the Deployment

From the Pi:
```bash
curl http://localhost:8090/healthz
# → {"status":"ok"}
```

From the local network:
```bash
curl http://192.168.0.150:8090/healthz
```

Via Cloudflare tunnel (if configured to forward to `:8090`):
```bash
curl https://<your-tunnel-host>/healthz
```
