// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {Distributor} from "../src/Distributor.sol";

contract DeployVault is Script {
    function run() external returns (Distributor, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig(); // This comes with our mocks!
        (
            address forwarder,
            address operator,
            address underlyingAsset,
            uint256 deployerKey
        ) = helperConfig.activeNetworkConfig();

        vm.startBroadcast(deployerKey);
        Distributor distributor = new Distributor(
            forwarder,
            operator,
            underlyingAsset
        );
        vm.stopBroadcast();
        return (distributor, helperConfig);
    }
}
