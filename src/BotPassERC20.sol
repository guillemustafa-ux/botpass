// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Interfaz mínima de un token ERC20. NO implementamos el token acá:
///         solo declaramos las funciones que vamos a LLAMAR sobre el contrato
///         del token (USDT/USDC, que vive en otra dirección). Una interfaz es
///         como un "control remoto": describe qué botones tiene el otro
///         contrato, sin saber cómo están hechos por dentro.
interface IERC20 {
    /// Mueve `amount` desde `from` hacia `to`, usando el permiso (allowance)
    /// que `from` le dio antes a quien llama (en nuestro caso, este contrato).
    function transferFrom(address from, address to, uint256 amount) external returns (bool);

    /// Mueve `amount` desde quien llama hacia `to`.
    function transfer(address to, uint256 amount) external returns (bool);

    /// Saldo de tokens de `account`.
    function balanceOf(address account) external view returns (uint256);
}

/// @title BotPass v2 — Suscripción on-chain cobrando en un token ERC20 (ej. USDT)
/// @notice Igual que v1, pero el cliente paga en un stablecoin en vez de ETH.
///         Flujo del cliente: 1) approve(botpass, price) en el token,
///         2) subscribe() acá. Pagar de nuevo extiende el vencimiento.
contract BotPassERC20 {
    // ---- Estado ----

    address public owner;   // quién administra y cobra (vos)
    IERC20  public token;   // el token aceptado (ej. el contrato de USDT)
    uint256 public price;   // precio por período, en unidades del token
                            // (OJO: USDT usa 6 decimales → 10 USDT = 10_000000)
    uint256 public period;  // duración del período, en segundos

    mapping(address => uint256) public expiresAt;

    // ---- Eventos ----

    event Subscribed(address indexed user, uint256 newExpiry, uint256 paid);
    event Withdrawn(address indexed to, uint256 amount);
    event PriceChanged(uint256 oldPrice, uint256 newPrice);

    // ---- Constructor ----

    /// @param _token dirección del contrato del token ERC20 a aceptar
    constructor(address _token, uint256 _price, uint256 _period) {
        owner = msg.sender;
        token = IERC20(_token);   // "envolvemos" la dirección con la interfaz
        price = _price;
        period = _period;
    }

    // ---- Modifier ----

    modifier onlyOwner() {
        require(msg.sender == owner, "BotPass: solo el owner");
        _;
    }

    // ---- Funciones que cambian estado ----

    /// @notice El cliente se suscribe/renueva. NO es `payable`: no se manda ETH,
    ///         el pago es en tokens y se cobra con transferFrom.
    /// @dev REQUISITO: el cliente tuvo que llamar antes a
    ///      token.approve(address(este_contrato), price). Sin ese permiso,
    ///      transferFrom revierte.
    function subscribe() external {
        // Tiramos del pago: mueve `price` tokens del cliente a este contrato.
        // Chequear el bool de retorno es importante: algunos tokens devuelven
        // false en vez de revertir. (Ver nota sobre USDT real más abajo.)
        bool ok = token.transferFrom(msg.sender, address(this), price);
        require(ok, "BotPass: transferFrom fallo");

        // Misma lógica de extensión que v1: si sigue vigente, apila; si no,
        // arranca desde ahora.
        uint256 base = expiresAt[msg.sender] > block.timestamp
            ? expiresAt[msg.sender]
            : block.timestamp;

        expiresAt[msg.sender] = base + period;

        emit Subscribed(msg.sender, expiresAt[msg.sender], price);
    }

    /// @notice El owner retira todos los tokens acumulados.
    function withdraw() external onlyOwner {
        uint256 amount = token.balanceOf(address(this));
        bool ok = token.transfer(owner, amount);
        require(ok, "BotPass: retiro fallido");
        emit Withdrawn(owner, amount);
    }

    /// @notice El owner cambia el precio (en unidades del token).
    function setPrice(uint256 _newPrice) external onlyOwner {
        emit PriceChanged(price, _newPrice);
        price = _newPrice;
    }

    // ---- Lecturas (gratis, `view`) ----

    function isActive(address user) external view returns (bool) {
        return expiresAt[user] >= block.timestamp;
    }

    function timeLeft(address user) external view returns (uint256) {
        if (expiresAt[user] <= block.timestamp) return 0;
        return expiresAt[user] - block.timestamp;
    }
}

// ---------------------------------------------------------------------------
// NOTA IMPORTANTE sobre USDT real (Tether):
//
// El USDT real en Ethereum mainnet NO devuelve un bool en transfer/transferFrom
// (su firma no retorna nada). Con este código, `bool ok = token.transferFrom(...)`
// fallaría al decodificar el retorno y revertiría aun cuando la transferencia
// fue OK. Funciona perfecto con USDC y con cualquier ERC20 "bien portado"
// (como nuestro mock de test).
//
// La solución profesional es la librería SafeERC20 de OpenZeppelin
// (safeTransferFrom / safeTransfer), que maneja tanto los tokens que devuelven
// bool como los que no. Eso lo dejamos para un v2.1, para no meter una
// dependencia nueva mientras aprendemos el patrón approve + transferFrom.
// ---------------------------------------------------------------------------
