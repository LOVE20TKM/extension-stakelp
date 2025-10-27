// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {ILOVE20ExtensionCenter} from "@extension/src/interface/ILOVE20ExtensionCenter.sol";

/**
 * @title MockExtensionCenter
 * @notice Mock Extension Center contract for testing
 */
contract MockExtensionCenter is ILOVE20ExtensionCenter {
    address internal _stakeAddress;
    address internal _joinAddress;
    address internal _verifyAddress;
    address internal _mintAddress;
    address internal _uniswapV2FactoryAddress;
    mapping(address => mapping(uint256 => address[])) internal _accounts;

    function setStakeAddress(address addr) external {
        _stakeAddress = addr;
    }

    function setJoinAddress(address addr) external {
        _joinAddress = addr;
    }

    function setVerifyAddress(address addr) external {
        _verifyAddress = addr;
    }

    function setMintAddress(address addr) external {
        _mintAddress = addr;
    }

    function setUniswapV2FactoryAddress(address addr) external {
        _uniswapV2FactoryAddress = addr;
    }

    function stakeAddress() external view returns (address) {
        return _stakeAddress;
    }

    function joinAddress() external view returns (address) {
        return _joinAddress;
    }

    function verifyAddress() external view returns (address) {
        return _verifyAddress;
    }

    function mintAddress() external view returns (address) {
        return _mintAddress;
    }

    function uniswapV2FactoryAddress() external view returns (address) {
        return _uniswapV2FactoryAddress;
    }

    function addAccount(
        address _tokenAddress,
        uint256 _actionId,
        address _account
    ) external {
        _accounts[_tokenAddress][_actionId].push(_account);
    }

    function removeAccount(
        address _tokenAddress,
        uint256 _actionId,
        address _account
    ) external {
        address[] storage accts = _accounts[_tokenAddress][_actionId];
        for (uint256 i = 0; i < accts.length; i++) {
            if (accts[i] == _account) {
                accts[i] = accts[accts.length - 1];
                accts.pop();
                break;
            }
        }
    }

    function accounts(
        address _tokenAddress,
        uint256 _actionId
    ) external view returns (address[] memory) {
        return _accounts[_tokenAddress][_actionId];
    }

    // Unimplemented functions from interface
    function factories(address) external pure returns (address[] memory) {
        return new address[](0);
    }

    function factoriesCount(address) external pure returns (uint256) {
        return 0;
    }

    function factoriesAtIndex(
        address,
        uint256
    ) external pure returns (address) {
        return address(0);
    }

    function addFactory(address, address) external {}

    function existsFactory(address, address) external pure returns (bool) {
        return false;
    }

    function initializeExtension(address) external {}

    function extension(address, uint256) external pure returns (address) {
        return address(0);
    }

    function extensionInfo(
        address
    ) external pure returns (address tokenAddr, uint256 actionIdNum) {
        return (address(0), 0);
    }

    function extensions(address) external pure returns (address[] memory) {
        return new address[](0);
    }

    function extensionsCount(address) external pure returns (uint256) {
        return 0;
    }

    function extensionsAtIndex(
        address,
        uint256
    ) external pure returns (address) {
        return address(0);
    }

    function accountsCount(address, uint256) external pure returns (uint256) {
        return 0;
    }

    function accountsAtIndex(
        address,
        uint256,
        uint256
    ) external pure returns (address) {
        return address(0);
    }

    function isAccountJoined(
        address,
        uint256,
        address
    ) external pure returns (bool) {
        return false;
    }

    function actionIdsByAccount(
        address,
        address
    ) external pure returns (uint256[] memory) {
        return new uint256[](0);
    }

    function actionIdsByAccountCount(
        address,
        address
    ) external pure returns (uint256) {
        return 0;
    }

    function actionIdsByAccountAtIndex(
        address,
        address,
        uint256
    ) external pure returns (uint256) {
        return 0;
    }

    function tokenAddress() external pure returns (address) {
        return address(0);
    }

    function submitAddress() external pure returns (address) {
        return address(0);
    }

    function launchAddress() external pure returns (address) {
        return address(0);
    }

    function voteAddress() external pure returns (address) {
        return address(0);
    }

    function randomAddress() external pure returns (address) {
        return address(0);
    }
}
