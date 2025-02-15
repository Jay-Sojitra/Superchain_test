// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IL2CrossDomainMessenger} from "optimism/packages/contracts-bedrock/interfaces/L2/IL2CrossDomainMessenger.sol";

contract SuperchainFactory {
    // Immutable reference to the L2 CrossDomainMessenger
    IL2CrossDomainMessenger public immutable messenger;

    // Addresses of the same factory contract on other chains
    address[] public siblingFactories;

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
    event SiblingFactoryAdded(address indexed siblingFactory);

    modifier onlyOwner() {
        require(msg.sender == owner, "SuperchainFactory: Only owner can call");
        _;
    }

    constructor(address _messenger) {
        messenger = IL2CrossDomainMessenger(_messenger);
        owner = msg.sender;
    }

    /**
     * @dev Adds a new sibling factory address.
     * @param sibling The address of the sibling factory contract.
     */
    function addSiblingFactory(address sibling) external onlyOwner {
        require(sibling != address(0), "SuperchainFactory: Invalid address");
        siblingFactories.push(sibling);
        emit SiblingFactoryAdded(sibling);
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
            bytes memory message = abi.encodeWithSignature(
                "deploy(bytes,bytes32)",
                bytecode,
                salt
            );
            messenger.sendMessage(
                siblingFactories[i],
                message,
                2_000_000 // Gas limit (adjustable)
            );
            emit CrossChainMessageSent(block.chainid, siblingFactories[i]);
        }
    }

    /**
     * @dev Deploys a contract on the current chain when triggered by a cross-chain message.
     * @param bytecode The creation bytecode of the contract to deploy.
     * @param salt A unique salt for deterministic deployment (CREATE2).
     */
    function deploy(bytes memory bytecode, bytes32 salt) external {
        // Ensure the call is from the CrossDomainMessenger and the sender is the source factory
        require(
            msg.sender == address(messenger),
            "SuperchainFactory: Only callable by CrossDomainMessenger"
        );
        address sourceFactory = messenger.xDomainMessageSender();
        require(
            sourceFactory == address(this) || isSiblingFactory(sourceFactory),
            "SuperchainFactory: Invalid sender"
        );

        // Deploy the contract
        _deploy(bytecode, salt);
    }

    function isSiblingFactory(address factory) public view returns (bool) {
        for (uint i = 0; i < siblingFactories.length; i++) {
            if (siblingFactories[i] == factory) {
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
    function getSiblingFactories() external view returns (address[] memory) {
        return siblingFactories;
    }
}
