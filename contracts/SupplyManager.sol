// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import "./lib/SafeMath.sol";
import "./interfaces/IArchToken.sol";

contract SupplyManager {
    using SafeMath for uint256;

    /// @notice ARCH token
    IArchToken public token;

    /// @notice Address which may make changes to token supply by calling provided functions
    address public admin;

    /// @notice The timestamp after which a change may occur
    uint256 public changeAllowedAfter;

    /// @notice The current time between proposal and acceptance
    uint32 public proposalLength = 1 days * 30;

    /// @notice The minimum time between proposal and acceptance
    uint32 public proposalLengthMinimum = 1 days * 7;

    /// @notice New admin proposal
    struct AdminProposal {
        uint256 eta;
        address newAdmin;
    }
    
    /// @notice New mint proposal
    struct MintProposal {
        uint256 eta;
        address destination;
        uint256 amount;
    }

    /// @notice New burn proposal
    struct BurnProposal {
        uint256 eta;
        address source;
        uint256 amount;
    }

    /// @notice New mint cap proposal
    struct MintCapProposal {
        uint256 eta;
        uint16 newCap;
    }

    /// @notice New waiting period proposal
    struct WaitingPeriodProposal {
        uint256 eta;
        uint32 newPeriod;
    }

    /// @notice New supply manager proposal
    struct SupplyManagerProposal {
        uint256 eta;
        address newSupplyManager;
    }

    /// @notice New proposal length proposal
    struct ProposalLengthProposal {
        uint256 eta;
        uint32 newLength;
    }

    /// @notice Current pending admin proposal
    AdminProposal public pendingAdmin;

    /// @notice Current pending mint proposal
    MintProposal public pendingMint;

    /// @notice Current pending burn proposal
    BurnProposal public pendingBurn;

    /// @notice Current pending mint cap proposal
    MintCapProposal public pendingMintCap;

    /// @notice Current pending waiting period proposal
    WaitingPeriodProposal public pendingWaitingPeriod;

    /// @notice Current pending supply manager proposal
    SupplyManagerProposal public pendingSupplyManager;

    /// @notice Current pending proposal length proposal
    ProposalLengthProposal public pendingProposalLength;

    /// @notice An event that's emitted when a new admin is proposed
    event AdminProposed(address indexed olAdmin, address indexed newAdmin, uint256 eta);

    /// @notice An event that's emitted when an admin proposal is canceled
    event AdminCanceled(address indexed proposedAdmin);

    /// @notice An event that's emitted when a new admin is accepted
    event AdminAccepted(address indexed olAdmin, address indexed newAdmin);

    /// @notice An event that's emitted when a new mint is proposed
    event MintProposed(uint256 indexed amount, address indexed recipient, uint256 oldSupply, uint256 newSupply, uint256 eta);

    /// @notice An event that's emitted when a mint proposal is canceled
    event MintCanceled(uint256 indexed amount, address indexed recipient);

    /// @notice An event that's emitted when a new mint is accepted
    event MintAccepted(uint256 indexed amount, address indexed recipient, uint256 oldSupply, uint256 newSupply);    

    /// @notice An event that's emitted when a new burn is proposed
    event BurnProposed(uint256 indexed amount, address indexed source, uint256 oldSupply, uint256 newSupply, uint256 eta);

    /// @notice An event that's emitted when a burn proposal is canceled
    event BurnCanceled(uint256 indexed amount, address indexed source);

    /// @notice An event that's emitted when a new burn is accepted
    event BurnAccepted(uint256 indexed amount, address indexed source, uint256 oldSupply, uint256 newSupply, );

    /// @notice An event that's emitted when a new mint cap is proposed
    event MintCapProposed(uint16 indexed oldCap, uint16 indexed newCap, uint256 eta);

    /// @notice An event that's emitted when a mint cap proposal is canceled
    event MintCapCanceled(uint16 indexed proposedCap);

    /// @notice An event that's emitted when a new mint cap is accepted
    event MintCapAccepted(uint16 indexed oldCap, uint16 indexed newCap);

    /// @notice An event that's emitted when a new waiting period is proposed
    event WaitingPeriodProposed(uint32 indexed oldWaitingPeriod, uint32 indexed newWaitingPeriod, uint256 eta);

    /// @notice An event that's emitted when a waiting period proposal is canceled
    event WaitingPeriodCanceled(uint32 indexed proposedWaitingPeriod);

    /// @notice An event that's emitted when a new waiting period is accepted
    event WaitingPeriodAccepted(uint32 indexed oldWaitingPeriod, uint32 indexed newWaitingPeriod);

    /// @notice An event that's emitted when a new supply manager is proposed
    event SupplyManagerProposed(address indexed oldSupplyManager, address indexed newSupplyManager, uint256 eta);

    /// @notice An event that's emitted when a supply manager proposal is canceled
    event SupplyManagerCanceled(address indexed proposedSupplyManager);

    /// @notice An event that's emitted when a new supply manager is accepted
    event SupplyManagerAccepted(address indexed oldSupplyManager, address indexed newSupplyManager);

    /// @notice An event that's emitted when a new proposal length is proposed
    event ProposalLengthProposed(uint32 indexed oldProposalLength, uint32 indexed newProposalLength, uint256 eta);

    /// @notice An event that's emitted when a proposal length proposal is canceled
    event ProposalLengthCanceled(uint32 indexed proposedProposalLength);

    /// @notice An event that's emitted when a new proposal length is accepted
    event ProposalLengthAccepted(uint32 indexed oldProposalLength, uint32 indexed newProposalLength);

    /**
     * @notice Construct a new supply manager
     * @param _token The address for the token
     * @param _admin The admin account for this contract
     */
    constructor(address _token, address _admin) {
        token = IArchToken(_token);
        changeAllowedAfter = token.supplyChangeAllowedAfter();
        admin = _admin;
    }

    /**
     * @notice Propose a new token mint
     * @param dst The address of the destination account
     * @param amount The number of tokens to be minted
     */
    function proposeMint(address dst, uint256 amount) external {
        uint256 currentSupply = token.totalSupply();
        require(msg.sender == admin, "Arch::proposeMint: caller must be admin");
        require(dst != address(0), "Arch::proposeMint: cannot transfer to the zero address");
        require(amount <= currentSupply.mul(token.mintCap()).div(1000000), "Arch::proposeMint: amount exceeds mint cap");
        uint256 eta = block.timestamp.add(proposalLength);
        require(eta >= token.supplyChangeAllowedAfter(), "Arch::proposeMint: minting not allowed yet");
        pendingMint = MintProposal(eta, dst, amount);
        emit MintProposed(amount, dst, eta);
    }

    /**
     * @notice Cancel proposed token mint
     */
    function cancelMint() external {
        require(msg.sender == admin, "Arch::cancelMint: caller must be admin");
        require(pendingMint.eta != 0, "Arch::cancelMint: no active proposal");
        emit MintCanceled(pendingMint.amount, pendingMint.destination);
        pendingMint = MintProposal(0, address(0), 0);
    }

    /**
     * @notice Accept proposed token mint
     */
    function acceptMint() external {
        require(msg.sender == admin, "Arch::acceptMint: caller must be admin");
        require(pendingMint.eta != 0, "Arch::acceptMint: no active proposal");
        require(block.timestamp >= pendingMint.eta, "Arch::acceptMint: proposal eta not yet passed");
        address dst = pendingMint.destination;
        uint256 amount = pendingMint.amount;
        pendingMint = MintProposal(0, address(0), 0);
        require(token.mint(dst, amount), "Arch::acceptMint: unsuccessful");
        emit MintAccepted(amount, dst);
    }

    /**
     * @notice Propose a new token burn
     * @param src The address of the account that will burn tokens
     * @param amount The number of tokens to be burned
     */
    function proposeBurn(address src, uint256 amount) external {
        require(msg.sender == admin, "Arch::proposeBurn: caller must be admin");
        require(src != address(0), "Arch::proposeBurn: cannot transfer from the zero address");
        require(token.allowance(src, address(this)) >= amount, "Arch::proposeBurn: supplyManager approval < amount");
        uint256 eta = block.timestamp.add(proposalLength);
        require(eta >= token.supplyChangeAllowedAfter(), "Arch::proposeBurn: burning not allowed yet");
        pendingBurn = BurnProposal(eta, src, amount);
        emit BurnProposed(amount, src, eta);
    }

    /**
     * @notice Cancel proposed token burn
     */
    function cancelBurn() external {
        require(msg.sender == admin, "Arch::cancelBurn: caller must be admin");
        require(pendingBurn.eta != 0, "Arch::cancelBurn: no active proposal");
        emit BurnCanceled(pendingBurn.amount, pendingBurn.source);
        pendingBurn = BurnProposal(0, address(0), 0);
    }

    /**
     * @notice Accept proposed token burn
     */
    function acceptBurn() external {
        require(msg.sender == admin, "Arch::acceptBurn: caller must be admin");
        require(pendingBurn.eta != 0, "Arch::acceptBurn: no active proposal");
        require(block.timestamp >= pendingBurn.eta, "Arch::acceptBurn: proposal eta not yet passed");
        address src = pendingBurn.source;
        uint256 amount = pendingBurn.amount;
        pendingBurn = BurnProposal(0, address(0), 0);
        require(token.burn(src, amount), "Arch::acceptBurn: unsuccessful");
        emit BurnAccepted(amount, src);
    }

    /**
     * @notice Propose change to the maximum amount of tokens that can be minted at once
     * @param newCap The new mint cap in bips (10,000 bips = 1% of totalSupply)
     */
    function proposeMintCap(uint16 newCap) external {
        require(msg.sender == admin, "Arch::proposeMintCap: caller must be admin");
        uint256 eta = block.timestamp.add(proposalLength);
        pendingMintCap = MintCapProposal(eta, newCap);
        emit MintCapProposed(token.mintCap(), newCap, eta);
    }

    /**
     * @notice Cancel proposed mint cap
     */
    function cancelMintCap() external {
        require(msg.sender == admin, "Arch::cancelMintCap: caller must be admin");
        require(pendingMintCap.eta != 0, "Arch::cancelMintCap: no active proposal");
        emit MintCapCanceled(pendingMintCap.newCap);
        pendingMintCap = MintCapProposal(0, 0);
    }

    /**
     * @notice Accept change to the maximum amount of tokens that can be minted at once
     */
    function acceptMintCap() external {
        require(msg.sender == admin, "Arch::acceptMintCap: caller must be admin");
        require(pendingMintCap.eta != 0, "Arch::acceptMintCap: no active proposal");
        require(block.timestamp >= pendingMintCap.eta, "Arch::acceptMintCap: proposal eta not yet passed");
        uint16 oldCap = token.mintCap();
        uint16 newCap = pendingMintCap.newCap;
        pendingMintCap = MintCapProposal(0, 0);
        require(token.setMintCap(newCap), "Arch::acceptMintCap: unsuccessful");
        emit MintCapAccepted(oldCap, newCap);
    }

    /**
     * @notice Propose change to the supply change waiting period
     * @param newPeriod new waiting period
     */
    function proposeSupplyChangeWaitingPeriod(uint32 newPeriod) external {
        require(msg.sender == admin, "Arch::proposeSupplyChangeWaitingPeriod: caller must be admin");
        uint256 eta = block.timestamp.add(proposalLength);
        pendingWaitingPeriod = WaitingPeriodProposal(eta, newPeriod);
        emit WaitingPeriodProposed(token.supplyChangeWaitingPeriod(), newPeriod, eta);
    }

    /**
     * @notice Cancel proposed waiting period
     */
    function cancelWaitingPeriod() external {
        require(msg.sender == admin, "Arch::cancelWaitingPeriod: caller must be admin");
        require(pendingWaitingPeriod.eta != 0, "Arch::cancelWaitingPeriod: no active proposal");
        pendingWaitingPeriod = WaitingPeriodProposal(0, 0);
        emit WaitingPeriodCanceled(pendingWaitingPeriod.newPeriod);
    }

    /**
     * @notice Accept change to the supply change waiting period
     */
    function acceptSupplyChangeWaitingPeriod() external {
        require(msg.sender == admin, "Arch::acceptSupplyChangeWaitingPeriod: caller must be admin");
        require(pendingWaitingPeriod.eta != 0, "Arch::acceptSupplyChangeWaitingPeriod: no active proposal");
        require(block.timestamp >= pendingWaitingPeriod.eta, "Arch::acceptSupplyChangeWaitingPeriod: proposal eta not yet passed");
        uint32 oldPeriod = token.supplyChangeWaitingPeriod();
        uint32 newPeriod = pendingWaitingPeriod.newPeriod;
        pendingWaitingPeriod = WaitingPeriodProposal(0, 0);
        require(token.setSupplyChangeWaitingPeriod(newPeriod), "Arch::acceptSupplyChangeWaitingPeriod: unsuccessful");
        emit WaitingPeriodAccepted(oldPeriod, newPeriod);
    }

    /**
     * @notice Propose change to the supplyManager address
     * @param newSupplyManager new supply manager address
     */
    function proposeSupplyManager(address newSupplyManager) external {
        require(msg.sender == admin, "Arch::proposeSupplyManager: caller must be admin");
        uint256 eta = block.timestamp.add(proposalLength);
        pendingSupplyManager = SupplyManagerProposal(eta, newSupplyManager);
        emit SupplyManagerProposed(token.supplyManager(), newSupplyManager, eta);
    }

    /**
     * @notice Cancel proposed supply manager update
     */
    function cancelSupplyManager() external {
        require(msg.sender == admin, "Arch::cancelSupplyManager: caller must be admin");
        require(pendingSupplyManager.eta != 0, "Arch::cancelSupplyManager: no active proposal");
        emit SupplyManagerCanceled(pendingSupplyManager.newSupplyManager);
        pendingSupplyManager = SupplyManagerProposal(0, address(0));
    }

    /**
     * @notice Accept change to the supplyManager address
     */
    function acceptSupplyManager() external {
        require(msg.sender == admin, "Arch::acceptSupplyManager: caller must be admin");
        require(pendingSupplyManager.eta != 0, "Arch::acceptSupplyManager: no active proposal");
        require(block.timestamp >= pendingSupplyManager.eta, "Arch::acceptSupplyManager: proposal eta not yet passed");
        address oldSupplyManager = token.supplyManager();
        address newSupplyManager = pendingSupplyManager.newSupplyManager;
        pendingSupplyManager = SupplyManagerProposal(0, address(0));
        require(token.setSupplyManager(newSupplyManager), "Arch::acceptSupplyManager: unsuccessful");
        emit SupplyManagerAccepted(oldSupplyManager, newSupplyManager);
    }

    /**
     * @notice Propose change to the proposal length
     * @param newLength new proposal length
     */
    function proposeNewProposalLength(uint32 newLength) external {
        require(msg.sender == admin, "Arch::proposeNewProposalLength: caller must be admin");
        require(newLength >= proposalLengthMinimum, "Arch::proposeNewProposalLength: length must be >= minimum");
        uint256 eta = block.timestamp.add(proposalLength);
        pendingProposalLength = ProposalLengthProposal(eta, newLength);
        emit ProposalLengthProposed(proposalLength, newLength, eta);
    }

    /**
     * @notice Cancel proposed update to proposal length
     */
    function cancelProposalLength() external {
        require(msg.sender == admin, "Arch::cancelProposalLength: caller must be admin");
        require(pendingProposalLength.eta != 0, "Arch::cancelProposalLength: no active proposal");
        emit ProposalLengthCanceled(pendingProposalLength.newLength);
        pendingProposalLength = ProposalLengthProposal(0, 0);
    }

    /**
     * @notice Accept change to the proposal length
     */
    function acceptProposalLength() external {
        require(msg.sender == admin, "Arch::acceptProposalLength: caller must be admin");
        require(pendingProposalLength.eta != 0, "Arch::acceptProposalLength: no active proposal");
        require(block.timestamp >= pendingProposalLength.eta, "Arch::acceptProposalLength: proposal eta not yet passed");
        uint32 oldLength = proposalLength;
        uint32 newLength = pendingProposalLength.newLength;
        pendingProposalLength = ProposalLengthProposal(0, 0);
        proposalLength = newLength;
        emit ProposalLengthAccepted(oldLength, newLength);
    }

    /**
     * @notice Propose a new admin
     * @param newAdmin The address of the new admin
     */
    function proposeAdmin(address newAdmin) external {
        require(msg.sender == admin, "Arch::proposeAdmin: caller must be admin");
        // ETA set to minimum to allow for quicker changes if necessary
        uint256 eta = block.timestamp.add(proposalLengthMinimum);
        pendingAdmin = AdminProposal(eta, newAdmin);
        emit AdminProposed(admin, newAdmin, eta);
    }

    /**
     * @notice Cancel proposed admin change
     */
    function cancelAdmin() external {
        require(msg.sender == admin, "Arch::cancelAdmin: caller must be admin");
        require(pendingAdmin.eta != 0, "Arch::cancelAdmin: no active proposal");
        emit AdminCanceled(pendingAdmin.newAdmin);
        pendingAdmin = AdminProposal(0, address(0));
    }

    /**
     * @notice Accept proposed admin
     */
    function acceptAdmin() external {
        require(msg.sender == admin, "Arch::acceptAdmin: caller must be admin");
        require(pendingAdmin.eta != 0, "Arch::acceptAdmin: no active proposal");
        require(block.timestamp >= pendingAdmin.eta, "Arch::acceptAdmin: proposal eta not yet passed");
        address oldAdmin = admin;
        address newAdmin = pendingAdmin.newAdmin;
        pendingAdmin = AdminProposal(0, address(0));
        admin = newAdmin;
        emit AdminAccepted(oldAdmin, newAdmin);
    }
}
