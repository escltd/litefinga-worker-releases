# litefinga-worker-releases

Public distribution repo for **litefinga-worker** cloud executor binaries. **No application source** — only release artifacts and manifests.

## Role

| Item | Location |
|------|----------|
| Source + CI | Private `escltd/litefinga-worker` |
| Public downloads | This repo — GitHub Releases |
| Stable manifest | `manifest.json` |
| Pre-release manifest | `manifest-prerelease.json` |

## Publishing (automated)

`litefinga-worker/.github/workflows/release.yml` on `main` / PR:

1. Tags the private worker repo.
2. Builds `linux-amd64`, `darwin-arm64`, `darwin-amd64`, `windows-amd64`.
3. Publishes archives + `SHA256SUMS` here via `WORKER_RELEASES_TOKEN`.
4. Commits updated manifest on `main`.

## Manual changes

Avoid hand-uploading releases — use worker CI. You may edit README; manifest files are CI-owned.

## Parent workspace

See `../AGENTS.md`.
