pragma solidity 0.8.5;

// SPDX-License-Identifier: LGPLv3

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/// @notice custom errors for revert statements

/// @dev requires privileged access
error NotPermitted();

/// @dev not a whitelisted token
error NotWhitelisted();

/// @dev payroll id equals zero
error InvalidPayroll();

/// @dev amount equals zero
error InvalidAmount();

/// @dev payroll has already been paid
error AlreadyPaid();

/// @dev sender is not a member
error NotMember();

/// @dev stake must be a non zero amount of whitelisted token
/// or non zero amount of eth
error InvalidStake();

/// @dev sender has already staked
error AlreadyStaked();

/// @dev setting one of the role to zero address
error ZeroAddress();

/// @dev whitelisting and empty list of tokens
error ZeroTokens();

/// @dev token has already been whitelisted
error AlreadyWhitelisted();

/// @dev sending eth directly to contract address
error DirectTransfer();

/// @title OpolisPay
/// @notice Minimalist Contract for Crypto Payroll Payments
contract OpolisPay {
    
    address[] public supportedTokens; //Tokens that can be sent. 
    address public opolisAdmin; //Should be Opolis multi-sig for security
    address payable public destination; // Where funds are liquidated 
    address public opolisHelper; //Can be bot wallet for convenience 
    
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
    
    mapping (uint256 => uint256) public payrolls; //Tracks payrolls  
    mapping (address => uint256) public stakes; // Tracks stakes
    mapping (address => bool) public whitelisted; //Tracks whitelisted tokens
    
    modifier onlyAdmin {
        if(msg.sender != opolisAdmin) revert NotPermitted();
        _;
    }
    
    modifier onlyOpolis {
        if (!(msg.sender == opolisAdmin || msg.sender == opolisHelper)) revert NotPermitted();
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
     
    function payPayroll(address token, uint256 amount, uint256 payrollId) external {
        
        if (!whitelisted[token]) revert NotWhitelisted();
        if (payrollId == 0) revert InvalidPayroll();
        if (amount == 0) revert InvalidAmount();
        if (payrolls[payrollId] != 0) revert AlreadyPaid();
        
        IERC20(token).transferFrom(msg.sender, address(this), amount);
        
        payrolls[payrollId] = amount;
        
        emit Paid(msg.sender, token, payrollId, amount); 
    }
    
    /// @notice staking function that allows for both ETH and whitelisted ERC20  
    /// @param token the token being used to stake 
    /// @param amount the amount due for staking -- up to user / front-end to match 
    /// @param memberId the way we'll associate the stake with a new member 
    
    function memberStake(address token, uint256 amount, uint256 memberId) public payable {
        if (
            !(
                (whitelisted[token] && amount !=0) || (token == address(0) && msg.value != 0)
            )
        ) revert InvalidStake();
        if (memberId == 0) revert NotMember();
        if (stakes[msg.sender] != 0) revert AlreadyStaked();
        
        stakes[msg.sender] = amount;
        
        // @dev function for auto transfering out stakes 

        if (msg.value > 0 && token == address(0)){
            destination.transfer(msg.value);
        } else {
            IERC20(token).transferFrom(msg.sender, destination, amount);
        }
        
        emit Staked(msg.sender, token, amount, memberId);
    }

    // /// @notice withdraw function for admin or OpsBot to call   
    // /// @param _payrollIds the paid payrolls we want to clear out 
    // /// @dev we iterate through payrolls and clear them out with the funds being sent to the destination address
    
    // function withdrawPayrolls(uint256[] memory _payrollIds) external onlyOpolis {
        
    //     require(_payrollIds.length > 0, "!payrolls");
    //     require(_payrollIds.length < 50, "too many withdraws");
        
    //     for (uint8 i = 0; i < _payrollIds.length; i++){
    //         uint256 idx = _payrollIds[i];
    //         address token = payrolls[idx].paymentToken;
    //         uint256 amount = payrolls[idx].paymentAmt;
            
    //         if (!payrolls[idx].withdrawn) {
    //             _withdraw(token, amount); 
    //             payrolls[idx].withdrawn = true;
                
    //             emit OpsWithdraw(token, payrolls[idx].payrollId, amount, true);
    //         }
    //     }
        
    // }
    
    /// @notice clearBalance() is meant to be a safety function to be used for stuck funds or upgrades
    /// @dev will mark any non-withdrawn payrolls as withdrawn
    
    function clearBalance() public onlyAdmin {
        
        for (uint256 i = 0; i < supportedTokens.length; i++){
            address token = supportedTokens[i];
            uint256 balance = IERC20(token).balanceOf(address(this));
            
            if(balance > 0){
                _withdraw(token, balance); 
            }
            emit Sweep(token, balance);
        }

    }

    /// @notice fallback function to prevent accidental ether transfers
    /// @dev if someone tries to send ether directly to the contract the tx will fail

    receive() external payable {
        revert DirectTransfer();
    }
    
    
    /********************************************************************************
                             ADMIN FUNCTIONS 
     *******************************************************************************/

    /// @notice this function is used to adjust where member funds are sent by contract
    /// @param newDestination is the new address where funds are sent (assumes it's payable exchange address)
    /// @dev must be called by Opolis Admin multi-sig
    
    function updateDestination(address payable newDestination) external onlyAdmin returns (address){
        
        if (newDestination == address(0)) revert ZeroAddress();
        destination = newDestination;
        
        emit NewDestination(destination);
        return destination;
    }
    
    /// @notice this function is used to replace the admin multi-sig
    /// @param newAdmin is the new admin address
    /// @dev this should always be a mulit-sig 
    
    function updateAdmin(address newAdmin) external onlyAdmin returns (address){
        
        if (newAdmin == address(0)) revert ZeroAddress();
        opolisAdmin = newAdmin;
      
        emit NewAdmin(opolisAdmin);
        return opolisAdmin;
    }
    
    /// @notice this function is used to replace a bot 
    /// @param newHelper is the new bot address
    /// @dev this can be a hot wallet, since it has limited powers
    
    function updateHelper(address newHelper) external onlyAdmin returns (address){
        
        if (newHelper == address(0)) revert ZeroAddress();
        opolisHelper = newHelper;
      
        emit NewHelper(opolisHelper);
        return opolisHelper;
    }
    
    /// @notice this function is used to add new whitelisted tokens
    /// @param newTokens are the tokens to be whitelisted
    /// @dev restricted to admin b/c this is a business / compliance decision 
    
    function addTokens(address[] memory newTokens) external onlyAdmin {
        
        if (newTokens.length == 0) revert ZeroTokens();
        
        for (uint256 i = 0; i < newTokens.length; i ++){
            _addTokens(newTokens[i]);
        }
        
         emit NewToken(newTokens);  
    }
    
    /********************************************************************************
                             INTERNAL FUNCTIONS 
     *******************************************************************************/
    
    function _addTokens(address token) internal {
        if (whitelisted[token]) revert AlreadyWhitelisted();
        if (token == address(0)) revert ZeroAddress();
        supportedTokens.push(token);
        whitelisted[token] = true;
        
    }

    function _withdraw(address token, uint256 amount) internal {
        IERC20(token).transfer(destination, amount);
    }
    
}
