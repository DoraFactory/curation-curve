// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.6;

import { Curation } from "./Curation.sol";
import { Proxy } from './Proxy.sol';
import { IERC20 } from "./interface/IERC20.sol";

contract CurationFactory {
  address public feeTo;
  address public signer;
  address public CURATION_LIB;
  Curation[] public allBondingToken;
  mapping (uint256 => Curation) public certified;

  /**
   * @dev Constructor for the factory contract
   * @param _feeTo The receiving address for fees that is generated from withdraw
   */
  constructor(address _feeTo, address _signer, address _lib) {
    require(_feeTo != address(0), "Address must not be address(0)");
    feeTo = _feeTo;
    signer = _signer;
    CURATION_LIB = _lib;
  }

  modifier onlyOwner() {
    require(msg.sender == feeTo);
    _;
  }

  function setOwner(address _feeTo) external onlyOwner { feeTo = _feeTo; }
  function setSigner(address _signer) external onlyOwner { signer = _signer; }
  function setLib(address _lib) external onlyOwner { CURATION_LIB = _lib; }

  function bondingTokenCount() public view returns (uint256) {
    return allBondingToken.length;
  }

  /**
   * @dev Create new bonding curve token
   * @param _name The name of this token
   * @param _symbol The symbol of this token
   * @param _basetoken The address for the trading token
   * @param _params params
   * @param _founder The address for the token creator team
   * @param _curve curve lib
   * @param _params The params list for curve
   */
  function createBondingCurveToken(
    IERC20 _basetoken,
    string memory _name,
    string memory _symbol,
    uint256[] memory _params,           // _bid, _start, _maxSupply
    address _founder,
    address _curve,
    uint256[] memory _curveparams,
    bytes calldata _sign
  ) external {
    Proxy p = new Proxy(this);
    Curation c = Curation(address(p));
    c.initialize(this, _name, _symbol, _basetoken, _params, _founder, _curve, _curveparams, _sign);
    allBondingToken.push(c);

    uint256 bid = _params[0];
    if (bid != 0) {
      certified[bid] = c;
    }
  }
}
