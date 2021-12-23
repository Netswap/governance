// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/cryptography/MerkleProof.sol";

// Allows anyone to claim a token if they exist in a merkle root.
interface IMerkleDistributor {
    // Returns the address of the token distributed by this contract.
    function token() external view returns (address);
    // Returns the merkle root of the merkle tree containing account balances available to claim.
    function merkleRoot() external view returns (bytes32);
    // Returns true if the index has been marked claimed.
    function isClaimed(uint256 index) external view returns (bool);
    // Claim the given amount of the token to the given address. Reverts if the inputs are invalid.
    function claim(uint256 index, address account, uint256 amount, bytes32[] calldata merkleProof) external;

    // This event is triggered whenever a call to #claim succeeds.
    event Claimed(uint256 index, address account, uint256 amount);
    // This event is triggered when a call to withdraw remaining tokens from owner.
    event WithdrawRemaining(address sender, uint256 amount);
}

contract MerkleDistributor is IMerkleDistributor {
    address public owner;
    address public immutable override token;
    bytes32 public immutable override merkleRoot;
    uint256 public endTime;
    bool public started = false;

    // This is a packed array of booleans.
    mapping(uint256 => uint256) private claimedBitMap;

    constructor(address token_, bytes32 merkleRoot_, uint256 endTime_) public {
        token = token_;
        merkleRoot = merkleRoot_;
        endTime = endTime_;
        owner = msg.sender;
    }

    function isClaimed(uint256 index) public view override returns (bool) {
        uint256 claimedWordIndex = index / 256;
        uint256 claimedBitIndex = index % 256;
        uint256 claimedWord = claimedBitMap[claimedWordIndex];
        uint256 mask = (1 << claimedBitIndex);
        return claimedWord & mask == mask;
    }

    function _setClaimed(uint256 index) private {
        uint256 claimedWordIndex = index / 256;
        uint256 claimedBitIndex = index % 256;
        claimedBitMap[claimedWordIndex] = claimedBitMap[claimedWordIndex] | (1 << claimedBitIndex);
    }

    function claim(uint256 index, address account, uint256 amount, bytes32[] calldata merkleProof) claimable external override  {
        require(!isClaimed(index), 'MerkleDistributor: Drop already claimed.');

        // Verify the merkle proof.
        bytes32 node = keccak256(abi.encodePacked(index, account, amount));
        require(MerkleProof.verify(merkleProof, merkleRoot, node), 'MerkleDistributor: Invalid proof.');

        // Mark it claimed and send the token.
        _setClaimed(index);
        require(IERC20(token).transfer(account, amount), 'MerkleDistributor: Transfer failed.');

        emit Claimed(index, account, amount);
    }

    function setStarted(bool started_) onlyOwner external {
        started = started_;
    }

    function setEndTime(uint256 _endTime) onlyOwner external {
        endTime = _endTime;
    }

    function withdrawRemaining() onlyOwner external {
        require(!started || block.timestamp > endTime, "only can be called when not started or ended");
        require(IERC20(token).transfer(msg.sender, IERC20(token).balanceOf(address(this))), 'MerkleDistributor: Transfer failed.');
        emit WithdrawRemaining(msg.sender, IERC20(token).balanceOf(address(this)));
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }

    modifier claimable() {
        require(started && block.timestamp <= endTime, 'MerkleDistributor: Not started or ended for claiming');
        _;
    }
}