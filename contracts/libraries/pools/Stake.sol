// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IDetailedERC20} from "../../interfaces/IDetailedERC20.sol";
import {Pool} from "./Pool.sol";

/// @title Stake
///
/// @dev A library which provides the Stake data struct and associated functions.
library Stake {
    using Pool for Pool.Data;
    using Stake for Stake.Data;

	// TODO: remove. We only need totalDeposited
    struct Data {
        uint256 totalDeposited;
        uint256 totalUnclaimed;
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
		if(_self.totalDeposited == 0) return false;
		uint256 today = toDays(_ctx.period, block.timestamp);
		if(today - _self.depositDay >= _ctx.periodThreshold) return true;
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
                periods = _ctx.levels[i].updateDay - updateDay;
                updateDay = _ctx.levels[i].updateDay;
				interest = interest + periods * _ctx.levels[previousLevelPtr].interest;
                previousLevelPtr = i;
            }
        }
		if(!inRange){
			return 0;
		}
        periods = toDays(_ctx.period, block.timestamp) - updateDay;
		interest = interest + periods * _ctx.levels[previousLevelPtr].interest;
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
			_self.totalUnclaimed += _interest;
		}
		_self.lastUpdateDay = toDays(_ctx.period, block.timestamp);
    }

}
