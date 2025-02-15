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
        address factoryOPChainA = 0xb19b36b1456E65E3A6D514D3F715f204BD59f431; // Replace
        address factoryOPChainB = 0xb19b36b1456E65E3A6D514D3F715f204BD59f431; // Replace

        // Chain IDs for OPChainA and OPChainB (replace with actual chain IDs)
        uint256 chainIdOPChainA = 901; // Replace with actual chain ID for OPChainA
        uint256 chainIdOPChainB = 902; // Replace with actual chain ID for OPChainB

        // Deploy TestToken on OPChainA and propagate to OPChainB
        vm.createSelectFork("http://127.0.0.1:9545"); // OPChainA
        vm.startBroadcast(deployerPrivateKey);

        // Add sibling factory for OPChainB on OPChainA
        // SuperchainFactory(factoryOPChainA).addSiblingFactory(
        //     chainIdOPChainB,
        //     factoryOPChainB
        // );

        // Deploy TestToken on OPChainA and propagate to OPChainB
        bytes memory bytecode = type(TestToken).creationCode;
        bytes32 salt = keccak256("test-salt");

        // Get sibling factories (for debugging/logging)
        SuperchainFactory.SiblingFactory[] memory siblings = SuperchainFactory(
            factoryOPChainA
        ).getSiblingFactories();
        console.log("Sibling factories on OPChainA:");
        for (uint256 i = 0; i < siblings.length; i++) {
            console.log(
                "Chain ID:",
                siblings[i].chainId,
                "Factory Address:",
                siblings[i].factoryAddress
            );
        }

        // Trigger deployment on OPChainA and propagate to OPChainB
        SuperchainFactory(factoryOPChainA).deployEverywhere(bytecode, salt);

        vm.stopBroadcast();

        // Verify deployment on OPChainB
        vm.createSelectFork("http://127.0.0.1:9546"); // OPChainB

        // Compute the CREATE2 address for the deployed contract
        address predictedAddr = computeCreate2Address(
            salt,
            keccak256(bytecode),
            factoryOPChainB
        );
        console.log("Predicted contract address on OPChainB:", predictedAddr);

        // Verify the contract is deployed
        require(
            predictedAddr.code.length > 0,
            "Contract not deployed on OPChainB"
        );
        console.log(
            "Contract successfully deployed on OPChainB at:",
            predictedAddr
        );
    }

    /**
     * @dev Computes the CREATE2 address for a contract.
     * @param salt The salt used for CREATE2 deployment.
     * @param bytecodeHash The keccak256 hash of the contract creation bytecode.
     * @param deployer The address of the deployer (factory contract).
     * @return The computed CREATE2 address.
     */
    function computeCreate2Address(
        bytes32 salt,
        bytes32 bytecodeHash,
        address deployer
    ) internal pure override returns (address) {
        return
            address(
                uint160(
                    uint256(
                        keccak256(
                            abi.encodePacked(
                                bytes1(0xff),
                                deployer,
                                salt,
                                bytecodeHash
                            )
                        )
                    )
                )
            );
    }
}
