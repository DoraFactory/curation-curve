// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.6;

import { IERC20 } from "./interface/IERC20.sol";
import { CurationFactory } from "./CurationFactory.sol";

library AddressUtils {
  function isContract(address addr) internal view returns (bool) {
    uint256 size;
    // solium-disable-next-line security/no-inline-assembly
    assembly { size := extcodesize(addr) }
    return size > 0;
  }
}

library SafeMath {
  function add(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a + b;
    assert(c >= a);
    return c;
  }

  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    assert(b <= a);
    return a - b;
  }
}

interface ICurve {
  function isCurve() external returns (bool);
}

contract Curation is IERC20 {
  using AddressUtils for address;
  using SafeMath for uint256;

  // keccak256("ERC20.decimals")
  bytes32 private constant DECIMALS_SLOT = 0x9af4a8efdef7082fbe0a356fe9ce920abbe3461c19ff1888bb79ec1fbee0a564;
  // keccak256("curve.parameters")
  bytes32 private constant PARAMETERS_SLOT = 0x9bb186d4e76241ac6fcfb26f9c0c67a7a4288892aa856bb2ef40fc277c0bbbe2;
  // keccak256(keccak256("curve.parameters"))
  bytes32 private constant PARAMETERS_SLOT_HASH = 0x22e3a4713640ec908fad4277bc5c59c3802aee5469f8a18fa0b552bf09d2299b;

  // bytes4(keccak256("integral(uint256,uint256)")
  bytes4 private constant INTEGRAL_ABI = 0xc3882fef;
  // bytes4(keccak256("valueOf(uint256)")
  bytes4 private constant VALUE_OF_ABI = 0xcadf338f;

  string public override name;
  string public override symbol;

  CurationFactory public factory;

  address public founder;         // the address of the founder
  uint256 public bid;             // the BUIDL id on hackerlink.io
  IERC20 public token;            // the token to receive
  address public curve;
  bool public initialized;        // if token transfer is ready

  uint256 public start;           // start time for sale

  uint256 public TAX;
  uint256 public FUND;

  // ERC20 params

  uint256 public override totalSupply = 0;
  uint256 public maxSupply;

  mapping (address => uint256) private _balances;
  mapping (address => mapping (address => uint256)) private _allowed;

  bool private rentrancyLock;
  bool public founderExit;

  event Buy(address indexed user, uint256 amount, uint256 prict);

  /**
   * @dev Constructor for the bonding curve
   * @param _factory The address for the factory
   * @param _name The name of this token
   * @param _symbol The symbol of this token
   * @param _token The address for the trading token
   * @param _params params
   * @param _founder The address for the token creator founder
   * @param _curve curve lib
   * @param _params The params list for curve
   */
  function initialize(
    CurationFactory _factory,
    string memory _name,
    string memory _symbol,
    IERC20 _token,
    uint256[] memory _params,           // _bid, _start, _maxSupply
    address _founder,
    address _curve,
    uint256[] memory _curveparams,
    bytes calldata _sign
  ) external {
    require(_founder != address(0), "Founder's address must not be address(0)");
    require(address(_token).isContract());
    require(ICurve(_curve).isCurve());
    require(_params.length == 3);

    factory = _factory;
    _checkBid(_founder, _params[0], _sign);
    initialized = true;

    name = _name;
    symbol = _symbol;

    token = _token;
    start = _params[1];
    maxSupply = _params[2];
    founder = _founder;
    curve = _curve;

    uint256 l = _curveparams.length;
    assembly {
      sstore(PARAMETERS_SLOT, l)
      sstore(DECIMALS_SLOT, 18)
    }
    for (uint256 i = 0; i < l; i++) {
      uint256 v = _curveparams[i];
      assembly {
        sstore(add(PARAMETERS_SLOT_HASH, i), v)
      }
    }
  }

  /**
   * @dev Prevents a contract from calling itself, directly or indirectly.
   */
  modifier nonReentrant() {
    require(!rentrancyLock);
    rentrancyLock = true;
    _;
    rentrancyLock = false;
  }

  /**
   * @dev Modifier for checking the token sale is active
   */
  modifier active() {
    require(initialized, "the contract has not initialized");
    require(block.timestamp > start, "the token sale hasn't started");
    _;
  }

  function parameters() external view returns (uint256[] memory params) {
    uint256 l;
    assembly {
      l := sload(PARAMETERS_SLOT)
    }
    params = new uint256[](l);
    for (uint256 i = 0; i < l; i++) {
      uint256 v;
      assembly {
        v := sload(add(PARAMETERS_SLOT_HASH, i))
      }
      params[i] = v;
    }
  }

  function priceNow() external view returns (uint256) {
    return priceAt(totalSupply);
  }

  function costFor(uint256 amount) external view returns (uint256) {
    return totalPriceBetween(totalSupply, totalSupply.add(amount));
  }

  function priceAt(uint256 position) public view returns (uint256 price) {
    (bool success, bytes memory data) = address(this).staticcall(abi.encodePacked(VALUE_OF_ABI, position));
    require(success);
    require(data.length == 32);
    assembly {
      price := mload(add(data, 32))
    }
  }

  function totalPriceBetween(uint256 left, uint256 right) public view returns (uint256 price) {
    (bool success, bytes memory result) = address(this).staticcall(abi.encodePacked(INTEGRAL_ABI, left, right));
    require(success);
    require(result.length == 32);
    assembly {
      price := mload(add(result, 32))
    }
  }

  /**
   * @dev Buy token with bonding curve 
   * @param amount The amount of token to mint
   */
  function buy(uint256 amount) external nonReentrant active  {
    uint256 newSupplied = totalSupply.add(amount);
    if (maxSupply != 0 && newSupplied > maxSupply) {
      amount = maxSupply - totalSupply;
      newSupplied = maxSupply;
    }
    uint256 totalCost = totalPriceBetween(totalSupply, newSupplied);
    _mint(msg.sender, amount);
    bool success = token.transferFrom(msg.sender, address(this), totalCost);
    require(success);

    uint256 tax = totalCost * 3 / 100;
    TAX = TAX.add(tax);
    uint256 afterTax = totalCost - tax;
    FUND = FUND.add(afterTax);

    emit Buy(msg.sender, amount, totalCost);
  }

  /**
   * @dev Withdraw function allows the founder to withdraw all funds to their founder address
   */
  function withdrawFund() external {
    uint256 tax = TAX; TAX = 0;
    uint256 fund = FUND; FUND = 0;
    bool success = token.transfer(factory.feeTo(), tax);
    require(success);
    success = token.transfer(founder, fund);
    require(success);
  }

  function _checkBid(address _founder, uint256 _bid, bytes calldata _sign) private {
    if (_bid == 0) {
      return;
    }
    require(_sign.length == 65);
    bytes32 h = keccak256(abi.encodePacked(_founder, _bid));
    uint8 v = uint8(bytes1(_sign[64:]));
    (bytes32 r, bytes32 s) = abi.decode(_sign[:64], (bytes32, bytes32));
    address signer = ecrecover(h, v, r, s);
    require(signer == factory.signer());
    bid = _bid;
  }

  // ERC20 methods

  /**
   * @dev Returns the symbol of the token, usually a shorter version of the
   * name.
   */
  function decimals() public view override returns (uint256) {
    uint256 d;
    assembly {
      d := sload(DECIMALS_SLOT)
    }
    return d;
  }

  function balanceOf(address account) public view override returns (uint256) {
    return _balances[account];
  }

  function transfer(address recipient, uint256 amount) public override returns (bool) {
    require(msg.sender != recipient, "Cannot transfer to own account");
    _balances[msg.sender] = _balances[msg.sender].sub(amount);
    _balances[recipient] = _balances[recipient].add(amount);
    emit Transfer(msg.sender, recipient, amount);
    return true;
  }

  function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
    require(sender != recipient, "Cannot transfer to own account");
    _balances[sender] = _balances[sender].sub(amount);
    _allowed[sender][msg.sender] = _allowed[sender][msg.sender].sub(amount);
    _balances[recipient] = _balances[recipient].add(amount);
    emit Transfer(sender, recipient, amount);
    return true;
  }

  function approve(address spender, uint256 amount) public override returns (bool) {
    require(_allowed[msg.sender][spender] == 0 || amount == 0);
    _allowed[msg.sender][spender] = amount;
    emit Approval(msg.sender, spender, amount);
    return true;
  }

  function allowance(address owner, address spender) public view override returns (uint256) {
    return _allowed[owner][spender];
  }

  function _mint(address account, uint256 amount) internal virtual {
    require (account != address(0));
    totalSupply = totalSupply.add(amount);
    _balances[account] = _balances[account].add(amount);
    emit Transfer(address(0), account, amount);
  }

  fallback() external {
    require(msg.sender == address(this));

    (bool success, bytes memory data) = curve.delegatecall(msg.data);
    assembly {
      switch success
        case 0 { revert(add(data, 32), returndatasize()) }
        default { return(add(data, 32), returndatasize()) }
    }
  }
}
