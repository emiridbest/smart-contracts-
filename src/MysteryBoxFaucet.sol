// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title TokenFaucet
 * @dev A faucet contract that distributes ERC20 tokens with rate limiting and access controls
 */
contract TokenFaucet is Ownable, ReentrancyGuard {
    
    // State variables
    IERC20 public token;
    uint256 public minPercent;
    uint256 public maxPercent;
    uint256 public cooldownPeriod;
    
    // Mapping to track last request time for each user
    mapping(address => uint256) public lastRequestTime;
    
    // Events
    event TokensRequested(address indexed user, uint256 amount);
    event TokensDeposited(address indexed user, uint256 amount);
    
    /**
     * @dev Constructor
     * @param _token Address of the ERC20 token to distribute
     * @param _minPercent Minimum percentage of balance that can be requested
     * @param _maxPercent Maximum percentage of balance that can be requested
     * @param _cooldownPeriod Time in seconds between requests for the same user
     */
    constructor(
        address _token,
        uint256 _minPercent,
        uint256 _maxPercent,
        uint256 _cooldownPeriod
    ) Ownable(msg.sender) {
        require(_token != address(0), "Invalid token address");
        require(_minPercent < _maxPercent, "Min must be less than max");
        require(_maxPercent <= 50, "Max percentage cannot exceed 50%");
        
        token = IERC20(_token);
        minPercent = _minPercent;
        maxPercent = _maxPercent;
        cooldownPeriod = _cooldownPeriod;
    }
    
    /**
     * @dev Request tokens from the faucet
     * @param amount Amount of tokens to request
     */
    function claim(uint256 amount) external nonReentrant {
        uint256 balance = getBalance();
        require(balance > 0, "Faucet is empty");
        
        // Check cooldown period
        require(
            block.timestamp >= lastRequestTime[msg.sender] + cooldownPeriod,
            "Cooldown period not elapsed"
        );
        
        // Calculate min and max allowed amounts based on current balance
        uint256 minAmount = (balance * minPercent) / 100;
        uint256 maxAmount = (balance * maxPercent) / 100;
        
        require(amount >= minAmount, "Amount too small");
        require(amount <= maxAmount, "Amount too large");
        
        // Update last request time
        lastRequestTime[msg.sender] = block.timestamp;
        
        // Transfer tokens
        bool success = token.transfer(msg.sender, amount);
        require(success, "Token transfer failed");
        
        emit TokensRequested(msg.sender, amount);
    }
    
    /**
     * @dev Deposit tokens into the faucet
     * @param amount Amount of tokens to deposit
     */
    function depositTokens(uint256 amount) external nonReentrant {
        require(amount > 0, "Amount must be greater than 0");
        
        bool success = token.transferFrom(msg.sender, address(this), amount);
        require(success, "Token transfer failed");
        
        emit TokensDeposited(msg.sender, amount);
    }
    
    /**
     * @dev Withdraw tokens from the faucet (owner only)
     * @param amount Amount of tokens to withdraw
     */
    function withdrawTokens(uint256 amount) external onlyOwner {
        uint256 balance = getBalance();
        require(amount <= balance, "Insufficient balance");
        
        bool success = token.transfer(owner(), amount);
        require(success, "Token transfer failed");
    }
    
    /**
     * @dev Set the request limits (owner only)
     * @param _minPercent New minimum percentage
     * @param _maxPercent New maximum percentage
     */
    function setRequestLimits(uint256 _minPercent, uint256 _maxPercent) external onlyOwner {
        require(_minPercent < _maxPercent, "Min must be less than max");
        require(_maxPercent <= 50, "Max percentage cannot exceed 50%");
        
        minPercent = _minPercent;
        maxPercent = _maxPercent;
    }
    
    /**
     * @dev Set the cooldown period (owner only)
     * @param _cooldownPeriod New cooldown period in seconds
     */
    function setCooldownPeriod(uint256 _cooldownPeriod) external onlyOwner {
        cooldownPeriod = _cooldownPeriod;
    }
    
    /**
     * @dev Get the current token balance of the faucet
     * @return Current balance
     */
    function getBalance() public view returns (uint256) {
        return token.balanceOf(address(this));
    }
    
    /**
     * @dev Get the minimum amount that can be requested
     * @return Minimum request amount based on current balance
     */
    function getMinRequestAmount() external view returns (uint256) {
        uint256 balance = getBalance();
        return (balance * minPercent) / 100;
    }
    
    /**
     * @dev Get the maximum amount that can be requested
     * @return Maximum request amount based on current balance
     */
    function getMaxRequestAmount() external view returns (uint256) {
        uint256 balance = getBalance();
        return (balance * maxPercent) / 100;
    }
    
    /**
     * @dev Check if a user can make a request
     * @param user Address to check
     * @return True if user can make a request
     */
    function canRequest(address user) external view returns (bool) {
        return block.timestamp >= lastRequestTime[user] + cooldownPeriod;
    }
    
    /**
     * @dev Get remaining cooldown time for a user
     * @param user Address to check
     * @return Remaining cooldown time in seconds
     */
    function getRemainingCooldown(address user) external view returns (uint256) {
        uint256 nextRequestTime = lastRequestTime[user] + cooldownPeriod;
        if (block.timestamp >= nextRequestTime) {
            return 0;
        }
        return nextRequestTime - block.timestamp;
    }
}