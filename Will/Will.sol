/*
 * Helloooooooooo web3 community! 
 * 
 * This is M. Yousuf (github.com/yousuf-git), and this is my very first smart
 * contract. You can't imagine how excited I am to finally dive into web3,
 * blockchain, and all the awesome things being built around it.
 *
 * I've commented this file heavily so it doubles as my learning notes: every
 * concept is explained the first time it shows up. If you're just starting
 * out too, I hope it helps you as much as writing it helped me.
 *
 * Let's cook.
 */

// SPDX-License-Identifier: GPL-3.0
//
// ^ The line above is a machine-readable license tag (SPDX = "Software Package
//   Data Exchange"). Smart contract source code is usually published on block
//   explorers like Etherscan, so the compiler asks you to state the license up
//   front. It has no effect on how the code runs; leaving it out only produces
//   a compiler warning. Use "UNLICENSED" for code you don't want to license.

// A "pragma" is an instruction to the compiler, not code that runs.
// This one says: "only compile this file with Solidity 0.8.4 or newer, but not
// 0.9.0 or newer". Why this exact range:
//   - 0.8.0 made arithmetic "checked" by default: if a number overflows
//     (e.g. uint256 max + 1) the transaction reverts instead of silently
//     wrapping around to 0. Before 0.8 you needed a library (SafeMath) for that.
//   - 0.8.4 introduced custom errors (`error NotOwner();`), used below.
//   - The upper bound "< 0.9.0" protects us from a future major version that
//     may contain breaking changes.
pragma solidity >=0.8.4 <0.9.0;

/*
 * =============================================================================
 *  WILL: an on-chain "dead man's switch" inheritance contract
 * =============================================================================
 *
 *  WHAT IS A SMART CONTRACT?
 *  -------------------------
 *  A program that lives at an address on the blockchain. Once deployed, its code
 *  cannot be changed. It can hold ETH, keep data ("state"), and anyone can call
 *  its functions by sending a transaction. Every state-changing call costs gas
 *  (paid in ETH), and every rule written here is enforced by the network itself,
 *  with no bank, lawyer or server in the middle.
 *
 *  WHAT DOES THIS CONTRACT DO?
 *  ---------------------------
 *  It is a digital will. The owner locks ETH in the contract and names heirs.
 *  While alive, the owner periodically sends a "heartbeat" transaction to prove
 *  they are still around. If the heartbeats stop for longer than an agreed
 *  interval (say, one year), the owner is presumed dead, a trusted guardian
 *  executes the will, and each heir can then claim their share.
 *
 *  THE THREE ROLES
 *  ---------------
 *    Owner     The person whose wealth this is. Deploys the contract, deposits
 *              and withdraws ETH, manages heirs, sends heartbeats.
 *    Guardian  A trusted person (lawyer, friend, family member) who confirms the
 *              owner has passed away by calling executeWill(). The guardian
 *              can only decide WHEN to execute, never WHO gets the money, so a
 *              dishonest guardian cannot steal anything.
 *    Heirs     The people who inherit. Each has a "share" (a weight). After the
 *              will is executed, each heir withdraws their own portion.
 *
 *  WHY A GUARDIAN AND A TIMER?
 *  ---------------------------
 *  Execution requires BOTH conditions: the heartbeat must have expired AND the
 *  guardian must call executeWill(). Each covers the other's weakness:
 *    - Timer alone: the will would fire if the owner simply forgot to send a
 *      heartbeat or was in hospital for a while.
 *    - Guardian alone: a guardian could execute the will while the owner is
 *      still alive. The timer makes that impossible.
 *
 *  LIFECYCLE
 *  ---------
 *    1. Deploy       owner deploys, naming a guardian and a heartbeat interval
 *    2. Fund         anyone sends ETH to the contract (receive())
 *    3. Configure    owner adds / updates / removes heirs
 *    4. Stay alive   owner calls heartbeat() (any owner action also counts)
 *    5. Silence      no owner activity for `heartbeatInterval` seconds
 *    6. Execute      guardian calls executeWill(); the balance is frozen
 *    7. Claim        each heir calls claimInheritance() to receive their ETH
 *
 *  TRYING IT IN REMIX (app.remix.live)
 *  -----------------------------------
 *    - Compile with any 0.8.x compiler >= 0.8.4.
 *    - In "Deploy & Run", the "Remix VM" gives you several funded test accounts.
 *      Account #1 = owner, #2 = guardian, #3 and #4 = heirs.
 *    - Deploy with a SHORT interval such as 60 (seconds) so you don't wait a year.
 *      Put some ETH in the "Value" field to fund the will at deploy time.
 *    - Add heirs, wait 60 seconds, switch to the guardian account, call
 *      executeWill(), then switch to each heir and call claimInheritance().
 *    - Note: amounts are always in wei. 1 ether = 1e18 wei.
 */

/// @title Will: a heartbeat-based inheritance contract
/// @notice Holds the owner's ETH and releases it to heirs once the owner stops
///         sending heartbeats and a guardian confirms their passing.
/// @dev Comments starting with `///` are NatSpec ("Ethereum Natural Language
///      Specification Format"). The compiler reads them and exports them as
///      documentation; Remix and block explorers show them to users. Tags:
///      @notice = for end users, @dev = for developers, @param / @return =
///      describe inputs and outputs. Normal `//` comments are ignored entirely.
contract Will {

    // =========================================================================
    // CONSTANTS
    // =========================================================================

    // Upper limit on the number of heirs.
    //
    // `constant` means the value is fixed at compile time and copied directly
    // into the bytecode wherever it's used. It takes no storage slot, so reading
    // it is almost free.
    //
    // Why a limit at all? removeHeir() loops over the heirs array. Every loop
    // iteration costs gas, and a block has a maximum gas limit. An unbounded
    // array could grow so large that looping over it no longer fits in a block,
    // making the function impossible to call forever. Bounding the array
    // prevents that class of bug ("unbounded loop DoS").
    uint256 public constant MAX_HEIRS = 20;

    // =========================================================================
    // STATE VARIABLES
    // =========================================================================
    //
    // State variables live in the contract's permanent storage on the
    // blockchain. Writing to storage is the most expensive thing a contract can
    // do (roughly 20,000 gas to fill a fresh slot), so we store only what we
    // need.
    //
    // Every variable starts with a default "zero value": 0 for numbers, false
    // for bool, address(0) for addresses. There is no "undefined" or "null".
    //
    // Marking a variable `public` makes the compiler generate a free getter
    // function with the same name, e.g. `owner()`. `private` hides the getter
    // from other contracts, BUT it does not make the data secret: anything on a
    // blockchain can be read by anyone who inspects the storage directly.
    // Never store passwords or secrets in a contract.

    // The owner of the will contract, to whom the wealth belongs.
    //
    // `address` is a 20-byte Ethereum account identifier, e.g.
    // 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4.
    //
    // `immutable` means the value is assigned exactly once, in the constructor,
    // and can never change afterwards. Like `constant`, it is stored in the
    // bytecode instead of storage, so reading it is cheap. The owner of a will
    // never changes, so immutable is a natural fit.
    address public immutable owner;

    // The guardian of the will contract, who is responsible for executing the
    // will after the owner's death.
    //
    // NOT immutable: the owner may need to replace the guardian (e.g. the
    // guardian loses their keys or passes away first). See setGuardian().
    address public willGuardian;

    // How many seconds of silence from the owner before the will may be
    // executed. Set once at deployment.
    //
    // Solidity has time-unit literals that make this readable when writing
    // code: `365 days` == 31536000, `1 hours` == 3600. (In Remix's deploy box
    // you must type the raw number of seconds.)
    uint256 public immutable heartbeatInterval;

    // The timestamp of the last heartbeat signal sent by the owner.
    //
    // `uint256` is an unsigned (never negative) 256-bit integer, the native
    // word size of the Ethereum Virtual Machine (EVM). Timestamps are stored as
    // "Unix time": seconds elapsed since 1 January 1970 UTC.
    uint256 public lastHeartbeat;

    // List of heirs.
    //
    // A dynamic array (`address[]`) keeps the ORDER and lets us enumerate every
    // heir, something a mapping cannot do. It's `private` because the auto
    // generated getter for a public array returns only ONE element per call
    // (`heirs(0)`, `heirs(1)` ...). getHeirs() below returns the whole list.
    address[] private heirs;

    // How big a slice each heir gets, as a relative weight.
    //
    // A `mapping(KeyType => ValueType)` is a hash table: given a key it returns
    // the value in constant time. Every possible key "exists" and maps to the
    // zero value by default, so a share of 0 means "not an heir".
    // Mappings cannot be iterated or asked for their length, which is why the
    // `heirs` array exists alongside this one.
    //
    // Shares are weights, not percentages. With shares A=50, B=30, C=20 a
    // 10 ETH estate pays 5, 3 and 2 ETH. With A=1, B=1, C=2 it pays 2.5, 2.5 and
    // 5 ETH. The payout formula is: pool * myShare / totalShares.
    mapping(address => uint256) public shareOf;

    // Sum of every heir's share. Kept up to date on every change so we never
    // need to loop over the heirs to compute it (looping costs gas).
    uint256 public totalShares;

    // Flips to true once the guardian executes the will. After that the owner
    // can no longer act, and heirs can start claiming. There is no way back.
    bool public isExecuted;

    // The contract balance at the moment of execution (a "snapshot").
    //
    // Why not just use address(this).balance when an heir claims? Because the
    // balance shrinks after every claim. If heir A claimed 50% of 10 ETH (5 ETH),
    // heir B's "30%" would then be computed from the remaining 5 ETH, which is
    // wrong. Freezing the pool at execution time gives everyone a fair share of
    // the same number.
    uint256 public inheritancePool;

    // Records which heirs have already withdrawn, so no one can claim twice.
    mapping(address => bool) public hasClaimed;

    // =========================================================================
    // EVENTS
    // =========================================================================
    //
    // Events are log entries written into the transaction receipt. Contracts
    // cannot read them, but off-chain apps (websites, wallets, explorers) can
    // listen for and search them. They are much cheaper than storage, so they
    // are the standard way to tell the outside world "something happened".
    //
    // Up to three parameters can be marked `indexed`. Indexed parameters become
    // searchable "topics", e.g. "show me every InheritanceClaimed for heir X".

    /// @notice ETH was sent into the will.
    event Deposited(address indexed from, uint256 amount);

    /// @notice The owner proved they are alive.
    event HeartbeatSent(uint256 timestamp);

    /// @notice A new heir was added.
    event HeirAdded(address indexed heir, uint256 share);

    /// @notice An existing heir's share was changed.
    event HeirShareUpdated(address indexed heir, uint256 oldShare, uint256 newShare);

    /// @notice An heir was removed from the will.
    event HeirRemoved(address indexed heir);

    /// @notice The owner appointed a new guardian.
    event GuardianChanged(address indexed oldGuardian, address indexed newGuardian);

    /// @notice The owner took ETH back out of the will.
    event Withdrawn(address indexed to, uint256 amount);

    /// @notice The guardian executed the will; `inheritancePool` wei is now claimable.
    event WillExecuted(uint256 inheritancePool, uint256 timestamp);

    /// @notice An heir withdrew their inheritance.
    event InheritanceClaimed(address indexed heir, uint256 amount);

    // =========================================================================
    // ERRORS
    // =========================================================================
    //
    // When something is wrong we "revert": the whole transaction is cancelled
    // and every state change it made is undone, as if it never happened (the
    // gas used up to that point is still paid). A revert carries a reason so
    // the caller knows what went wrong.
    //
    // Custom errors (`error Name(args)`) are the modern way to give that reason.
    // They are cheaper than the older `require(cond, "text message")` style
    // because only a 4-byte identifier plus the arguments is stored, not a whole
    // string. They can also carry useful data, like the exact time the owner's
    // heartbeat expires.

    /// @notice Caller is not the owner.
    error NotOwner();
    /// @notice Caller is not the guardian.
    error NotGuardian();
    /// @notice The will has already been executed; this action is closed.
    error AlreadyExecuted();
    /// @notice The will has not been executed yet; nothing can be claimed.
    error NotExecuted();
    /// @notice address(0) was given where a real address is required.
    error ZeroAddress();
    /// @notice The guardian cannot be the owner.
    error GuardianIsOwner();
    /// @notice The heartbeat interval must be greater than zero.
    error ZeroInterval();
    /// @notice A share must be greater than zero.
    error ZeroShare();
    /// @notice The address is already an heir; use updateHeirShare instead.
    error AlreadyHeir(address heir);
    /// @notice The address is not an heir.
    error NotHeir(address heir);
    /// @notice The heir list is full (see MAX_HEIRS).
    error TooManyHeirs();
    /// @notice The will cannot be executed without at least one heir.
    error NoHeirs();
    /// @notice The owner's heartbeat has not expired yet.
    /// @param executableAt Unix timestamp from which execution becomes possible.
    error OwnerStillAlive(uint256 executableAt);
    /// @notice This heir has already claimed.
    error AlreadyClaimed();
    /// @notice Caller has nothing to claim (not an heir).
    error NothingToClaim();
    /// @notice The owner asked to withdraw more than the contract holds.
    error InsufficientBalance(uint256 requested, uint256 available);
    /// @notice Sending ETH to the recipient failed.
    error TransferFailed();

    // =========================================================================
    // MODIFIERS
    // =========================================================================
    //
    // A modifier is a reusable check that wraps a function. The special symbol
    // `_;` marks where the wrapped function's body runs. So for:
    //
    //     function heartbeat() external onlyOwner { ... }
    //
    // Solidity runs the onlyOwner check first, then the body of heartbeat().
    // This is how access control is usually written: declare it once, attach it
    // to every function that needs it.

    // Only the owner may call.
    //
    // `msg.sender` is the address that directly called this function. Always
    // use it for permission checks. Never use `tx.origin` (the wallet that
    // started the whole transaction): a malicious contract the owner interacts
    // with could then call this one and pass the check.
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    // Only the guardian may call.
    modifier onlyGuardian() {
        if (msg.sender != willGuardian) revert NotGuardian();
        _;
    }

    // Blocks the action once the will has been executed. After execution the
    // estate is frozen: no new deposits, no withdrawals, no heir changes.
    modifier notExecuted() {
        if (isExecuted) revert AlreadyExecuted();
        _;
    }

    // =========================================================================
    // CONSTRUCTOR
    // =========================================================================

    /// @notice Creates the will. The deployer becomes the owner.
    /// @dev The constructor runs exactly once, during deployment, and is never
    ///      callable again. `payable` lets the owner fund the will in the same
    ///      transaction that deploys it; without `payable`, sending ETH to a
    ///      function makes it revert.
    /// @param _willGuardian Address of the guardian who will execute the will.
    /// @param _heartbeatInterval Seconds of owner inactivity before execution is allowed.
    constructor(address _willGuardian, uint256 _heartbeatInterval) payable {
        // Validate inputs first. A typo here would be permanent for the
        // immutable values, so it's worth rejecting obviously bad input.
        if (_willGuardian == address(0)) revert ZeroAddress();
        if (_willGuardian == msg.sender) revert GuardianIsOwner();
        if (_heartbeatInterval == 0) revert ZeroInterval();

        owner = msg.sender;
        willGuardian = _willGuardian;
        heartbeatInterval = _heartbeatInterval;

        // `block.timestamp` is the time of the block containing this
        // transaction. It's set by the validator who produced the block and can
        // be skewed by a few seconds, so never rely on it for second-level
        // precision. For intervals measured in days it's perfectly fine.
        lastHeartbeat = block.timestamp;

        // `msg.value` is the amount of wei sent along with this call.
        if (msg.value > 0) emit Deposited(msg.sender, msg.value);
    }

    // =========================================================================
    // RECEIVING ETH
    // =========================================================================

    /// @notice Accepts plain ETH transfers into the will. Anyone may contribute.
    /// @dev `receive()` is a special function with no name and no `function`
    ///      keyword. It runs when someone sends ETH with no data, e.g. a normal
    ///      wallet transfer to the contract's address. Without it (and without a
    ///      payable `fallback()`), such transfers would be rejected. It is
    ///      blocked after execution because ETH arriving then would sit in the
    ///      contract forever: the inheritance pool is already frozen.
    receive() external payable notExecuted {
        emit Deposited(msg.sender, msg.value);
    }

    // =========================================================================
    // OWNER FUNCTIONS
    // =========================================================================
    //
    // `external` means the function can only be called from outside the
    // contract (by a wallet or another contract). Use `public` when the
    // contract itself also needs to call it, as with inheritanceOf() below.
    //
    // Every owner action also refreshes the heartbeat: if the owner is managing
    // heirs or withdrawing funds, they are clearly alive.

    /// @notice Proves the owner is alive, restarting the countdown.
    function heartbeat() external onlyOwner notExecuted {
        _recordHeartbeat();
    }

    /// @notice Adds a new heir to the will.
    /// @param heir The heir's address.
    /// @param share The heir's weight relative to other heirs' shares.
    function addHeir(address heir, uint256 share) external onlyOwner notExecuted {
        if (heir == address(0)) revert ZeroAddress();
        if (share == 0) revert ZeroShare();
        // A non-zero share means the address is already in the list. Adding it
        // twice would put a duplicate in the array.
        if (shareOf[heir] != 0) revert AlreadyHeir(heir);
        if (heirs.length >= MAX_HEIRS) revert TooManyHeirs();

        // `.push()` appends to the end of a storage array.
        heirs.push(heir);
        shareOf[heir] = share;
        totalShares += share;

        emit HeirAdded(heir, share);
        _recordHeartbeat();
    }

    /// @notice Changes the share of an existing heir.
    /// @param heir The heir's address.
    /// @param newShare The new weight. Must be greater than zero; to take an
    ///        heir out entirely, use removeHeir.
    function updateHeirShare(address heir, uint256 newShare) external onlyOwner notExecuted {
        if (newShare == 0) revert ZeroShare();
        uint256 oldShare = shareOf[heir];
        if (oldShare == 0) revert NotHeir(heir);

        shareOf[heir] = newShare;
        // Subtract first, then add. Because oldShare is part of totalShares,
        // the subtraction can never go below zero.
        totalShares = totalShares - oldShare + newShare;

        emit HeirShareUpdated(heir, oldShare, newShare);
        _recordHeartbeat();
    }

    /// @notice Removes an heir from the will.
    /// @param heir The heir's address.
    function removeHeir(address heir) external onlyOwner notExecuted {
        uint256 share = shareOf[heir];
        if (share == 0) revert NotHeir(heir);

        // Find the heir in the array and remove them with "swap and pop":
        // overwrite their slot with the LAST element, then delete the last
        // slot. Solidity arrays have no "remove at index" operation, and
        // shifting every later element left one by one would cost far more gas.
        // The trade-off: the order of the list changes. That's fine here since
        // order has no meaning for payouts.
        //
        // Copying heirs.length into a local variable avoids reading storage on
        // every iteration. Local variables live in cheap temporary memory.
        uint256 length = heirs.length;
        for (uint256 i = 0; i < length; i++) {
            if (heirs[i] == heir) {
                heirs[i] = heirs[length - 1];
                heirs.pop();
                break;
            }
        }

        // `delete` resets a value to its default (0 here). Clearing storage
        // also earns a small gas refund.
        delete shareOf[heir];
        totalShares -= share;

        emit HeirRemoved(heir);
        _recordHeartbeat();
    }

    /// @notice Appoints a new guardian.
    /// @param newGuardian Address of the new guardian.
    function setGuardian(address newGuardian) external onlyOwner notExecuted {
        if (newGuardian == address(0)) revert ZeroAddress();
        if (newGuardian == owner) revert GuardianIsOwner();

        // Emit before overwriting so the event can report the old value too.
        emit GuardianChanged(willGuardian, newGuardian);
        willGuardian = newGuardian;
        _recordHeartbeat();
    }

    /// @notice Lets the owner take ETH back out while they are still alive.
    ///         It's their money until the will is executed.
    /// @param amount Amount to withdraw, in wei.
    function withdraw(uint256 amount) external onlyOwner notExecuted {
        // `address(this)` is this contract's own address; `.balance` is how
        // much wei it holds.
        uint256 available = address(this).balance;
        if (amount > available) revert InsufficientBalance(amount, available);

        // Update state BEFORE sending ETH (see claimInheritance for why).
        _recordHeartbeat();
        emit Withdrawn(owner, amount);

        _sendEth(owner, amount);
    }

    // =========================================================================
    // GUARDIAN FUNCTIONS
    // =========================================================================

    /// @notice Executes the will once the owner's heartbeat has expired.
    ///         After this, the owner can no longer act and heirs can claim.
    function executeWill() external onlyGuardian notExecuted {
        // The core rule of the whole contract: the guardian cannot act early.
        uint256 executableAt = lastHeartbeat + heartbeatInterval;
        if (block.timestamp < executableAt) revert OwnerStillAlive(executableAt);

        // With zero heirs, the payout formula would divide by zero and the ETH
        // would be locked forever. Refuse instead; the owner may still come
        // back and add heirs.
        if (totalShares == 0) revert NoHeirs();

        isExecuted = true;
        inheritancePool = address(this).balance;

        emit WillExecuted(inheritancePool, block.timestamp);
    }

    // =========================================================================
    // HEIR FUNCTIONS
    // =========================================================================

    /// @notice Sends the caller their share of the inheritance.
    /// @dev This uses the "pull payment" pattern: instead of the contract
    ///      looping over heirs and pushing ETH to each one inside
    ///      executeWill(), each heir pulls their own money. Benefits:
    ///        1. If one heir's address cannot receive ETH (e.g. a contract that
    ///           rejects payments), only that heir's claim fails. A push loop
    ///           would revert entirely and block EVERY heir.
    ///        2. Each heir pays the gas for their own transfer.
    ///        3. No loop means no risk of running out of gas.
    function claimInheritance() external {
        // --- CHECKS: validate everything first ---
        if (!isExecuted) revert NotExecuted();
        if (hasClaimed[msg.sender]) revert AlreadyClaimed();
        uint256 amount = inheritanceOf(msg.sender);
        if (amount == 0) revert NothingToClaim();

        // --- EFFECTS: update our own state ---
        // This line MUST come before the transfer below. Sending ETH to a
        // contract hands control to that contract's code, which could call
        // claimInheritance() again ("re-entrancy") before this function has
        // finished. If hasClaimed were still false at that moment, the attacker
        // would be paid again and again until the contract was empty. This is
        // exactly how "The DAO" was drained of ~3.6M ETH in 2016.
        // Marking the claim first means any re-entrant call hits AlreadyClaimed.
        hasClaimed[msg.sender] = true;
        emit InheritanceClaimed(msg.sender, amount);

        // --- INTERACTIONS: talk to other addresses last ---
        // This ordering is called the Checks-Effects-Interactions pattern.
        _sendEth(msg.sender, amount);
    }

    // =========================================================================
    // VIEW FUNCTIONS (read-only)
    // =========================================================================
    //
    // `view` promises the function only reads state and never modifies it.
    // Calling a view function from a wallet or website costs no gas because no
    // transaction is needed: a node just runs it locally and returns the answer.
    // (If another contract calls it inside a transaction, gas is still paid.)

    /// @notice Returns the full list of heirs.
    /// @dev `memory` means the returned array is a temporary copy, not a
    ///      reference to storage. Data locations in Solidity:
    ///        storage  = permanent, on-chain (state variables)
    ///        memory   = temporary, exists only during the function call
    ///        calldata = read-only function input, cheapest of all
    /// @return The addresses of all current heirs.
    function getHeirs() external view returns (address[] memory) {
        return heirs;
    }

    /// @notice True once the owner has been silent long enough for the
    ///         guardian to execute the will.
    /// @return Whether the heartbeat has expired.
    function isHeartbeatExpired() external view returns (bool) {
        return block.timestamp >= lastHeartbeat + heartbeatInterval;
    }

    /// @notice How much `heir` can claim right now, in wei.
    /// @dev `public` rather than `external` because claimInheritance() calls it.
    /// @param heir The address to check.
    /// @return Claimable amount in wei (0 before execution or after claiming).
    function inheritanceOf(address heir) public view returns (uint256) {
        if (!isExecuted || hasClaimed[heir]) return 0;

        // Solidity has no decimals: integer division rounds DOWN, so always
        // multiply before dividing. (pool / totalShares) * share would throw
        // away precision early; (pool * share) / totalShares keeps it.
        // Rounding may leave a few wei of "dust" in the contract; that's
        // unavoidable with integer math and worth far less than a cent.
        // totalShares is never 0 here: executeWill() refuses to run without
        // heirs, and heirs cannot change after execution.
        return (inheritancePool * shareOf[heir]) / totalShares;
    }

    // =========================================================================
    // PRIVATE HELPERS
    // =========================================================================
    //
    // `private` functions can only be called from inside this contract. The
    // leading underscore is a naming convention that signals "internal
    // plumbing, not part of the public interface".

    // Restarts the owner's countdown.
    function _recordHeartbeat() private {
        lastHeartbeat = block.timestamp;
        emit HeartbeatSent(block.timestamp);
    }

    // Sends `amount` wei to `to`, reverting if the transfer fails.
    //
    // `.call{value: amount}("")` is the recommended way to send ETH. It returns
    // (success, returnData); we only need success. Always check it: a failed
    // call does NOT revert by itself, it just returns false.
    //
    // Older tutorials use `payable(to).transfer(amount)`. Avoid it: transfer
    // forwards only 2300 gas to the recipient, which is not enough for many
    // smart-contract wallets (e.g. multisigs), so they could never receive
    // their inheritance.
    //
    // `payable(to)` converts a plain `address` into an `address payable`, the
    // type Solidity requires for anything that receives ETH.
    function _sendEth(address to, uint256 amount) private {
        (bool success, ) = payable(to).call{value: amount}("");
        if (!success) revert TransferFailed();
    }
}

/*
 * =============================================================================
 *  KNOWN LIMITATIONS (and ideas for your next version)
 * =============================================================================
 *
 *  - If the guardian loses their keys or refuses to act, the will can never be
 *    executed and the ETH stays locked. Fix idea: after a long extra grace
 *    period (e.g. heartbeatInterval * 2), let any heir call executeWill().
 *  - A single guardian is a single point of failure. Fix idea: several
 *    guardians with an M-of-N vote.
 *  - Execution is final. If the owner was simply unreachable (not dead) past
 *    the interval, they cannot undo it. Choose a generous interval.
 *  - Only ETH is handled. Tokens (ERC-20) or NFTs (ERC-721) sent here would be
 *    stuck. Fix idea: add token-aware claim functions.
 *  - Access control and re-entrancy protection are hand-written for learning.
 *    Production code usually reuses audited libraries such as OpenZeppelin's
 *    `Ownable` and `ReentrancyGuard`.
 */
