// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract Tarma is ERC1155, Ownable, ReentrancyGuard {

    IERC20 public blit;

    uint256 constant MIN_TIME_TICK_DELAY_SECONDS = 5; 
    uint256 constant MIN_FEED_DELAY_SECONDS = 10; 
    uint256 constant MAX_NOURISH_LOSS = 5; 
    uint256 constant MILLIS_PER_DAY = 86400000;
    uint256 constant BLIT_BALANCE_INITIAL_CREDIT = 100;

    struct TarmaCollectable {
        string name;
        uint256 id;
        uint256 unlockCost;
        uint256 multiplier;
        Memories memories;
        MindValues mind_values;
        BodyValues body_values;
        TarmaStates tarma_state;
    }

    enum TarmaStates {
        egg,
        baby,
        teenager,
        adult,
        senior
    }

    struct MindValues {
        int happy;
        int disciplined;
        int energy;
    }

    struct BodyValues {
        bool alive;
        int species;
        int healthy;
        int nourished;
    }

    struct Memories {
        uint256 bornDate;
        uint256 unlockedDate;
        uint256 lastUpdated;
        uint256 lastCheckin;
        uint256 lastRested;
        uint256 lastFed;
    }

    mapping(address => uint256) public playerBlitBalance; 
    mapping(address => bool) public playerInitialized;
    mapping(address => TarmaCollectable[]) public playerTarmas;
    mapping(address => uint256) public playerTarmaCount;
    uint256 public nftCount;

    constructor(address blitAddress) ERC1155("") {
        blit = IERC20(blitAddress);
    }

    function checkin() public nonReentrant {
        // TODO: onlyOwner on initialization code to prevent sybil attack
        if (!playerInitialized[msg.sender]) {
            playerBlitBalance[msg.sender] += BLIT_BALANCE_INITIAL_CREDIT;
            playerInitialized[msg.sender] = true;
        }
        for (uint i=0; i<playerTarmas[msg.sender].length; i++) {
            if(playerTarmas[msg.sender][i].memories.lastCheckin + MILLIS_PER_DAY < block.timestamp) {
                if(playerTarmas[msg.sender][i].memories.unlockedDate != 0) {
                    playerTarmas[msg.sender][i].memories.lastCheckin = block.timestamp;
                    playerBlitBalance[msg.sender] += blitEarned(msg.sender, i);
                }
            }
        }
        // TODO emit event
    }

    function blitEarned(address sender, uint256 playerTarmaId) internal view returns (uint256) {
        if (playerTarmas[sender][playerTarmaId].mind_values.happy > 0) {
            return 20;
        } else {
            return 1;
        }
    }

    function withdrawBlit(address toAddress, uint256 amount) public nonReentrant {
        require(playerBlitBalance[msg.sender] >= amount, "you've no blit, guv");
        playerBlitBalance[msg.sender] -= amount;
        blit.transfer(toAddress, amount);
    }

    function sendBlitAdmin(address recipient, uint256 amount) public onlyOwner {
        blit.transfer(recipient, amount);
    }

    function spawnUniqueTarma(address recipient, string memory name, int species, uint256 cost, uint256 multiplier) public onlyOwner {
        nftCount += 1;
        playerTarmaCount[recipient] += 1;

        _mint(recipient, nftCount, 1, "");

        TarmaCollectable memory tarma = TarmaCollectable({
            name: name,
            id: nftCount,
            unlockCost: cost,
            multiplier: multiplier,
            memories: Memories({
                bornDate: block.timestamp,
                unlockedDate: 0,
                lastUpdated: block.timestamp,
                lastCheckin: 0,
                lastFed: 0,
                lastRested: 0
            }),
            mind_values: MindValues({
                happy: 0,
                disciplined: 0,
                energy: 0
            }),
            body_values: BodyValues({
                alive: true,
                species: species,
                healthy: 0,
                nourished: 0
            }),
            tarma_state: TarmaStates.baby
        });

        playerTarmas[recipient].push(tarma);

        emit TarmaBorn(
            recipient,
            nftCount
        );
    }

    event TarmaBorn(
        address indexed owner,
        uint256 nftId
    );

    function unlock(uint256 tarmaId) public nonReentrant {
        bool found = false;
        for(uint i = 0; i<playerTarmas[msg.sender].length; i++){
            if (playerTarmas[msg.sender][i].id == tarmaId) {
                require(playerTarmas[msg.sender][i].memories.unlockedDate == 0, "No locked tarma found");
                _unlock(msg.sender, i);
                found = true;
            }
        }
        require(found, "Not found");
    }

    function _unlock(address playerAddress, uint256 playerTarmaId) internal {
        require(playerBlitBalance[playerAddress] >= playerTarmas[playerAddress][playerTarmaId].unlockCost, "Insufficient balance!");

        playerBlitBalance[playerAddress] -= playerTarmas[playerAddress][playerTarmaId].unlockCost;
        playerTarmas[playerAddress][playerTarmaId].memories.unlockedDate = block.timestamp;

        emit TarmaUnlocked(
            playerAddress,
            playerTarmas[playerAddress][playerTarmaId].id
        );
    }

    event TarmaUnlocked(
        address indexed owner,
        uint256 nftId
    );

    function _timeTick(address playerAddress, uint256 playerTarmaId) internal {
        TarmaCollectable memory tarma = playerTarmas[playerAddress][playerTarmaId];
        require(tarma.body_values.alive == true, "No living tarma found");
        require(tarma.memories.bornDate != 0, "No living tarma found");

        uint timeElapsed = block.timestamp - tarma.memories.lastUpdated;
        uint awayPercent;
        {
            if (timeElapsed >= MILLIS_PER_DAY) {
                awayPercent = 100;
            } else {
                awayPercent = (timeElapsed / MILLIS_PER_DAY) * 100;
            }
        }

        playerTarmas[playerAddress][playerTarmaId].memories.lastUpdated = block.timestamp;
        playerTarmas[playerAddress][playerTarmaId].body_values.nourished-=1;
        playerTarmas[playerAddress][playerTarmaId].mind_values.energy-=1;

        emit TarmaAged(
            playerAddress,
            playerTarmas[playerAddress][playerTarmaId].body_values.nourished,
            playerTarmas[playerAddress][playerTarmaId].mind_values.energy,
            awayPercent
        );

    }

    event TarmaAged(
        address indexed owner,
        int256 nourished,
        int256 energy,
        uint awayPercent
    );

    function feedMeal(uint256 tarmaId) public nonReentrant {
        {
            for(uint i = 0; i<playerTarmas[msg.sender].length; i++){
                if (playerTarmas[msg.sender][i].id == tarmaId) {
                    require(playerTarmas[msg.sender][i].body_values.alive, "No living tarma found");
                    require(playerTarmas[msg.sender][i].memories.unlockedDate != 0, "No unlocked tarma found");

                    _timeTick(msg.sender, i);
                    _feedMeal(msg.sender, i);
                }
            }
        }
    }

    function _feedMeal(address playerAddress, uint256 playerTarmaId) internal {
        TarmaCollectable memory tarma = playerTarmas[playerAddress][playerTarmaId];
        uint timeElapsed = block.timestamp - tarma.memories.lastFed;

        // require(timeElapsed > MIN_FEED_DELAY_SECONDS, "Too soon to feed!");

        playerTarmas[playerAddress][playerTarmaId].memories.lastFed = block.timestamp;
        playerTarmas[playerAddress][playerTarmaId].body_values.nourished+=3;
        playerTarmas[playerAddress][playerTarmaId].mind_values.happy+=1;
        playerTarmas[playerAddress][playerTarmaId].mind_values.energy-=1;

        emit TarmaFed(
            playerAddress,
            playerTarmas[playerAddress][playerTarmaId].body_values.nourished,
            playerTarmas[playerAddress][playerTarmaId].mind_values.happy,
            playerTarmas[playerAddress][playerTarmaId].mind_values.energy,
            timeElapsed
        );
    }

    event TarmaFed(
        address indexed owner,
        int256 nourished,
        int256 happy,
        int256 energy,
        uint256 timeSinceLastFeed
    );

    function rest(uint256 tarmaId) public nonReentrant {
        {
            for(uint i = 0; i<playerTarmas[msg.sender].length; i++){
                if (playerTarmas[msg.sender][i].id == tarmaId) {
                    require(playerTarmas[msg.sender][i].body_values.alive, "No living tarma found");
                    require(playerTarmas[msg.sender][i].memories.unlockedDate != 0, "No unlocked tarma found");

                    _timeTick(msg.sender, i);
                    _rest(msg.sender, i);
                }
            }
        }
    }

    function _rest(address playerAddress, uint256 playerTarmaId) internal {
        TarmaCollectable memory tarma = playerTarmas[playerAddress][playerTarmaId];

        uint timeElapsed = block.timestamp - tarma.memories.lastRested;

        // require(timeElapsed > MIN_REST_DELAY_SECONDS, "Too soon to rest!");

        playerTarmas[playerAddress][playerTarmaId].memories.lastRested = block.timestamp;
        playerTarmas[playerAddress][playerTarmaId].body_values.nourished-=1;
        playerTarmas[playerAddress][playerTarmaId].mind_values.happy+=2;
        playerTarmas[playerAddress][playerTarmaId].mind_values.energy+=3;

        emit TarmaRested(
            playerAddress,
            playerTarmas[playerAddress][playerTarmaId].body_values.nourished,
            playerTarmas[playerAddress][playerTarmaId].mind_values.happy,
            playerTarmas[playerAddress][playerTarmaId].mind_values.energy,
            timeElapsed
        );
    }

    event TarmaRested(
        address indexed owner,
        int256 nourished,
        int256 happy,
        int256 energy,
        uint256 timeSinceLastRest
    );
}