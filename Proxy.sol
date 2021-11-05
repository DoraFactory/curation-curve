
// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import { CurationFactory } from './CurationFactory.sol';

contract Proxy {
  bytes32 private constant FACTORY_SLOT = 0x4dd7ae261255a0a175c0532b4f2a50ea831b51e00e3ed19b82b1079e542a4766;

  constructor (CurationFactory _f) {
    assert(FACTORY_SLOT == keccak256("curation.proxy.factory"));
    _setFactory(_f);
  }

  function _setFactory (CurationFactory newFactory) internal {
    bytes32 slot = FACTORY_SLOT;
    assembly {
      sstore(slot, newFactory)
    }
  }

  function _factory () internal view returns (CurationFactory factory) {
    bytes32 slot = FACTORY_SLOT;
    assembly {
      factory := sload(slot)
    }
  }

  fallback () external payable {
    address i = _factory().CURATION_LIB();
    assembly {
      calldatacopy(0, 0, calldatasize())

      let result := delegatecall(gas(), i, 0, calldatasize(), 0, 0)

      returndatacopy(0, 0, returndatasize())

      switch result
      case 0 { revert(0, returndatasize()) }
      default { return(0, returndatasize()) }
    }
  }
}
