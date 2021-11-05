// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.6;

import { CurationFactory } from "./CurationFactory.sol";
import { Curation } from "./Curation.sol";
import { IERC20 } from "./interface/IERC20.sol";
import { Curve } from "./interface/Curve.sol";

contract QueryService {
  CurationFactory public factory;
  address public admin;

  constructor(CurationFactory _factory) {
    admin = msg.sender;
    factory = _factory;
  }
  
  function setFactory(CurationFactory _factory) external {
    require(msg.sender == admin);
    factory = _factory;
  }

  function allBondingCurves(uint256 size) public view returns (
    address[] memory bcs,
    string[] memory symbols,
    uint256[] memory completions,
    uint256[] memory starts
  ) {
    uint256 l = factory.bondingTokenCount();
    if (size < l) {
      l = size;
    }
    bcs = new address[](l);
    symbols = new string[](l);
    completions = new uint256[](l);
    starts = new uint256[](l);
    for (uint256 i = 0; i < l; i++) {
      Curation bc = factory.allBondingToken(i);
      bcs[i] = address(bc);
      symbols[i] = bc.symbol();
      completions[i] = bc.totalSupply() * 100 / bc.totalSupply();
      starts[i] = bc.start();
    }
  }

  function bondingCurvesList(uint256 page, uint256 size) public view returns (
    bool ended,
    address[] memory bc,
    uint256[] memory bid,
    string[] memory symbol,
    string[] memory tokenSymbol,
    uint256[] memory starts,
    uint256[] memory tokenDecimals,
    uint256[] memory maxSupply,
    uint256[] memory supplied,
    uint256[] memory priceNow,
    string[] memory curveName
  ) {
    uint256 start = page * size;
    uint256 s;
    {
      uint256 end = start + size;
      uint256 l = factory.bondingTokenCount();
      if (end >= l) {
        end = l;
        ended = true;
      }
      s = end - start;
    }
    if (s > 0) {
      bc = new address[](s);
      bid = new uint256[](s);
      symbol = new string[](s);
      tokenSymbol = new string[](s);
      starts = new uint256[](s);
      tokenDecimals = new uint256[](s);
      maxSupply = new uint256[](s);
      supplied = new uint256[](s);
      priceNow = new uint256[](s);
      curveName = new string[](s);
      for (uint256 i = 0; i < s; i++) {
        Curation b = factory.allBondingToken(i + start);
        bc[i] = address(b);
        bid[i] = b.bid();
        symbol[i] = b.symbol();
        starts[i] = b.start();
        maxSupply[i] = b.maxSupply();
        supplied[i] = b.totalSupply();
        priceNow[i] = b.priceNow();
        address curve = b.curve();
        curveName[i] = Curve(curve).name();

        IERC20 token = b.token();
        tokenSymbol[i] = token.symbol();
        tokenDecimals[i] = token.decimals();
      }
    }
  }

  function bondingCurveInfo(Curation bc) public view returns (
    string memory name,
    string memory symbol,
    address token,
    string memory tokenSymbol,
    uint256[8] memory params // [bid, start, tokenDecimals, maxSupply, supplied, priceNow, FUND, TAX]
  ) {
    name = bc.name();
    symbol = bc.symbol();
    IERC20 _token = bc.token();
    token = address(_token);
    tokenSymbol = _token.symbol();

    params[0] = bc.bid();
    params[1] = bc.start();

    params[2] = _token.decimals();
    params[3] = bc.maxSupply();
    params[4] = bc.totalSupply();
    params[5] = bc.priceNow();

    params[6] = bc.FUND();
    params[7] = bc.TAX();
  }

  function curveInfo(Curation bc) public view returns (
    address curve,
    string memory curveName,
    uint256[] memory params
  ) {
    curve = bc.curve();
    curveName = Curve(curve).name();
    params = bc.parameters();
  }

  function balanceOf(Curation bc, address account) public view returns (
    uint256 curationBalance,
    uint256 tokenBalance,
    uint256 tokenAllowance
  ) {
    curationBalance = bc.balanceOf(account);

    IERC20 token = bc.token();
    tokenBalance = token.balanceOf(account);
    tokenAllowance = token.allowance(account, address(bc));
  }

  function ERC20TokenInfo(IERC20 token, address account) public view returns (
    string memory symbol,
    uint256 decimals,
    uint256 balance,
    uint256 allowance
  ) {
    symbol = token.symbol();
    decimals = token.decimals();
    balance = token.balanceOf(account);
    allowance = token.allowance(account, address(factory));
  }
}
