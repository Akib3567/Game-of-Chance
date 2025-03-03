// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "src/Raffle.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "script/Interactions.s.sol";

contract DeployRaffle is Script
{
    function run() public{
        deployContract();
    }

    function deployContract() public returns(Raffle, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory networkConfig = helperConfig.getConfig();

        //Creating a new Subscription
        if(networkConfig.subscriptionId == 0){
            CreateSubscription create_Subscription = new CreateSubscription();
            (networkConfig.subscriptionId, networkConfig.vrfCoordinator) = 
                create_Subscription.createSubscription(networkConfig.vrfCoordinator, networkConfig.account);

            //Funding the Subscription
            FundSubscription fund_Subscription = new FundSubscription();
            fund_Subscription.fundSubscription(networkConfig.vrfCoordinator, networkConfig.subscriptionId, networkConfig.link, networkConfig.account);
        }

        vm.startBroadcast(networkConfig.account);
        Raffle raffle = new Raffle(
            networkConfig.entranceFee,
            networkConfig.interval,
            networkConfig.vrfCoordinator,
            networkConfig.gasLane,
            networkConfig.subscriptionId,
            networkConfig.callbackGasLimit
        );
        vm.stopBroadcast();

        AddConsumer add_Consumer = new AddConsumer();
        add_Consumer.addConsumer(address(raffle), networkConfig.vrfCoordinator, networkConfig.subscriptionId, networkConfig.account);

        return (raffle, helperConfig);
    }
}