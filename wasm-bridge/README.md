# Browser and bridge interface

The demo and Privacy Lab use the same routes. The reverse proxy serves the demo and forwards `/wasm-lab/*` to the bridge on the same HTTPS origin.

| Route | Purpose |
| --- | --- |
| `GET /wasm-lab/health` | Reports whether a valid signed directory generation and browser artifacts are available |
| `GET /wasm-lab/client.js` | Browser entry point exposing `window.AnyoneWasmLab.measure(nonce, onProgress)` |
| `GET /wasm-lab/client-worker.js` | Module worker that loads and runs the WebAssembly client |
| `GET /wasm-lab/tor_js_bg.wasm?v=<sha256>` | Versioned WASM with Brotli, gzip and uncompressed representations |
| `GET /wasm-lab/bootstrap` | Directory archive and its generation identifier |
| `GET /wasm-lab/relay?target=<IPv4:port>&generation=<id>` | WebSocket upgrade for a listed relay endpoint |

The directory publisher verifies the Anyone consensus before publishing an archive and the relay list as a single generation. The browser independently checks the signatures and verifies the WASM against the hash embedded in the worker bundle. The bridge accepts the current and previous published generations while each is valid.

Keep the bridge behind the reverse proxy. The proxy must replace `X-Lab-Client-IP` with the verified client address. The bridge uses this address for connection and download quotas. The standalone Compose setup binds only to loopback and gives the bridge read-only access to the directory volume.

Run the bridge policy tests with Python 3.12 and `aiohttp==3.14.5`.

```sh
cd wasm-bridge
python -m unittest -v
```
