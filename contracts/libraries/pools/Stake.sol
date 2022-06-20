// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.6.12;

import {Math} from "@openzeppelin/contracts/math/Math.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import {SafeMath} from "@openzeppelin/contracts/math/SafeMath.sol";

import {FixedPointMath} from "../FixedPointMath.sol";
import {IDetailedERC20} from "../../interfaces/IDetailedERC20.sol";
import {Pool} from "./Pool.sol";

/// @title Stake
///
/// @dev A library which provides the Stake data struct and associated functions.
library Stake {
    using FixedPointMath for FixedPointMath.uq192x64;
    using Pool for Pool.Data;
    using SafeMath for uint256;
    using Stake for Stake.Data;

	// TODO: remove. We only need totalDeposited
    struct Data {
        uint256 totalDeposited;
        uint256 totalUnclaimed;
        FixedPointMath.uq192x64 lastAccumulatedWeight;
		uint256 lastUpdateDay;
		uint256 depositDay;
    }

	/// @dev returns number of periods passed since epoch time
	///
	/// @param period number of blocktime that count as a period
	/// @param time the target time since epoch
	function toDays(uint period, uint time) internal view returns(uint256){
		return time / period;
	}

	/// @dev true if the staking is long enough to claim its rewards
	///
	/// @param _ctx the pool context
	function canClaim(Data storage _self, Pool.Context storage _ctx) internal view returns(bool) {
		uint256 today = toDays(_ctx.period, block.timestamp);
		if(today.sub(_self.depositDay) >= _ctx.periodThreshold) return true;
		return false;
	}

	/// @dev Calculates the interest yeilds so far
	///
	/// @param _ctx the pool context
   function _updateInterest(Data storage _self, Pool.Context storage _ctx) internal view returns(uint256) {
        uint interest = 0;
        uint previousLevelPtr;
        uint updateDay = _self.lastUpdateDay;
        uint periods;
        bool inRange = false;
        for(uint256 i = 0;i < _ctx.levels.length;i++){
            // find all levels fitting the deposit amount
            if(_self.totalDeposited < _ctx.levels[i].lowerBound || _ctx.levels[i].upperBound <= _self.totalDeposited){
                continue;
            }
            inRange = true;
            // try to update the interest
            if(_ctx.levels[i].updateDay <= updateDay){
                previousLevelPtr = i;
                continue;
            }else{
                periods = toDays(_ctx.period, _ctx.levels[i].updateDay) - toDays(_ctx.period, updateDay);
                updateDay = _ctx.levels[i].updateDay;
                interest += periods * _ctx.levels[previousLevelPtr].interest;
                previousLevelPtr = i;
            }
        }
        require(inRange, "not in any levels");
        periods = toDays(_ctx.period, block.timestamp) - updateDay;
        interest += periods * _ctx.levels[previousLevelPtr].interest;
        return interest;
    }
    function update(
        Data storage _self,
        Pool.Data storage _pool,
        Pool.Context storage _ctx
    ) internal {
		if(_self.totalDeposited == 0){
			_self.depositDay = toDays(_ctx.period, block.timestamp);
		}else{
			uint256 _interest = _self._updateInterest(_ctx);
			_self.totalUnclaimed = _self.totalUnclaimed.add(_interest);
		}
		_self.lastUpdateDay = toDays(_ctx.period, block.timestamp);
        // _self.totalUnclaimed = _self.getUpdatedTotalUnclaimed(_pool, _ctx);
        // _self.lastAccumulatedWeight = _pool.getUpdatedAccumulatedRewardWeight(_ctx);
    }

	function getUpdatedTotalUnclaimed(
		Data storage _self,
		Pool.Data storage _pool,
		Pool.Context storage _ctx
	) internal view returns (uint256) {
		FixedPointMath.uq192x64 memory _currentAccumulatedWeight = _pool.getUpdatedAccumulatedRewardWeight(_ctx);
		FixedPointMath.uq192x64 memory _lastAccumulatedWeight = _self.lastAccumulatedWeight;

		if (_currentAccumulatedWeight.cmp(_lastAccumulatedWeight) == 0) {
			return _self.totalUnclaimed;
		}

		uint256 _distributedAmount = _currentAccumulatedWeight.sub(_lastAccumulatedWeight).mul(_self.totalDeposited).decode();

		return _self.totalUnclaimed.add(_distributedAmount);
	}
}
