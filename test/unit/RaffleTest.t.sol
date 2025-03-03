// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {Script, console} from "forge-std/Script.sol";
import {Raffle} from "src/Raffle.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2_5Mock} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

contract RaffleTest is Test {
    Raffle public raffle;
    HelperConfig public helperConfig;

    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint32 callbackGasLimit;
    uint256 subscriptionId;
    
    address public PARTICIPANT = makeAddr("participant");
    uint256 public constant STARTING_BALANCE = 10 ether;

    event RaffleEntered(address indexed participant);
    event WinnerPicked(address indexed winner);

    function setUp() external {
        DeployRaffle deployRaffle = new DeployRaffle();
        (raffle, helperConfig) = deployRaffle.deployContract();

        HelperConfig.NetworkConfig memory networkConfig = helperConfig.getConfig();
        entranceFee = networkConfig.entranceFee;
        interval = networkConfig.interval;
        vrfCoordinator = networkConfig.vrfCoordinator;
        gasLane = networkConfig.gasLane;
        callbackGasLimit = networkConfig.callbackGasLimit;
        subscriptionId = networkConfig.subscriptionId;

        vm.deal(PARTICIPANT, STARTING_BALANCE);
    }

    function testRaffleInitialState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    function testRaffleEntranceFeeIsNotEnough() public {
        vm.prank(PARTICIPANT);
        vm.expectRevert(Raffle.IncorrectEntranceFee.selector);
        raffle.enterRaffle();
    }

    function testParticipantsAreRecorded() public {
        vm.prank(PARTICIPANT);
        raffle.enterRaffle{value: entranceFee}();
        address participantRecorded = raffle.getParticipants(0);
        assert(participantRecorded == PARTICIPANT);
    }

    function testEnteringRaffleEmitsEvent() public {
        //Arrange
        vm.prank(PARTICIPANT);
        //Act
        vm.expectEmit(true, false, false, false, address(raffle));
        emit RaffleEntered(PARTICIPANT);
        //Assert
        raffle.enterRaffle{value: entranceFee}();
    }

    modifier raffleEntry() {
        vm.prank(PARTICIPANT);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    function testDontAllowRaffleEntranceAfterRaffleIsClosed() public raffleEntry{
        //Arrange
        raffle.performUpKeep("");
        //Act
        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        vm.prank(PARTICIPANT);
        raffle.enterRaffle{value: entranceFee}();
    }

    /*//////////////////////////////////// 
             CheckUpKeep tests 
    /////////////////////////////////////*/

    function testCheckUpKeepReturnsFalseIfItHasNoBalance() public {
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        (bool upKeepNeeded, ) = raffle.checkUpKeep("");
        assert(!upKeepNeeded);
    }

    function testCheckUpKeepReturnsFalseIfRaffleIsntOpen() public raffleEntry {
        raffle.performUpKeep("");

        (bool upKeepNeeded, ) = raffle.checkUpKeep("");
        assert(!upKeepNeeded);
    }

    function testCheckUpKeepReturnsFalseIfTimeHasntPassed() public {
        vm.prank(PARTICIPANT);
        raffle.enterRaffle{value: entranceFee}();

        (bool upKeepNeeded, ) = raffle.checkUpKeep("");
        assert(!upKeepNeeded);
    }

    function testCheckUpKeepReturnsTrueWhenParametersAreGood() public raffleEntry{
        // vm.prank(PARTICIPANT);
        // raffle.enterRaffle{value: entranceFee}();
        // vm.warp(block.timestamp + interval + 1);
        // vm.roll(block.number + 1);
        
        (bool upKeepNeeded, ) = raffle.checkUpKeep("");
        assert(upKeepNeeded);
    }

    /*//////////////////////////////////// 
             PerformUpKeep tests 
    /////////////////////////////////////*/

    function testPerformUpKeepCanOnlyRunWhenUpKeepNeeded() public raffleEntry{
        // vm.prank(PARTICIPANT);
        // raffle.enterRaffle{value: entranceFee}();
        // vm.warp(block.timestamp + interval + 1);
        // vm.roll(block.number + 1);

        raffle.performUpKeep("");
    }

    /*///////////////////////////////////// 
       Fetching data from emitted events 
    /////////////////////////////////////*/

    function testPerformUpKeepUpdatesRaffleStateAndEmitsRequestId() public raffleEntry{
        //Arrange

        //Act
        vm.recordLogs();
        raffle.performUpKeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[0].topics[1];

        Raffle.RaffleState raffleState = raffle.getRaffleState();
        assert(uint256(requestId) > 0);
        assert(uint256(raffleState) == 1);
    }

    /*///////////////////////////////////// 
                 Fuzz testing 
    /////////////////////////////////////*/

    function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpKeep(uint256 randomRequestId) public raffleEntry {
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(randomRequestId, address(raffle));
    }

    function testFulfillRandomWordsPicksAWinnerResetsAndSendsMoney() public raffleEntry{
        uint256 additionalEntries = 3;  //Total 4 participants
        uint256 startingIndex = 1;
        address expectectedWinner = address(1);

        for(uint256 i = startingIndex; i < startingIndex + additionalEntries; i++){
            address newParticipant = address(uint160(i));
            hoax(newParticipant, 1 ether);
            raffle.enterRaffle{value: entranceFee}();
        }
        uint256 startingTimeStamp = raffle.getLastTimeStamp();
        uint256 winnerStartingBalance = expectectedWinner.balance;

        //Act
        vm.recordLogs();
        raffle.performUpKeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        //uint256 requestId = uint256(entries[0].topics[0]);
        //VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(requestId, address(raffle));
        uint256 requestId = abi.decode(entries[0].data, (uint256));
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(requestId, address(raffle));

        //Assert
        address recentWinner = raffle.getRecentWinner();
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        uint256 winnerBalance = recentWinner.balance;
        uint256 endingTimeStamp = raffle.getLastTimeStamp();
        uint256 price = entranceFee * (additionalEntries + 1);

        assert(recentWinner == expectectedWinner);
        assert(uint256(raffleState) == 0);
        assert(winnerBalance == winnerStartingBalance + price);
        assert(endingTimeStamp > startingTimeStamp);
    }
}