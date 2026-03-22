# Mini-Umbau (macOS) für Bitcoin + Electrs + Mempool

Dieses Setup läuft **ohne komplettes Umbrel OS**, nutzt aber die Service-Konfigurationen/Image-Versionen aus `umbrel-apps` für:
- `bitcoin` (Umbrel Bitcoin Image)
- `electrs`
- `mempool` (api/web/db)

## Dateien im `node`-Root
- `docker-compose.yml`
- `.env`
- `start-mini-umbrel.sh`
- `stop-mini-umbrel.sh`
- `app-data/*` (persistente Daten)

## Start
```bash
cd /Users/dennitzo/Documents/GitHub/node
./start-mini-umbrel.sh
```

## Stop
```bash
cd /Users/dennitzo/Documents/GitHub/node
./stop-mini-umbrel.sh
```

## Ports
- Mempool Web: `http://localhost:3006`
- Bitcoin RPC: `http://localhost:8332`
- Bitcoin P2P: `8333/tcp`
- Electrs TCP: `50001/tcp`

## Hinweis
Beim ersten Start braucht `bitcoind` lange für den Blockchain-Sync. `mempool` wird erst voll nutzbar, wenn Bitcoin/Electrs ausreichend synchronisiert sind.
