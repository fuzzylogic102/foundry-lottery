// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "src/Raffle.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import "forge-std/console.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "script/Interactions.s.sol";


contract DeployRaffle is Script{

    function run() public {
        
    }

function deployContract() public returns (Raffle, HelperConfig){
    HelperConfig helperConfig = new HelperConfig();
    HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

    if (config.subscriptionId == 0) {
        CreateSubscription createSubscription = new CreateSubscription();
        (config.subscriptionId, config.vrfCoordinator) = createSubscription.createSubscription(config.vrfCoordinator, config.account);

        //Fund it
         FundSubscription fundSubscription = new FundSubscription();
         fundSubscription.fundSubscription(config.vrfCoordinator, config.subscriptionId, config.link, config.account);
    }

    // Debugging: Log the values
    console.log("Entrance Fee:", config.entranceFee);
    console.log("Interval:", config.interval);
    console.log("VRF Coordinator:", config.vrfCoordinator);
    console.log("Subscription ID:", config.subscriptionId);
    console.log("Callback Gas Limit:", config.callbackGasLimit);

    vm.startBroadcast(config.account);
    Raffle raffle = new Raffle(
        config.entranceFee,
        config.interval,
        config.vrfCoordinator,
        config.gasLane,
        config.subscriptionId,
        config.callbackGasLimit
    );
    vm.stopBroadcast();

    AddConsumer addConsumer = new AddConsumer();
    // don't need to broadcast.....
    addConsumer.addConsumer(address(raffle), config.vrfCoordinator, config.subscriptionId, config.account);

    return(raffle, helperConfig);
}
}
