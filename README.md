# BotPass — Suscripción on-chain para bots de señales

Smart contract de suscripción por tiempo. El cliente paga en cripto y
recibe acceso por un período. Los bots off-chain (Telegram, etc.)
consultan `isActive(user)` antes de enviar señales.

Proyecto de aprendizaje de Solidity — pensado para crecer en etapas,
cada una enseñando un concepto nuevo.

## Estado actual: v1 (ETH nativo) — verificado ✅

- `subscribe()` — pagar en ETH, obtener/renovar acceso por `period` segundos
- `isActive(user)` — los bots consultan esto (lectura gratis)
- `timeLeft(user)` — segundos restantes
- `withdraw()` — el owner retira lo recaudado
- `setPrice()` — el owner ajusta el precio

Probado con 11 tests en Foundry (`test/BotPass.t.sol`), todos en verde.

## Roadmap (cada etapa = un concepto nuevo)

- [x] **v1 — ETH nativo.** Pagos, mappings, tiempo, modifiers, eventos. **+ 11 tests en Foundry.**
- [x] **v2 — USDT (ERC20).** Aceptar stablecoins. Interfaz `IERC20`, patrón `approve` + `transferFrom`. **+ 10 tests.** (`src/BotPassERC20.sol`)
- [x] **v3 — Planes por niveles.** basic/pro/vip con precios y duraciones distintas. `enum` + `struct`. **+ 11 tests.** (`src/BotPassTiers.sol`)
- [x] **v4 — Referidos.** Quien refiere cobra un % (basis points). Patrón pull (`claim`) + Checks-Effects-Interactions + candado `nonReentrant`. **+ 13 tests + 2 de reentrancy** (vault vulnerable drenado vs ataque bloqueado, `test/ReentrancyAttack.t.sol`). (`src/BotPassReferral.sol`)
- [x] **v5 — Pase como NFT.** La suscripción es un ERC-721 transferible/revendible. Herencia de OpenZeppelin (`is ERC721, Ownable`), el acceso viaja con el NFT (vencimiento por `tokenId`). **+ 12 tests.** (`src/BotPassNFT.sol`)
- [ ] **v5 — Pase como NFT.** La suscripción es un ERC-721 transferible/revendible.

## Cómo probarlo HOY (sin instalar nada — Remix)

1. Abrí https://remix.ethereum.org
2. Creá un archivo `BotPass.sol` y pegá el contenido de `src/BotPass.sol`
3. Pestaña **Solidity Compiler** → Compile (versión 0.8.24+)
4. Pestaña **Deploy & Run** → Environment: **Remix VM (Cancun)** (red de prueba en tu navegador, ETH falso)
5. En el constructor poné:
   - `_price`: `10000000000000000` (= 0.01 ETH en wei)
   - `_period`: `2592000` (= 30 días en segundos)
6. **Deploy**. Abajo aparece tu contrato desplegado.
7. Probá:
   - `subscribe` → poné `0.01` ETH arriba (campo Value) → ejecutá
   - `isActive` con tu address → debería dar `true`
   - `timeLeft` → segundos restantes

## Tests con Foundry

Foundry ya está instalado y configurado. Para compilar y correr los tests:

```bash
forge build       # compila el contrato
forge test -vv    # corre los 11 tests
```

(En Git Bash, si `forge` no está en el PATH: `export PATH="$HOME/.foundry/bin:$PATH"`.)

## Conceptos clave de Solidity (glosario rápido)

- **wei**: la unidad mínima de ETH. `1 ETH = 1e18 wei`. Todo se calcula en wei.
- **msg.sender**: quién llamó a la función (la wallet que firma la transacción).
- **msg.value**: cuánto ETH se envió con la llamada (solo en funciones `payable`).
- **block.timestamp**: la hora actual del bloque, en segundos Unix.
- **mapping**: tabla clave→valor. Lo no asignado vale 0 / false / "".
- **view**: función que solo lee, no cambia estado → no cuesta gas llamarla desde afuera.
- **event / emit**: logs baratos que apps off-chain pueden escuchar.
- **modifier**: chequeo reutilizable (ej. `onlyOwner`) que se pega antes del cuerpo.
