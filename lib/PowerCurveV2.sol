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

contract PowerCurveV2 is Curve {
  using SafeMath for uint256;

	string public override name = "PowerCurveV2";

	uint256 constant MAX = 0xc097ce7bc90715b34b9f1000000000; // 1e36

	function valueOf(uint256 x) external view override returns (uint256) {
		uint256 k = _parameter(0);
		uint256 a = _parameter(1);
		uint256 b = _parameter(2);
		uint256 d = _parameter(3);

		require(d != 0);

		uint256 decimals = _decimals();
		require(decimals <= 36);
		uint256 unit = 10 ** decimals;

		uint256 a1 = x.add(a);
		uint256 a2 = a1.mul(a1);

		return b.add(k.mul(a2 / unit) / unit / d);
	}

	function integral(uint256 left, uint256 right) external view override returns (uint256) {
		assert(right >= left);

		uint256 k = _parameter(0);
		uint256 a = _parameter(1);
		uint256 b = _parameter(2);
		uint256 d = _parameter(3);
	
		require(d != 0);
		require(a < MAX);
		require(left < MAX);
		require(right < MAX);

		uint256 decimals = _decimals();
		require(decimals <= 36);
		uint256 e = 10 ** decimals;

		uint256 s = left + right;
		uint256 m = left * right;
		uint256 m2 = (s * s - m) / 3 + a * s + a * a;

		return (k.mul(m2 / e) / e / d + b) * (right - left) / e;
	}
}

// 588807
