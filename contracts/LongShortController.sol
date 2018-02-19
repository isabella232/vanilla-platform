pragma solidity ^0.4.18;
import "./Ownable.sol";
import "./Debuggable.sol";
import "./SafeMath.sol";

/**
@dev Controller for Long/Short options
on the Ethereum blockchain.

@author Convoluted Labs
*/
contract LongShortController is Ownable, Debuggable {
    
    // Use Zeppelin's SafeMath library for calculations
    using SafeMath for uint256;

    uint[] private activeClosingDates;
    mapping(uint => LongShort[]) private longShorts;
    mapping(bytes32 => Position[]) private positions;

    /**
    @dev Position struct
    */
    struct Position {
        bool isLong;
        bytes32 ownerSignature;
        address paymentAddress;
        uint256 balance;
    }

    /**
    @dev Activated LongShort struct
    */
    struct LongShort {
        bytes32 parameterHash;
        uint256 startingPrice;
        uint leverage;
    }

    /**
    @dev Helper function to check if both sides of the bet have same balance
    
    @param isLongs list of position types {long: true, short: false}
    @param balances list of position amounts in wei
    */
    function requireNullSum(bool[] isLongs, uint256[] balances) internal pure {
        uint256 shortBalance;
        uint256 longBalance;
        for (uint8 i = 0; i < isLongs.length; i++) {
            if (isLongs[i]) {
                longBalance = longBalance.add(balances[i]);
            } else {
                shortBalance = shortBalance.add(balances[i]);
            }
        }
        require(shortBalance==longBalance);
    }

    /**
    @dev LongShort activator function. Called by OrdersManager.
    */
    function openLongShort(bytes32 parameterHash, uint duration, uint leverage, bytes32[] ownerSignatures, address[] paymentAddresses, uint256[] balances, bool[] isLongs) public payable onlyOwner {

        // Require all input arrays to be the same length
        // The backend must make sure that the indices point to the same original order
        require(ownerSignatures.length == paymentAddresses.length);
        require(paymentAddresses.length == balances.length);
        require(balances.length == isLongs.length);

        // Require both sides of the LongShort to have same total balance
        requireNullSum(isLongs, balances);

        uint256 startingPrice = 900; // CHange this to an oracle-fetched price
        bytes32 longShortHash = keccak256(this, parameterHash, block.timestamp);
        uint closingDate = block.timestamp + duration;

        for (uint8 i = 0; i < isLongs.length; i++) {
            positions[longShortHash].push(Position(isLongs[i], ownerSignatures[i], paymentAddresses[i], balances[i]));
        }

        activeClosingDates.push(closingDate);
        longShorts[closingDate].push(LongShort(parameterHash, startingPrice, leverage));

        debug("New LongShort activated.");

    }

    function getActiveClosingDates() public view returns (uint[]) {
        return activeClosingDates;
    }
}
