// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";

abstract contract CodeConstants {
    // VRF MOCK VALUES
    uint96 public constant MOCK_BASE_FEE = 0.25 ether;
    uint96 public constant MOCK_GAS_PRICE_LINK = 1e9;

    // LINK / ETH Price
    int256 public constant MOCK_WEI_PER_UINT_LINK = 4e15;

    uint256 public constant ETH_SEPOLIA_CHAIN_ID = 1115511;
    uint256 public constant LOCAL_CHAIN_ID = 31337;
}

contract HelperConfig is Script, CodeConstants {
    error HelperConfig__InvalidChainID();
    error HelperConfig__NoLocalConfigAvailable();

    struct NetworkConfig {
        uint256 entranceFee;
        uint256 interval;
        address vrfCoordinator;
        bytes32 gasLane;
        uint32 callbackGasLimit;
        uint256 subscriptionId;
        address link;
        address account;  // Add link token address here
    }

    NetworkConfig public localNetworkConfig;
    mapping(uint256 => NetworkConfig) public networkConfigs; //uint256 represents a chainId

    constructor() {
        networkConfigs[ETH_SEPOLIA_CHAIN_ID] = getSepoliaEthConfig();
    }

    //now you need to know if the it is a local chain or not, since you either have to make a VRFCoordinater object or not
    //So you just check if the VRFCoordinator in the NetworkConfig is not 0x00000000

    function getConfigByChainId(uint256 chainId) public returns (NetworkConfig memory config) {
        if (networkConfigs[chainId].vrfCoordinator != address(0)){ //address (0) used as a placeholde for the absence of an address which is 0x000000
            return networkConfigs[chainId];
            //If the VRFoordinator address is not 0x000, then we are using a normal chain since we do not have to create a new VRFCoordinator
            //object in an actual chain
        } else if (chainId == LOCAL_CHAIN_ID) {
            return getOrCreateAnvilEthConfig();
        } else {
            revert HelperConfig__InvalidChainID();
        }
    }

    function getConfig() public returns (NetworkConfig memory) {
        return getConfigByChainId(block.chainid);
    }

    //Sepolia is a Test Network: Sepolia is an actual test network (testnet) that 
    //Simulates Ethereum’s mainnet behavior. It already has real (but test) instances of various components, including the Chainlink VRF Coordinator, Link token, and other infrastructure.
    //So no need to create the object here but we will have to create it on the anvil or local one since it does not come with the VRF component

    function getSepoliaEthConfig() public pure returns (NetworkConfig memory config) {
        return NetworkConfig({
            entranceFee: 0.01 ether,
            interval: 30, // seconds
            vrfCoordinator: 0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625,
            gasLane: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c,
            callbackGasLimit: 500000,
            subscriptionId: 0,
            link: address(0), // Add a default value for the link token address
            account: 0x53875F9a225603D09c16c71f47467DC516Ba30fC
        });
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory config) {
        if (localNetworkConfig.vrfCoordinator != address(0)) {
            return localNetworkConfig;
        }

        vm.startBroadcast(); // using broadcast since we are using anvil
        VRFCoordinatorV2_5Mock vrfCoordinatorMock = new VRFCoordinatorV2_5Mock(
            MOCK_BASE_FEE, 
            MOCK_GAS_PRICE_LINK, 
            MOCK_WEI_PER_UINT_LINK
        );
        
        LinkToken linkToken = new LinkToken();
        vm.stopBroadcast();

        localNetworkConfig = NetworkConfig({
            entranceFee: 0.01 ether,
            interval: 30, // seconds
            vrfCoordinator: address(vrfCoordinatorMock), // This has a create subscription function, see code in interactions.s.sol
            gasLane: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c,
            callbackGasLimit: 500000,
            subscriptionId: 0,
            link: address(linkToken), // Store the link token address in the config
            account: 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38 //this is the default sender address from base.sol
        });

        return localNetworkConfig;
    }
}