# Litefinga Cloud Worker — public releases

**Public** download repo for `litefinga-worker` binaries. Source code stays in the private `litefinga-worker` repository; this repo only hosts **release archives** and **manifests** for auto-update.

## Download

Open [Releases](https://github.com/escltd/litefinga-worker-releases/releases) and pick your platform:

| Platform | Update archive | Binary inside archive |
|----------|----------------|------------------------|
| Linux x64 | `litefinga-worker-{version}-linux-amd64.tar.gz` | `litefinga-worker` |
| macOS Apple Silicon | `…-darwin-arm64.tar.gz` | `litefinga-worker` |
| macOS Intel | `…-darwin-amd64.tar.gz` | `litefinga-worker` |
| Windows x64 | `…-windows-amd64.zip` | `litefinga-worker.exe` |

Install manually (Linux example):

```bash
curl -L -o worker.tar.gz "https://github.com/escltd/litefinga-worker-releases/releases/download/v0.1.0/litefinga-worker-v0.1.0-linux-amd64.tar.gz"
tar -xzf worker.tar.gz
sudo install -m755 litefinga-worker /usr/local/bin/litefinga-worker
```

## Auto-update

Workers poll [`manifest.json`](manifest.json) (stable) or [`manifest-prerelease.json`](manifest-prerelease.json) when built with `LITEFINGA_RELEASE_CHANNEL=prerelease`.

Each manifest entry includes:

- `assets["linux-amd64-update"]` (and darwin/windows variants)
- `checksums["linux-amd64-update"]` as `sha256:…`

Workers drain active runs, verify SHA256, extract the archive, replace their binary, and exit (systemd/launchd restarts them).

Admin can also set **Target app version** on a cloud executor to roll the fleet to a specific release.

## Chromium (separate)

Browser binaries are **not** in this repo. Workers download Litefinga Chromium from the API setting `worker.chromium.manifest` (typically S3 URLs). Expected layout after extract:

| Platform | Binary path under install dir |
|----------|-------------------------------|
| macOS | `Chromium.app/Contents/MacOS/Chromium` |
| Linux | `chromium` (fallback: `chrome`) |
| Windows | `chromium.exe` (fallback: `chrome.exe`) |

## Publishing

CI in private `litefinga-worker` builds all four platforms on `main` / PR, publishes GitHub Releases **here**, and commits the updated manifest. Requires `WORKER_RELEASES_TOKEN` with Contents write on this repo.

## Related

- Operator guide: `litefinga-worker/docs/OPERATOR.md`
- Desktop releases (same pattern): `litefinga-desktop-releases`
