// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";

abstract contract CodeConstants{
    /* VRF mck values */
    uint96 public constant MOCK_BASE_FEE = 0.25 ether;
    uint96 public constant MOCK_GAS_PRICE = 1e9;
    int256 public constant MOCK_WEI_PER_UNIT_LINK = 4e15;

    uint256 public constant ETH_SEPOLIA_CHAIN_ID = 11155111;
    uint256 public constant LOCAL_CHAIN_ID = 31337;
}

contract HelperConfig is Script, CodeConstants{
    error HelperConfig__InvalidChainId();

    struct NetworkConfig{
        uint256 entranceFee;
        uint256 interval;
        address vrfCoordinator;
        bytes32 gasLane;
        uint32 callbackGasLimit;
        uint256 subscriptionId;
        address link;
        address account;
    }

    NetworkConfig public localNetworkConfig;
    mapping(uint256 chainId => NetworkConfig) public networkConfigs;

    constructor() {
        networkConfigs[ETH_SEPOLIA_CHAIN_ID] = getSepoliaEthConfig();
    }

    function getConfigByChainId(uint256 chainId) public returns(NetworkConfig memory){
        if(networkConfigs[chainId].vrfCoordinator != address(0)){
            return networkConfigs[chainId];
        } else if(chainId == LOCAL_CHAIN_ID){
            return getOrCreateAnvilEthConfig();
        } else {
            revert HelperConfig__InvalidChainId();
        }
    }

    function getConfig() public returns(NetworkConfig memory){
        return getConfigByChainId(block.chainid);
    }

    function getSepoliaEthConfig() public pure returns(NetworkConfig memory){
        return NetworkConfig({
            entranceFee: 0.01 ether,   //1e16
            interval: 30,
            vrfCoordinator: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B,
            gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            callbackGasLimit: 500000,
            subscriptionId: 44675532911566650495878925434701783067400343760908735212432426800941018658649,
            link: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
            account: 0x79a16F9887e1cD2B9A4cb6c8b73B41F9652E8FB7
        });
    }

    function getOrCreateAnvilEthConfig() public returns(NetworkConfig memory){
        //check if the localNetworkConfig is already set
        if(localNetworkConfig.vrfCoordinator != address(0)){
            return localNetworkConfig;
        }

        //Deploy mocks for the local chain
        vm.startBroadcast();
        VRFCoordinatorV2_5Mock vrfCoordinator = new VRFCoordinatorV2_5Mock(
            MOCK_BASE_FEE, 
            MOCK_GAS_PRICE, 
            MOCK_WEI_PER_UNIT_LINK
        );
        LinkToken linkToken = new LinkToken();
        vm.stopBroadcast();

        localNetworkConfig = NetworkConfig({
            entranceFee: 0.01 ether,   //1e16
            interval: 30,
            vrfCoordinator: address(vrfCoordinator),
            gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,  //Doesn't matter
            callbackGasLimit: 500000,
            subscriptionId: 0,
            link: address(linkToken),
            account: 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38
        });
        return localNetworkConfig;
    }

}