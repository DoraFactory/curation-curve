// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.6;

abstract contract Curve {
	// keccak256("ERC20.decimals")
	bytes32 private constant DECIMALS_SLOT = 0x9af4a8efdef7082fbe0a356fe9ce920abbe3461c19ff1888bb79ec1fbee0a564;
	// keccak256("curve.parameters")
	bytes32 private constant PARAMETERS_SLOT = 0x9bb186d4e76241ac6fcfb26f9c0c67a7a4288892aa856bb2ef40fc277c0bbbe2;
	// keccak256(keccak256("curve.parameters"))
	bytes32 private constant PARAMETERS_SLOT_HASH = 0x22e3a4713640ec908fad4277bc5c59c3802aee5469f8a18fa0b552bf09d2299b;
	
	bool public isCurve = true;
	function name() external view virtual returns (string memory);
	string public url;
	address payable public maintainer;

	constructor() {
		maintainer = payable(msg.sender);
	}

	function updateURL(string memory _url) public {
		require(msg.sender == maintainer);
		url = _url;
	}

	/**
		* @dev Returns the curve parameters from specified slot.
		*/
	function _parameter(uint256 index) internal view returns (uint256 param) {
		assembly {
			param := sload(add(PARAMETERS_SLOT_HASH, index))
		}
	}

	/**
		* @dev Returns the token decimals from specified slot.
		*/
	function _decimals() internal view returns (uint256) {
		uint256 d;
		assembly {
			d := sload(DECIMALS_SLOT)
		}
		return d;
	}

	/**
		* @dev Returns the value of the corresponding point on the curve.
		* @param x corresponding point
		*/
	function valueOf(uint256 x) external view virtual returns (uint256);

	/**
		* @dev Returns the area between two points on a curve.
		* @param left left side
		* @param right right side
		*/
	function integral(uint256 left, uint256 right) external view virtual returns (uint256);
}
