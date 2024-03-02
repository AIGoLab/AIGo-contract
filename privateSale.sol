// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

contract Context {
    // Empty internal constructor, to prevent people from mistakenly deploying
    // an instance of this contract, which should be used via inheritance.
    //   constructor () internal { }

    function _msgSender() internal view returns (address) {
        return payable(msg.sender);
    }

    function _msgData() internal view returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}

contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public onlyOwner {
        emit OwnershipTransferred(
            _owner,
            0x000000000000000000000000000000000000dEaD
        );
        _owner = 0x000000000000000000000000000000000000dEaD;
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public onlyOwner {
        require(
            newOwner != address(0),
            "Ownable: new owner is the zero address"
        );
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }
}

contract PrivateSale is Ownable {
    mapping(address => uint256) private participated;
    address[] private participants;
    uint256 public _price;

    event Participated(address indexed participant);

    constructor (uint256 price) {
        _price = price;
    }

    function setPrice(uint256 price) public onlyOwner {
        _price = price;
    }

    function participate(uint256[] memory amount, address[] memory addr) external onlyOwner {
        require(amount.length == addr.length, "length not match");
        for (uint256 i = 0; i < amount.length; i++) {
            if (isContract(addr[i]) || participated[addr[i]] > 0 || amount[i] == 0) {
                continue;
            }
            participated[addr[i]] = amount[i];
            participants.push(addr[i]);
            emit Participated(addr[i]);
        }
    }
    
    function hasParticipated(address _address) external view returns (uint256) {
        return participated[_address];
    }
    
    function exportParticipants() external view onlyOwner returns (address[] memory) {
        return participants;
    }

    function isContract(address _addr) private view returns (bool) {
        uint32 size;
        assembly {
            size := extcodesize(_addr)
        }
        return (size > 0);
    }
}