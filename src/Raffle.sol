// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

/**
 * @title A sample Raffle Contract
 * @author Fuzzlogic102
 * @notice This contract is for creating a sample raffle
 * @dev Implements Chainlink VRFv2.5
 */
contract Raffle is VRFConsumerBaseV2Plus {

    error Raffle__NotEnoughEthSent();
    error Raffle_TransferFailed();  
    error Raffle__NotOpen();
    error Raffle__UpKeepNeeded(uint256 balance, uint256 playersLength, RaffleState raffleState);
    error Raffle_UpkeepNotNeeded(uint256 currentBalance, uint256 numPlayers, RaffleState rState);

    enum RaffleState{
        OPEN, // 0
        CALCULATING // 1
    }

    uint256 private immutable i_entranceFee;
    uint256 private immutable i_interval;
    address payable[] private s_players;
    uint256 private s_lastTimeStamp;
    bytes32 private immutable i_keyHash;
    uint256 private immutable i_subscriptionId;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private immutable i_callBackGasLimit;
    uint32 private constant NUM_WORDS = 1;
    address private s_recentWinner;
    RaffleState private s_raffleState;  //Start as open
    
    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);
    event RequestedRaffleWinner(uint256 indexed requestId);

    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint256 subscriptionId,
        uint32 callBackGasLimit
    ) 
        VRFConsumerBaseV2Plus(vrfCoordinator)
    {
        i_entranceFee = entranceFee;
        i_interval = interval;
        s_lastTimeStamp = block.timestamp;
        i_keyHash = gasLane;
        i_subscriptionId = subscriptionId;
        i_callBackGasLimit = callBackGasLimit;
        s_raffleState == RaffleState.OPEN;

    }

    function enterRaffle() external payable {
        if (msg.value < i_entranceFee) {
            revert Raffle__NotEnoughEthSent();
        }

        if(s_raffleState!= RaffleState.OPEN){
            revert Raffle__NotOpen();
        }
        s_players.push(payable(msg.sender));
        emit RaffleEntered(msg.sender);
    }

    /**
 * @dev This is the function that the ChainLink nodes will call to see if the lottery is ready to have a winner picked.
 * The following should be true in order for `upkeepNeeded` to be true:
 * 1. The time interval has passed between raffle runs
 * 2. The lottery is open
 * 3. The contract has ETH
 * 4. Implicitly, your subscription has LINK
 * 
 * @return upkeepNeeded True if it's time to restart the lottery.
 * @return _ Ignored.
 */


    function checkUpkeep(bytes memory /*checkData*/) public view returns (bool upkeepNeeded, bytes memory /*performData*/) {
         bool timeHasPassed = ((block.timestamp - s_lastTimeStamp) >= i_interval);
         bool isOpen = s_raffleState== RaffleState.OPEN;
         bool hasBalance = address(this).balance>0;
         bool hasPlayers = s_players.length > 0;
         upkeepNeeded =  timeHasPassed && hasPlayers && hasBalance && isOpen;
         return(upkeepNeeded, "");
    }

    function performUpkeep(bytes memory /* performData */) external {
        (bool upkeepNeeded, ) = checkUpkeep("");

        if(!upkeepNeeded){
            revert Raffle_UpkeepNotNeeded(address(this).balance, s_players.length, RaffleState(s_raffleState));
        }

        s_raffleState = RaffleState.CALCULATING; 

        VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient.RandomWordsRequest({
            keyHash: i_keyHash, 
            subId: i_subscriptionId,
            requestConfirmations: REQUEST_CONFIRMATIONS,
            callbackGasLimit: i_callBackGasLimit,
            numWords: NUM_WORDS,
            extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: false}))
        });

        uint256 requestId = s_vrfCoordinator.requestRandomWords(request);
        // You should store the requestId and use it to handle the random number later
        emit RequestedRaffleWinner(requestId);
    }

    //CEI: Checks, Effects, Interactions Pattern

    function fulfillRandomWords(uint256 /*requestId*/, uint256[] calldata randomWords) internal override { // There is already a fulfillRandomWords function so we have to override it
        //Checks

        // Implement how you want to use the random words to pick the winner
        // For example, use randomWords[0] to index into the s_players array

        //Effect (Internal Conract State)
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable recentWinner = s_players[indexOfWinner];
        s_recentWinner = recentWinner;
        s_raffleState = RaffleState.OPEN;
        s_players = new address payable[](0); //This resets the array to a brand new arrayt
        s_lastTimeStamp = block.timestamp;
        emit WinnerPicked(s_recentWinner);

        //Interactions (External Contract Interactions)
        (bool success,) = recentWinner.call{value: address(this).balance}("");
        if(!success){
            revert Raffle_TransferFailed();
        }
        emit WinnerPicked(recentWinner);
    }

    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }

    function getRaffleState() external view returns(RaffleState){
        return s_raffleState;
    }

    function getPlayer(uint256 indexOfPlayer) external view returns(address){
        return s_players[indexOfPlayer];
    }

    function getLastTimeStamp() external view returns(uint256){
        return s_lastTimeStamp;
    }

    function getRecentWinner() external view returns (address){
        return s_recentWinner;
    }
}
