// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/SuperchainFactory.sol";

contract DeployFactory is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        ChainConfig[] memory chains = new ChainConfig[](2);
        chains[0] = ChainConfig(901, "http://127.0.0.1:9545"); // OPChainA
        chains[1] = ChainConfig(902, "http://127.0.0.1:9546"); // OPChainB

        // Create persistent forks for each chain
        uint256 fork1 = vm.createFork(chains[0].rpcUrl);
        uint256 fork2 = vm.createFork(chains[1].rpcUrl);

        // Deploy factories on both chains
        address[] memory factoryAddresses = new address[](2);

        // Deploy on Chain 1 (OPChainA)
        vm.selectFork(fork1);
        vm.startBroadcast(deployerPrivateKey);
        SuperchainFactory factory1 = new SuperchainFactory(
            0x4200000000000000000000000000000000000023
        );
        factoryAddresses[0] = address(factory1);
        vm.stopBroadcast();
        console.log("Factory on OPChainA:", factoryAddresses[0]);

        // Deploy on Chain 2 (OPChainB)
        vm.selectFork(fork2);
        vm.startBroadcast(deployerPrivateKey);
        SuperchainFactory factory2 = new SuperchainFactory(
            0x4200000000000000000000000000000000000023
        );
        factoryAddresses[1] = address(factory2);
        vm.stopBroadcast();
        console.log("Factory on OPChainB:", factoryAddresses[1]);

        // Add siblings (Chain 1)
        vm.selectFork(fork1);
        vm.startBroadcast(deployerPrivateKey);
        SuperchainFactory(factoryAddresses[0]).addSiblingFactory(
            factoryAddresses[1]
        );
        vm.stopBroadcast();
        address[] memory siblings = factory1.getSiblingFactories();
        console.log("Sibling factories on OPChainA:", siblings[0]);

        // Add siblings (Chain 2)
        vm.selectFork(fork2);
        vm.startBroadcast(deployerPrivateKey);
        SuperchainFactory(factoryAddresses[1]).addSiblingFactory(
            factoryAddresses[0]
        );

        vm.stopBroadcast();
        siblings = factory2.getSiblingFactories();
        console.log("Sibling factories on OPChainB:", siblings[0]);

        console.log("Sibling factories added successfully!");
    }
}

struct ChainConfig {
    uint256 chainId;
    string rpcUrl;
}
