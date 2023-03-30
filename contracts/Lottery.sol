//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

contract Lottery {
    uint256 public total = 0;
    uint256 public ticketPrice = 0.0001 ether;
    uint256 public roundInterval = 1;
    uint256 public endTime;
    uint256 public maxNumber;

    mapping(uint256 => address[]) private tickets;
    uint256[] private guesses;
    mapping(address => uint256) private debts;

    constructor(uint256 _roundInterval, uint256 _maxNumber) {
        require(_roundInterval > 0, "Interval should be one day at least");
        require(_maxNumber > 0, "There should be at least one possible number");

        endTime = block.timestamp + (_roundInterval * 1 days);
        roundInterval = _roundInterval;
        maxNumber = _maxNumber;
    }

    function participate(uint256 _guess) external payable {
        require(_guess <= maxNumber, "Guess should less or equal to maxNumber");
        require(block.timestamp < endTime, "Lottery is finished");
        require(msg.value == ticketPrice, "Ticket price is 0.0001 ether");

        tickets[_guess].push(msg.sender);
        guesses.push(_guess);
        total += ticketPrice;
    }

    bool private _lock;
    modifier nonReentrant() {
        require(!_lock);
        _lock = true;
        _;
        _lock = false;
    }

    function finish(uint256 _randomNumber) external nonReentrant {
        require(block.timestamp >= endTime, "Lottery has not ended");

        address[] memory winners = tickets[_randomNumber];

        endTime += (roundInterval * 1 days);
        if (winners.length > 0) {
            uint256 prize = total / winners.length;
            total = 0;
            for (uint256 i = 0; i < winners.length; i++) {
                (bool sent, ) = payable(winners[i]).call{value: prize}("");
                if (!sent) {
                    debts[winners[i]] += prize;
                }
            }
        }

        for (uint256 i = 0; i < guesses.length; i++) {
            delete tickets[guesses[i]];
        }
        delete guesses;
    }

    function collectDebt() external nonReentrant {
        require(debts[msg.sender] > 0, "No debts on this address");

        (bool sent, ) = payable(msg.sender).call{value: debts[msg.sender]}("");
        require(sent, "Debt is not collected");

        delete debts[msg.sender];
    }

    function random() private view returns (uint) {
        return uint(keccak256(abi.encode(block.timestamp, guesses)));
    }

    receive() external payable {
        total += msg.value;
    }
}
