#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONTRACTS_DIR="$ROOT_DIR/contracts"

echo "[*] Starting Anvil..."
ANVIL_PORT="${ANVIL_PORT:-8545}"
ANVIL_HOST="${ANVIL_HOST:-127.0.0.1}"
RPC_URL="http://${ANVIL_HOST}:${ANVIL_PORT}"

# Start anvil in background
anvil --host "$ANVIL_HOST" --port "$ANVIL_PORT" > /tmp/anvil-qkey.log 2>&1 &
ANVIL_PID=$!

cleanup() {
  echo "[*] Stopping Anvil (pid=$ANVIL_PID)"
  kill "$ANVIL_PID" >/dev/null 2>&1 || true
}
trap cleanup EXIT

sleep 1

echo "[*] Building & testing..."
cd "$CONTRACTS_DIR"
forge build >/dev/null
forge test -q >/dev/null

# Default Anvil dev keys (do NOT use in production)
# Anvil prints these; this is the common first key.
PRIVATE_KEY="${PRIVATE_KEY:-0x59c6995e998f97a5a0044966f094538b6b6b8e2d9e2d9c7e9c9d1f9b2e2b2b2b}"

OWNER="$(cast wallet address --private-key "$PRIVATE_KEY")"

# Demo identities (addresses only)
WALLET="${WALLET:-0x000000000000000000000000000000000000A11C}"
FIRSTKEY="${FIRSTKEY:-0x000000000000000000000000000000000000BEEF}"
NEWKEY="${NEWKEY:-0x000000000000000000000000000000000000CAFE}"

G1="${G1:-0x0000000000000000000000000000000000001111}"
G2="${G2:-0x0000000000000000000000000000000000002222}"
G3="${G3:-0x0000000000000000000000000000000000003333}"

DELAY_SECONDS="${DELAY_SECONDS:-5}"

echo "[*] Deploying QKeyRotation with delay=$DELAY_SECONDS..."
export DELAY_SECONDS
DEPLOY_OUT="$(forge script script/Deploy.s.sol:Deploy --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY" --broadcast -q)"
ROT="$(echo "$DEPLOY_OUT" | sed -n 's/.*rot: contract QKeyRotation \(0x[0-9a-fA-F]\+\).*/\1/p' | tail -n 1)"

if [[ -z "${ROT:-}" ]]; then
  echo "[!] Could not parse deployed address. Full output:"
  echo "$DEPLOY_OUT"
  exit 1
fi

echo "[+] ROT=$ROT"
echo "[*] init(wallet, owner, firstKey)..."
cast send "$ROT" "init(address,address,address)" "$WALLET" "$OWNER" "$FIRSTKEY" --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY" -q

echo "[*] Add guardians (3) + threshold=2..."
cast send "$ROT" "addGuardian(address,address)" "$WALLET" "$G1" --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY" -q
cast send "$ROT" "addGuardian(address,address)" "$WALLET" "$G2" --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY" -q
cast send "$ROT" "addGuardian(address,address)" "$WALLET" "$G3" --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY" -q
cast send "$ROT" "setGuardianThreshold(address,uint256)" "$WALLET" 2 --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY" -q

echo "[*] Propose rotation to NEWKEY..."
cast send "$ROT" "propose(address,address)" "$WALLET" "$NEWKEY" --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY" -q

echo "[*] Show pending..."
cast call "$ROT" "pendingOf(address)(address,uint64,bool)" "$WALLET" --rpc-url "$RPC_URL"

echo "[*] Guardians cancel pending rotation..."
# NOTE: cancelByGuardians expects an address[] approvals (implementation may require sorted/unique approvals)
cast send "$ROT" "cancelByGuardians(address,address[])" "$WALLET" "[$G1,$G2]" --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY" -q

echo "[*] Confirm pending is cleared..."
cast call "$ROT" "pendingOf(address)(address,uint64,bool)" "$WALLET" --rpc-url "$RPC_URL"

echo "[*] Propose again, then activate after delay..."
cast send "$ROT" "propose(address,address)" "$WALLET" "$NEWKEY" --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY" -q

echo "[*] Increase time by (delay+1) and mine..."
cast rpc --rpc-url "$RPC_URL" anvil_increaseTime $((DELAY_SECONDS+1)) >/dev/null
cast rpc --rpc-url "$RPC_URL" anvil_mine >/dev/null

cast send "$ROT" "activate(address)" "$WALLET" --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY" -q

echo "[*] Active key:"
cast call "$ROT" "activeKeyOf(address)(address)" "$WALLET" --rpc-url "$RPC_URL"

echo "[+] Demo complete."
