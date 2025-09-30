// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title BaseFaucet
 * @dev A contract that allows users to claim random amounts of usdc tokens
 * The contract must be funded with usdc tokens by the owner
 */
contract BaseFaucet is Ownable, ReentrancyGuard {
    // The usdc token contract
    IERC20 public usdcToken;
    
    // Authorized AI wallet that can make claims on behalf of users
    address public authorizedAI;
    
    // Mapping to track when a destination address last received tokens
    mapping(address => uint256) public lastReceiveTime;
    
    // Events
    event FaucetFunded(address indexed funder, uint256 amount);
    event RewardClaimed(address indexed claimer, address indexed recipient, uint256 amount);
    event AuthorizedAIUpdated(address indexed oldAI, address indexed newAI);
    
    modifier onlyAuthorizedAI() {
        require(msg.sender == authorizedAI, "Only authorized AI can claim");
        _;
    }
    
    /**
     * @dev Constructor sets the usdc token address and authorized AI
     * @param _usdcToken The address of the usdc token contract
     * @param _authorizedAI The address of the authorized AI wallet
     */
    constructor(address _usdcToken, address _authorizedAI) Ownable(msg.sender) {
        usdcToken = IERC20(_usdcToken);
        authorizedAI = _authorizedAI;
    }
    
    /**
     * @dev Get the current balance of the faucet
     * @return The balance of usdc tokens in the contract
     */
    function getFaucetBalance() public view returns (uint256) {
        return usdcToken.balanceOf(address(this));
    }
    
    /**
     * @dev Sets the authorized AI address (only owner)
     * @param _authorizedAI The new authorized AI address
     */
    function setAuthorizedAI(address _authorizedAI) external onlyOwner {
        require(_authorizedAI != address(0), "Invalid AI address");
        address oldAI = authorizedAI;
        authorizedAI = _authorizedAI;
        emit AuthorizedAIUpdated(oldAI, _authorizedAI);
    }

    /**
     * @dev Allows authorized AI to claim tokens for a user
     * @param recipient The address that will receive the tokens
     * @param randomPercentage Random percentage between 1-20 to claim
     * @return amount The amount of tokens claimed
     */
    function claimForUser(address recipient, uint256 randomPercentage) external onlyAuthorizedAI nonReentrant returns (uint256) {
        require(recipient != address(0), "Invalid recipient address");
        require(block.timestamp >= lastReceiveTime[recipient] + 24 hours, "Must wait 24 hours between claims");
        require(randomPercentage >= 1 && randomPercentage <= 20, "Percentage must be between 1-20");
        
        uint256 balance = usdcToken.balanceOf(address(this));
        require(balance > 0, "Faucet is empty");
        
        uint256 claimAmount = (balance * randomPercentage) / 100;
        require(claimAmount > 0, "Claim amount too small");
        
        lastReceiveTime[recipient] = block.timestamp;
        
        require(usdcToken.transfer(recipient, claimAmount), "Token transfer failed");
        
        emit RewardClaimed(msg.sender, recipient, claimAmount);
        return claimAmount;
    }

    /**
     * @dev Allows users to directly claim tokens (with random percentage between 1-20%)
     * @param randomPercentage Random percentage between 1-20 to claim
     * @return amount The amount of tokens claimed
     */
    function claimTokens(uint256 randomPercentage) external nonReentrant returns (uint256) {
        require(block.timestamp >= lastReceiveTime[msg.sender] + 24 hours, "Must wait 24 hours between claims");
        require(randomPercentage >= 1 && randomPercentage <= 20, "Percentage must be between 1-20");
        
        uint256 balance = usdcToken.balanceOf(address(this));
        require(balance > 0, "Faucet is empty");
        
        uint256 claimAmount = (balance * randomPercentage) / 100;
        require(claimAmount > 0, "Claim amount too small");
        
        lastReceiveTime[msg.sender] = block.timestamp;
        
        require(usdcToken.transfer(msg.sender, claimAmount), "Token transfer failed");
        
        emit RewardClaimed(msg.sender, msg.sender, claimAmount);
        return claimAmount;
    }

    /**
     * @dev Get time until user can claim again
     * @param user The user address to check
     * @return Time in seconds until next claim is allowed
     */
    function getTimeUntilNextClaim(address user) public view returns (uint256) {
        uint256 nextClaimTime = lastReceiveTime[user] + 24 hours;
        if (block.timestamp >= nextClaimTime) {
            return 0;
        }
        return nextClaimTime - block.timestamp;
    }

    /**
     * @dev Fund the faucet with usdc tokens
     * @param _amount The amount of usdc tokens to add to the faucet
     */
    function fundFaucet(uint256 _amount) external nonReentrant  {
        require(_amount > 0, "Amount must be greater than 0");
        
        // Transfer tokens from sender to this contract
        bool success = usdcToken.transferFrom(msg.sender, address(this), _amount);
        require(success, "Token transfer failed");
        
        emit FaucetFunded(msg.sender, _amount);
    }
    
    /**
     * @dev Withdraw tokens in case of emergency
     * @param _amount The amount of tokens to withdraw
     */
    function emergencyWithdraw(uint256 _amount) external onlyOwner {
        uint256 faucetBalance = getFaucetBalance();
        require(_amount <= faucetBalance, "Insufficient balance");
        
        bool success = usdcToken.transfer(owner(), _amount);
        require(success, "Token transfer failed");
    }
}
