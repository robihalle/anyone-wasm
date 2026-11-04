# Anyone WASM

Anyone WASM is an independent experimental browser client for the Anyone network. The local demo sends one HTTPS request through Anyone and shows the public IP the test endpoint saw. It also shows how long the browser took to get ready and how long the request took. The project grew out of [Privacy Lab](https://github.com/robihalle/privacylab).

**Want to try it first?** Open the hosted Privacy Lab, enable the experimental browser path, and run the comparison. Run it again immediately to see the effect of reusing the browser session. [Open Privacy Lab](https://anyone-privacylab.com/#test)

**Want to run it yourself?** [Set up your machine](#1-set-up-your-machine), [build the client](#2-clone-and-build), [start the local demo](#3-start-the-local-demo), and [run the browser test](#4-trust-local-https-and-run-the-test).

## What the demo does

```text
Web Worker in your browser
    │ WebSocket
    ▼
Local bridge ── TCP ──► First Anyone relay ──► Anyone network ──► httpbingo.org
```

1. A local directory service verifies the signed Anyone consensus and publishes a snapshot of the relay directory.
2. After you start the test, your browser downloads the WASM client and the snapshot. The client verifies the directory signatures and builds its connection in a Web Worker.
3. The bridge connects the WebSocket from your browser to the first Anyone relay over TCP. It checks that the requested relay belongs to the relevant unexpired directory.
4. The WASM client sends an HTTPS request to `httpbingo.org` with a random test ID. The browser checks the returned test URL and shows the reported exit IP.

The bridge operator can see your incoming IP, the first relay address, and traffic timing and volume. The HTTPS request travels inside the encrypted relay traffic. The test endpoint sees the exit IP and test ID. Your other browser tabs and apps continue to use their usual connection.

## 1. Set up your machine

The build runs on **Linux x86-64**. Ubuntu 24.04 and Debian 13 are suitable starting points. The native binary runs in a Debian 13 container, so build it with glibc **2.41 or earlier**. On Windows x64, use Ubuntu 24.04 in WSL2. On macOS or ARM hardware, the hosted demo is the quickest way to try it. For a local build, use a Linux x86-64 environment.

### Windows with WSL2

1. If you need to install WSL, run this in Windows PowerShell and restart Windows if prompted.

   ```powershell
   wsl --install -d Ubuntu-24.04
   wsl -l -v
   ```

2. Confirm that Ubuntu reports `VERSION 2`. Start Docker Desktop in Linux container mode. In **Settings → Resources → WSL Integration**, enable integration for your Ubuntu distribution. [WSL installation](https://learn.microsoft.com/en-us/windows/wsl/install), [Docker Desktop WSL integration](https://docs.docker.com/desktop/features/wsl/)
3. Open the **Ubuntu** terminal for the remaining build and Docker commands. Clone the repo under your Linux home directory, for example `~/src`. Install the Linux versions of Node.js and npm inside Ubuntu.

### Linux and WSL2 build tools

On Ubuntu or Debian, install the system packages.

```bash
sudo apt update
sudo apt install git build-essential clang pkg-config libssl-dev libsqlite3-dev binutils ca-certificates curl
```

Install **Node.js 22 or newer** with npm, and install Rust through **rustup**. Choose a Linux x64 LTS release from Node.js if your distribution ships an older version. On native Linux, install Docker Engine and the Docker Compose plugin. With Docker Desktop on Windows, use the Docker integration from the previous step. [Node.js downloads](https://nodejs.org/en/download), [Rust installation](https://rustup.rs/), [Docker Engine](https://docs.docker.com/engine/install/), [Docker Compose](https://docs.docker.com/compose/install/)

Check the tools from the same Linux shell that will run the build.

```bash
uname -m
getconf GNU_LIBC_VERSION
node --version
npm --version
rustup --version
docker compose version
docker info
```

You should see `x86_64`, a Node version of at least 22, and a running Docker engine. If the shell cannot find Rust after installation, reopen it or run `source "$HOME/.cargo/env"`.

## 2. Clone and build

```bash
mkdir -p ~/src
cd ~/src
git clone https://github.com/robihalle/anyone-wasm.git
cd anyone-wasm

rustup toolchain install 1.97.1 --target wasm32-unknown-unknown
cargo +1.97.1 install wasm-bindgen-cli --version 0.2.128 --locked
bash scripts/build.sh
```

The build fetches the pinned Arti and tor-js revisions, applies the checked-in patches, and compiles the native directory service and browser client. The first build needs internet access and can take several minutes. It leaves the generated files in `wasm-bridge/artifacts/`. [Upstream revisions and license notices](NOTICE.md)

```bash
ls -lh wasm-bridge/artifacts/
```

The directory should contain `tor-js-gateway`, `client.js`, `client-worker.js`, and the WASM file in uncompressed, Brotli, and gzip variants. The WASM filename is `tor_js_bg.wasm`. Generated files are ignored by Git.

By default the script keeps its Cargo build cache in `.build/`. To put it on a different disk, run `ANYONE_WASM_BUILD_DIR="$HOME/.cache/anyone-wasm" bash scripts/build.sh`. On WSL, using the Linux filesystem for the repo and build cache avoids slow cross-filesystem builds.

## 3. Start the local demo

Read the Anyone terms before connecting the local service to the live network. Then start the three containers from the repository directory. The environment variable records the operator's opt-in for this start. The demo also asks visitors to opt in before their browser runs a test. [Anyone terms](https://www.anyone.io/terms)

```bash
ANYONE_ACCEPT_TERMS=yes docker compose up --build -d
docker compose ps -a
docker compose logs --tail=30 wasm-snapshot
```

The first directory sync can take a few minutes. The demo uses **https://localhost:8443**. Docker publishes only Caddy on the local loopback address. Pass `ANYONE_ACCEPT_TERMS=yes` again when you run `docker compose up` to restart or update the demo.

## 4. Trust local HTTPS and run the test

Caddy creates a certificate for `localhost` using a local certificate authority. Copy the public root certificate from your own running Caddy container.

```bash
docker compose cp caddy:/data/caddy/pki/authorities/local/root.crt ./anyone-wasm-local-root.crt
```

If the file is missing immediately after startup, give Caddy a few seconds and retry. Use `docker compose logs --tail=50 caddy` if it still fails.

You can check that the local server and certificate work before importing the certificate into a browser.

```bash
curl --cacert ./anyone-wasm-local-root.crt -sS -i https://localhost:8443/wasm-lab/health
```

**HTTP 200** with `{"ready": true}` means the bridge has its browser files and a valid directory snapshot. **HTTP 503** with `{"ready": false}` usually means the initial sync is still running. Check `docker compose logs --tail=50 wasm-snapshot` if it persists.

### Trust the certificate where your browser runs

- **Windows Chrome or Edge with WSL2.** Run `explorer.exe .` from the repo directory in Ubuntu. In Explorer, open `anyone-wasm-local-root.crt` and install it under **Current User → Trusted Root Certification Authorities**. Reopen the browser if needed. The Windows browser uses the Windows trust store, even when Docker runs through WSL. [Windows certificate tooling](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/certutil)
- **Linux.** Import the certificate under your browser's certificate authorities. On Ubuntu or Debian, you can also add it to the system trust store with the commands below. Use the browser's import option if it still reports a trust error. [Caddy local HTTPS](https://caddyserver.com/docs/automatic-https#local-https)

```bash
sudo install -m 0644 anyone-wasm-local-root.crt /usr/local/share/ca-certificates/anyone-wasm-local-root.crt
sudo update-ca-certificates
```

Import only the public `root.crt` from your own demo. Keep Caddy's private CA key in its Docker volume.

### Run and read the result

1. Open **https://localhost:8443** in a current browser. Use the hostname `localhost`, which matches the certificate and the bridge's configured origin.
2. Read and select the Anyone terms checkbox, then start the test.
3. Check the **exit IP**, **setup time**, **request time**, **total time**, and **test ID**.
4. Run it again promptly in the same tab. A **Reused (warm)** session can skip the initial setup. The timings vary with your device, connection, and the relays selected for that run.

**Setup** covers the time before the successful request, including downloads, worker startup, and any retry overhead. **Request** is the time for the successful HTTPS request through Anyone.

## Troubleshooting

| Symptom | What to check |
| --- | --- |
| `Missing required tool: node` or Node version below 22 | Install Node.js and npm in the Linux environment that runs the build. In WSL, check `which node npm` for Linux executables. |
| Wrong `wasm-bindgen` version | Run `wasm-bindgen --version`. Install `0.2.128` with the command in step 2 and make sure `~/.cargo/bin` is on your path. |
| Docker cannot connect to the daemon | Start Docker Desktop or the Linux Docker service. On Windows, verify the Ubuntu distro is enabled in Docker Desktop's WSL integration. Check `docker info`. |
| Docker build cannot copy `artifacts/...` | Finish `bash scripts/build.sh` before starting Compose. Run both commands from the cloned repo. |
| Port 8443 is already in use | Stop the other local service on that port, then start the demo again. |
| The browser reports a certificate warning | Use `https://localhost:8443`, copy the root certificate from the current Caddy container, and import it where your browser runs. |
| Health returns HTTP 502 | Check whether the bridge is running with `docker compose ps -a`. Inspect `docker compose logs --tail=50 caddy wasm-bridge`. |
| Health returns HTTP 503 | Inspect `docker compose ps -a` and the `wasm-snapshot` logs. Check operator opt-in, internet access from Docker, and the host clock. |
| The browser cannot connect to an Anyone relay | Check the bridge and directory logs with `docker compose logs --tail=50 wasm-bridge wasm-snapshot`. Try again after verifying that the health endpoint is ready. |
| A repeat still shows a new session | Run again promptly in the same tab. The worker closes idle sessions, and a failed connection can require a fresh session. |

Stop the demo with `docker compose down`. This keeps the directory cache and Caddy's local CA for the next run. To update an existing checkout, run `git pull --ff-only`, repeat the build in step 2, and start it with the command in step 3.

To reset the demo completely, `docker compose down -v` removes the cache and CA volumes. Remove the old CA from the trust store where you imported it. A fresh start generates a new CA and needs a fresh import.

## Use it in another site

Start with the [demo source](demo/public/demo.js). It checks browser support, waits for visitor consent, checks the bridge's readiness, loads the browser entry point, and renders the result. The browser entry point exposes `window.AnyoneWasmLab.measure(nonce, onProgress)`. The result includes the exit IP, test ID, timing fields, and whether the session was reused. The worker currently sends the fixed test request to `httpbingo.org`.

Serve the page and `/wasm-lab/*` on the same HTTPS origin. Configure the bridge with that origin, and let the reverse proxy set the trusted client-address header. Keep the bridge and directory service behind the proxy. The [bridge interface notes](wasm-bridge/README.md) document the routes and the checks that protect them.

## Run the bridge tests

With Python 3.12 and virtual-environment support installed, run these commands from the repository directory.

```bash
python3 -m venv .build/test-venv
.build/test-venv/bin/python -m pip install aiohttp==3.14.5
(cd wasm-bridge && ../.build/test-venv/bin/python -m unittest -v)
```

The tests use local fixtures to exercise relay validation, directory generations, request quotas, and content negotiation. [Source and license notices](NOTICE.md)
