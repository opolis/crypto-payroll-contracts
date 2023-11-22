pragma solidity 0.8.5;

// SPDX-License-Identifier: LGPLv3
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/// @notice custom errors for revert statements

/// @dev requires privileged access
error NotPermitted();

/// @dev not a whitelisted token
error NotWhitelisted();

/// @dev payroll id equals zero
error InvalidPayroll();

/// @dev payroll id used
error DuplicatePayroll();

/// @dev amount equals zero
error InvalidAmount();

/// @dev sender is not a member
error NotMember();

/// @dev stake must be a non zero amount of whitelisted token
/// or non zero amount of eth
error InvalidStake();

/// @dev stake must be a non zero amount of whitelisted token
/// or non zero amount of eth
error InvalidWithdraw();

/// @dev setting one of the role to zero address
error ZeroAddress();

/// @dev withdrawing non whitelisted token
error InvalidToken();

/// @dev whitelisting and empty list of tokens
error ZeroTokens();

/// @dev token has already been whitelisted
error AlreadyWhitelisted();

/// @dev sending eth directly to contract address
error DirectTransfer();

/// @dev token and destination length mismatch
error LengthMismatch();

/// @title OpolisPay
/// @notice Minimalist Contract for Crypto Payroll Payments
contract OpolisPay is ReentrancyGuard {
    using SafeERC20 for IERC20;

    address internal constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address internal constant ZERO = address(0);

    address[] public supportedTokens; //Tokens that can be sent.
    address private opolisAdmin; //Should be Opolis multi-sig for security
    address private opolisHelper; //Can be bot wallet for convenience
    address private ethLiquidation; //Address for ETH liquidations

    event SetupComplete(
        address indexed admin,
        address indexed helper,
        address ethLiquidation,
        address[] tokens,
        address[] liqDestinations
    );
    event Staked(
        address indexed staker, address indexed token, uint256 amount, uint256 indexed memberId, uint256 stakeNumber
    );
    event Paid(address indexed payor, address indexed token, uint256 indexed payrollId, uint256 amount);
    event OpsPayrollWithdraw(address indexed token, uint256 indexed payrollId, uint256 amount);
    event OpsStakeWithdraw(address indexed token, uint256 indexed stakeId, uint256 stakeNumber, uint256 amount);
    event Sweep(address indexed token, uint256 amount);
    event NewDestination(address indexed oldDestination, address indexed token, address indexed destination);
    event NewAdmin(address indexed oldAdmin, address indexed opolisAdmin);
    event NewHelper(address indexed oldHelper, address indexed newHelper);
    event NewTokens(address[] newTokens, address[] newDestinations);

    mapping(uint256 => uint256) private stakes; //Tracks used stake ids
    mapping(uint256 => bool) private payrollIds; //Tracks used payroll ids
    mapping(uint256 => bool) public payrollWithdrawn; //Tracks payroll withdrawals
    mapping(uint256 => uint256) public stakeWithdrawn; //Tracks stake withdrawals
    mapping(address => bool) public whitelisted; //Tracks whitelisted tokens
    mapping(address => address) public liqDestinations; //Tracks liquidation destinations for tokens

    modifier onlyAdmin() {
        _checkAdmin();
        _;
    }

    modifier onlyOpolis() {
        if (!(msg.sender == opolisAdmin || msg.sender == opolisHelper)) {
            revert NotPermitted();
        }
        _;
    }

    /// @notice launches contract with a destination as the Opolis wallet, the admins, and a token whitelist
    /// @param _opolisAdmin the multi-sig which is the ultimate admin
    /// @param _opolisHelper meant to allow for a bot to handle less sensitive items
    /// @param _ethLiq the address where we send eth or native token liquidations
    /// @param _tokenList initial whitelist of tokens for staking and payroll
    /// @param _destinationList the addresses where payroll and stakes will be sent when withdrawn based on token

    constructor(
        address _opolisAdmin,
        address _opolisHelper,
        address _ethLiq,
        address[] memory _tokenList,
        address[] memory _destinationList
    ) {
        if (_tokenList.length != _destinationList.length) revert LengthMismatch();
        opolisAdmin = _opolisAdmin;
        opolisHelper = _opolisHelper;
        ethLiquidation = _ethLiq;

        for (uint256 i; i < _tokenList.length;) {
            _addToken(_tokenList[i]);
            _addDestination(_destinationList[i], _tokenList[i]);

            unchecked {
                ++i;
            }
        }

        emit SetupComplete(opolisAdmin, opolisHelper, _ethLiq, _tokenList, _destinationList);
    }

    /**
     *
     *                          CORE PAYROLL FUNCTIONS
     *
     */

    /// @notice core function for members to pay their payroll
    /// @param token the token being used to pay for their payroll
    /// @param amount the amount due for their payroll -- up to user / front-end to match
    /// @param payrollId the way we'll associate payments with members' invoices

    function payPayroll(address token, uint256 amount, uint256 payrollId) external nonReentrant {
        if (!whitelisted[token]) revert NotWhitelisted();
        if (payrollId == 0) revert InvalidPayroll();
        if (amount == 0) revert InvalidAmount();
        if (payrollIds[payrollId]) revert DuplicatePayroll();

        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        payrollIds[payrollId] = true;

        emit Paid(msg.sender, token, payrollId, amount);
    }

    /// @notice staking function that allows for both ETH and whitelisted ERC20
    /// @param token the token being used to stake
    /// @param amount the amount due for staking -- up to user / front-end to match
    /// @param memberId the way we'll associate the stake with a new member

    function memberStake(address token, uint256 amount, uint256 memberId) public payable nonReentrant {
        if (!((whitelisted[token] && amount != 0) || (token == ETH && msg.value != 0))) {
            revert InvalidStake();
        }
        if (memberId == 0) revert NotMember();

        // @dev increments the stake id for each member
        uint256 stakeCount = ++stakes[memberId];

        // @dev function for auto transferring out stake
        if (msg.value > 0 && token == ETH) {
            payable(ethLiquidation).transfer(msg.value);
            emit Staked(msg.sender, ETH, msg.value, memberId, stakeCount);
        } else {
            IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
            emit Staked(msg.sender, token, amount, memberId, stakeCount);
        }
    }

    /// @notice withdraw function for admin or OpsBot to call
    /// @param _payrollIds the paid payrolls we want to clear out
    /// @param _payrollTokens the tokens the payrolls were paid in
    /// @param _payrollAmounts the amount that was paid
    /// @dev we iterate through payrolls and clear them out with the funds being sent to the destination address
    function withdrawPayrolls(
        uint256[] calldata _payrollIds,
        address[] calldata _payrollTokens,
        uint256[] calldata _payrollAmounts
    ) external onlyOpolis {
        uint256[] memory withdrawAmounts = new uint256[](
            supportedTokens.length
        );
        for (uint256 i; i < _payrollIds.length;) {
            uint256 id = _payrollIds[i];
            if (!payrollIds[id]) revert InvalidPayroll();

            address token = _payrollTokens[i];
            uint256 amount = _payrollAmounts[i];

            if (!payrollWithdrawn[id]) {
                uint256 j;
                for (; j < supportedTokens.length;) {
                    if (supportedTokens[j] == token) {
                        withdrawAmounts[j] += amount;
                        break;
                    }

                    unchecked {
                        ++j;
                    }
                }
                if (j == supportedTokens.length) revert InvalidToken();
                payrollWithdrawn[id] = true;

                emit OpsPayrollWithdraw(token, id, amount);
            }

            unchecked {
                ++i;
            }
        }

        for (uint256 i; i < withdrawAmounts.length;) {
            uint256 amount = withdrawAmounts[i];
            if (amount > 0) {
                _withdraw(supportedTokens[i], amount);
            }

            unchecked {
                ++i;
            }
        }
    }

    /// @notice withdraw function for admin or OpsBot to call
    /// @param _stakeIds the paid stakes id we want to clear out
    /// @param _stakeNum the particular stake number associated with that id
    /// @param _stakeTokens the tokens the stakes were paid in
    /// @param _stakeAmounts the amount that was paid
    /// @dev we iterate through stakes and clear them out with the funds being sent to the destination address
    function withdrawStakes(
        uint256[] calldata _stakeIds,
        uint256[] calldata _stakeNum,
        address[] calldata _stakeTokens,
        uint256[] calldata _stakeAmounts
    ) external onlyOpolis {
        uint256[] memory withdrawAmounts = new uint256[](
            supportedTokens.length
        );
        if (_stakeIds.length != _stakeNum.length) revert InvalidWithdraw();

        for (uint256 i; i < _stakeIds.length;) {
            uint256 id = _stakeIds[i];
            address token = _stakeTokens[i];
            uint256 amount = _stakeAmounts[i];
            uint256 num = _stakeNum[i];

            if (stakeWithdrawn[id] < num) {
                uint256 j;
                for (; j < supportedTokens.length;) {
                    if (supportedTokens[j] == token) {
                        withdrawAmounts[j] += amount;
                        break;
                    }

                    unchecked {
                        ++j;
                    }
                }
                if (j == supportedTokens.length) revert InvalidToken();
                stakeWithdrawn[id] = num;

                emit OpsStakeWithdraw(token, id, num, amount);
            }

            unchecked {
                ++i;
            }
        }

        for (uint256 i; i < withdrawAmounts.length;) {
            uint256 amount = withdrawAmounts[i];
            if (amount > 0) {
                _withdraw(supportedTokens[i], amount);
            }

            unchecked {
                ++i;
            }
        }
    }

    /// @notice clearBalance() is meant to be a safety function to be used for stuck funds or upgrades
    /// @dev will mark any non-withdrawn payrolls as withdrawn

    function clearBalance() public onlyAdmin {
        for (uint256 i; i < supportedTokens.length;) {
            address token = supportedTokens[i];
            uint256 balance = IERC20(token).balanceOf(address(this));

            if (balance > 0) {
                _withdraw(token, balance);
            }
            emit Sweep(token, balance);

            unchecked {
                ++i;
            }
        }
    }

    /// @notice fallback function to prevent accidental ether transfers
    /// @dev if someone tries to send ether directly to the contract the tx will fail

    receive() external payable {
        revert DirectTransfer();
    }

    /**
     *
     *                          ADMIN FUNCTIONS
     *
     */

    /// @notice this function is used to adjust where member funds are sent by contract
    /// @param token since each token has a new destination
    /// @param newDestination is the new address where funds are sent (assumes it's payable exchange address)
    /// @dev must be called by Opolis Admin multi-sig

    function updateDestination(address token, address newDestination) external onlyAdmin {
        if (newDestination == ZERO) revert ZeroAddress();

        address oldDestination = liqDestinations[token];
        liqDestinations[token] = newDestination;

        emit NewDestination(oldDestination, token, newDestination);
    }

    /// @notice this function is used to replace the admin multi-sig
    /// @param newAdmin is the new admin address
    /// @dev this should always be a mulit-sig

    function updateAdmin(address newAdmin) external onlyAdmin returns (address) {
        if (newAdmin == ZERO) revert ZeroAddress();

        emit NewAdmin(opolisAdmin, newAdmin);
        opolisAdmin = newAdmin;

        return opolisAdmin;
    }

    /// @notice this function is used to replace a bot
    /// @param newHelper is the new bot address
    /// @dev this can be a hot wallet, since it has limited powers

    function updateHelper(address newHelper) external onlyAdmin returns (address) {
        if (newHelper == ZERO) revert ZeroAddress();

        emit NewHelper(opolisHelper, newHelper);
        opolisHelper = newHelper;

        return opolisHelper;
    }

    /// @notice this function is used to add new whitelisted tokens
    /// @param newTokens are the tokens to be whitelisted
    /// @param newDestinations since each new token may have a different destination
    /// @dev restricted to admin b/c this is a business / compliance decision

    function addTokens(address[] memory newTokens, address[] memory newDestinations) external onlyAdmin {
        if (newTokens.length == 0) revert ZeroTokens();
        if (newTokens.length != newDestinations.length) revert LengthMismatch();

        for (uint256 i; i < newTokens.length;) {
            _addToken(newTokens[i]);
            _addDestination(newDestinations[i], newTokens[i]);

            unchecked {
                ++i;
            }
        }

        emit NewTokens(newTokens, newDestinations);
    }

    /**
     *
     *                          INTERNAL FUNCTIONS
     *
     */

    /// @dev This function is used by modifier onlyAdmin
    function _checkAdmin() internal view {
        if (msg.sender != opolisAdmin) revert NotPermitted();
    }

    function _addToken(address token) internal {
        if (whitelisted[token]) revert AlreadyWhitelisted();
        if (token == ZERO) revert ZeroAddress();
        supportedTokens.push(token);
        whitelisted[token] = true;
    }

    function _addDestination(address destination, address token) internal {
        if (destination == ZERO) revert ZeroAddress();
        liqDestinations[token] = destination;
    }

    function _withdraw(address token, uint256 amount) internal {
        address dest = liqDestinations[token];
        IERC20(token).safeTransfer(dest, amount);
    }
}
