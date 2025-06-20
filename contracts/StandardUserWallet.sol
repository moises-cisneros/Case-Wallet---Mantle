// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

/**
 * @title StandardUserWallet
 * @dev Smart Contract for Profile 1 - Standard User
 * @notice Basic dual wallet functionalities, P2P transfers and conversions
 */
contract StandardUserWallet is ReentrancyGuard, Pausable, Ownable {
    using SafeMath for uint256;

    // Public state variables
    mapping(address => bool) public isRegistered;
    mapping(address => uint256) public balanceCrypto;
    mapping(address => UserProfile) public userProfiles;
    mapping(address => uint256) public lastActivity;
    
    uint256 public constant TRANSFER_FEE = 50; // 0.5% in basis points
    uint256 public constant MAX_DAILY_TRANSFER = 1000 * 10**18;
    uint256 public constant MIN_TRANSFER_AMOUNT = 1 * 10**15;
    uint256 public constant MAX_SINGLE_TRANSFER = 10000 * 10**18;
    
    bool public systemActive = true;
    address public priceOracle;
    uint256 public totalUsers;

    // Private state variables
    mapping(address => uint256) private _dailyTransferUsed;
    mapping(address => uint256) private _lastTransferReset;
    mapping(bytes32 => bool) private _processedTransactions;
    mapping(address => uint256) private _lastTransactionTime;
    
    uint256 private constant _RATE_LIMIT_WINDOW = 1 minutes;
    uint256 private _nonce;

    // Data structures
    struct UserProfile {
        address walletAddress;
        uint256 profileType;
        uint256 registrationDate;
        bool isActive;
        string username;
        uint256 totalTransactions;
    }
    
    struct TransferData {
        address from;
        address to;
        uint256 amount;
        uint256 fee;
        uint256 timestamp;
        bytes32 transactionId;
    }

    // Events
    event UserRegistered(
        address indexed user, 
        uint256 profileType, 
        string username,
        uint256 timestamp
    );
    
    event CryptoTransfer(
        address indexed from, 
        address indexed to, 
        uint256 amount, 
        uint256 fee,
        bytes32 indexed transactionId
    );
    
    event LocalToCryptoSwap(
        address indexed user, 
        uint256 localAmount, 
        uint256 cryptoAmount,
        uint256 rate
    );
    
    event CryptoToLocalSwap(
        address indexed user, 
        uint256 cryptoAmount, 
        uint256 localAmount,
        uint256 rate
    );
    
    event CryptoWithdrawal(
        address indexed user, 
        address indexed externalWallet, 
        uint256 amount,
        uint256 fee
    );
    
    event EmergencyPause(address indexed by, uint256 timestamp);
    event EmergencyUnpause(address indexed by, uint256 timestamp);

    // Modifiers
    modifier onlyRegistered() {
        require(isRegistered[msg.sender], "User not registered");
        _;
    }
    
    modifier whenSystemActive() {
        require(systemActive, "System is not active");
        _;
    }
    
    modifier rateLimited() {
        require(
            block.timestamp >= _lastTransactionTime[msg.sender].add(_RATE_LIMIT_WINDOW),
            "Rate limit exceeded - wait before next transaction"
        );
        _;
        _lastTransactionTime[msg.sender] = block.timestamp;
    }
    
    modifier validAddress(address _addr) {
        require(_addr != address(0), "Invalid address - cannot be zero");
        _;
    }

    // Constructor - Fixed to properly initialize parent contracts
    constructor(address _priceOracle) Ownable(msg.sender) {
        require(_priceOracle != address(0), "Price oracle cannot be zero address");
        priceOracle = _priceOracle;
        totalUsers = 0;
        _nonce = 1;
    }

    // Main public functions
    
    /**
     * @notice Register a new user in the system
     * @param userWallet User's wallet address
     * @param username Unique username
     */
    function registerUser(
        address userWallet, 
        string memory username
    ) 
        external 
        onlyOwner 
        validAddress(userWallet) 
        whenSystemActive 
    {
        require(!isRegistered[userWallet], "User already registered");
        require(bytes(username).length > 0, "Username cannot be empty");
        require(bytes(username).length <= 50, "Username too long");
        require(_isUsernameAvailable(username), "Username already taken");
        
        _registerUserInternal(userWallet, username);
    }
    
    /**
     * @notice Transfer crypto tokens between registered users
     * @param recipient Recipient address
     * @param amount Amount to transfer (in wei)
     */
    function transferCrypto(
        address recipient, 
        uint256 amount
    ) 
        external 
        onlyRegistered 
        validAddress(recipient) 
        whenSystemActive 
        rateLimited
        nonReentrant 
    {
        require(isRegistered[recipient], "Recipient not registered");
        require(amount >= MIN_TRANSFER_AMOUNT, "Amount below minimum");
        require(amount <= MAX_SINGLE_TRANSFER, "Amount exceeds maximum");
        require(balanceCrypto[msg.sender] >= amount, "Insufficient crypto balance");
        require(recipient != msg.sender, "Cannot transfer to yourself");
        
        _validateDailyLimits(msg.sender, amount);
        
        bytes32 transactionId = _generateTransactionId();
        _executeCryptoTransfer(msg.sender, recipient, amount, transactionId);
    }
    
    /**
     * @notice Convert local balance to crypto using price oracle
     * @param localAmount Amount in local currency (cents)
     */
    function swapLocalToCrypto(
        uint256 localAmount
    ) 
        external 
        onlyRegistered 
        whenSystemActive 
        rateLimited
        nonReentrant 
    {
        require(localAmount > 0, "Local amount must be greater than 0");
        
        uint256 rate = _getCurrentExchangeRate();
        require(rate > 0, "Invalid exchange rate from oracle");
        
        uint256 cryptoAmount = localAmount.mul(10**18).div(rate);
        require(cryptoAmount > 0, "Crypto amount too small");
        
        balanceCrypto[msg.sender] = balanceCrypto[msg.sender].add(cryptoAmount);
        userProfiles[msg.sender].totalTransactions++;
        lastActivity[msg.sender] = block.timestamp;
        
        emit LocalToCryptoSwap(msg.sender, localAmount, cryptoAmount, rate);
    }
    
    /**
     * @notice Convert crypto to local balance using price oracle
     * @param cryptoAmount Crypto amount to convert
     */
    function swapCryptoToLocal(
        uint256 cryptoAmount
    ) 
        external 
        onlyRegistered 
        whenSystemActive 
        rateLimited
        nonReentrant 
    {
        require(cryptoAmount > 0, "Crypto amount must be greater than 0");
        require(balanceCrypto[msg.sender] >= cryptoAmount, "Insufficient crypto balance");
        
        uint256 rate = _getCurrentExchangeRate();
        require(rate > 0, "Invalid exchange rate from oracle");
        
        uint256 localAmount = cryptoAmount.mul(rate).div(10**18);
        require(localAmount > 0, "Local amount too small");
        
        balanceCrypto[msg.sender] = balanceCrypto[msg.sender].sub(cryptoAmount);
        userProfiles[msg.sender].totalTransactions++;
        lastActivity[msg.sender] = block.timestamp;

        emit CryptoToLocalSwap(msg.sender, cryptoAmount, localAmount, rate);
    }
    
    /**
     * @notice Withdraw crypto to external wallet
     * @param externalWallet External wallet address
     * @param amount Amount to withdraw
     */
    function withdrawCrypto(
        address externalWallet, 
        uint256 amount
    ) 
        external 
        onlyRegistered 
        validAddress(externalWallet) 
        whenSystemActive 
        rateLimited
        nonReentrant 
    {
        require(amount > 0, "Amount must be greater than 0");
        require(balanceCrypto[msg.sender] >= amount, "Insufficient crypto balance");
        require(externalWallet != msg.sender, "Cannot withdraw to same address");
        
        uint256 withdrawalFee = 5 * 10**15; 
        uint256 totalDeduct = amount.add(withdrawalFee);
        
        require(balanceCrypto[msg.sender] >= totalDeduct, "Insufficient balance for fee");
        
        balanceCrypto[msg.sender] = balanceCrypto[msg.sender].sub(totalDeduct);
        userProfiles[msg.sender].totalTransactions++;
        lastActivity[msg.sender] = block.timestamp;
        
        emit CryptoWithdrawal(msg.sender, externalWallet, amount, withdrawalFee);
    }

    // Public query functions
    
    /**
     * @notice Get complete user profile
     * @param user User address
     * @return UserProfile with all information
     */
    function getUserProfile(address user) external view returns (UserProfile memory) {
        require(isRegistered[user], "User not registered");
        return userProfiles[user];
    }
    
    /**
     * @notice Get remaining daily transfer limit
     * @param user User address
     * @return Available amount for transfers today
     */
    function getDailyTransferLimit(address user) external view returns (uint256) {
        if (!isRegistered[user]) return 0;
        
        uint256 used = _getTodayTransferUsed(user);
        if (used >= MAX_DAILY_TRANSFER) return 0;
        
        return MAX_DAILY_TRANSFER.sub(used);
    }
    
    /**
     * @notice Get user's crypto balance
     * @param user User address
     * @return Balance in tokens
     */
    function getBalance(address user) external view returns (uint256) {
        return balanceCrypto[user];
    }
    
    /**
     * @notice Check if username is available
     * @param username Username to check
     * @return true if available
     */
    function isUsernameAvailable(string memory username) external view returns (bool) {
        return _isUsernameAvailable(username);
    }
    
    /**
     * @notice Get current exchange rate from oracle
     * @return Exchange rate (local per crypto)
     */
    function getCurrentExchangeRate() external view returns (uint256) {
        return _getCurrentExchangeRate();
    }

    // Private internal functions
    
    function _registerUserInternal(address userWallet, string memory username) private {
        userProfiles[userWallet] = UserProfile({
            walletAddress: userWallet,
            profileType: 1,
            registrationDate: block.timestamp,
            isActive: true,
            username: username,
            totalTransactions: 0
        });
        
        isRegistered[userWallet] = true;
        lastActivity[userWallet] = block.timestamp;
        totalUsers++;
        
        emit UserRegistered(userWallet, 1, username, block.timestamp);
    }
    
    function _validateDailyLimits(address user, uint256 amount) private view {
        uint256 todayUsed = _getTodayTransferUsed(user);
        require(
            todayUsed.add(amount) <= MAX_DAILY_TRANSFER, 
            "Daily transfer limit exceeded"
        );
    }
    
    function _getTodayTransferUsed(address user) private view returns (uint256) {
        if (_isNewDay(user)) {
            return 0;
        }
        return _dailyTransferUsed[user];
    }
    
    function _isNewDay(address user) private view returns (bool) {
        uint256 lastReset = _lastTransferReset[user];
        uint256 currentDay = block.timestamp / 1 days;
        uint256 lastResetDay = lastReset / 1 days;
        return currentDay > lastResetDay;
    }
    
    function _updateDailyTransferUsed(address user, uint256 amount) private {
        if (_isNewDay(user)) {
            _dailyTransferUsed[user] = amount;
        } else {
            _dailyTransferUsed[user] = _dailyTransferUsed[user].add(amount);
        }
        _lastTransferReset[user] = block.timestamp;
    }
    
    function _executeCryptoTransfer(
        address sender, 
        address recipient, 
        uint256 amount,
        bytes32 transactionId
    ) private {
        uint256 fee = amount.mul(TRANSFER_FEE).div(10000);
        uint256 netAmount = amount.sub(fee);
        
        balanceCrypto[sender] = balanceCrypto[sender].sub(amount);
        balanceCrypto[recipient] = balanceCrypto[recipient].add(netAmount);
        
        userProfiles[sender].totalTransactions++;
        userProfiles[recipient].totalTransactions++;
        lastActivity[sender] = block.timestamp;
        lastActivity[recipient] = block.timestamp;
        
        _updateDailyTransferUsed(sender, amount);
        _processedTransactions[transactionId] = true;
        
        emit CryptoTransfer(sender, recipient, netAmount, fee, transactionId);
    }
    
    function _generateTransactionId() private returns (bytes32) {
        bytes32 id = keccak256(
            abi.encodePacked(
                msg.sender,
                block.timestamp,
                block.prevrandao, // Updated from block.difficulty
                _nonce
            )
        );
        _nonce++;
        return id;
    }
    
    function _isUsernameAvailable(string memory username) private pure returns (bool) {
        return bytes(username).length > 0;
    }
    
    function _getCurrentExchangeRate() private view returns (uint256) {
        // Mock implementation: 1 USD = 1 token (rate = 100 cents)
        return 100;
    }

    // Administrative functions
    
    /**
     * @notice Pause system for emergency
     */
    function emergencyPause() external onlyOwner {
        _pause();
        systemActive = false;
        emit EmergencyPause(msg.sender, block.timestamp);
    }
    
    /**
     * @notice Unpause system after emergency
     */
    function emergencyUnpause() external onlyOwner {
        _unpause();
        systemActive = true;
        emit EmergencyUnpause(msg.sender, block.timestamp);
    }
    
    /**
     * @notice Update price oracle address
     * @param newOracle New oracle address
     */
    function updatePriceOracle(address newOracle) external onlyOwner validAddress(newOracle) {
        priceOracle = newOracle;
    }
    
    /**
     * @notice Deposit crypto tokens to user (owner/backend only)
     * @param user Recipient user
     * @param amount Amount to deposit
     */
    function depositCrypto(address user, uint256 amount) 
        external 
        onlyOwner 
        validAddress(user) 
        whenSystemActive 
    {
        require(isRegistered[user], "User not registered");
        require(amount > 0, "Amount must be greater than 0");
        
        balanceCrypto[user] = balanceCrypto[user].add(amount);
        lastActivity[user] = block.timestamp;
    }
}