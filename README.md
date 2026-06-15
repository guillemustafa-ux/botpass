# BotPass — On-chain subscription passes for trading-signal bots

> Pay in crypto → get a time-based access pass → your off-chain bot checks
> `isActive()` on-chain before sending signals. The pass is an **ERC-721 NFT**,
> so access is transferable and resellable.

A from-scratch Solidity project built in five incremental versions (native ETH →
ERC-20 → tiered plans → referrals → NFT passes), each one adding a real concept and
its own test suite. **59 Foundry tests, all green.** Includes a deploy script for
Ethereum + L2 testnets and a zero-build dApp frontend.

| | |
|---|---|
| **Language** | Solidity `0.8.24` |
| **Tooling** | Foundry (forge), OpenZeppelin v5 |
| **Tests** | 59 passing (unit + reentrancy attack sims) |
| **Networks** | Sepolia (verified) · Base Sepolia · Arbitrum Sepolia |
| **Frontend** | Single-file dApp, ethers.js v6 (CDN + SRI), no build step |

---

## Why this exists

I build off-chain trading/signal bots (Telegram). Gating them with a database +
manual payments is fragile and centralized. BotPass moves the **access control
on-chain**: the customer pays the contract, the contract is the source of truth,
and the bot just asks `isActive(tokenId)` before doing anything. No payment
processor, no trust in my own DB. This is the **on-chain contract + off-chain
agent** combo — the part most signal-bot sellers don't have.

## Architecture

```
   Customer wallet                BotPassNFT (on-chain)             Off-chain bot
  ───────────────                ────────────────────             ─────────────
   subscribe() + ETH  ───────▶   mint ERC-721 pass
                                 expiresAt[tokenId] = now+period
                                                                   isActive(id)? ──┐
   owns NFT  ◀──────────────────  (access lives in the NFT)                        │
                                 isActive(id) / timeLeft(id)  ◀────────────────────┘
                                                                   true → send signal
   owner: withdraw()  ◀────────  accumulated ETH
```

Access is keyed by **`tokenId`, not wallet** — so a pass can be transferred or sold
on a secondary market and the access travels with it.

## Contracts (incremental versions)

| Version | File | Concept introduced | Tests |
|---|---|---|---|
| v1 — Native ETH | [`src/BotPass.sol`](src/BotPass.sol) | payments, mappings, time, modifiers, events | 11 |
| v2 — ERC-20 (USDT) | [`src/BotPassERC20.sol`](src/BotPassERC20.sol) | `IERC20`, `approve` + `transferFrom` | 10 |
| v3 — Tiered plans | [`src/BotPassTiers.sol`](src/BotPassTiers.sol) | `enum` + `struct`, per-tier pricing | 11 |
| v4 — Referrals | [`src/BotPassReferral.sol`](src/BotPassReferral.sol) | pull-payment, Checks-Effects-Interactions, `nonReentrant` | 13 + 2 |
| v5 — NFT pass | [`src/BotPassNFT.sol`](src/BotPassNFT.sol) | OpenZeppelin `ERC721` + `Ownable` inheritance | 12 |

## Security & threat model

Security was treated as a day-one requirement, not an afterthought:

- **Reentrancy (v4).** The referral payout is the dangerous path. It uses the
  **pull-payment pattern** (`claim()`), **Checks-Effects-Interactions** ordering, and
  a `nonReentrant` guard. [`test/ReentrancyAttack.t.sol`](test/ReentrancyAttack.t.sol)
  proves it: a malicious contract **drains a deliberately-vulnerable vault** but is
  **blocked** against BotPass.
- **Access control.** Admin functions (`withdraw`, `setPrice`, `setBaseURI`) are
  gated by `onlyOwner` (custom modifier in v1, OpenZeppelin `Ownable` in v5).
- **Safe ETH transfers.** Withdrawals use `.call{value:}` with a checked return,
  not the deprecated `transfer`/`send`.
- **Audited base.** v5 inherits battle-tested OpenZeppelin v5 implementations
  instead of re-rolling ERC-721.

**Known limitations (honest scope):** `isActive` uses `block.timestamp`, which
validators can nudge by a few seconds — irrelevant at the 30-day granularity here.
No upgradeability proxy (intentional: immutable is simpler and safer for this scope).
No pausing/circuit-breaker. These are documented, not hidden.

## Design tradeoffs

- **NFT vs wallet-mapping for access.** v1–v4 key access by wallet; v5 keys it by
  `tokenId`. NFT wins for transferability/resale and composability, at the cost of
  needing event-log lookups to find a user's token (plain ERC-721 isn't enumerable).
  The frontend resolves this by querying the indexed `PassMinted` event.
- **ETH vs ERC-20.** Native ETH (v1) is simplest; stablecoins (v2) remove price
  volatility for the customer but add the `approve` UX step. Both are shipped.
- **Extend-on-renew.** Renewing while still active **adds** to the current expiry
  instead of resetting it — customers never lose paid time.

## Gas report (`forge test --gas-report`, BotPassNFT)

| Function | Avg gas |
|---|---|
| `subscribe` (mint pass) | 94,653 |
| `renew` | 30,906 |
| `withdraw` | 27,308 |
| `setPrice` | 24,260 |
| `isActive` (view) | 2,873 |
| `timeLeft` (view) | 3,125 |

Running on an L2 (Base/Arbitrum Sepolia) makes these fractions of a cent.

## Deployments

Same address on both chains (CREATE with deployer nonce 0):
`0x39D0AE0B7eeEEf371D209453F0c81D75bCA02dEc`

| Network | Explorer | Status |
|---|---|---|
| Ethereum Sepolia | [Etherscan](https://sepolia.etherscan.io/address/0x39D0AE0B7eeEEf371D209453F0c81D75bCA02dEc) | ✅ verified |
| Base Sepolia (L2) | [Basescan](https://sepolia.basescan.org/address/0x39D0AE0B7eeEEf371D209453F0c81D75bCA02dEc) | ✅ verified |
| Arbitrum Sepolia | _(optional: run the deploy command below)_ | ⏳ |

## Quickstart

### Tests
```bash
forge build
forge test -vv            # 59 tests
forge test --gas-report   # gas table above
```
(Git Bash, if `forge` isn't on PATH: `export PATH="$HOME/.foundry/bin:$PATH"`.)

### Deploy to a testnet
1. `cp .env.example .env` and fill `PRIVATE_KEY` (a throwaway test wallet),
   the RPC URL for your target network, and `ETHERSCAN_API_KEY`.
2. Get testnet ETH from a faucet, then:
```bash
forge script script/Deploy.s.sol:Deploy --rpc-url base_sepolia --broadcast --verify -vvvv
```
3. Copy the printed address into `frontend/index.html` (`NETWORKS`) and the table above.

### Run the dApp
Open [`frontend/index.html`](frontend/index.html) in a browser with MetaMask
(or serve it on GitHub Pages). Connect → it reads `price`, your pass and
`timeLeft`; **the padlock opens (🔓) when your pass is active.** Subscribe/Renew
sends the ETH and updates state live, with a link to the block explorer.

## Solidity glossary (for newcomers)

- **wei** — smallest ETH unit, `1 ETH = 1e18 wei`.
- **msg.sender / msg.value** — caller address / ETH sent with a `payable` call.
- **block.timestamp** — current block time (Unix seconds).
- **mapping** — key→value table; unset entries are `0` / `false`.
- **view** — read-only function, free to call externally.
- **event / emit** — cheap logs off-chain apps can subscribe to.
- **modifier** — reusable check (e.g. `onlyOwner`) run before a function body.

## License

MIT.
