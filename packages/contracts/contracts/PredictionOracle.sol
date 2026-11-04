// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {PredictionMarket} from "./PredictionMarket.sol";
import {PredictionMarketFactory} from "./PredictionMarketFactory.sol";

/// @title PredictionOracle
/// @notice Accepts EIP-712 signed metric attestations from the public-metrics oracle backend.
/// Flow: propose -> challenge window -> finalize (resolves the market). A conflicting attestation
/// from any reporter, or a CHALLENGER_ROLE challenge, moves the proposal to Disputed; only an
/// ARBITER_ROLE holder can settle a dispute. `invalid = true` cancels the market (refunds).
contract PredictionOracle is AccessControl, EIP712 {
    bytes32 public constant REPORTER_ROLE = keccak256("REPORTER_ROLE");
    bytes32 public constant CHALLENGER_ROLE = keccak256("CHALLENGER_ROLE");
    bytes32 public constant ARBITER_ROLE = keccak256("ARBITER_ROLE");

    bytes32 public constant ATTESTATION_TYPEHASH = keccak256(
        "Attestation(address market,uint8 outcome,bool invalid,int256 observedValue,uint64 snapshotTime,bytes32 sourceHash,bytes32 evidenceHash,uint64 nonce)"
    );

    struct Attestation {
        address market;
        uint8 outcome;
        bool invalid; // data missing or unreliable -> cancel and refund
        int256 observedValue; // e.g. chart rank observed at the deadline
        uint64 snapshotTime;
        bytes32 sourceHash; // identifies the authoritative source/feed
        bytes32 evidenceHash; // keccak256 of the archived raw snapshot
        uint64 nonce;
    }

    enum Status {
        None,
        Proposed,
        Disputed,
        Final
    }

    struct Proposal {
        Status status;
        uint8 outcome;
        bool invalid;
        uint64 challengeEnds;
        address reporter;
        int256 observedValue;
        bytes32 evidenceHash;
    }

    uint64 public immutable challengeWindow;
    uint64 public immutable maxSnapshotAge;
    PredictionMarketFactory public factory;

    mapping(address market => Proposal) public proposals;
    mapping(bytes32 digest => bool) public usedDigests;

    event FactorySet(address factory);
    event OutcomeProposed(address indexed market, uint8 outcome, bool invalid, int256 observedValue, bytes32 evidenceHash, address reporter, uint64 challengeEnds);
    event OutcomeConfirmed(address indexed market, address reporter);
    event OutcomeDisputed(address indexed market, address by, bytes32 reason);
    event OutcomeFinalized(address indexed market, uint8 outcome, bool invalid);

    error FactoryAlreadySet();
    error UnknownMarket(address market);
    error ReplayedAttestation();
    error UnauthorizedReporter(address signer);
    error SnapshotBeforeClose();
    error SnapshotFromFuture();
    error SnapshotTooOld();
    error WrongStatus(Status actual);
    error ChallengeWindowOpen(uint64 endsAt);
    error ChallengeWindowClosed();

    constructor(address admin, uint64 challengeWindow_, uint64 maxSnapshotAge_) EIP712("AppLove PredictionOracle", "1") {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(CHALLENGER_ROLE, admin);
        _grantRole(ARBITER_ROLE, admin);
        challengeWindow = challengeWindow_;
        maxSnapshotAge = maxSnapshotAge_;
    }

    /// @notice One-time wiring (factory needs this oracle's address at construction).
    function setFactory(PredictionMarketFactory factory_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (address(factory) != address(0)) revert FactoryAlreadySet();
        factory = factory_;
        emit FactorySet(address(factory_));
    }

    function hashAttestation(Attestation calldata a) public view returns (bytes32) {
        return _hashTypedDataV4(
            keccak256(
                abi.encode(
                    ATTESTATION_TYPEHASH, a.market, a.outcome, a.invalid, a.observedValue, a.snapshotTime, a.sourceHash,
                    a.evidenceHash, a.nonce
                )
            )
        );
    }

    function propose(Attestation calldata a, bytes calldata signature) external {
        if (address(factory) == address(0) || !factory.isMarket(a.market)) revert UnknownMarket(a.market);
        bytes32 digest = hashAttestation(a);
        if (usedDigests[digest]) revert ReplayedAttestation();
        address signer = ECDSA.recover(digest, signature);
        if (!hasRole(REPORTER_ROLE, signer)) revert UnauthorizedReporter(signer);

        PredictionMarket m = PredictionMarket(a.market);
        if (a.snapshotTime < m.closeTime()) revert SnapshotBeforeClose();
        if (a.snapshotTime > block.timestamp) revert SnapshotFromFuture();
        if (block.timestamp - a.snapshotTime > maxSnapshotAge) revert SnapshotTooOld();
        usedDigests[digest] = true;

        Proposal storage p = proposals[a.market];
        if (p.status == Status.None) {
            proposals[a.market] = Proposal(
                Status.Proposed, a.outcome, a.invalid, uint64(block.timestamp) + challengeWindow, signer, a.observedValue, a.evidenceHash
            );
            emit OutcomeProposed(a.market, a.outcome, a.invalid, a.observedValue, a.evidenceHash, signer, p.challengeEnds);
        } else if (p.status == Status.Proposed) {
            if (block.timestamp >= p.challengeEnds) revert ChallengeWindowClosed();
            if (p.outcome == a.outcome && p.invalid == a.invalid) {
                emit OutcomeConfirmed(a.market, signer);
            } else {
                p.status = Status.Disputed;
                emit OutcomeDisputed(a.market, signer, "conflicting attestation");
            }
        } else {
            revert WrongStatus(p.status);
        }
    }

    function challenge(address market, bytes32 reason) external onlyRole(CHALLENGER_ROLE) {
        Proposal storage p = proposals[market];
        if (p.status != Status.Proposed) revert WrongStatus(p.status);
        if (block.timestamp >= p.challengeEnds) revert ChallengeWindowClosed();
        p.status = Status.Disputed;
        emit OutcomeDisputed(market, msg.sender, reason);
    }

    /// @notice Anyone may finalize an unchallenged proposal after the window.
    function finalize(address market) external {
        Proposal storage p = proposals[market];
        if (p.status != Status.Proposed) revert WrongStatus(p.status);
        if (block.timestamp < p.challengeEnds) revert ChallengeWindowOpen(p.challengeEnds);
        _settle(market, p, p.outcome, p.invalid);
    }

    function resolveDispute(address market, uint8 outcome, bool invalid) external onlyRole(ARBITER_ROLE) {
        Proposal storage p = proposals[market];
        if (p.status != Status.Disputed) revert WrongStatus(p.status);
        _settle(market, p, outcome, invalid);
    }

    function _settle(address market, Proposal storage p, uint8 outcome, bool invalid) private {
        p.status = Status.Final;
        p.outcome = outcome;
        p.invalid = invalid;
        emit OutcomeFinalized(market, outcome, invalid);
        if (invalid) PredictionMarket(market).cancel();
        else PredictionMarket(market).resolve(outcome);
    }
}
