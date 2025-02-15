// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.0;

// import "forge-std/Test.sol";
// import "../src/SuperchainFactory.sol";
// import "../src/TestToken.sol";

// contract SuperchainTest is Test {
//     // Simulate two Superchains: Chain 1 (source) and Chain 2 (destination)
//     uint256 chain1 = 901;
//     uint256 chain2 = 902;

//     // CrossDomainMessenger addresses (mocked for Supersim)
//     address messengerChain1 = 0x4200000000000000000000000000000000000007;
//     address messengerChain2 = 0x4200000000000000000000000000000000000007;

//     // Factories on both chains
//     SuperchainFactory factoryChain1;
//     SuperchainFactory factoryChain2;

//     function setUp() public {
//         // Deploy factories on both chains
//         vm.chainId(chain1);
//         address[] memory siblingsChain1 = new address[](1);
//         siblingsChain1[0] = address(0xFactoryChain2); // Placeholder (updated later)
//         factoryChain1 = new SuperchainFactory(messengerChain1, siblingsChain1);

//         vm.chainId(chain2);
//         address[] memory siblingsChain2 = new address[](1);
//         siblingsChain2[0] = address(factoryChain1);
//         factoryChain2 = new SuperchainFactory(messengerChain2, siblingsChain2);

//         // Update sibling addresses
//         factoryChain1.setSiblingFactories(address[](address(factoryChain2)));
//         factoryChain2.setSiblingFactories(address[](address(factoryChain1)));
//     }

//     function testCrossChainDeployment() public {
//         // Generate TestToken bytecode and salt
//         bytes memory bytecode = type(TestToken).creationCode;
//         bytes32 salt = keccak256("test-salt");

//         // Switch to Chain 1 and deploy everywhere
//         vm.chainId(chain1);
//         factoryChain1.deployEverywhere(bytecode, salt);

//         // Check deployment on Chain 1
//         address predictedAddrChain1 = computeCreate2Address(
//             salt,
//             keccak256(bytecode),
//             address(factoryChain1)
//         );
//         assertEq(predictedAddrChain1.code.length > 0, true);

//         // Simulate cross-chain message relay (Supersim handles this)
//         vm.chainId(chain2);
//         vm.prank(messengerChain2); // Mock CrossDomainMessenger
//         factoryChain2.deploy(bytecode, salt);

//         // Check deployment on Chain 2
//         address predictedAddrChain2 = computeCreate2Address(
//             salt,
//             keccak256(bytecode),
//             address(factoryChain2)
//         );
//         assertEq(predictedAddrChain2.code.length > 0, true);

//         // Ensure addresses match across chains
//         assertEq(predictedAddrChain1, predictedAddrChain2);
//     }
// }
