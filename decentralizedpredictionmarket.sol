// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract Project {
    // Struct to represent a prediction market
    struct Market {
        uint256 id;
        string question;
        string[] options;
        uint256 endTime;
        bool resolved;
        uint256 winningOption;
        address creator;
        uint256 totalPool;
        mapping(uint256 => uint256) optionPools; // option index => total bet amount
        mapping(address => mapping(uint256 => uint256)) userBets; // user => option => amount
    }
    
    // State variables
    mapping(uint256 => Market) public markets;
    uint256 public marketCounter;
    uint256 public constant PLATFORM_FEE = 2; // 2% platform fee
    address public owner;
    
    // Events
    event MarketCreated(uint256 indexed marketId, string question, address creator);
    event BetPlaced(uint256 indexed marketId, address indexed user, uint256 option, uint256 amount);
    event MarketResolved(uint256 indexed marketId, uint256 winningOption);
    event WinningsWithdrawn(uint256 indexed marketId, address indexed user, uint256 amount);
    
    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    modifier marketExists(uint256 _marketId) {
        require(_marketId < marketCounter, "Market does not exist");
        _;
    }
    
    modifier marketActive(uint256 _marketId) {
        require(block.timestamp < markets[_marketId].endTime, "Market has ended");
        require(!markets[_marketId].resolved, "Market already resolved");
        _;
    }
    
    modifier marketEnded(uint256 _marketId) {
        require(block.timestamp >= markets[_marketId].endTime, "Market still active");
        _;
    }
    
    constructor() {
        owner = msg.sender;
    }
    
    // Core Function 1: Create a new prediction market
    function createMarket(
        string memory _question,
        string[] memory _options,
        uint256 _duration
    ) external returns (uint256) {
        require(_options.length >= 2, "At least 2 options required");
        require(_duration > 0, "Duration must be positive");
        require(bytes(_question).length > 0, "Question cannot be empty");
        
        uint256 marketId = marketCounter++;
        Market storage newMarket = markets[marketId];
        
        newMarket.id = marketId;
        newMarket.question = _question;
        newMarket.options = _options;
        newMarket.endTime = block.timestamp + _duration;
        newMarket.resolved = false;
        newMarket.creator = msg.sender;
        newMarket.totalPool = 0;
        
        emit MarketCreated(marketId, _question, msg.sender);
        return marketId;
    }
    
    // Core Function 2: Place a bet on a prediction market
    function placeBet(uint256 _marketId, uint256 _option) 
        external 
        payable 
        marketExists(_marketId) 
        marketActive(_marketId) 
    {
        require(msg.value > 0, "Bet amount must be greater than 0");
        require(_option < markets[_marketId].options.length, "Invalid option");
        
        Market storage market = markets[_marketId];
        
        // Update user's bet for this option
        market.userBets[msg.sender][_option] += msg.value;
        
        // Update option pool
        market.optionPools[_option] += msg.value;
        
        // Update total pool
        market.totalPool += msg.value;
        
        emit BetPlaced(_marketId, msg.sender, _option, msg.value);
    }
    
    // Core Function 3: Resolve market and distribute winnings
    function resolveMarket(uint256 _marketId, uint256 _winningOption) 
        external 
        onlyOwner 
        marketExists(_marketId) 
        marketEnded(_marketId) 
    {
        require(!markets[_marketId].resolved, "Market already resolved");
        require(_winningOption < markets[_marketId].options.length, "Invalid winning option");
        
        Market storage market = markets[_marketId];
        market.resolved = true;
        market.winningOption = _winningOption;
        
        emit MarketResolved(_marketId, _winningOption);
    }
    
    // Function to withdraw winnings after market resolution
    function withdrawWinnings(uint256 _marketId) 
        external 
        marketExists(_marketId) 
    {
        require(markets[_marketId].resolved, "Market not resolved yet");
        
        Market storage market = markets[_marketId];
        uint256 userBetAmount = market.userBets[msg.sender][market.winningOption];
        require(userBetAmount > 0, "No winning bet found");
        
        // Calculate winnings
        uint256 winningPool = market.optionPools[market.winningOption];
        uint256 totalAfterFee = market.totalPool * (100 - PLATFORM_FEE) / 100;
        uint256 userWinnings = (userBetAmount * totalAfterFee) / winningPool;
        
        // Reset user's bet to prevent double withdrawal
        market.userBets[msg.sender][market.winningOption] = 0;
        
        // Transfer winnings
        payable(msg.sender).transfer(userWinnings);
        
        emit WinningsWithdrawn(_marketId, msg.sender, userWinnings);
    }
    
    // View functions
    function getMarketDetails(uint256 _marketId) 
        external 
        view 
        marketExists(_marketId) 
        returns (
            string memory question,
            string[] memory options,
            uint256 endTime,
            bool resolved,
            uint256 winningOption,
            address creator,
            uint256 totalPool
        ) 
    {
        Market storage market = markets[_marketId];
        return (
            market.question,
            market.options,
            market.endTime,
            market.resolved,
            market.winningOption,
            market.creator,
            market.totalPool
        );
    }
    
    function getUserBet(uint256 _marketId, address _user, uint256 _option) 
        external 
        view 
        marketExists(_marketId) 
        returns (uint256) 
    {
        return markets[_marketId].userBets[_user][_option];
    }
    
    function getOptionPool(uint256 _marketId, uint256 _option) 
        external 
        view 
        marketExists(_marketId) 
        returns (uint256) 
    {
        return markets[_marketId].optionPools[_option];
    }
    
    // Owner function to withdraw platform fees
    function withdrawPlatformFees() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No fees to withdraw");
        payable(owner).transfer(balance);
    }
}
