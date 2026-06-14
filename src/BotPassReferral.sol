// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title BotPass v4 — Suscripción con referidos y comisión
/// @notice Como v1 (paga en ETH), pero quien refiere a un cliente nuevo cobra
///         un % del pago. Lo recaudado NO se manda en el acto: se acredita en un
///         saldo (mapping `pending`) y cada uno lo retira cuando quiere con
///         claim() — el patrón "pull", más seguro que "push".
contract BotPassReferral {
    // ---- Estado ----

    address public owner;
    uint256 public price;        // precio por período, en wei
    uint256 public period;       // duración del período, en segundos

    // Comisión del referido en "basis points" (puntos básicos).
    // 10000 bps = 100%. Ej.: 1000 bps = 10%. Se usan bps en vez de %
    // para poder expresar fracciones (ej. 250 bps = 2,5%) sin decimales,
    // que Solidity no tiene.
    uint256 public referralBps;

    mapping(address => uint256) public expiresAt;  // vencimiento por usuario
    mapping(address => uint256) public pending;    // saldo a retirar (pull)

    // Cerrojo del reentrancy guard: 1 = abierto, 2 = trabado.
    uint256 private _locked = 1;

    // ---- Eventos ----

    event Subscribed(
        address indexed user,
        uint256 newExpiry,
        uint256 paid,
        address indexed referrer,
        uint256 commission
    );
    event Claimed(address indexed who, uint256 amount);
    event ReferralBpsChanged(uint256 oldBps, uint256 newBps);
    event PriceChanged(uint256 oldPrice, uint256 newPrice);

    // ---- Constructor ----

    constructor(uint256 _price, uint256 _period, uint256 _referralBps) {
        owner = msg.sender;
        price = _price;
        period = _period;
        _setBps(_referralBps);
    }

    // ---- Modifier ----

    modifier onlyOwner() {
        require(msg.sender == owner, "BotPass: solo el owner");
        _;
    }

    /// @notice Candado anti-reentrancy: si alguien intenta re-entrar a una
    ///         función trabada, revierte. Esto es lo que hace `nonReentrant`
    ///         de OpenZeppelin (ReentrancyGuard). Defensa extra además de CEI.
    modifier nonReentrant() {
        require(_locked == 1, "BotPass: reentrancy");
        _locked = 2;   // trabar al entrar
        _;             // cuerpo de la función
        _locked = 1;   // destrabar al salir
    }

    // ---- Admin ----

    function setReferralBps(uint256 _bps) external onlyOwner {
        _setBps(_bps);
    }

    /// @dev Helper interno reutilizado por constructor y setter.
    function _setBps(uint256 _bps) internal {
        require(_bps <= 5000, "BotPass: comision max 50%");
        emit ReferralBpsChanged(referralBps, _bps);
        referralBps = _bps;
    }

    function setPrice(uint256 _newPrice) external onlyOwner {
        emit PriceChanged(price, _newPrice);
        price = _newPrice;
    }

    // ---- Suscripción ----

    /// @notice El cliente se suscribe/renueva. `referrer` es quién lo refirió
    ///         (o address(0) si nadie). El referidor cobra `referralBps` del pago.
    function subscribe(address referrer) external payable {
        require(msg.value >= price, "BotPass: pago insuficiente");

        uint256 commission = 0;
        // Referidor válido: existe y no es uno mismo (no auto-referirse).
        if (referrer != address(0) && referrer != msg.sender) {
            commission = (msg.value * referralBps) / 10000;
            pending[referrer] += commission;
        }
        // El resto (incluido el redondeo) queda para el owner.
        pending[owner] += msg.value - commission;

        uint256 base = expiresAt[msg.sender] > block.timestamp
            ? expiresAt[msg.sender]
            : block.timestamp;
        expiresAt[msg.sender] = base + period;

        emit Subscribed(msg.sender, expiresAt[msg.sender], msg.value, referrer, commission);
    }

    /// @notice Cada quien retira su saldo acumulado (owner incluido).
    /// @dev Patrón Checks-Effects-Interactions para evitar REENTRANCY:
    ///      1) Checks: que haya algo para retirar.
    ///      2) Effects: poner el saldo en 0 ANTES de mandar la plata.
    ///      3) Interactions: recién ahí transferir.
    ///      Si se mandara la plata antes de poner el saldo en 0, un contrato
    ///      malicioso podría re-entrar a claim() y vaciar el contrato.
    ///      Además del orden CEI, le ponemos el candado `nonReentrant` como
    ///      segunda capa de defensa (cinturón y tiradores).
    function claim() external nonReentrant {
        uint256 amount = pending[msg.sender];
        require(amount > 0, "BotPass: nada para retirar");

        pending[msg.sender] = 0;                       // EFFECT (antes de enviar)
        (bool ok, ) = msg.sender.call{value: amount}(""); // INTERACTION
        require(ok, "BotPass: retiro fallido");

        emit Claimed(msg.sender, amount);
    }

    // ---- Lecturas ----

    function isActive(address user) external view returns (bool) {
        return expiresAt[user] >= block.timestamp;
    }

    function timeLeft(address user) external view returns (uint256) {
        if (expiresAt[user] <= block.timestamp) return 0;
        return expiresAt[user] - block.timestamp;
    }
}
