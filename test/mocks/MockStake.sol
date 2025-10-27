// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

/**
 * @title MockStake
 * @notice Mock Stake contract for testing
 */
contract MockStake {
    mapping(address => uint256) internal _govVotesNum;
    mapping(address => mapping(address => uint256)) internal _validGovVotes;

    function setGovVotesNum(address tokenAddress, uint256 amount) external {
        _govVotesNum[tokenAddress] = amount;
    }

    function setValidGovVotes(
        address tokenAddress,
        address account,
        uint256 amount
    ) external {
        _validGovVotes[tokenAddress][account] = amount;
    }

    function govVotesNum(address tokenAddress) external view returns (uint256) {
        return _govVotesNum[tokenAddress];
    }

    function validGovVotes(
        address tokenAddress,
        address account
    ) external view returns (uint256) {
        return _validGovVotes[tokenAddress][account];
    }
}
