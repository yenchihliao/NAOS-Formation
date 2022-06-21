// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.6.12;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {SafeMath} from "@openzeppelin/contracts/math/SafeMath.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

import {FixedPointMath} from "./libraries/FixedPointMath.sol";
import {IMintableERC20} from "./interfaces/IMintableERC20.sol";
import {Pool} from "./libraries/pools/Pool.sol";
import {Stake} from "./libraries/pools/Stake.sol";
import {StakingPools} from "./StakingPools.sol";

/// @title StakingPools
/// @dev A contract which allows users to stake to farm tokens.
///
/// This contract was inspired by Chef Nomi's 'MasterChef' contract which can be found in this
/// repository: https://github.com/sushiswap/sushiswap.
contract StakingPools is ReentrancyGuard {
    using FixedPointMath for FixedPointMath.uq192x64;
    using Pool for Pool.Data;
    using Pool for Pool.List;
    using SafeERC20 for IERC20;
    using SafeMath for uint256;
    using Stake for Stake.Data;

    event PendingGovernanceUpdated(address pendingGovernance);

    event GovernanceUpdated(address governance);

    event PoolCreated(uint256 indexed poolId, IERC20 indexed token);

    event TokensDeposited(address indexed user, uint256 indexed poolId, uint256 amount);

    event TokensWithdrawn(address indexed user, uint256 indexed poolId, uint256 amount);

    event TokensClaimed(address indexed user, uint256 indexed poolId, uint256 amount);

    /// @dev The token which will be minted as a reward for staking.
	// TODO: remove
    IMintableERC20 public reward;

    /// @dev The address of the account which currently has administrative capabilities over this contract.
    address public governance;

    address public pendingGovernance;

    /// @dev Tokens are mapped to their pool identifier plus one. Tokens that do not have an associated pool
    /// will return an identifier of zero.
    mapping(IERC20 => uint256) public tokenPoolIds;

    /// @dev The context shared between the pools.
    Pool.Context private _ctx;

    /// @dev A list of all of the pools.
    Pool.List private _pools;

    /// @dev A mapping of all of the user stakes mapped first by pool and then by address.
    mapping(address => mapping(uint256 => Stake.Data)) private _stakes;

    constructor(IMintableERC20 _reward, address _governance) public {
        require(address(_reward) != address(0), "StakingPools: reward address cannot be 0x0");
        require(_governance != address(0), "StakingPools: governance address cannot be 0x0");

        reward = _reward;
        governance = _governance;
    }

    /// @dev A modifier which reverts when the caller is not the governance.
    modifier onlyGovernance() {
        require(msg.sender == governance, "StakingPools: only governance");
        _;
    }

	/// @dev Set the period for calculating interest.
	///
    /// This function can only called by the current governance.
	///
	/// WARNING: It's depreciated to change the period after it's set the
	///				first time. It can result in huge interest change
	/// @param _period the period for calculating interest.
	function setPeriod(uint256 _period) external onlyGovernance {
		require(_period > 0,  "StakingPools: period cannot be 0");
		_ctx.period = _period;

		// TODO
		// emit PeriodUpdated(_period);
	}

	/// @dev Set the threshold of periods to wait before claiming interest is allowed
	///
	/// @param _periodThreshold The threshold of periods to wait before claiming interest is allowed
	function setPeriodThreshold(uint256 _periodThreshold) external onlyGovernance {
		require(_periodThreshold > 0,  "StakingPools: period threshold cannot be 0");
		_ctx.periodThreshold = _periodThreshold;

		// TODO
		// emit PeriodThresholdUpdated(_periodThreshold);
	}

	/// @dev Set the address of the official account distributing tokens as reward of stakings.
	///
    /// This function can only called by the current governance.
	///
	/// @param _rewardAddress the new token distributing address.
	function setRewardingAddress(address _rewardAddress) external onlyGovernance {
        require(_rewardAddress != address(0), "StakingPools: reward token pool cannot be 0x0");
		_ctx.rewardAddress = _rewardAddress;

		// TODO
		// emit RewardAddressUpdated(_rewardAddress);
	}
	function addLevel(uint256 _interest, uint256 _lowerBound, uint256 _upperBound) external onlyGovernance {
		_ctx.levels.push(
			Pool.Level({interest: _interest, lowerBound: _lowerBound, upperBound: _upperBound, updateDay: Stake.toDays(_ctx.period, block.timestamp)})
		);
	}

    /// @dev Sets the governance.
    ///
    /// This function can only called by the current governance.
    ///
    /// @param _pendingGovernance the new pending governance.
    function setPendingGovernance(address _pendingGovernance) external onlyGovernance {
        require(_pendingGovernance != address(0), "StakingPools: pending governance address cannot be 0x0");
        pendingGovernance = _pendingGovernance;

        emit PendingGovernanceUpdated(_pendingGovernance);
    }

    function acceptGovernance() external {
        require(msg.sender == pendingGovernance, "StakingPools: only pending governance");

        governance = pendingGovernance;

        emit GovernanceUpdated(pendingGovernance);
    }

    /// @dev Creates a new pool.
    ///
    /// The created pool will need to have its reward weight initialized before it begins generating rewards.
    ///
    /// @param _token The token the pool will accept for staking.
    ///
    /// @return the identifier for the newly created pool.
    function createPool(IERC20 _token) external onlyGovernance returns (uint256) {
        require(address(_token) != address(0), "StakingPools: token address cannot be 0x0");
        require(tokenPoolIds[_token] == 0, "StakingPools: token already has a pool");

        uint256 _poolId = _pools.length();

        _pools.push(Pool.Data({token: _token, totalDeposited: 0, rewardWeight: 0, accumulatedRewardWeight: FixedPointMath.uq192x64(0), lastUpdatedBlock: block.number}));

        tokenPoolIds[_token] = _poolId + 1;

        emit PoolCreated(_poolId, _token);

        return _poolId;
    }

    /// @dev Stakes tokens into a pool.
    ///
    /// @param _poolId        the pool to deposit tokens into.
    /// @param _depositAmount the amount of tokens to deposit.
	// do nothing against pool; update deposit and unclaimed(interest) in stake
    function deposit(uint256 _poolId, uint256 _depositAmount) external nonReentrant {
        Pool.Data storage _pool = _pools.get(_poolId);
        _pool.update(_ctx);

        Stake.Data storage _stake = _stakes[msg.sender][_poolId];
        _stake.update(_pool, _ctx);

        _deposit(_poolId, _depositAmount);
    }

    /// @dev Claims all rewarded tokens from a pool.
    ///
    /// @param _poolId The pool to claim rewards from.
    ///
	/// Claim the amount if the interest is enough from the target pool, claim all otherwise.
	///
    /// @notice use this function to claim the tokens from a corresponding pool by ID.
    function claim(uint256 _poolId, uint256 _claimAmount) external nonReentrant {
        Pool.Data storage _pool = _pools.get(_poolId);
        _pool.update(_ctx);

        Stake.Data storage _stake = _stakes[msg.sender][_poolId];
        _stake.update(_pool, _ctx);

		require(_stake.canClaim(_ctx),  "StakingPools: staking too short to be claimed");

        _claim(_poolId, _claimAmount);
    }

    /// @dev Claims all rewards from a pool and then withdraws all staked tokens.
    ///
    /// @param _poolId the pool to exit from.
    function exit(uint256 _poolId) external nonReentrant {
        Pool.Data storage _pool = _pools.get(_poolId);
        _pool.update(_ctx);

        Stake.Data storage _stake = _stakes[msg.sender][_poolId];
        _stake.update(_pool, _ctx);

		// _claim(_poolId);
		if(_stake.canClaim(_ctx)){
			_claim(_poolId, _stake.totalUnclaimed);
		}
        _withdraw(_poolId);
    }

    /// @dev Gets the number of pools that exist.
    ///
    /// @return the pool count.
    function poolCount() external view returns (uint256) {
        return _pools.length();
    }

	/// @dev Gets the period to calculate interest
	///
	/// @return The period
	function getPeriod() external view returns(uint256) {
		return _ctx.period;
	}

	/// @dev Gets the threshold of periods to wait before claiming interest is allowed
	///
	/// @return The period
	function getPeriodThreshold() external view returns(uint256) {
		return _ctx.periodThreshold;
	}

	/// @dev Gets the address of the official account distributing tokens as reward of stakings.
	///
	/// @return The address distributing tokens
	function getRewardingAddress() external view returns(address) {
		return _ctx.rewardAddress;
	}

	/// @dev Gets the count of deposit levels added before.
	///
	/// @return The count
	function getLevelCount() external view returns(uint256){
		return _ctx.levels.length;
	}

	/// @dev Gets the n-th level added
	///
	/// @param n the index to the level added before.
	///
	/// @return the interest, lower bound, upper bound, and updateDay of the level
	function getLevel(uint256 n) external view returns(uint256, uint256, uint256, uint256){
		Pool.Level memory level = _ctx.levels[n];
		return (level.interest, level.lowerBound, level.upperBound, level.updateDay);
	}

	function canClaim(address _account, uint256 _poolId) external view returns(bool){
		Stake.Data storage _stake = _stakes[_account][_poolId];
		return _stake.canClaim(_ctx);
	}

    /// @dev Gets the token a pool accepts.
    ///
    /// @param _poolId the identifier of the pool.
    ///
    /// @return the token.
    function getPoolToken(uint256 _poolId) external view returns (IERC20) {
        Pool.Data storage _pool = _pools.get(_poolId);
        return _pool.token;
    }

    /// @dev Gets the total amount of funds staked in a pool.
    ///
    /// @param _poolId the identifier of the pool.
    ///
    /// @return the total amount of staked or deposited tokens.
    function getPoolTotalDeposited(uint256 _poolId) external view returns (uint256) {
        Pool.Data storage _pool = _pools.get(_poolId);
        return _pool.totalDeposited;
    }

    /// @dev Gets the number of tokens a user has staked into a pool.
    ///
    /// @param _account The account to query.
    /// @param _poolId  the identifier of the pool.
    ///
    /// @return the amount of deposited tokens.
    function getStakeTotalDeposited(address _account, uint256 _poolId) external view returns (uint256) {
        Stake.Data storage _stake = _stakes[_account][_poolId];
        return _stake.totalDeposited;
    }

    /// @dev Gets the number of unclaimed reward tokens a user can claim from a pool.
    ///
    /// @param _account The account to get the unclaimed balance of.
    /// @param _poolId  The pool to check for unclaimed rewards.
    ///
    /// @return the amount of unclaimed reward tokens a user has in a pool.
    function getStakeInfo(address _account, uint256 _poolId) external view returns (uint256, uint256, uint256, uint256) {
        Stake.Data storage _stake = _stakes[_account][_poolId];
        return (_stake.totalDeposited,
				_stake._updateInterest(_ctx).add(_stake.totalUnclaimed),
				_stake.lastUpdateDay,
				_stake.depositDay);
    }

    /// Warning:
    /// Make the staking plan before add a new pool. If the amount of pool becomes too many would
    /// result the transaction failed due to high gas usage in for-loop.
    function _updatePools() internal {
        for (uint256 _poolId = 0; _poolId < _pools.length(); _poolId++) {
            Pool.Data storage _pool = _pools.get(_poolId);
            _pool.update(_ctx);
        }
    }

    /// @dev Stakes tokens into a pool.
    ///
    /// The pool and stake MUST be updated before calling this function.
    ///
    /// @param _poolId        the pool to deposit tokens into.
    /// @param _depositAmount the amount of tokens to deposit.
    function _deposit(uint256 _poolId, uint256 _depositAmount) internal {
        Pool.Data storage _pool = _pools.get(_poolId);
        Stake.Data storage _stake = _stakes[msg.sender][_poolId];

        _pool.totalDeposited = _pool.totalDeposited.add(_depositAmount);
        _stake.totalDeposited = _stake.totalDeposited.add(_depositAmount);

        _pool.token.safeTransferFrom(msg.sender, address(this), _depositAmount);

        emit TokensDeposited(msg.sender, _poolId, _depositAmount);
    }

    /// @dev Withdraws staked tokens from a pool.
    ///
    /// The pool and stake MUST be updated before calling this function.
    ///
    /// @param _poolId          The pool to withdraw staked tokens from.
    function _withdraw(uint256 _poolId) internal {
        Pool.Data storage _pool = _pools.get(_poolId);
        Stake.Data storage _stake = _stakes[msg.sender][_poolId];

		uint256 _withdrawAmount = _stake.totalDeposited;
        _pool.totalDeposited = _pool.totalDeposited.sub(_withdrawAmount);
        _stake.totalDeposited = 0;
		_stake.totalUnclaimed = 0;

        _pool.token.safeTransfer(msg.sender, _withdrawAmount);

        emit TokensWithdrawn(msg.sender, _poolId, _withdrawAmount);
    }

    /// @dev Claims all rewarded tokens from a pool.
    ///
    /// The pool and stake MUST be updated before calling this function.
    ///
    /// @param _poolId The pool to claim rewards from.
    ///
    /// @notice use this function to claim the tokens from a corresponding pool by ID.
    function _claim(uint256 _poolId, uint256 _claimAmount) internal {
        Stake.Data storage _stake = _stakes[msg.sender][_poolId];
        Pool.Data storage _pool = _pools.get(_poolId);

		if(_claimAmount >= _stake.totalUnclaimed){
			_claimAmount = _stake.totalUnclaimed;
			_stake.totalUnclaimed = 0;
		}else{
			_stake.totalUnclaimed = _stake.totalUnclaimed.sub(_claimAmount);
		}

		_pool.token.safeTransferFrom(_ctx.rewardAddress, msg.sender, _claimAmount);
        // reward.mint(msg.sender, _claimAmount);

        emit TokensClaimed(msg.sender, _poolId, _claimAmount);
    }
}
