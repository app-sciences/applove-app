// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {AppRegistry} from "./AppRegistry.sol";

/// @title RevenueRegistry
/// @notice Stores EIP-712 signed monthly revenue attestations from the AppLove revenue oracle.
/// Anyone may relay a signed report; only ORACLE_ROLE signers are accepted. Each report opens a
/// dispute window. A disputed report is superseded by a higher version. Finalized reports are immutable.
/// All amounts are integer base units of the settlement currency (USD with 6 decimals, matching USDC).
contract RevenueRegistry is AccessControl, EIP712 {
    bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");
    bytes32 public constant DISPUTER_ROLE = keccak256("DISPUTER_ROLE");
    bytes32 public constant USD = "USD";

    bytes32 public constant REPORT_TYPEHASH = keccak256(
        "RevenueReport(uint256 projectId,uint32 period,bytes32 settlementCurrency,uint256 grossSales,uint256 storeProceeds,uint256 refunds,uint256 taxes,uint256 eligibleProceeds,bytes32 reportHash,uint32 version,uint64 issuedAt)"
    );

    struct RevenueReport {
        uint256 projectId;
        uint32 period; // YYYYMM
        bytes32 settlementCurrency;
        uint256 grossSales; // customer price incl. tax
        uint256 storeProceeds; // after store commission
        uint256 refunds;
        uint256 taxes;
        uint256 eligibleProceeds; // amount the revenue share applies to
        bytes32 reportHash; // keccak256 of the archived source report(s)
        uint32 version;
        uint64 issuedAt;
    }

    enum Status {
        None,
        Pending,
        Disputed,
        Finalized
    }

    struct Record {
        RevenueReport report;
        Status status;
        uint64 challengeEnds;
        address signer;
    }

    AppRegistry public immutable registry;
    uint64 public immutable disputeWindow;
    uint64 public immutable maxReportAge;

    mapping(uint256 projectId => mapping(uint32 period => Record)) private _records;
    mapping(bytes32 digest => bool) public usedDigests;

    event ReportSubmitted(uint256 indexed projectId, uint32 indexed period, uint32 version, bytes32 reportHash, uint256 eligibleProceeds, address signer, uint64 challengeEnds);
    event ReportDisputed(uint256 indexed projectId, uint32 indexed period, uint32 version, bytes32 reason);
    event ReportFinalized(uint256 indexed projectId, uint32 indexed period, uint32 version, uint256 eligibleProceeds);

    error ReplayedReport();
    error UnauthorizedSigner(address signer);
    error ProjectNotEligible(uint256 projectId);
    error InvalidPeriod(uint32 period);
    error UnsupportedCurrency(bytes32 currency);
    error InconsistentAmounts();
    error ReportFromFuture();
    error ReportTooOld();
    error StaleVersion(uint32 current, uint32 submitted);
    error AlreadyFinalized();
    error NotPending();
    error ChallengeWindowOpen(uint64 endsAt);
    error ChallengeWindowClosed();
    error NotFinalized(uint256 projectId, uint32 period);

    constructor(address admin, AppRegistry registry_, uint64 disputeWindow_, uint64 maxReportAge_)
        EIP712("AppLove RevenueRegistry", "1")
    {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(DISPUTER_ROLE, admin);
        registry = registry_;
        disputeWindow = disputeWindow_;
        maxReportAge = maxReportAge_;
    }

    function hashReport(RevenueReport calldata r) public view returns (bytes32) {
        return _hashTypedDataV4(
            keccak256(
                abi.encode(
                    REPORT_TYPEHASH, r.projectId, r.period, r.settlementCurrency, r.grossSales, r.storeProceeds,
                    r.refunds, r.taxes, r.eligibleProceeds, r.reportHash, r.version, r.issuedAt
                )
            )
        );
    }

    function submitReport(RevenueReport calldata r, bytes calldata signature) external {
        bytes32 digest = hashReport(r);
        if (usedDigests[digest]) revert ReplayedReport();
        address signer = ECDSA.recover(digest, signature);
        if (!hasRole(ORACLE_ROLE, signer)) revert UnauthorizedSigner(signer);
        if (!registry.isRevenueSharingActive(r.projectId)) revert ProjectNotEligible(r.projectId);
        _validatePeriod(r.period);
        if (r.settlementCurrency != USD) revert UnsupportedCurrency(r.settlementCurrency);
        if (r.eligibleProceeds > r.storeProceeds || r.storeProceeds > r.grossSales) revert InconsistentAmounts();
        if (r.issuedAt > block.timestamp) revert ReportFromFuture();
        if (block.timestamp - r.issuedAt > maxReportAge) revert ReportTooOld();

        Record storage rec = _records[r.projectId][r.period];
        if (rec.status == Status.Finalized) revert AlreadyFinalized();
        if (rec.status != Status.None && r.version <= rec.report.version) revert StaleVersion(rec.report.version, r.version);

        usedDigests[digest] = true;
        rec.report = r;
        rec.status = Status.Pending;
        rec.signer = signer;
        rec.challengeEnds = uint64(block.timestamp) + disputeWindow;
        emit ReportSubmitted(r.projectId, r.period, r.version, r.reportHash, r.eligibleProceeds, signer, rec.challengeEnds);
    }

    function dispute(uint256 projectId, uint32 period, bytes32 reason) external onlyRole(DISPUTER_ROLE) {
        Record storage rec = _records[projectId][period];
        if (rec.status != Status.Pending) revert NotPending();
        if (block.timestamp >= rec.challengeEnds) revert ChallengeWindowClosed();
        rec.status = Status.Disputed;
        emit ReportDisputed(projectId, period, rec.report.version, reason);
    }

    /// @notice Anyone can finalize an undisputed report once its window has passed.
    function finalize(uint256 projectId, uint32 period) external {
        Record storage rec = _records[projectId][period];
        if (rec.status != Status.Pending) revert NotPending();
        if (block.timestamp < rec.challengeEnds) revert ChallengeWindowOpen(rec.challengeEnds);
        rec.status = Status.Finalized;
        emit ReportFinalized(projectId, period, rec.report.version, rec.report.eligibleProceeds);
    }

    function getRecord(uint256 projectId, uint32 period) external view returns (Record memory) {
        return _records[projectId][period];
    }

    function finalizedEligibleProceeds(uint256 projectId, uint32 period) external view returns (uint256) {
        Record storage rec = _records[projectId][period];
        if (rec.status != Status.Finalized) revert NotFinalized(projectId, period);
        return rec.report.eligibleProceeds;
    }

    function _validatePeriod(uint32 period) private pure {
        uint32 month = period % 100;
        uint32 year = period / 100;
        if (month == 0 || month > 12 || year < 2020 || year > 2100) revert InvalidPeriod(period);
    }
}
