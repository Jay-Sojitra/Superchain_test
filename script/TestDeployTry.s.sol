// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/TestToken.sol";
import "../src/SuperchainFactory.sol";

contract TestDeploy is Script {
    // Supersim's predeploy addresses
    address constant L2_CROSS_DOMAIN_MESSENGER =
        0x4200000000000000000000000000000000000023;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        console.log("deployer:", deployer);

        // Chain IDs for OPChainA and OPChainB (replace with actual chain IDs)
        uint256 chainIdOPChainA = 901; // Replace with actual chain ID for OPChainA
        uint256 chainIdOPChainB = 902; // Replace with actual chain ID for OPChainB

        // Deploy factory on ChainA if not already deployed
        uint256 fork1 = vm.createFork("http://127.0.0.1:9545"); // OPChainA
        uint256 fork2 = vm.createFork("http://127.0.0.1:9546"); // OPChainB

        vm.selectFork(fork1); // OPChainA
        vm.startBroadcast(deployerPrivateKey);

        // First deploy the factory if not already deployed
        SuperchainFactory factoryA;
        address factoryOPChainA = 0x700b6A60ce7EaaEA56F065753d8dcB9653dbAD35;

        uint size;
        assembly {
            size := extcodesize(factoryOPChainA)
        }

        if (size == 0) {
            console.log("Deploying new factory on ChainA");
            factoryA = new SuperchainFactory();
            factoryOPChainA = address(factoryA);
        } else {
            console.log("Using existing factory on ChainA");
            factoryA = SuperchainFactory(factoryOPChainA);
        }
        vm.stopBroadcast();

        // Deploy factory on ChainB if needed
        vm.selectFork(fork2); // OPChainB
        vm.startBroadcast(deployerPrivateKey);

        address factoryOPChainB = 0x700b6A60ce7EaaEA56F065753d8dcB9653dbAD35;

        assembly {
            size := extcodesize(factoryOPChainB)
        }

        if (size == 0) {
            console.log("Deploying new factory on ChainB");
            SuperchainFactory factoryB = new SuperchainFactory();
            factoryOPChainB = address(factoryB);
        } else {
            console.log("Using existing factory on ChainB");
        }

        vm.stopBroadcast();

        // Switch back to ChainA to set up sibling relationship
        vm.selectFork(fork1);
        vm.startBroadcast(deployerPrivateKey);

        uint256 messengerSize;
        assembly {
            messengerSize := extcodesize(L2_CROSS_DOMAIN_MESSENGER)
        }
        console.log("L2CrossDomainMessenger code size:", messengerSize);
        require(messengerSize > 0, "L2CrossDomainMessenger not deployed");

        // Check if it's initialized
        (bool success, ) = L2_CROSS_DOMAIN_MESSENGER.staticcall(
            abi.encodeWithSignature("version()")
        );
        console.log("L2CrossDomainMessenger initialized:", success);

        // Check if sibling is already added
        SuperchainFactory.SiblingFactory[] memory siblings = factoryA
            .getSiblingFactories();
        bool siblingExists = false;
        for (uint i = 0; i < siblings.length; i++) {
            if (
                siblings[i].factoryAddress == factoryOPChainB &&
                siblings[i].chainId == chainIdOPChainB
            ) {
                siblingExists = true;
                break;
            }
        }

        if (!siblingExists) {
            console.log("Adding ChainB factory as sibling");
            factoryA.addSiblingFactory(chainIdOPChainB, factoryOPChainB);
        }

        // Deploy TestToken
        console.log("Deploying TestToken through factory");
        bytes memory bytecode = type(TestToken).creationCode;
        bytes32 salt = keccak256("test-salt");

        try factoryA.deployEverywhere(bytecode, salt) {
            console.log("Token deployment initiated successfully");
        } catch Error(string memory reason) {
            console.log("Token deployment failed:", reason);
            revert(reason);
        } catch (bytes memory) {
            console.log("Token deployment failed with raw revert");
            revert("Raw revert in deployEverywhere");
        }

        vm.stopBroadcast();

        // Wait for a few blocks to allow cross-chain message to be processed
        vm.roll(block.number + 5);

        // Verify deployment on ChainB
        vm.selectFork(fork2);
        vm.startBroadcast(deployerPrivateKey);

        address predictedAddr = computeCreate2Address(
            salt,
            keccak256(bytecode),
            factoryOPChainB
        );

        assembly {
            size := extcodesize(predictedAddr)
        }
        console.log("Contract size on ChainB:", size);
        console.log("Predicted address on ChainB:", predictedAddr);
        vm.stopBroadcast();
    }

    function computeCreate2Address(
        bytes32 salt,
        bytes32 codeHash,
        address deployer
    ) internal override pure returns (address) {
        return
            address(
                uint160(
                    uint(
                        keccak256(
                            abi.encodePacked(
                                bytes1(0xff),
                                deployer,
                                salt,
                                codeHash
                            )
                        )
                    )
                )
            );
    }
}
