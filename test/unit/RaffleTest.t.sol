// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {Raffle} from "src/Raffle.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {console} from "forge-std/Script.sol";
import {CodeConstants} from "script/HelperConfig.s.sol";

contract RaffleTest is Test, CodeConstants {
    Raffle public raffle;
    HelperConfig public helperConfig;

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_PLAYER_BALANCE = 10 ether;

    uint256 public entranceFee;
    uint256 public interval;
    address public vrfCoordinator;
    bytes32 public gasLane;
    uint32 public callbackGasLimit;
    uint256 public subscriptionId;

    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner); //to test out events and emitting in testing, you need to copy paste your events into your test folder

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.deployContract();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        entranceFee = config.entranceFee;
        interval = config.interval;
        vrfCoordinator = config.vrfCoordinator;
        gasLane = config.gasLane;
        callbackGasLimit = config.callbackGasLimit;
        subscriptionId = config.subscriptionId;
    }

    function testRaffleInitializesInOpenState() view public {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    function testRaffleRevertsWhenYouDontPayEnough() public {
        // Arrange
        vm.prank(PLAYER);
        // Act
        vm.expectRevert(Raffle.Raffle__NotEnoughEthSent.selector);
        //Assert
        raffle.enterRaffle();
    }

    function testRaffleRecordsPlayersWhenTheyEnter() public{
        vm.prank(PLAYER);
        vm.deal(PLAYER, STARTING_PLAYER_BALANCE);
        raffle.enterRaffle{value: entranceFee}();
        address playerRecorded = raffle.getPlayer(0);
        assert(PLAYER == playerRecorded);
    }

    function testEnteringRaffleEmitsEvent() public{
        //Arrange
        vm.prank(PLAYER);
        vm.deal(PLAYER, STARTING_PLAYER_BALANCE);
        //Act
        vm.expectEmit(true, false, false, false, address(raffle));
        emit RaffleEntered(PLAYER);
        //Assert
        raffle.enterRaffle{value: entranceFee}();
    }

    function testDontAllowPlayersToEnterWhileRaffleIsCalculating() public{
        //Here we have to start performUpkeep since it sets the enum to CALCULATING
        //Arrange
        vm.prank(PLAYER);
        vm.deal(PLAYER, STARTING_PLAYER_BALANCE);
        raffle.enterRaffle{value:entranceFee}();
        //Here we can use vm.warp which sets t the block timestamp to whatever we want it to be
        vm.warp(block.timestamp + interval + 1);
        //vm.roll will simulate a new block being added. Idk wh we need this
        vm.roll(block.number + 1);
        raffle.performUpkeep("");
        //Act/Assert
        vm.expectRevert(Raffle.Raffle__NotOpen.selector);
        raffle.enterRaffle{value: entranceFee}();
        //This function is coded correctly, but it will throw an error. It will throw an "InvalidConsumer" error, from the VRFCoordinatorV2_5Mock::requestRandomWords contract and function
        //Now this is because we have not yet made a scubscription with the chainlink, whether it be through code or through the UI
        //Now the reason you have to subscribe to chainlink is so that random contracts cant call chainlink functions
        //You need to update your deploy raffle script so that when you deploy you are a valid consumer
    }

    function testCheckUpKeepReturnsFalseIfItHasNoBalance() public{
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        assert(!upkeepNeeded);
    }

    function testCheckUpKeepRetuRnsFalseIfRaffleIsntOpen() public {
        vm.prank(PLAYER);
        vm.deal(PLAYER, STARTING_PLAYER_BALANCE);
        raffle.enterRaffle{value:entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");

        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        assert(!upkeepNeeded);
    }

    function testPerformUpKeppCanOnlyRunIfCheckUpIsTrue() public {
        vm.prank(PLAYER);
        vm.deal(PLAYER, STARTING_PLAYER_BALANCE);
        raffle.enterRaffle{value:entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        raffle.performUpkeep(""); //If this fails, then it will return false and the function will fail thus the test will fail
    }

    function testperformUpkeepRevertsIfCheckUpkeepIsFalse() public {
        uint256 currentBalance = 0;
        uint256 numPlayers = 0;
        Raffle.RaffleState rState = raffle.getRaffleState();

        vm.prank(PLAYER);
        vm.deal(PLAYER, STARTING_PLAYER_BALANCE);
        raffle.enterRaffle{value: entranceFee}();
        currentBalance = currentBalance + entranceFee;
        numPlayers= 1;

        vm.expectRevert(
            abi.encodeWithSelector(Raffle.Raffle_UpkeepNotNeeded.selector, currentBalance, numPlayers, rState)
        );

        raffle.performUpkeep("");
    }

    modifier raffleEntered() {
        vm.prank(PLAYER);
        vm.deal(PLAYER, STARTING_PLAYER_BALANCE);
        raffle.enterRaffle{value:entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    function testPerformUpKeepUpdatesRaffleStateAndEmitsRequstId() public raffleEntered{
        vm.recordLogs();
        raffle.performUpkeep(""); //the rcord logs thingy woorks on this line
        Vm.Log[] memory entries = vm.getRecordedLogs(); // this means all the logs from performUpkeep, stick them into this array
        bytes32 requestId = entries[1].topics[1];

        Raffle.RaffleState raffleState = raffle.getRaffleState();
        assert(uint256(requestId) > 0);
        assert(uint256(raffleState) == 1);
    }

    
    //FROM HERE ON FORTH, THESE ARE ALWAYS GOING TO FAIL WHEN YOU FORK THE SEPOLIA RPC
    //THE REASAON BEING IS BECAUSE CALLING THE fulfillRandomWords CAN ONLY BE CALLED BY THE CHAINLINK NODES AND NOT FROM FUNCTIONS  
    //IF YOU ARE RUNNING IT ON A LOCALCHAIN THEN YOU CANNOT CALL IT ON THE REAL SEPOLIA CHAIN

    modifier skipFork() {
        if(block.chainid != LOCAL_CHAIN_ID)  {
            return;
        }
        _;
    }

    function testFulfillrandomWordsCanOnlyBeCalledAfterPerformUpkeep(uint256 randomRequestId) public raffleEntered skipFork{ //here this is called a fuzz test, solidity will run 256 tests with a
        //random number in randomRequetd, it is attempting to break your test.
        //Arrange / Act
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(randomRequestId, address(raffle)); 
    }


    function testFullFillRandomWordsPicksAWinnerResetsAndSendMoney() public raffleEntered skipFork{
        //Arrange
        uint256 additionalEntrants = 3;
        uint256 startingIndex = 1;
        address expectedWinner = address(1);

        for(uint256 i = startingIndex; i < startingIndex + additionalEntrants; i++){
            address newPlayer = address(uint160(i)); //This is how we can change any number into an address
            hoax(newPlayer, 1 ether); //sets up prank and gives ether
            raffle.enterRaffle{value: entranceFee}();
        }
        uint256 startingTimeStamp = raffle.getLastTimeStamp();
        uint256 winnerStartingBalance = expectedWinner.balance;

        //Act
        vm.recordLogs();
        raffle.performUpkeep(""); //the rcord logs thingy works on this line
        Vm.Log[] memory entries = vm.getRecordedLogs(); // this means all the logs from performUpkeep, stick them into this array
        bytes32 requestId = entries[1].topics[1];
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(uint256(requestId), address(raffle));

        //assert
        address recentWinner = raffle.getRecentWinner();
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        uint256 winnerBalance = recentWinner.balance;
        uint256 endingTimeStamp = raffle.getLastTimeStamp();
        uint256 prize = entranceFee * (additionalEntrants + 1);

        assert(recentWinner == expectedWinner);
        assert(uint256(raffleState) == 0);
        assert(winnerBalance == winnerStartingBalance + prize);
        assert(endingTimeStamp > startingTimeStamp);
    }
}