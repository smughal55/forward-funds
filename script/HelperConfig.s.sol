// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract HelperConfig is Script {
    NetworkConfig public activeNetworkConfig;

    struct NetworkConfig {
        address forwarder;
        address operator;
        address underlyingAsset;
        uint256 deployerKey;
    }

    uint256 public DEFAULT_ANVIL_PRIVATE_KEY =
        0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    constructor() {
        if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaEthConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilEthConfig();
        }
    }

    function getSepoliaEthConfig()
        public
        view
        returns (NetworkConfig memory sepoliaNetworkConfig)
    {
        sepoliaNetworkConfig = NetworkConfig({
            forwarder: vm.envAddress("FORWARDER_ADDRESS"),
            operator: vm.envAddress("PRIVATE_KEY"),
            underlyingAsset: vm.envAddress("ERC20_ADDRESS"),
            deployerKey: vm.envUint("PRIVATE_KEY")
        });
    }

    function getOrCreateAnvilEthConfig()
        public
        returns (NetworkConfig memory anvilNetworkConfig)
    {
        //Check to see if the active network config is already set
        if (activeNetworkConfig.underlyingAsset != address(0)) {
            return activeNetworkConfig;
        }

        vm.startBroadcast();
        ERC20Mock underlyingAssetMock = new ERC20Mock();
        vm.stopBroadcast();

        // address[] memory _recipients = new address[](5);
        // _recipients[0] = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;
        // _recipients[1] = 0x90F79bf6EB2c4f870365E785982E1f101E93b906;
        // _recipients[2] = 0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65;
        // _recipients[3] = 0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc;
        // _recipients[4] = 0x976EA74026E726554dB657fA54763abd0C3a0aa9;

        anvilNetworkConfig = NetworkConfig({
            forwarder: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266,
            operator: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266,
            underlyingAsset: address(underlyingAssetMock),
            deployerKey: DEFAULT_ANVIL_PRIVATE_KEY
        });
    }
}
