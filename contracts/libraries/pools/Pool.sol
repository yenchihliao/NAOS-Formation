// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IDetailedERC20} from "../../interfaces/IDetailedERC20.sol";

/// @title Pool
///
/// @dev A library which provides the Pool data struct and associated functions.
library Pool {
    using Pool for Pool.Data;
    using Pool for Pool.List;

	struct Level {
          uint256 interest;
          uint256 lowerBound; // included
          uint256 upperBound; // excluded
          uint256 updateDay;
      }

    struct Context {
		uint256 period;
		uint256 periodThreshold; // time for users enabled to withdraw their interest
		address rewardAddress;
		Level[] levels;
    }

    struct Data {
        IERC20 token;
        uint256 totalDeposited;
    }

    struct List {
        Data[] elements;
    }


    /// @dev Updates the pool.
    ///
    /// @param _ctx the pool context.
    function update(Data storage _self, Context storage _ctx) internal {
    }

    /// @dev Adds an element to the list.
    ///
    /// @param _element the element to add.
    function push(List storage _self, Data memory _element) internal {
        _self.elements.push(_element);
    }

    /// @dev Gets an element from the list.
    ///
    /// @param _index the index in the list.
    ///
    /// @return the element at the specified index.
    function get(List storage _self, uint256 _index) internal view returns (Data storage) {
        return _self.elements[_index];
    }

    /// @dev Gets the last element in the list.
    ///
    /// This function will revert if there are no elements in the list.
    ///ck
    /// @return the last element in the list.
    function last(List storage _self) internal view returns (Data storage) {
        return _self.elements[_self.lastIndex()];
    }

    /// @dev Gets the index of the last element in the list.
    ///
    /// This function will revert if there are no elements in the list.
    ///
    /// @return the index of the last element.
    function lastIndex(List storage _self) internal view returns (uint256) {
        uint256 _length = _self.length();
		require(_length > 0, "Pool.List: list is empty");
        return _length - 1;
    }

    /// @dev Gets the number of elements in the list.
    ///
    /// @return the number of elements.
    function length(List storage _self) internal view returns (uint256) {
        return _self.elements.length;
    }
}
