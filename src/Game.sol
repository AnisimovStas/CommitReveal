// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract Game {
    enum HandSign {
        PAPER,
        ROCK,
        SCISSOR
    }

    struct Player {
        address _address;
        bytes32 hashedChoice;
        bool isRevealed;
        HandSign choice;
    }

    mapping(address => Player) public players;
    address[] private playerAddresses;
    uint256 public enterPrice;
    uint256 public commissionsFee;
    bool public revealTime;
    uint256 private deadline;

    constructor(uint256 _enterPrice) {
        deadline = block.number + 10;
        enterPrice = _enterPrice;
        commissionsFee = _enterPrice * 3 / 100;
    }

    function register(bytes32 _hashedChoice) external payable {
        require(playerAddresses.length < 2, "only for two players");
        require(msg.value == enterPrice, "Not enough to join");
        require(players[msg.sender]._address == address(0), "can't join twice");
        require(block.number <= deadline, "Can't join after deadline");
        players[msg.sender] =
            Player({_address: msg.sender, hashedChoice: _hashedChoice, isRevealed: false, choice: HandSign.PAPER});
        playerAddresses.push(msg.sender);

        if (playerAddresses.length == 2) {
            revealTime = true;
        }
    }

    function reveal(uint256 _choice, bytes calldata _salt) external {
        require(block.number <= deadline, "can't reveal after deadline");
        Player memory p = players[msg.sender];
        require(p._address != address(0), "don't registered player");

        bytes32 submittedChoice = keccak256(abi.encode(_choice, _salt));
        require(submittedChoice == p.hashedChoice, "wrong hash diff initially");
        p.choice = HandSign(_choice);
        p.isRevealed = true;

        players[msg.sender] = p;
    }

    function computeWinner() external {
        require(revealTime, "too early");
        Player memory p1 = players[playerAddresses[0]];
        Player memory p2 = players[playerAddresses[1]];

        require(p1.isRevealed && p2.isRevealed, "players not reveal choice");
        address winner = determineWinner(p1, p2);
        if (winner == address(0)) {
            (bool p1Ok,) = payable(p1._address).call{value: enterPrice - commissionsFee}("");
            require(p1Ok, "p1 Transfer failed");
            (bool p2Ok,) = payable(p2._address).call{value: enterPrice - commissionsFee}("");
            require(p2Ok, "p2 Transfer failed");
        } else {
            (bool winnerOk,) = payable(winner).call{value: 2 * (enterPrice - commissionsFee)}("");
            require(winnerOk, "winner Transfer failed");
        }
    }

    function withdraw() external {
        require(block.number > deadline, "able to withdraw only after deadline");
        address[] memory playerList = playerAddresses;
        if (playerList.length == 1) {
            (bool ok,) = payable(playerList[0]).call{value: enterPrice}("");
            require(ok, "game cancel withdraw Transfer failed");
            return;
        }

        Player memory p1 = players[playerList[0]];
        Player memory p2 = players[playerList[1]];
        require(!p1.isRevealed || !p2.isRevealed, "too late to withdraw, use compute and claim reward");
        if (!p1.isRevealed && !p2.isRevealed) {
            (bool p1Ok,) = payable(p1._address).call{value: enterPrice}("");
            require(p1Ok, "p1 Transfer failed");
            (bool p2Ok,) = payable(p2._address).call{value: enterPrice}("");
            require(p2Ok, "p2 Transfer failed");

            return;
        }

        address revealed = p1.isRevealed ? p1._address : p2._address;
        (bool winnerOk,) = payable(revealed).call{value: 2 * (enterPrice - commissionsFee)}("");
        require(winnerOk, "winner Transfer failed");
    }

    function determineWinner(Player memory pl1, Player memory pl2) public pure returns (address winner) {
        uint8 p1 = uint8(pl1.choice);
        uint8 p2 = uint8(pl2.choice);
        if (p1 == p2) {
            return address(0); // Ничья
        }

        if ((p1 + 1) % 3 == p2) {
            return pl1._address; // p1 выиграл
        } else {
            return pl2._address; // p2 выиграл
        }
    }

    function getPlayer(address _addr) public view returns (Player memory) {
        return players[_addr];
    }

    function getAllPlayers() public view returns (address[] memory) {
        return playerAddresses;
    }
}
