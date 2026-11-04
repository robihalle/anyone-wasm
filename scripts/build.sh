#!/usr/bin/env bash
set -euo pipefail

rust_version=1.97.1
target=wasm32-unknown-unknown
arti_revision=2527494a8961a7522a36f96d9c0048096f657c88
tor_js_revision=d9d9612d10d3775ff100b70e96a291718191d856
repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
bridge="$repo_root/wasm-bridge"

fail() {
  printf 'Build error: %s\n' "$*" >&2
  exit 1
}

[[ $(uname -s) == Linux && $(uname -m) == x86_64 ]] ||
  fail 'Run the build on Linux x86-64, including WSL2 on x86-64.'
for tool in git rustup cargo wasm-bindgen clang node npm strip pkg-config; do
  command -v "$tool" >/dev/null || fail "Missing required tool: $tool"
done
rustup target list --toolchain "$rust_version" --installed | grep -Fx "$target" >/dev/null ||
  fail "Install the target with: rustup toolchain install $rust_version --target $target"
node --input-type=module -e 'if (Number(process.versions.node.split(".")[0]) < 22) process.exit(1)' ||
  fail 'Use Node.js 22 or newer.'
pkg-config --exists openssl sqlite3 || fail 'Install the OpenSSL and SQLite development packages.'

mkdir -p -- "${ANYONE_WASM_BUILD_DIR:-$repo_root/.build}"
build_dir=$(cd -- "${ANYONE_WASM_BUILD_DIR:-$repo_root/.build}" && pwd)
sources=$(mktemp -d "$build_dir/source.XXXXXXXX")
trap 'rm -rf -- "$sources"' EXIT

checkout() {
  local directory=$1 url=$2 revision=$3
  git init --quiet "$directory"
  git -C "$directory" config core.autocrlf false
  git -C "$directory" config core.hooksPath /dev/null
  git -C "$directory" fetch --depth=1 --no-tags "$url" "$revision"
  git -C "$directory" checkout --quiet --detach FETCH_HEAD
  [[ $(git -C "$directory" rev-parse HEAD) == "$revision" ]] || fail "Unexpected revision in $directory"
}

apply_patches() {
  local directory=$1
  shift
  git -C "$directory" \
    -c user.name='Anyone WASM build' -c user.email='build@users.noreply.github.com' \
    am --committer-date-is-author-date --no-gpg-sign "$@"
}

arti="$sources/arti-browser"
tor_js="$sources/tor-js"
checkout "$arti" https://github.com/voltrevo/arti.git "$arti_revision"
apply_patches "$arti" "$bridge/patches/0001-Use-Anyone-directory-authorities-and-fallback-relays.patch"
checkout "$tor_js" https://github.com/ethereum/tor-js.git "$tor_js_revision"
apply_patches "$tor_js" \
  "$bridge/patches/0001-Prototype-Anyone-consensus-validation-in-browser-WAS.patch" \
  "$bridge/patches/0002-Retry-failed-WASM-loads-and-borrow-bootstrap-archive.patch" \
  "$bridge/patches/0003-Keep-supplied-directory-snapshots-in-WASM-memory.patch" \
  "$bridge/patches/0004-Publish-coherent-directory-generations-and-bound-boo.patch"

cd -- "$tor_js"
bindgen_version=$(awk -F '"' '$0 == "name = \"wasm-bindgen\"" {getline; print $2; exit}' Cargo.lock)
[[ -n "$bindgen_version" && $(wasm-bindgen --version) == "wasm-bindgen $bindgen_version" ]] ||
  fail "Install the matching CLI with: cargo +$rust_version install wasm-bindgen-cli --version $bindgen_version --locked"

export CARGO_TARGET_DIR="$build_dir/target"
export CARGO_NET_GIT_FETCH_WITH_CLI=true
export CARGO_PROFILE_DEV_DEBUG=0 CARGO_INCREMENTAL=0
cargo "+$rust_version" build --locked -p tor-js-gateway
CARGO_PROFILE_RELEASE_LTO=thin CARGO_PROFILE_RELEASE_OPT_LEVEL=2 CC_wasm32_unknown_unknown=clang \
  cargo "+$rust_version" build --locked --release --target "$target" -p tor-js
wasm-bindgen "$CARGO_TARGET_DIR/$target/release/tor_js.wasm" \
  --target web --out-dir crates/tor-js-wasm/pkg-release --out-name tor_js
npm ci --include=dev --no-audit --no-fund
node "$bridge/build-client.mjs" "$tor_js"
strip --strip-unneeded -o "$bridge/artifacts/tor-js-gateway" "$CARGO_TARGET_DIR/debug/tor-js-gateway"
chmod 0755 "$bridge/artifacts/tor-js-gateway"
printf 'Build artifacts are in %s\n' "$bridge/artifacts"
