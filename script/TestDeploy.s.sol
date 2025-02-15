// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/TestToken.sol";
import "../src/SuperchainFactory.sol";

contract TestDeploy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        console.log("deployer:", deployer);

        // Factory addresses (replace with actual addresses from Step 2)
        address factoryOPChainA = 0x700b6A60ce7EaaEA56F065753d8dcB9653dbAD35; // Replace
        address factoryOPChainB = 0x700b6A60ce7EaaEA56F065753d8dcB9653dbAD35; // Replace

        // Deploy TestToken on OPChainA and propagate to OPChainB
        vm.createSelectFork("http://127.0.0.1:9545"); // OPChainA
        vm.startBroadcast(deployerPrivateKey);

        bytes memory bytecode = type(TestToken).creationCode;
        bytes32 salt = keccak256("test-salt");
        address[] memory siblings = SuperchainFactory(factoryOPChainA)
            .getSiblingFactories();
        console.log("Sibling factories on OPChainA:", siblings[0]);

        SuperchainFactory(factoryOPChainA).deployEverywhere(bytecode, salt);

        vm.stopBroadcast();

        // Verify deployment on OPChainB
        vm.createSelectFork("http://127.0.0.1:9546"); // OPChainB
        address predictedAddr = computeCreate2Address(
            salt,
            keccak256(bytecode),
            factoryOPChainB
        );
        require(
            predictedAddr.code.length > 0,
            "Contract not deployed on OPChainB"
        );
    }
}
