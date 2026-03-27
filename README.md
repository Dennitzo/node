# Mini Setup (macOS) for Bitcoin + Electrs + Mempool

This setup runs **without full Umbrel OS**, but uses service configuration and image versions from `umbrel-apps` for:
- `bitcoin` (Umbrel Bitcoin image)
- `electrs`
- `mempool` (api/web/db)

## Files in the `node` root
- `docker-compose.yml`
- `.env`
- `start-mini-umbrel.sh`
- `stop-mini-umbrel.sh`
- `app-data/*` (persistent data)

## Start
```bash
cd node
./start-mini-umbrel.sh
```

## Fresh Setup / Re-Setup (Colima + Docker)
If you reinstall macOS or want to rebuild your local Colima/Docker runtime with the
same stability fixes (RAM, disk, qemu backend, auto-start stack), run:

```bash
cd node
./bootstrap-colima-docker.sh
```

Defaults applied by the script:
- `vmType=qemu` (prevents the low-memory `vz` issue seen in this setup)
- `cpu=8`
- `memory=96GiB`
- `disk=auto` (calculates dynamically from host disk size: `total - 30GiB` reserve)
- reapplies `docker-compose.yml` stability tunings (`BITCOIND_EXTRA_ARGS`, `NODE_OPTIONS`)
- starts `docker compose` stack after runtime validation

Optional overrides:
```bash
COLIMA_CPU=12 COLIMA_MEMORY_GIB=112 COLIMA_DISK_GIB=1500 ./bootstrap-colima-docker.sh
COLIMA_DISK_GIB=free COLIMA_DISK_RESERVE_GIB=50 ./bootstrap-colima-docker.sh
```

Disk modes:
- `COLIMA_DISK_GIB=auto` (default): uses filesystem total size minus `COLIMA_DISK_RESERVE_GIB`
- `COLIMA_DISK_GIB=free`: uses current free space minus `COLIMA_DISK_RESERVE_GIB`
- `COLIMA_DISK_GIB=<number>`: fixed size in GiB (manual override)
- `COLIMA_DISK_SOURCE_PATH=/path`: choose which mounted filesystem is measured

Skip stack startup if you only want runtime setup:
```bash
START_STACK=0 ./bootstrap-colima-docker.sh
```

## Stop
```bash
cd node
./stop-mini-umbrel.sh
```

## Ports
- Bitcoin UI (Umbrel app frontend): `http://localhost:2100`
- Electrs UI (Umbrel app frontend): `http://localhost:2102`
- Mempool web UI: `http://localhost:3006`
- Bitcoin RPC: `http://localhost:8332`
- Bitcoin P2P: `8333/tcp`
- Electrs TCP (wallets): `50001/tcp` (no TLS)

## Note
On first start, `bitcoind` needs significant time to sync the blockchain.  
`mempool` and Electrs-backed wallet features become fully usable once sync has progressed sufficiently.

## Troubleshooting (Colima)
If your Docker config contains `"credsStore": "desktop"` but Docker Desktop is not installed,
`docker compose` fails with `docker-credential-desktop: executable file not found`.

`start-mini-umbrel.sh` now auto-detects this case and uses a temporary sanitized Docker config
for the current run, preserving your existing Docker context.
