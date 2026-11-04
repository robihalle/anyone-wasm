# Anyone WASM

An independent experimental browser client for the Anyone network, extracted from [Privacy Lab](https://github.com/robihalle/privacylab).

The browser verifies the signed Anyone directory and builds a circuit in a Web Worker. A WebSocket bridge forwards the encrypted relay traffic from the browser to the first relay over TCP. The demo makes one HTTPS request through that circuit and shows the IP reported by the test endpoint.

```text
Browser Web Worker → WebSocket bridge → Anyone relays → HTTPS test endpoint
```

The bridge operator can see the incoming IP, the first relay address, and traffic timing and volume. The endpoint receives the exit IP and a random test ID. The WASM client handles only the demo request. A warm repeat can reuse its short-lived browser session.

## Build

Use Linux x86-64 or WSL2 on x86-64 with glibc no newer than Debian 13. You need Git, a C toolchain with Clang, pkg-config, OpenSSL and SQLite development libraries, binutils, Node.js 22 or newer, and npm. Install [Rust via rustup](https://rustup.rs/) and Docker Compose for the local demo.

```sh
rustup toolchain install 1.97.1 --target wasm32-unknown-unknown
cargo +1.97.1 install wasm-bindgen-cli --version 0.2.128 --locked
bash scripts/build.sh
```

The build checks out the pinned upstream revisions and applies the checked-in patches. It produces the native snapshot publisher and browser assets, including Brotli and gzip variants, in `wasm-bridge/artifacts/`. On WSL, setting `ANYONE_WASM_BUILD_DIR="$HOME/.cache/anyone-wasm"` keeps the intermediate build on Linux storage.

## Run locally

Review the Anyone terms before connecting the demo to the live network. [Anyone terms](https://www.anyone.io/terms)

```sh
ANYONE_ACCEPT_TERMS=yes docker compose up --build -d
docker compose cp caddy:/data/caddy/pki/authorities/local/root.crt ./anyone-wasm-local-root.crt
```

Trust that local Caddy CA in the browser or OS used for the demo, then open **https://localhost:8443**. The first directory sync can take a few minutes. If the test reports that the directory is unavailable, wait for the sync and retry. Run it again immediately to measure a warm session. Stop the demo with `docker compose down`. [Caddy local HTTPS](https://caddyserver.com/docs/automatic-https#local-https)

The demo binds to loopback. For the bridge interface, see [the WASM service notes](wasm-bridge/README.md). For source provenance and upstream licenses, see [NOTICE](NOTICE.md).
