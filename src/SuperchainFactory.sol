// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IL2ToL2CrossDomainMessenger} from "optimism/packages/contracts-bedrock/interfaces/L2/IL2ToL2CrossDomainMessenger.sol";
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

    // Struct to hold sibling factory information
    struct SiblingFactory {
        uint256 chainId;
        address factoryAddress;
    }

    // Array of sibling factories with chain IDs
    SiblingFactory[] public siblingFactories;

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
    event SiblingFactoryAdded(
        uint256 indexed chainId,
        address indexed factoryAddress
    );

    modifier onlyOwner() {
        require(msg.sender == owner, "SuperchainFactory: Only owner can call");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    /**
     * @dev Adds a new sibling factory address with chain ID.
     * @param chainId The chain ID where the sibling factory is deployed.
     * @param factoryAddress The address of the sibling factory contract.
     */
    function addSiblingFactory(
        uint256 chainId,
        address factoryAddress
    ) external onlyOwner {
        require(
            factoryAddress != address(0),
            "SuperchainFactory: Invalid address"
        );
        siblingFactories.push(SiblingFactory(chainId, factoryAddress));
        emit SiblingFactoryAdded(chainId, factoryAddress);
    }

    /**
     * @dev Deploys a contract on the current chain and sends cross-chain messages to deploy on all sibling chains.
     * @param bytecode The creation bytecode of the contract to deploy.
     * @param salt A unique salt for deterministic deployment (CREATE2).
     */
    function deployEverywhere(bytes memory bytecode, bytes32 salt) external {
        // Step 1: Deploy on the current chain
        address deployedAddr = _deploy(bytecode, salt);
        emit ContractDeployed(deployedAddr, block.chainid);

        // Step 2: Send cross-chain messages to sibling chains
        for (uint i = 0; i < siblingFactories.length; i++) {
            SiblingFactory memory sibling = siblingFactories[i];

            // Encode the deploy call for the target factory
            bytes memory message = abi.encodeCall(
                this.deploy,
                (bytecode, salt)
            );

            // Send cross-chain message
            messenger.sendMessage(
                sibling.chainId,
                sibling.factoryAddress,
                message
            );

            emit CrossChainMessageSent(sibling.chainId, sibling.factoryAddress);
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
     * @dev Checks if an address is a registered sibling factory.
     * @param factory Address to check.
     * @return True if the address is a sibling factory.
     */
    function isSiblingFactory(address factory) public view returns (bool) {
        for (uint i = 0; i < siblingFactories.length; i++) {
            if (siblingFactories[i].factoryAddress == factory) {
                return true;
            }
        }
        return false;
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

    /**
     * @dev Returns the list of sibling factories.
     */
    function getSiblingFactories()
        external
        view
        returns (SiblingFactory[] memory)
    {
        return siblingFactories;
    }
}
