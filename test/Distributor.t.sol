// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Distributor} from "../src/Distributor.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";
import {DeployDistributor} from "../script/DeployDistributor.s.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

using SafeERC20 for IERC20;

contract DistributorTest is Test {
    Distributor distributor;
    HelperConfig helperConfig;
    ERC20Mock underlyingAsset;

    function setUp() public {
        DeployDistributor deployDistributor = new DeployDistributor();
        (distributor, helperConfig) = deployDistributor.run();

        (, , address underlyingAssetAddress, ) = helperConfig
            .activeNetworkConfig();

        underlyingAsset = ERC20Mock(underlyingAssetAddress);
    }

    function test_deposit() public {
        uint256 amount = 1000;
        underlyingAsset.mint(address(this), amount);
        underlyingAsset.approve(address(distributor), amount);
        distributor.deposit(amount);
        assertEq(underlyingAsset.balanceOf(address(distributor)), amount);
    }

    function test_forwardFunds() public {
        uint256 amount = 1000;
        underlyingAsset.mint(address(this), amount);
        underlyingAsset.approve(address(distributor), amount);
        distributor.deposit(amount);
        address[] memory recipients = new address[](5);
        recipients[0] = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;
        recipients[1] = 0x90F79bf6EB2c4f870365E785982E1f101E93b906;
        recipients[2] = 0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65;
        recipients[3] = 0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc;
        recipients[4] = 0x976EA74026E726554dB657fA54763abd0C3a0aa9;
        uint256[] memory splits = new uint256[](5);
        splits[0] = 20;
        splits[1] = 20;
        splits[2] = 20;
        splits[3] = 20;
        splits[4] = 20;
        distributor.updateReceipients(recipients);
        distributor.forward_funds(1000, splits, 0);
        for (uint256 i = 0; i < 5; i++) {
            assertEq(underlyingAsset.balanceOf(recipients[i]), amount / 5);
        }
    }
}
