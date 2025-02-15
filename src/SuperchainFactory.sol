// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IL2ToL2CrossDomainMessenger} from "lib/optimism/packages/contracts-bedrock/interfaces/L2/IL2ToL2CrossDomainMessenger.sol"; 
import {Predeploys} from "optimism/packages/contracts-bedrock/src/libraries/Predeploys.sol";

error CallerNotL2ToL2CrossDomainMessenger();
error InvalidCrossDomainSender();

contract SuperchainFactory {
    // Immutable reference to the L2 CrossDomainMessenger
    IL2ToL2CrossDomainMessenger internal messenger =
        IL2ToL2CrossDomainMessenger(Predeploys.L2_TO_L2_CROSS_DOMAIN_MESSENGER);

    modifier onlyCrossDomainCallback() {
        if (msg.sender != address(messenger))
            revert CallerNotL2ToL2CrossDomainMessenger();
        if (messenger.crossDomainMessageSender() != address(this))
            revert InvalidCrossDomainSender();
        _;
    }

    // Contract owner
    address public owner;

    // Events for tracking deployments
    event ContractDeployed(
        address indexed contractAddress,
        uint256 indexed chainId
    );
    event CrossChainMessageSent(
        uint256 indexed chainId,
        address indexed targetFactory
    );

    modifier onlyOwner() {
        require(msg.sender == owner, "SuperchainFactory: Only owner can call");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    /**
     * @dev Deploys a contract on the current chain and sends cross-chain messages to deploy it on the specified chains.
     * @param chainIds Array of chain IDs on which to deploy the contract.
     * @param bytecode The creation bytecode of the contract to deploy.
     * @param salt A unique salt for deterministic deployment (CREATE2).
     */
    function deployEverywhere(
        uint256[] calldata chainIds,
        bytes memory bytecode,
        bytes32 salt
    ) external onlyOwner {
        // Step 1: Deploy on the current chain
        address deployedAddr = _deploy(bytecode, salt);
        emit ContractDeployed(deployedAddr, block.chainid);

        // Step 2: Send cross-chain messages to each target chain.
        for (uint i = 0; i < chainIds.length; i++) {
            bytes memory message = abi.encodeCall(this.deploy, (bytecode, salt));
            messenger.sendMessage(
                chainIds[i],
                address(this),
                message
            );
            emit CrossChainMessageSent(chainIds[i], address(this));
        }
    }

    /**
     * @dev Deploys a contract on the current chain when triggered by a cross-chain message.
     * @param bytecode The creation bytecode of the contract to deploy.
     * @param salt A unique salt for deterministic deployment (CREATE2).
     */
    function deploy(
        bytes memory bytecode,
        bytes32 salt
    ) external onlyCrossDomainCallback {
        _deploy(bytecode, salt);
    }

    /**
     * @dev Internal helper function to deploy a contract using CREATE2.
     * @param bytecode The creation bytecode of the contract to deploy.
     * @param salt A unique salt for deterministic deployment.
     * @return The address of the deployed contract.
     */
    function _deploy(
        bytes memory bytecode,
        bytes32 salt
    ) internal returns (address) {
        address addr;
        assembly {
            addr := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
            if iszero(extcodesize(addr)) {
                revert(0, 0)
            }
        }
        return addr;
    }
}
