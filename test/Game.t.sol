// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Game} from "../src/Game.sol";

contract GameTest is Test {
    Game public game;
    address player1 = makeAddr("1");
    address player2 = makeAddr("2");

    function setUp() public {
        game = new Game(1 ether);
        vm.deal(player1, 1 ether);
        vm.deal(player2, 1 ether);
    }

    function test_correct_data_set_on_register() public {
        bytes32 p1HashChoice = keccak256(abi.encode(0, "salt"));
        vm.prank(player1);
        game.register{value: 1 ether}(p1HashChoice);

        Game.Player memory data = game.getPlayer(player1);
        assertEq(data.hashedChoice, p1HashChoice);
        assertEq(data.isRevealed, false);
        assertEq(uint8(data.choice), 0);
    }

    function test_only_two_players() public {
        bytes32 p1HashChoice = keccak256(abi.encode(0, "salt"));
        vm.prank(player1);
        game.register{value: 1 ether}(p1HashChoice);

        bytes32 p2HashChoice = keccak256(abi.encode(1, "tlas"));
        vm.prank(player2);
        game.register{value: 1 ether}(p2HashChoice);

        // Игра поддерживает только двух игроков.
        address player3 = makeAddr("3");
        vm.deal(player3, 1 ether);
        vm.prank(player3);
        vm.expectRevert();
        game.register{value: 1 ether}(p2HashChoice);

        address[] memory players = game.getAllPlayers();
        assertEq(players.length, 2);
    }

    function test_one_player_cant_join_twice() public {
        bytes32 p1HashChoice = keccak256(abi.encode(0, "salt"));
        vm.prank(player1);
        game.register{value: 1 ether}(p1HashChoice);
        vm.deal(player1, 1 ether);

        vm.prank(player1);
        vm.expectRevert();
        game.register{value: 1 ether}(p1HashChoice);
    }

    function test_player_should_deposit_enterPrice() public {
        bytes32 p1HashChoice = keccak256(abi.encode(0, "salt"));
        vm.startPrank(player1);
        //Игроки должны вносить залог (stake) в ETH для участия в раунде.
        vm.expectRevert();
        game.register(p1HashChoice);
        game.register{value: 1 ether}(p1HashChoice);
        vm.stopPrank();
    }

    function test_cant_register_after_deadline() public {
        vm.roll(block.number + 20);
        bytes32 p1HashChoice = keccak256(abi.encode(0, "salt"));
        vm.prank(player1);
        //Нельзя зарегистрироваться после дедлайна
        vm.expectRevert();
        game.register{value: 1 ether}(p1HashChoice);
    }

    function test_reveal_phase_start_at_two_player_register() public {
        bytes32 p1HashChoice = keccak256(abi.encode(0, "salt"));
        vm.prank(player1);
        game.register{value: 1 ether}(p1HashChoice);

        bytes32 p2HashChoice = keccak256(abi.encode(1, "tlas"));
        vm.prank(player2);
        game.register{value: 1 ether}(p2HashChoice);

        assertEq(game.revealTime(), true);
    }

    function test_reveal_work() public {
        bytes32 p1HashChoice = keccak256(abi.encode(2, "salt"));
        vm.prank(player1);
        game.register{value: 1 ether}(p1HashChoice);

        bytes32 p2HashChoice = keccak256(abi.encode(1, "tlas"));
        vm.prank(player2);
        game.register{value: 1 ether}(p2HashChoice);

        vm.prank(player1);
        game.reveal(2, "salt");

        Game.Player memory data = game.getPlayer(player1);
        assertEq(data.isRevealed, true);
        assertEq(uint8(data.choice), 2);
    }

    function test_unregistered_player_reveal() public {
        bytes32 p1HashChoice = keccak256(abi.encode(2, "salt"));
        vm.prank(player1);
        game.register{value: 1 ether}(p1HashChoice);

        bytes32 p2HashChoice = keccak256(abi.encode(1, "tlas"));
        vm.prank(player2);
        game.register{value: 1 ether}(p2HashChoice);

        address player3 = makeAddr("3");

        vm.prank(player3);
        vm.expectRevert();
        game.reveal(2, "salt");
    }

    function test_reveal_with_wrong_data() public {
        bytes32 p1HashChoice = keccak256(abi.encode(2, "salt"));
        vm.prank(player1);
        game.register{value: 1 ether}(p1HashChoice);

        bytes32 p2HashChoice = keccak256(abi.encode(1, "tlas"));
        vm.prank(player2);
        game.register{value: 1 ether}(p2HashChoice);

        vm.prank(player1);
        vm.expectRevert();
        game.reveal(1, "salt");
        vm.expectRevert();
        game.reveal(2, "salt333");
    }

    function test_reveal_after_deadline() public {
        bytes32 p1HashChoice = keccak256(abi.encode(2, "salt"));
        vm.prank(player1);
        game.register{value: 1 ether}(p1HashChoice);

        bytes32 p2HashChoice = keccak256(abi.encode(1, "tlas"));
        vm.prank(player2);
        game.register{value: 1 ether}(p2HashChoice);

        vm.roll(block.number + 20);
        vm.prank(player1);
        vm.expectRevert();
        game.reveal(2, "salt");
    }

    function test_rules_core() public {
        Game.Player memory p1 = Game.Player({
            _address: address(0x1),
            hashedChoice: bytes32(0),
            isRevealed: false,
            choice: Game.HandSign.PAPER // 0
        });

        Game.Player memory p2 = Game.Player({
            _address: address(0x2),
            hashedChoice: bytes32(0),
            isRevealed: false,
            choice: Game.HandSign.ROCK // 1
        });

        // Бумага (0) побеждает камень (1)
        address winner = game.determineWinner(p1, p2);
        assertEq(winner, p1._address, "Paper should beat rock");

        // 2. Ножницы (2) побеждают бумагу (0)
        p1.choice = Game.HandSign.SCISSOR;
        p2.choice = Game.HandSign.PAPER;
        winner = game.determineWinner(p1, p2);
        assertEq(winner, p1._address, "Scissors should beat paper");

        // 3. Ничья (одинаковые знаки)
        p1.choice = Game.HandSign.ROCK;
        p2.choice = Game.HandSign.ROCK;
        winner = game.determineWinner(p1, p2);
        assertEq(winner, address(0), "Same choices should result in draw");

        // 4. Обратные случаи (когда побеждает p2)
        p1.choice = Game.HandSign.ROCK;
        p2.choice = Game.HandSign.PAPER;
        winner = game.determineWinner(p1, p2);
        assertEq(winner, p2._address, "Paper should beat rock (reverse)");

        p1.choice = Game.HandSign.SCISSOR;
        p2.choice = Game.HandSign.ROCK;
        winner = game.determineWinner(p1, p2);
        assertEq(winner, p2._address, "Rock should beat scissors (reverse)");

        p1.choice = Game.HandSign.PAPER;
        p2.choice = Game.HandSign.SCISSOR;
        winner = game.determineWinner(p1, p2);
        assertEq(winner, p2._address, "Scissors should beat paper (reverse)");
    }

    function test_winner_get_price() public {
        bytes32 p1HashChoice = keccak256(abi.encode(2, "salt"));
        vm.prank(player1);
        game.register{value: 1 ether}(p1HashChoice);

        bytes32 p2HashChoice = keccak256(abi.encode(1, "tlas"));
        vm.prank(player2);
        game.register{value: 1 ether}(p2HashChoice);

        vm.prank(player1);
        game.reveal(2, "salt");

        vm.prank(player2);
        game.reveal(1, "tlas");

        game.computeWinner();
        assertEq(player1.balance, 0);
        assertEq(player2.balance, 2 ether - 2 * game.commissionsFee());
    }

    function test_draw() public {
        bytes32 p1HashChoice = keccak256(abi.encode(2, "salt"));
        vm.prank(player1);
        game.register{value: 1 ether}(p1HashChoice);

        bytes32 p2HashChoice = keccak256(abi.encode(2, "tlas"));
        vm.prank(player2);
        game.register{value: 1 ether}(p2HashChoice);

        vm.prank(player1);
        game.reveal(2, "salt");

        vm.prank(player2);
        game.reveal(2, "tlas");

        game.computeWinner();
        assertEq(player1.balance, 1 ether - game.commissionsFee());
        assertEq(player2.balance, 1 ether - game.commissionsFee());
    }

    function test_withdraw_is_no_one_revealed() public {
        bytes32 p1HashChoice = keccak256(abi.encode(2, "salt"));
        vm.prank(player1);
        game.register{value: 1 ether}(p1HashChoice);

        bytes32 p2HashChoice = keccak256(abi.encode(2, "tlas"));
        vm.prank(player2);
        game.register{value: 1 ether}(p2HashChoice);

        vm.roll(block.number + 20);

        game.withdraw();

        assertEq(player1.balance, 1 ether);
        assertEq(player2.balance, 1 ether);
    }

    function test_withdraw_with_only_one_player() public {
        bytes32 p1HashChoice = keccak256(abi.encode(2, "salt"));
        vm.prank(player1);
        game.register{value: 1 ether}(p1HashChoice);

        vm.roll(block.number + 20);

        game.withdraw();

        assertEq(player1.balance, 1 ether);
    }

    function test_withdraw_with_only_one_reveal() public {
        bytes32 p1HashChoice = keccak256(abi.encode(2, "salt"));
        vm.prank(player1);
        game.register{value: 1 ether}(p1HashChoice);

        bytes32 p2HashChoice = keccak256(abi.encode(2, "tlas"));
        vm.prank(player2);
        game.register{value: 1 ether}(p2HashChoice);

        vm.prank(player1);
        game.reveal(2, "salt");

        vm.roll(block.number + 20);

        game.withdraw();

        assertEq(player1.balance, 2 ether - 2 * game.commissionsFee());
        assertEq(player2.balance, 0);
    }
}
