// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import "../interfaces/IArchToken.sol";
import "../interfaces/IVesting.sol";

/// @notice Proxy admin storage variables
struct AdminStorage {
    // Administrator for this contract
    address admin;

    // Pending administrator for this contract
    address pendingAdmin;

    // Active implementation of Voting Power contract
    address votingPowerImplementation;

    // Pending implementation of Voting Power contract
    address pendingVotingPowerImplementation;

    // Voting Power implementation version
    uint8 version;
}

/// @notice App metadata storage
struct AppStorage {

    // A record of states for signing / validating signatures
    mapping (address => uint) nonces;

    // ARCH token
    IArchToken archToken;

    // Vesting contract
    IVesting vesting;
}

/// @notice A checkpoint for marking number of votes from a given block
struct Checkpoint {
    uint32 fromBlock;
    uint256 votes;
}

/// @notice All storage variables related to checkpoints
struct CheckpointStorage {
     // A record of vote checkpoints for each account, by index
    mapping (address => mapping (uint32 => Checkpoint)) checkpoints;

    // The number of checkpoints for each account
    mapping (address => uint32) numCheckpoints;
}

/// @notice All storage variables related to staking
struct StakeStorage {
    // Total amount staked in the VotingPower contract for each token > amount
    mapping (address => uint256) totalStaked;

    // Official record of staked balances for each account > token > amount
    mapping (address => mapping (address => uint256)) stakes;
}

struct Delegation {
    address delegate;
    uint256 amount;
}

 /// @notice All storage variables related to delegation
 struct DelegateStorage {
    // Mapping of delegator > delegate + amount
    mapping (address => Delegation) delegations;

    // How much total Voting Power a delegate currently has delegated to them
    mapping (address => uint256) delegatedVotes;
 }

library VotingPowerStorage {
    bytes32 constant VOTING_POWER_ADMIN_STORAGE_POSITION = keccak256("voting.power.admin.storage");
    bytes32 constant VOTING_POWER_APP_STORAGE_POSITION = keccak256("voting.power.app.storage");
    bytes32 constant VOTING_POWER_CHECKPOINT_STORAGE_POSITION = keccak256("voting.power.checkpoint.storage");
    bytes32 constant VOTING_POWER_STAKE_STORAGE_POSITION = keccak256("voting.power.stake.storage");
    bytes32 constant VOTING_POWER_DELEGATE_STORAGE_POSITION = keccak256("voting.power.delegate.storage");

    bytes32 constant DOMAIN_TYPEHASH = keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)");
    bytes32 constant DELEGATION_TYPEHASH = keccak256("Delegation(address delegatee,uint256 nonce,uint256 expiry)");

    function adminStorage() internal pure returns (AdminStorage storage adm) {        
        bytes32 position = VOTING_POWER_ADMIN_STORAGE_POSITION;
        assembly {
            adm.slot := position
        }
    }
    
    function appStorage() internal pure returns (AppStorage storage app) {        
        bytes32 position = VOTING_POWER_APP_STORAGE_POSITION;
        assembly {
            app.slot := position
        }
    }

    function checkpointStorage() internal pure returns (CheckpointStorage storage cs) {        
        bytes32 position = VOTING_POWER_CHECKPOINT_STORAGE_POSITION;
        assembly {
            cs.slot := position
        }
    }

    function stakeStorage() internal pure returns (StakeStorage storage ss) {        
        bytes32 position = VOTING_POWER_STAKE_STORAGE_POSITION;
        assembly {
            ss.slot := position
        }
    }

    function delegateStorage() internal pure returns (DelegateStorage storage ds) {        
        bytes32 position = VOTING_POWER_DELEGATE_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
    }

    function domainTypeHash() internal pure returns (bytes32) {        
        return DOMAIN_TYPEHASH;
    }

    function delegationTypeHash() internal pure returns (bytes32) {        
        return DELEGATION_TYPEHASH;
    }
}