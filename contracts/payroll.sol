pragma solidity 0.8.5;

// SPDX-License-Identifier: LGPLv3


import './oz/IERC20.sol';
import './oz/ERC20.sol';
import './oz/ReentrancyGuard.sol';

/// @title OpolisPay
/// @notice Minimalist Contract for Crypto Payroll Payments
contract OpolisPay {
    
    address[] public supportedTokens; //Tokens that can be sent. 
    address public opolisAdmin; //Should be Opolis multi-sig for security
    address payable public destination; // Where funds are liquidated 
    address private opolisHelper; //Can be bot wallet for convenience 
    
    uint256[] public payrollIds; //List of payrollIds associated with payments
    
    event SetupComplete(address payable destination, address admin, address helper, address[] tokens);
    event Staked(address staker, address token, uint256 amount, uint256 memberId);
    event Paid(address payor, address token, uint256 payrollId, uint256 amount); 
    event OpsWithdraw(address token, uint256 payrollId, uint256 amount, bool withdrawn);
    event Sweep(address token, uint256 amount);
    event NewDestination(address destination);
    event NewAdmin(address opolisAdmin);
    event NewHelper(address newHelper);
    event NewToken(address[] newTokens);
    
    mapping (uint256 => Payroll) public payrolls; //Tracks payrolls  
    mapping (address => Stake) public stakes; // Tracks stakes
    mapping (address => uint256) public payments; //Tracks who paid payrolls
    mapping (address => bool) public whitelisted; //Tracks whitelisted tokens
    mapping (address => uint256) public tokenBalances; //Tracks token balances by token 
    
    struct Payroll {
        address payor; // Msg sender 
        address paymentToken; // Token being used to pay payroll, must be whitelisted
        uint256 payrollId; // Payroll.Id for tracking on Web2 side
        uint256 paymentAmt; // Payroll amount, should match payroll invoice amount
        bool withdrawn; // Tracks whether it's been withdrawn to Opolis wallet
    }
    
    struct Stake {
        address payor; // Msg sender 
        address paymentToken; // Should be whitelisted token or ETH (address(0)
        uint256 memberId; // Member Id for confirming member has staked
        uint256 paymentAmt; // Payment amount for confirming stake amount satisfied 
        bool withdrawn; // Confirm stake has been passed along to Opolis wallet
    }
    
    modifier onlyAdmin {
        require(msg.sender == opolisAdmin, "!permitted");
        _;
    }
    
    modifier onlyOpolis {
        require(msg.sender == opolisAdmin || msg.sender == opolisHelper, "!permitted");
        _;
    }
    
    /// @notice launches contract with a destination as the Opolis wallet, the admins, and a token whitelist
    /// @param _destination the address where payroll and stakes will be sent when withdrawn 
    /// @param _opolisAdmin the multi-sig which is the ultimate admin 
    /// @param _opolisHelper meant to allow for a bot to handle less sensitive items 
    /// @param _tokenList initial whitelist of tokens for staking and payroll 
    
    constructor (
        address payable _destination,
        address _opolisAdmin,
        address _opolisHelper,
        address[] memory _tokenList
    ) {
        destination = _destination; 
        opolisAdmin = _opolisAdmin;
        opolisHelper = _opolisHelper;
        
        for (uint256 i = 0; i < _tokenList.length; i++) {
            _addTokens(_tokenList[i]);
        }
        
        emit SetupComplete(destination, opolisAdmin, opolisHelper, _tokenList);

    }
    
    /********************************************************************************
                             CORE PAYROLL FUNCTIONS 
     *******************************************************************************/
     
     /// @notice core function for members to pay their payroll 
     /// @param token the token being used to pay for their payroll 
     /// @param amount the amount due for their payroll -- up to user / front-end to match 
     /// @param payrollId the way we'll associate payments with members' invoices 
     
    function payPayroll(address token, uint256 amount, uint256 payrollId) external returns (uint, uint) {
        
        require(whitelisted[token], "!whitelisted");
        require(payrollId !=0, "!payroll");
        require(amount !=0, "!amount");
        require(payrolls[payrollId].paymentAmt == 0, "already paid");
        
        IERC20(token).approve(address(this), amount+1); 
        IERC20(token).transferFrom(msg.sender, address(this), amount);
        
        Payroll memory payroll = Payroll({
            payor : msg.sender, 
            paymentToken : token,
            payrollId : payrollId, 
            paymentAmt : amount,
            withdrawn : false 
        });
        
        payrolls[payrollId] = payroll;
        payrollIds.push(payrollId);
        
        emit Paid(msg.sender, token, payrollId, amount); 
        return (payrollId, amount);
    }
    
    /// @notice staking function that allows for both ETH and whitelisted ERC20  
    /// @param token the token being used to stake 
    /// @param amount the amount due for staking -- up to user / front-end to match 
    /// @param memberId the way we'll associate the stake with a new member 
    
    function memberStake(address token, uint256 amount, uint256 memberId) public payable returns (uint, uint) {
        
        require(whitelisted[token] || token == address(0), "!token");
        require(memberId !=0, "!member");
        
        Stake memory stake = Stake({
            payor : msg.sender,
            paymentToken : token,
            memberId : memberId,
            paymentAmt : amount, 
            withdrawn: false
        });
        
        stakes[msg.sender] = stake;
        
        // @dev function for auto transfering out stakes 
        
        if (msg.value > 0 && token == address(0)){
            destination.transfer(msg.value);
            emit Staked(msg.sender, token, amount, memberId);
            return(memberId, msg.value);
        } else {
            IERC20(token).transfer(destination, amount);
            emit Staked(msg.sender, token, amount, memberId);
            return(memberId, amount);
        }
        
        
    }
    
    /// @notice withdraw function for admin or OpsBot to call   
    /// @param _payrollIds the paid payrolls we want to clear out 
    /// @dev we iterate through payrolls and clear them out with the funds being sent to the destination address
    
    function withdrawPayrolls(uint256[] memory _payrollIds) external onlyOpolis {
        
        require(_payrollIds.length > 0, "!payrolls");
        
        for (uint256 i = 0; i < _payrollIds.length; i++){
            
            address token = payrolls[i].paymentToken;
            uint256 amount = payrolls[i].paymentAmt;
            
            require(_payrollIds.length < 50, "too many withdraws");
            require(payrolls[i].withdrawn == false, "already withdraw");
            require(tokenBalances[token] >= amount, "!enough$$");

            _withdraw(token, balance); 
            payrolls[i].withdrawn = true;
            
            emit OpsWithdraw(token, payrolls[i].payrollId, amount, true);
        }
        
    }
    
    /// @notice clearBalance() is meant to be a safety function to be used for stuck funds or upgrades
    /// @dev will mark any non-withdrawn payrolls as withdrawn
    
    function clearBalance() external onlyAdmin {
        
        for (uint256 i = 0; i < supportedTokens.length; i++){
            address token = supportedTokens[i];
            uint256 balance = IERC20(token).balanceOf(address(this));
            
            if(balance > 0){
                _withdraw(token, balance); 
            }
            emit Sweep(token, balance);
        }
        
        for (uint256 i = 0; i < payrollIds.length; i++){
            uint256 payroll = payrollIds[i];
            
            if(!payrolls[payroll].withdrawn) {
               payrolls[payroll].withdrawn = true; 
            }
        }
    }
    
    
    /********************************************************************************
                             ADMIN FUNCTIONS 
     *******************************************************************************/

    /// @notice this function is used to adjust where member funds are sent by contract
    /// @param newDestination is the new address where funds are sent (assumes it's payable exchange address)
    /// @dev must be called by Opolis Admin multi-sig
    
    function updateDestination(address payable newDestination) external onlyAdmin returns (address){
        
        require(newDestination != address(0), "!address");
        destination = newDestination;
        
        emit NewDestination(destination);
        return destination;
    }
    
    /// @notice this function is used to replace the admin multi-sig
    /// @param newAdmin is the new admin address
    /// @dev this should always be a mulit-sig 
    
    function updateAdmin(address newAdmin) external onlyAdmin returns (address){
        
        require(newAdmin != address(0), "!address");
        opolisAdmin = newAdmin;
      
        emit NewAdmin(opolisAdmin);
        return opolisAdmin;
    }
    
    /// @notice this function is used to replace a bot 
    /// @param newHelper is the new bot address
    /// @dev this can be a hot wallet, since it has limited powers
    
    function updateHelper(address newHelper) external onlyAdmin returns (address){
        
        require(newHelper != address(0), "!address");
        opolisHelper = newHelper;
      
        emit NewHelper(opolisHelper);
        return opolisHelper;
    }
    
    /// @notice this function is used to add new whitelisted tokens
    /// @param newTokens are the tokens to be whitelisted
    /// @dev restricted to admin b/c this is a business / compliance decision 
    
    function addTokens(address[] memory newTokens) external onlyAdmin {
        
        require(newTokens.length > 0, "!list");
        
        for (uint256 i = 0; i < newTokens.length; i ++){
            _addTokens(newTokens[i]);
        }
        
         emit NewToken(newTokens);  
    }
    
    /********************************************************************************
                             INTERNAL FUNCTIONS 
     *******************************************************************************/
    
    function _addTokens(address token) internal {
        require(!whitelisted[token], "already listed");
        require(token != address(0), "!address");
        supportedTokens.push(token);
        whitelisted[token] = true;
        tokenBalances[token] = 0;
        
    }

    function _withdraw(address token, uint256 amount) internal {
        IERC20(token).transfer(destination, balance);
        tokenBalances[token] -= balance; 
    }
    
}