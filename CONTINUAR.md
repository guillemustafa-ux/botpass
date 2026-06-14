# CONTINUAR — BotPass (handoff entre sesiones)

> Archivo para retomar el proyecto en una sesión nueva sin perder contexto.

## Dónde estamos (2026-06-14)

Proyecto de aprendizaje de Solidity. **ROADMAP COMPLETO (v1→v5) VERIFICADO con Foundry** ✅.

- `src/BotPass.sol` — v1 (ETH nativo), comentado línea por línea
- `src/BotPassERC20.sol` — v2 (cobra en token ERC20 tipo USDT), patrón approve+transferFrom
- `src/BotPassTiers.sol` — v3 (planes basic/pro/vip), enum + struct, subscribe(plan)
- `src/BotPassReferral.sol` — v4 (referidos), split en basis points, patrón pull (claim) + CEI + candado `nonReentrant`
- `src/BotPassNFT.sol` — v5 (pase = NFT ERC-721 transferible), hereda de OpenZeppelin ERC721 + Ownable
- `test/BotPass.t.sol` (11) · `test/BotPassERC20.t.sol` (10) · `test/BotPassTiers.t.sol` (11) · `test/BotPassReferral.t.sol` (13) · `test/ReentrancyAttack.t.sol` (2, demo de reentrancy) · `test/BotPassNFT.t.sol` (12)
- `script/DeployBotPassNFT.s.sol` — deploy del NFT, probado en anvil local ✅
- `foundry.toml` (solc 0.8.24, + rpc/etherscan de Sepolia) · `remappings.txt` (@openzeppelin + forge-std) · `.env.example`
- `lib/forge-std`, `lib/openzeppelin-contracts` (v5.6.1) — dependencias
- `README.md` — qué hace, roadmap por etapas, glosario de Solidity
- Entorno: Node v24 ✅, git ✅ (repo inicializado), **Foundry v1.7.1 ✅**
  (instalado en `~/.foundry/bin` vía foundryup; binarios Windows .exe)

**Total: 59 tests en verde.** Correr con `forge test -vv`.

## Cómo correr los tests

```bash
export PATH="$HOME/.foundry/bin:$PATH"   # solo en Git Bash si forge no está en PATH
cd /c/Users/Cript/botpass
forge build       # compila
forge test -vv    # corre los 11 tests
```

> Nota: `forge build` tira warnings de lint sobre `block.timestamp` — son benignos
> (un validador solo puede mover el reloj unos segundos; irrelevante para períodos
> de 30 días). No son errores.

## El roadmap base está COMPLETO 🎉

Los 5 conceptos centrales de Solidity quedaron cubiertos y testeados. Opciones
para seguir (ya no hay un "próximo paso" obligado):

### ✅ DESPLEGADO Y VERIFICADO EN SEPOLIA (2026-06-14)
**BotPassNFT (v5) en vivo:** `0x39D0AE0B7eeEEf371D209453F0c81D75bCA02dEc`
🔗 https://sepolia.etherscan.io/address/0x39d0ae0b7eeeef371d209453f0c81d75bca02dec
Código verificado (tilde verde). Wallet de deploy: `0x40b282c45EE5667fB72b4D37a676A0110cEe36d5`.
Esta URL es la que se enlaza en LaborX/Fiverr/CV.

### A) Desplegar a Sepolia (recomendado para portfolio) — INFRA YA LISTA
El script de deploy y la config ya están hechos, **probados localmente con anvil** ✅ y
**usados para el deploy real a Sepolia** ✅.
- `script/DeployBotPassNFT.s.sol` — despliega el NFT (v5). Para otro contrato, copiar/editar.
- `foundry.toml` — tiene `[rpc_endpoints] sepolia` y `[etherscan] sepolia` leyendo de .env.
- `.env.example` — plantilla. `.env` está en .gitignore.

**📋 Guía paso a paso con todos los clicks: ver `DEPLOY_SEPOLIA.md`**

**Lo que falta (lo hace Guillermo, requiere sus cuentas):**
1. Crear cuenta gratis en Alchemy (o Infura) → copiar la URL RPC de Sepolia.
2. Crear una wallet de PRUEBA descartable (ej. MetaMask nueva) → copiar su clave privada.
   ⚠️ NUNCA usar una wallet con fondos reales.
3. Pedir ETH de faucet de Sepolia para esa wallet (ej. sepoliafaucet.com, faucet de Alchemy).
4. Crear API key en etherscan.io/myapikey.
5. `cp .env.example .env` y completar SEPOLIA_RPC_URL, PRIVATE_KEY, ETHERSCAN_API_KEY.
6. Desplegar + verificar (en Git Bash, con `export PATH="$HOME/.foundry/bin:$PATH"`):
   ```bash
   source .env
   forge script script/DeployBotPassNFT.s.sol \
     --rpc-url sepolia \
     --private-key $PRIVATE_KEY \
     --broadcast --verify
   ```
   (`--verify` sube el código a Etherscan automáticamente.)
7. La consola imprime la dirección. Verla en https://sepolia.etherscan.io/address/<DIRECCION>
   → esa URL pública es la que se enlaza en LaborX/Fiverr/CV.

> Prueba local hecha (sin tocar redes reales ni claves): `anvil` + `forge script ... --broadcast`
> contra http://127.0.0.1:8545 desplegó OK (owner/price/period correctos).

### B) Mejoras de robustez
- v2.1 — SafeERC20 (soportar USDT real de mainnet, ver nota en BotPassERC20.sol).
- Tests de fuzzing (`forge test` con inputs aleatorios) y coverage (`forge coverage`).
- Combinar features: un contrato final que junte ERC20 + planes + referidos + NFT.

### C) Integrar con los bots reales
- Script (ethers.js/web3.py) que el bot use para consultar isActive antes de
  mandar señales. Conecta este proyecto con [[project_rochas_whatsapp_bot]] /
  los bots de Telegram.

## Pendiente / mejoras conocidas

- **v2.1 — SafeERC20:** el v2 actual usa `bool ok = transferFrom(...)`, que falla
  con el USDT real de mainnet (no devuelve bool). Para producción real con USDT,
  migrar a SafeERC20 de OpenZeppelin (`forge install OpenZeppelin/openzeppelin-contracts`).
  Funciona OK con USDC y tokens estándar. Detalle en el comentario al pie de
  `src/BotPassERC20.sol`.

## Roadmap

- [x] v1 — ETH nativo (+ 11 tests)
- [x] v2 — USDT/ERC20 (transferFrom + approve) (+ 10 tests)
- [x] v3 — Planes por niveles (struct + enum) (+ 11 tests)
- [x] v4 — Referidos con comisión (basis points + pull + CEI + nonReentrant) (+ 13 tests + 2 de reentrancy)
- [x] v5 — Pase como NFT ERC-721 (OpenZeppelin, transferible, acceso por tokenId) (+ 12 tests)
- [ ] v2.1 — SafeERC20 (soportar USDT real de mainnet) — opcional
- [ ] Deploy a testnet (Sepolia) + verificar en Etherscan — opcional

## Cómo retomar en sesión nueva

Pegar este prompt:

> Retomemos el proyecto BotPass de Solidity. Está en C:\Users\Cript\botpass.
> Leé CONTINUAR.md y seguimos desde el próximo paso.
