# Guía paso a paso — Desplegar BotPass a Sepolia

> Sepolia es la red de prueba de Ethereum. Todo es gratis (el ETH no vale nada),
> pero el contrato queda público y verificado en Etherscan, igual que en mainnet.
> Ideal para mostrar en portfolio/CV/LaborX.

Vas a juntar **4 cosas** (todas gratis) y completar un archivo `.env`. Calculá ~15 min.

---

## ⚠️ Regla de oro de seguridad

Usá una wallet **NUEVA y descartable** solo para esto. La clave privada va a un
archivo de texto (`.env`). NUNCA pongas ahí la clave de una wallet con plata real.
El `.env` ya está en `.gitignore`, así que no se sube a GitHub.

---

## Paso 1 — Crear una wallet de prueba (MetaMask)

Si ya tenés MetaMask, igual conviene crear una cuenta **nueva** adentro solo para esto.

1. Instalá la extensión **MetaMask** desde https://metamask.io (Chrome/Brave/Firefox).
2. Creá una wallet nueva (te da una frase de 12 palabras → guardala, pero recordá
   que esta wallet es descartable).
3. Arriba, clic en el ícono de cuenta → **"Agregar cuenta"** → "Cuenta de prueba BotPass".
4. **Mostrar Sepolia:** clic en la lista de redes (arriba a la izquierda) →
   activá **"Show test networks"** → elegí **Sepolia**.
5. **Copiar la clave privada** (esto es lo que necesitamos):
   - Los 3 puntitos `⋮` → **"Detalles de la cuenta"** → **"Mostrar clave privada"**.
   - Te pide la contraseña → copiá la clave (empieza con `0x...`, 64 caracteres).
   - 👉 Esta es tu `PRIVATE_KEY`.
6. **Copiar la dirección** de la wallet (arriba, algo como `0x1234...abcd`).
   La vas a necesitar para el faucet. 👉 Esta es tu dirección pública.

---

## Paso 2 — Conseguir el RPC (Alchemy)

El RPC es la "puerta" para hablar con la blockchain.

1. Entrá a https://alchemy.com → **Sign up** (gratis, con tu email de Google sirve).
2. En el dashboard, **"Create new app"**:
   - Name: `BotPass`
   - Chain: **Ethereum**
   - Network: **Ethereum Sepolia**
3. Una vez creada, clic en la app → botón **"API Key"** o **"Endpoints"**.
4. Copiá la **HTTPS URL**. Se ve así:
   `https://eth-sepolia.g.alchemy.com/v2/AbCdEf123...`
   👉 Esta es tu `SEPOLIA_RPC_URL`.

---

## Paso 3 — Pedir ETH de prueba (faucet)

Necesitás un poco de Sepolia ETH para pagar el "gas" del deploy (~0.01 es de sobra).

Opciones (probá la primera; si pide saldo en mainnet, pasá a la otra):

- **Google Cloud faucet** (la más fácil, da 0.05/día, no pide saldo):
  https://cloud.google.com/application/web3/faucet/ethereum/sepolia
  → pegá tu dirección del Paso 1 → "Receive".
- **Alchemy faucet:** https://sepoliafaucet.com (logueado con tu cuenta de Alchemy).
- **PoW faucet (sin requisitos):** https://sepolia-faucet.pk910.de (minás un ratito en el navegador).

Esperá 1-2 min y verificá en MetaMask (red Sepolia) que te llegó el ETH.
También podés ver tu dirección en https://sepolia.etherscan.io/address/TU_DIRECCION

---

## Paso 4 — API key de Etherscan (para verificar el contrato)

"Verificar" = subir el código fuente para que cualquiera lo vea en Etherscan.

1. Entrá a https://etherscan.io → **Sign in / Register** (gratis).
2. Ir a https://etherscan.io/myapikey → **"Add"** → nombre `BotPass`.
3. Copiá la **API Key Token**. 👉 Esta es tu `ETHERSCAN_API_KEY`.

> Nota: una sola API key de Etherscan sirve para todas las redes (incluida Sepolia).

---

## Paso 5 — Completar el archivo .env

En la carpeta del proyecto (`C:\Users\Cript\botpass`):

1. Copiá la plantilla:
   ```bash
   cp .env.example .env
   ```
2. Abrí `.env` y pegá los 3 valores que juntaste:
   ```
   SEPOLIA_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/TU_API_KEY
   ETHERSCAN_API_KEY=TU_ETHERSCAN_API_KEY
   PRIVATE_KEY=0xtu_clave_privada_de_la_wallet_de_prueba
   ```

---

## Paso 6 — Desplegar 🚀

En Git Bash, dentro del proyecto:

```bash
export PATH="$HOME/.foundry/bin:$PATH"
source .env
forge script script/DeployBotPassNFT.s.sol \
  --rpc-url sepolia \
  --private-key $PRIVATE_KEY \
  --broadcast --verify
```

- `--broadcast` = manda las transacciones de verdad.
- `--verify` = sube el código a Etherscan automáticamente.

Al terminar, la consola imprime algo como:
```
BotPassNFT desplegado en: 0xABC123...
```
Y abajo, líneas de verificación en Etherscan.

---

## Paso 7 — Verlo en Etherscan ✅

Abrí: `https://sepolia.etherscan.io/address/0xABC123...` (tu dirección)

- Pestaña **"Contract"** con un tilde verde ✓ = código verificado.
- Pestaña **"Read/Write Contract"** = podés interactuar desde el navegador
  (probá `subscribe` con value, `isActive`, etc.).

**Esa URL es la que enlazás en LaborX / Fiverr / CV.**

---

## Cuando lo tengas todo

Volvé a la sesión de Claude y decime: *"ya tengo las 4 cosas / ya completé el .env"*
y lo desplegamos juntos. Si algo falla en el Paso 6, copiame el error y lo resolvemos.

### Problemas comunes
- **"insufficient funds"** → falta ETH de faucet en la wallet (Paso 3).
- **"invalid private key"** → la clave debe empezar con `0x` y tener 64 hex.
- **Verificación falla pero el deploy salió** → no pasa nada, el contrato está
  desplegado; se puede re-verificar después con `forge verify-contract`.
- **`source: command not found`** (si usás PowerShell) → usá **Git Bash**, o cargá
  las variables a mano.
