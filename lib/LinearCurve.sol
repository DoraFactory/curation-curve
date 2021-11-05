// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.6;

import { Curve } from "../interface/Curve.sol";

library SafeMath {
  function add(uint256 a, uint256 b) internal pure returns (uint256) {
		uint256 c = a + b;
		assert(c >= a);
		return c;
  }
  function mul(uint256 a, uint256 b) internal pure returns (uint256) {
		if (b == 0) {
			return 0;
		}
		uint256 c = a * b;
		assert(c / b == a);
		return c;
  }
}

contract LinearCurve is Curve {
  using SafeMath for uint256;

	string public override name = "LinearCurve";

	function valueOf(uint256 x) external view override returns (uint256) {
		uint256 k = _parameter(0);
		uint256 b = _parameter(1);
		return b.add(k.mul(x) / 1e18);
	}

	function integral(uint256 left, uint256 right) external view override returns (uint256) {
		assert(right >= left);

		uint256 k = _parameter(0);
		uint256 b = _parameter(1);

		uint256 decimals = _decimals();
		require(decimals <= 36);
		uint256 unit = 10 ** decimals;

		return (b.add(k.mul(left.add(right)) / 2e18)).mul(right - left) / unit;
	}
}

// 546493
