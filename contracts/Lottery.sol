//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

contract Lottery {
    bytes32 internal keyHash;
    uint256 internal fee;

    uint256[] private rolls;
    bytes32[] private requestIds;

    uint256 public total = 0;
    uint256 public ticketPrice = 0.0001 ether;
    uint256 public roundInterval = 1;
    uint256 public endTime;
    uint256 public maxNumber;

    mapping(uint256 => address[]) private tickets;
    uint256[] private guesses;
    mapping(address => uint256) private debts;

    constructor(uint256 _roundInterval, uint256 _maxNumber,address _vrfCoordinator, address _link)
        VRFConsumerBase(_vrfCoordinator, _link) public {
        require(_roundInterval > 0, "Interval should be one day at least");
        require(_maxNumber > 0, "There should be at least one possible number");

        endTime = block.timestamp + (_roundInterval * 1 days);
        roundInterval = _roundInterval;
        maxNumber = _maxNumber;

        vrfCoordinator = _vrfCoordinator;
        LINK = LinkTokenInterface(_link);
        keyHash = 0xced103054e349b8dfb51352f0f8fa9b5d20dde3d06f9f43cb2b85bc64b238205;
        fee = 10 ** 18;
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

    function finish(bytes32 requestId) external nonReentrant {
        require(block.timestamp >= endTime, "Lottery has not ended");
        require(rolls.length > 0, "Should be at least one roller")

        lastRoll = rolls[rolls.length - 1]
        lastRequestId = requestIds[requestIds.length - 1]
        require(lastRequestId == requestId, "Idempotency key is unrecognised")

        // uint256 randomNumber = random();
        address[] memory winners = tickets[lastRoll];

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
        delete rolls;
        delete requestIds;
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

    function rollNumber(uint256 userProvidedSeed) public returns (bytes32 requestId) {
        require(LINK.balanceOf(address(this)) > fee, "Not enough LINK - fill contract with faucet");
        bytes32 _requestId = requestRandomness(keyHash, fee, userProvidedSeed);
        return _requestId;
    }
    
    modifier onlyVRFCoordinator {
        require(msg.sender == vrfCoordinator, 'Fulfillment only allowed by VRFCoordinator');
        _;
    }

    function fulfillRandomness(bytes32 requestId, uint256 randomness) external override onlyVRFCoordinator {
        uint256 roll = randomness.mod(maxNumber);
        rolls.push(roll);
        requestIds.push(requestId);
    }
}
