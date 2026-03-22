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
