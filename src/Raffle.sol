// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {VRFConsumerBaseV2Plus} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

/**
 * @title A sample Raffle Contract
 * @author Ahsan Habib Akib
 * @notice This contract is for creating a sample raffle contract
 * @dev This implements the Chainlink VRF Version 2
 */

contract Raffle is VRFConsumerBaseV2Plus{
    error IncorrectEntranceFee();
    error Raffle__TransferFailed();
    error Raffle__RaffleNotOpen();
    error Raffle__UpKeepNotNeeded(uint256 balance, uint256 participantsLength);

    //Type declarations
    enum RaffleState {OPEN, CLOSED}

    //State variables
    uint16 private constant REQUEST_CONFIRMATIONS = 2;
    uint32 private constant NUM_WORDS = 1;
    uint256 private immutable i_entranceFee;
    // @dev interval is the time in seconds after which the winner will be picked
    uint256 private immutable i_interval;
    bytes32 private immutable i_keyHash;
    uint256 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;
    address payable[] private s_participants;
    address payable private s_recentWinner;
    uint256 private s_lastTimeStamp;
    RaffleState private s_raffleState;

    event RaffleEntered(address indexed participant);
    event WinnerPicked(address indexed winner);
    event RequestedRaffleWinner(uint256 requestId);

    constructor(
        uint256 _entranceFee, 
        uint256 _interval, 
        address vrfCoordinator, 
        bytes32 gasLane, 
        uint256 subscriptionId, 
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2Plus(vrfCoordinator)
    {
        i_entranceFee = _entranceFee;
        i_interval = _interval;
        s_lastTimeStamp = block.timestamp;
        i_keyHash = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;

        s_raffleState = RaffleState.OPEN;
    }

    function enterRaffle() external payable {
        //require(msg.value == i_entranceFee, "Raffle: Incorrect entrance fee");
        if (msg.value != i_entranceFee) {
            revert IncorrectEntranceFee();
        }
        if(s_raffleState != RaffleState.OPEN) {
            revert Raffle__RaffleNotOpen();
        }

        s_participants.push(payable(msg.sender));

        emit RaffleEntered(msg.sender);
    }

    function checkUpKeep(bytes memory /*checkData*/) public view returns(bool upKeepNeeded, bytes memory /* performData */) {
        bool timeHasPassed = (block.timestamp >= (s_lastTimeStamp + i_interval));
        bool isOpen = (s_raffleState == RaffleState.OPEN);
        bool hasBalance = (address(this).balance > 0);
        bool hasParticipants = (s_participants.length > 0);
        upKeepNeeded = timeHasPassed && isOpen && hasBalance && hasParticipants;
        return (upKeepNeeded, "");
    }

    function performUpKeep(bytes calldata /* performData */) external{
        (bool upKeepNeeded, ) = checkUpKeep("");
        if(!upKeepNeeded) {
            revert Raffle__UpKeepNotNeeded(address(this).balance, s_participants.length);
        }

        s_raffleState = RaffleState.CLOSED;
        
        VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient.RandomWordsRequest({
            keyHash: i_keyHash,
            subId: i_subscriptionId,
            requestConfirmations: REQUEST_CONFIRMATIONS,
            callbackGasLimit: i_callbackGasLimit,
            numWords: NUM_WORDS,
            extraArgs: VRFV2PlusClient._argsToBytes(
                VRFV2PlusClient.ExtraArgsV1({
                    nativePayment: false
                })
            )
        });
        uint256 requestId = s_vrfCoordinator.requestRandomWords(request);

        emit RequestedRaffleWinner(requestId);
    }
    
    function fulfillRandomWords(uint256 /*requestId*/, uint256[] calldata randomWords) internal override {
        uint256 winnerIndex = randomWords[0] % s_participants.length;
        address payable recentWinner = s_participants[winnerIndex];
        s_recentWinner = recentWinner;

        s_raffleState = RaffleState.OPEN;
        s_participants = new address payable[](0);
        s_lastTimeStamp = block.timestamp;
        emit WinnerPicked(s_recentWinner);

        (bool success, ) = recentWinner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle__TransferFailed();
        }
    }

    function entranceFee() external view returns (uint256) {
        return i_entranceFee;
    }

    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }

    function getParticipants(uint256 indexOfPlayers) external view returns (address) {
        return s_participants[indexOfPlayers];
    }

    function getLastTimeStamp() external view returns (uint256) {
        return s_lastTimeStamp;
    }

    function getRecentWinner() external view returns (address) {
        return s_recentWinner;
    }
}
