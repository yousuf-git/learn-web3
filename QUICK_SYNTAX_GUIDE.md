# Solidity Quick Syntax Guide

> **Before you read:** this guide assumes you already know at least one mainstream language, such as JavaScript or Python. It won't explain what a variable, loop or function *is*. It shows how Solidity writes these things and, more importantly, **where Solidity behaves differently from what your JS/Python instincts expect**. Those differences are marked with ⚠️.
>
> Everything here targets **Solidity 0.8.37**, the latest release as of September 2026, and follows current best practices. Features that only exist in newer 0.8.x versions are labeled with the version that introduced them, and features deprecated ahead of the upcoming 0.9.0 are flagged (see [§15](#15-staying-current-modern-features-and-deprecations)). For a fully commented, working example, see [`Will/Will.sol`](Will/Will.sol).

## Contents

1. [The mental model shift](#1-the-mental-model-shift)
2. [File anatomy](#2-file-anatomy)
3. [Types](#3-types)
4. [Variables, scope and constants](#4-variables-scope-and-constants)
5. [Operators and arithmetic](#5-operators-and-arithmetic)
6. [Control structures](#6-control-structures)
7. [Functions](#7-functions)
8. [Arrays, mappings, structs and enums](#8-arrays-mappings-structs-and-enums)
9. [Data locations: storage, memory, calldata](#9-data-locations-storage-memory-calldata)
10. [Error handling](#10-error-handling)
11. [Contract building blocks](#11-contract-building-blocks)
12. [Inheritance, interfaces and libraries](#12-inheritance-interfaces-and-libraries)
13. [Global variables and built-ins](#13-global-variables-and-built-ins)
14. [JS / Python to Solidity cheat sheet](#14-js--python-to-solidity-cheat-sheet)
15. [Staying current: modern features and deprecations](#15-staying-current-modern-features-and-deprecations)
16. [Style conventions](#16-style-conventions)
- [Sources](#sources)

---

## 1. The mental model shift

A few facts shape almost every syntax decision in Solidity:

- **Code is immutable once deployed.** No hotfixes. Bugs are permanent unless you planned an upgrade path.
- **Every operation costs gas (real money).** Storage writes are the most expensive thing you can do, and loops are a liability, not a convenience.
- **Statically typed, compiled, C-like syntax.** Semicolons and braces are mandatory, and types come before names.
- **No floats, no null, no exceptions in the usual sense.** A failure *reverts* the whole transaction and undoes every state change it made.
- **Everything is public.** `private` only stops other contracts from reading a value. Anyone can still read raw chain storage.
- **No async, no timers, no I/O.** A contract only runs when a transaction calls it, and it can't fetch from the internet.

---

## 2. File anatomy

```solidity
// SPDX-License-Identifier: MIT          // license tag (compiler warns if missing)
pragma solidity ^0.8.37;                 // compiler version constraint: 0.8.37 up to (not incl.) 0.9.0

import "./Other.sol";                                        // import everything
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol"; // named import (preferred)

contract MyContract {                    // like a class; one file can hold several
    // state variables, events, errors, modifiers, functions ...
}
```

The `^` works like in npm: any 0.8.x from 0.8.37 on. Libraries meant for reuse keep a floating pragma like this, but contracts you actually deploy should pin one exact version (`pragma solidity 0.8.37;`) so the audited bytecode is reproducible.

Comments work like JS (`//` and `/* */`). Solidity adds **NatSpec** doc comments (`///` or `/** */`) with tags such as `@notice`, `@dev`, `@param` and `@return`.

---

## 3. Types

### Value types (copied on assignment)

| Type | Notes |
|------|-------|
| `bool` | `true` / `false` |
| `uint8` ... `uint256` | Unsigned ints in steps of 8 bits. `uint` is an alias for `uint256`. |
| `int8` ... `int256` | Signed ints. `int` is an alias for `int256`. |
| `address` | 20-byte account address. |
| `address payable` | An address that can receive ETH. Convert with `payable(addr)`. Send ETH with `.call{value: amount}("")`. ⚠️ `.transfer` and `.send` are deprecated since 0.8.31. |
| `bytes1` ... `bytes32` | Fixed-size byte arrays. `bytes32` is common for hashes and IDs. |
| `enum` | User-defined named constants (see [§8](#8-arrays-mappings-structs-and-enums)). |

### Reference types (need a data location, see [§9](#9-data-locations-storage-memory-calldata))

| Type | Notes |
|------|-------|
| `T[]` / `T[k]` | Dynamic / fixed-size arrays |
| `bytes` | Dynamic byte array |
| `string` | UTF-8 string (really just `bytes` with fewer features) |
| `struct` | Custom record type |
| `mapping(K => V)` | Hash map, storage only |

### Literals and units

```solidity
uint256 a = 1_000_000;         // underscores allowed
uint256 b = 1e18;              // scientific notation (must result in an integer)
uint256 c = 0xff;              // hex
uint256 price = 2 ether;       // 2 * 10**18 wei. Also: wei, gwei
uint256 lock  = 30 days;       // 2592000. Also: seconds, minutes, hours, weeks
address zero  = address(0);    // the "empty" address
string memory s = unicode"gm ☀️"; // non-ASCII needs the unicode prefix
```

⚠️ **No floating point.** Money is represented in the smallest unit (wei: 1 ETH = 10¹⁸ wei) and percentages in basis points (1% = 100 bps).

⚠️ **No `null` / `undefined` / `None`.** Every variable starts at its type's zero value: `0`, `false`, `address(0)`, empty string/array, and structs with all fields zeroed. You can't tell "never set" from "set to zero" unless you track that yourself.

### Type conversions

```solidity
uint8  small = 200;
uint256 big  = small;          // implicit widening: OK
uint8  back  = uint8(big);     // explicit narrowing: allowed
uint256 x    = 300;
uint8  y     = uint8(x);       // ⚠️ y == 44. Truncates silently, does NOT revert
int256 neg   = -1;
uint256 u    = uint256(neg);   // ⚠️ becomes 2**256 - 1
```

To get safe narrowing, check the range yourself or use OpenZeppelin's `SafeCast`. Type limits are available via `type(uint8).max` and `type(int256).min`.

---

## 4. Variables, scope and constants

```solidity
contract Scopes {
    uint256 public count;                       // STATE variable: stored on-chain permanently
    uint256 public constant MAX = 100;          // compile-time constant, no storage used
    address public immutable deployer;          // set once in constructor, then read-only

    constructor() {
        deployer = msg.sender;
    }

    function demo() external view returns (uint256) {
        uint256 local = count + 1;              // LOCAL variable: lives only during the call
        return local;
    }
}
```

- Type comes first, then the name. There's no `let`, `const` or `var`.
- Scoping is **block-scoped**, like JS `let`: a variable declared inside `{ }` doesn't exist outside it.
- State variables default to `internal` visibility. You can mark them `public` (the compiler auto-generates a getter), `internal` or `private`.
- `constant` means the value is known at compile time. `immutable` means it's set once in the constructor. Both are much cheaper to read than regular storage.
- ⚠️ Don't use `at`, `error`, `layout`, `leave`, `super`, `transient` or `this` as variable or function names. Since 0.8.35 the compiler warns about them because they're scheduled to become reserved keywords.

**Tuple destructuring** works like Python unpacking, including skipping values:

```solidity
(uint256 a, bool ok) = getPair();
(, bool onlyThis)    = getPair();   // skip the first value
(a, b) = (b, a);                    // swap
```

---

## 5. Operators and arithmetic

Operators are mostly what you know from C and JS: `+ - * / % **`, `== != < <= > >=`, `&& || !`, `& | ^ ~ << >>`, `+= -= *= ...`, `++ --` and `cond ? a : b`.

The differences:

- ⚠️ **There is no `===`.** There's no type coercion to guard against, so `==` is already strict.
- ⚠️ **No truthiness.** `if (count)` is a compile error. Write `if (count != 0)`. `!` only works on `bool`.
- ⚠️ **Overflow reverts.** Since 0.8.0, `type(uint256).max + 1` reverts instead of wrapping. JS silently loses precision and Python grows the number forever.
- ⚠️ **Integer division truncates toward zero.** With `int256 a = -7`, `a / 2` is `-3` (Python's `//` gives `-4`), and `7 / 2` on variables gives `3`.
- ⚠️ **Modulo takes the sign of the left operand**, like JS: `a % 3` is `-1` for `a = -7`. Python gives `2`.
- ⚠️ **Literal-only math is exact.** An expression made only of literals is computed at compile time as a precise fraction, so `uint256 x = 5 / 2;` is a compile error (2.5 isn't an integer), while `uint256 x = 10 / 2;` is fine.
- ⚠️ **Division by zero reverts.** There's no `Infinity` or `NaN`.
- **Multiply before dividing** to keep precision: `amount * pct / 100`, not `amount / 100 * pct`.
- `==` does **not** work on `string`, `bytes`, arrays or structs. Compare strings by hash (see [§13](#13-global-variables-and-built-ins)).
- ⚠️ Comparing two contract-typed variables (`tokenA == tokenB`) is deprecated since 0.8.31. Compare their addresses instead: `address(tokenA) == address(tokenB)`.
- `delete x` resets `x` to its zero value. It does not remove a key the way JS `delete` does.

When you've proven overflow is impossible, you can opt out of checks to save gas:

```solidity
unchecked {
    i++;   // no overflow check inside this block
}
```

---

## 6. Control structures

`if`, `else`, `for`, `while`, `do-while`, `break`, `continue` and `return` look exactly like JS/C, and braces around single statements are optional (but recommended).

```solidity
// if / else if / else
if (balance == 0) {
    revert Empty();
} else if (balance < MIN) {
    status = Status.Low;
} else {
    status = Status.Ok;
}

// ternary
uint256 fee = isVip ? 0 : 100;

// classic for loop (the only kind of for loop)
for (uint256 i = 0; i < holders.length; i++) {
    if (holders[i] == address(0)) continue;
    if (holders[i] == target) break;
}

// while
while (n > 1) {
    n /= 2;
}

// do-while
do {
    n--;
} while (n > 0);
```

What's missing, and what to use instead:

| You might reach for | Solidity reality |
|---------------------|------------------|
| `for...of` / `for x in list` | Doesn't exist. Loop over an index. |
| `forEach`, `map`, `filter`, list comprehensions | Don't exist. Write the loop manually. |
| `switch` / `match` | Doesn't exist. Use `if/else if` chains, or a `mapping` lookup table. |
| `try/catch` around anything | Only around **external calls** (see [§10](#10-error-handling)). |
| Iterating a `mapping` / `dict` | Impossible. Keep a separate array of keys. |

⚠️ **Loops cost gas per iteration.** A loop over an array that users can grow without limit may eventually exceed the block gas limit, and then the function can never run again. Keep loops bounded, or redesign so that each user handles their own item (the "pull" pattern in `Will.sol`).

Since 0.8.22 the compiler automatically skips the overflow check on the increment of simple `for` loops, so the old `unchecked { ++i; }` trick is usually unnecessary.

---

## 7. Functions

### Anatomy

```solidity
function name(uint256 a, string calldata s)   // parameters (reference types need a location)
    external                                  // visibility (required)
    view                                      // state mutability (optional)
    onlyOwner                                 // custom modifiers (optional)
    returns (uint256, bool)                   // return types
{
    return (a, true);
}
```

### Visibility

| Keyword | Callable from outside | Callable from inside | Callable by child contracts |
|---------|:---------------------:|:--------------------:|:---------------------------:|
| `external` | ✅ | ❌ (only via `this.f()`) | ❌ |
| `public` | ✅ | ✅ | ✅ |
| `internal` | ❌ | ✅ | ✅ |
| `private` | ❌ | ✅ | ❌ |

### State mutability

| Keyword | Meaning |
|---------|---------|
| *(none)* | Can read and write state |
| `view` | Reads state, never writes it. Free when called off-chain. |
| `pure` | Neither reads nor writes state (pure computation) |
| `payable` | Can receive ETH with the call. Without it, sending ETH reverts. |

### Returns

```solidity
// multiple return values
function stats() public pure returns (uint256, uint256) {
    return (1, 2);
}

// named return values: assigned like variables, returned implicitly
function split(uint256 total) public pure returns (uint256 half, uint256 rest) {
    half = total / 2;
    rest = total - half;
}
```

### Calling conventions

```solidity
transfer(to, 100);                  // positional
transfer({amount: 100, to: to});    // named arguments, any order
```

- ⚠️ **No default parameter values and no variadic (`...args` / `*args`) parameters.**
- **Overloading is allowed**: two functions can share a name if their parameter types differ.
- ⚠️ **Functions aren't first-class the way they are in JS.** There are function *types*, but no closures, lambdas or arrow functions.

---

## 8. Arrays, mappings, structs and enums

### Arrays

```solidity
uint256[] public nums;                     // dynamic storage array
uint256[3] public fixedNums;               // fixed length 3

function arrays() external {
    nums.push(10);                         // append (storage arrays only)
    nums.pop();                            // remove last (storage arrays only)
    uint256 len = nums.length;             // length
    delete nums[0];                        // ⚠️ zeroes the element, length stays the same
    delete nums;                           // empties the array (length becomes 0)

    uint256[] memory tmp = new uint256[](len);   // memory array: fixed size, no push/pop
    uint256[3] memory lit = [uint256(1), 2, 3];  // ⚠️ literal type comes from the first element
}
```

- ⚠️ Reading past the end **reverts**. There's no `undefined` and no `IndexError` you can catch.
- ⚠️ There's no `splice`, `slice`, `indexOf`, `includes` or `sort`. To remove from the middle, swap the element with the last one, then `pop()`.
- Slicing (`data[start:end]`) works only on `calldata` arrays.

### Mappings (the `dict` / `Map` equivalent)

```solidity
mapping(address => uint256) public balances;
mapping(address owner => mapping(address spender => uint256)) public allowance; // named keys: 0.8.18+

balances[msg.sender] += 100;
uint256 b = balances[someone];     // ⚠️ missing keys return 0, never an error
delete balances[msg.sender];       // reset to 0
```

⚠️ A mapping has **no length, no keys list and no iteration**, and every possible key "exists" with a zero value. Mappings can only live in storage, never in memory or as function parameters of public/external functions.

### Structs

```solidity
struct Heir {
    address wallet;
    uint256 share;
    bool claimed;
}

Heir[] public heirs;
mapping(address => Heir) public heirOf;

function structs(address a) external {
    heirs.push(Heir({wallet: a, share: 50, claimed: false}));  // named fields
    heirs.push(Heir(a, 50, false));                            // positional

    Heir storage h = heirs[0];   // reference to storage: changes persist
    h.share = 60;

    Heir memory copy = heirs[0]; // ⚠️ a COPY: changing it does not touch storage
    copy.share = 999;            // heirs[0].share is still 60
}
```

### Enums

```solidity
enum Status { Pending, Active, Closed }   // stored as uint8: 0, 1, 2

Status public status = Status.Pending;

function close() external {
    status = Status.Closed;
    uint256 asNumber = uint256(status);   // 2
    Status last = type(Status).max;       // Status.Closed (0.8.8+)
}
```

---

## 9. Data locations: storage, memory, calldata

This has no JS or Python equivalent, and it's the #1 source of beginner bugs. Every reference type (array, struct, `string`, `bytes`) used as a local variable or parameter must say **where it lives**:

| Location | Lifetime | Mutable | Cost | Typical use |
|----------|----------|---------|------|-------------|
| `storage` | Permanent, on-chain | ✅ | Very expensive | State variables, pointers to them |
| `memory` | Only during the function call | ✅ | Cheap | Temporary values, return values |
| `calldata` | Only during the call, read-only | ❌ | Cheapest | `external` function inputs |
| `transient` | Until the end of the **transaction**, then auto-cleared | ✅ | Cheap | Re-entrancy locks, per-transaction flags (0.8.28+) |

`transient` is only for state variables, and currently only value types (`bool`, `uint256`, `address` ...):

```solidity
bool transient locked;   // resets to false automatically after every transaction

modifier nonReentrant() {
    require(!locked, Reentered());
    locked = true;
    _;
    locked = false;
}
```

Whether assignment **copies** or **references** depends on the locations:

| Assignment | Result |
|------------|--------|
| storage to local `storage` variable | reference (edits persist) |
| storage to `memory` | copy |
| `memory` to storage | copy |
| `memory` to `memory` | reference |

```solidity
function rename(string calldata newName) external {   // calldata: read-only input
    name = newName;                                     // copied into storage
}
```

---

## 10. Error handling

A revert undoes **every** state change in the transaction, including changes made by other contracts it called. There's no partial success.

```solidity
error InsufficientBalance(uint256 have, uint256 want);     // custom error (0.8.4+)

function withdraw(uint256 amount) external {
    // 1) require with a custom error: the modern default (0.8.27+)
    require(amount <= balances[msg.sender], InsufficientBalance(balances[msg.sender], amount));

    // 2) if + revert with a custom error: equivalent, handy for complex conditions
    if (amount > LIMIT) {
        revert InsufficientBalance(LIMIT, amount);
    }

    // 3) require with a string message: legacy style, costs more gas. You'll see it in older code.
    require(amount > 0, "amount is zero");

    // 4) assert: only for invariants that should be impossible. Failing = a bug in your code
    assert(totalSupply >= amount);
}
```

`Will.sol` uses style 2 everywhere because it supports compilers back to 0.8.4, before `require` accepted custom errors.

| Tool | When to use |
|------|-------------|
| `require` / `if + revert` | Validate inputs, permissions and conditions |
| `assert` | Internal invariants. A failure means a bug. |
| Custom errors | Preferred reason format: cheaper than strings and can carry data |

Built-in failures (overflow, division by zero, out-of-bounds index, failed `assert`) revert with a `Panic(uint256 code)` error.

### try/catch

⚠️ This works **only** around external contract calls and `new` contract creation, not around arbitrary code:

```solidity
try otherContract.getPrice(token) returns (uint256 price) {
    lastPrice = price;
} catch Error(string memory reason) {      // from require(..., "msg") / revert("msg")
    emit Failed(reason);
} catch Panic(uint256 code) {              // from assert, overflow, division by zero ...
    emit PanicCode(code);
} catch (bytes memory data) {              // anything else, including custom errors
    emit RawFailure(data);
}
```

---

## 11. Contract building blocks

These are covered in depth, with comments, in [`Will/Will.sol`](Will/Will.sol). Here's the syntax at a glance:

```solidity
contract Vault {
    address public owner;

    // Events: logs for off-chain apps. Up to 3 `indexed` params become searchable.
    event Deposited(address indexed from, uint256 amount);

    error NotOwner();
    error TransferFailed();

    // Modifiers: reusable checks. `_;` is where the function body runs.
    modifier onlyOwner() {
        require(msg.sender == owner, NotOwner());
        _;
    }

    // Constructor: runs once at deployment
    constructor() {
        owner = msg.sender;
    }

    // receive: called on plain ETH transfers (empty calldata)
    receive() external payable {
        emit Deposited(msg.sender, msg.value);
    }

    // fallback: called when no function matches the calldata
    fallback() external payable {}

    function sweep() external onlyOwner {
        (bool ok, ) = payable(owner).call{value: address(this).balance}("");
        require(ok, TransferFailed());
    }
}
```

---

## 12. Inheritance, interfaces and libraries

```solidity
// Interface: signatures only. No state, no constructor, all functions external.
interface IGreeter {
    function greet() external view returns (string memory);
}

// Abstract contract: can have unimplemented functions
abstract contract Base {
    function greet() public view virtual returns (string memory);   // `virtual` = overridable
}

// Inheritance uses `is`. Multiple parents allowed, listed "most base" to "most derived".
contract Greeter is Base, IGreeter {
    function greet() public pure override(Base, IGreeter) returns (string memory) {
        return "gm";
    }
}

contract LoudGreeter is Greeter {
    function shout() external pure returns (string memory) {
        return string.concat(super.greet(), "!!!");   // `super` calls the parent version
    }
}

// Library: stateless helpers, attached to types with `using ... for`
library MathLib {
    function double(uint256 x) internal pure returns (uint256) {
        return x * 2;
    }
}

contract UsesLib {
    using MathLib for uint256;

    function quad(uint256 x) external pure returns (uint256) {
        return x.double().double();   // x becomes the first argument
    }
}
```

- An overriding function must say `override`, and the original must say `virtual`. Nothing is overridable by default.
- ⚠️ `virtual` **modifiers** are deprecated since 0.8.31. If a child contract needs to customize a check, have the modifier call a `virtual` internal function and override that function instead.
- Call another contract through its interface: `IGreeter(addr).greet()`.

---

## 13. Global variables and built-ins

| Expression | Meaning |
|------------|---------|
| `msg.sender` | Address that directly called this function. Use it for auth. |
| `msg.value` | Wei sent with the call (only in `payable` functions) |
| `msg.data` | Raw calldata (`bytes`) |
| `block.timestamp` | Current block time, Unix seconds (`now` was removed in 0.7) |
| `block.number` | Current block number |
| `block.chainid` | Chain ID (1 = Ethereum mainnet) |
| `tx.origin` | EOA that started the transaction. ⚠️ Never use it for auth. |
| `gasleft()` | Remaining gas |
| `address(this)` | This contract's address |
| `addr.balance` | ETH balance of an address, in wei |
| `addr.code.length` | Size of the code at an address (see the warning below) |

⚠️ **You can no longer reliably tell a wallet from a contract.** Since the Pectra upgrade (EIP-7702), a normal wallet (EOA) can delegate to contract code, so it has `code.length > 0` and can run logic when it receives ETH. The old tricks `addr.code.length == 0` and `tx.origin == msg.sender` don't prove "this is a plain wallet". Design as if any address may run code.
| `type(T).max` / `.min` | Numeric limits |

### Strings and bytes

Solidity strings are deliberately minimal:

```solidity
string memory full = string.concat("gm, ", name);       // concat (0.8.12+)
bytes memory raw   = bytes.concat(a, b);                // concat bytes (0.8.4+)
uint256 byteLen    = bytes(full).length;                // ⚠️ byte length, not character count
bool same = keccak256(bytes(a)) == keccak256(bytes(b)); // ⚠️ the only way to compare strings
```

⚠️ There's no `.length` on `string` itself, no indexing, no `split`, `toUpperCase`, templates or f-strings. Heavy string work belongs off-chain.

### Hashing and encoding

```solidity
bytes32 h1 = keccak256(abi.encode(user, amount));        // standard ABI encoding
bytes32 h2 = keccak256(abi.encodePacked(user, amount));  // compact, but ⚠️ collisions possible with 2+ dynamic types
(address u, uint256 amt) = abi.decode(data, (address, uint256));
```

### Debugging

There's no `console.log` / `print` on-chain. For real contracts, emit **events**. During development, Hardhat, Foundry and Remix support a `console.log` helper:

```solidity
import "hardhat/console.sol";         // Hardhat & Remix
// import "forge-std/console.sol";    // Foundry

console.log("balance is", balance);   // shows in the dev tool's output, not on a real chain
```

---

## 14. JS / Python to Solidity cheat sheet

| Concept | JavaScript | Python | Solidity |
|---------|-----------|--------|----------|
| Declare variable | `let x = 5` | `x = 5` | `uint256 x = 5;` |
| Constant | `const X = 5` | `X = 5` (convention) | `uint256 constant X = 5;` |
| Null / missing | `null` / `undefined` | `None` | *(none: zero values)* |
| Float | `0.5` | `0.5` | *(none: use integers)* |
| Strict equality | `===` | `==` | `==` |
| Integer division | `Math.trunc(a / b)` | `a // b` | `a / b` |
| Power | `a ** b` | `a ** b` | `a ** b` |
| Dictionary | `Map` / object | `dict` | `mapping(K => V)` |
| List append | `arr.push(x)` | `lst.append(x)` | `arr.push(x);` |
| List length | `arr.length` | `len(lst)` | `arr.length` |
| Remove last | `arr.pop()` | `lst.pop()` | `arr.pop();` (returns nothing) |
| Loop over list | `for (const x of arr)` | `for x in lst:` | `for (uint256 i; i < arr.length; i++)` |
| Class | `class A {}` | `class A:` | `contract A {}` |
| Inherit | `extends B` | `class A(B):` | `contract A is B {}` |
| Constructor | `constructor()` | `__init__` | `constructor()` |
| `this` / `self` | `this.x` | `self.x` | `x` (state vars are in scope directly) |
| Private member | `#x` | `_x` (convention) | `private` (still readable on-chain!) |
| Throw / raise | `throw new Error()` | `raise ValueError()` | `revert MyError();` |
| Assert input | `if (!ok) throw` | `if not ok: raise` | `require(ok, "msg");` |
| Try/catch | anywhere | anywhere | only around external calls |
| Print / log | `console.log` | `print` | `emit Event(...)` |
| String compare | `a === b` | `a == b` | `keccak256(bytes(a)) == keccak256(bytes(b))` |
| String concat | `` `${a}${b}` `` | `f"{a}{b}"` | `string.concat(a, b)` |
| Current time | `Date.now()` (ms) | `time.time()` | `block.timestamp` (seconds) |
| Randomness | `Math.random()` | `random.random()` | ⚠️ none that's safe (use an oracle like Chainlink VRF) |
| Async / await | ✅ | ✅ | ❌ (everything runs inside one transaction) |

---

## 15. Staying current: modern features and deprecations

Solidity 0.8.x keeps adding features without breaking old code, so tutorials from different years look quite different. Here's what "modern" means as of **0.8.37**.

### Use these (newer features)

| Feature | Since | What it replaces |
|---------|-------|------------------|
| `require(cond, CustomError(...))` | 0.8.27 (0.8.26 via-IR only) | `if (!cond) revert CustomError();` or string messages |
| `transient` state variables | 0.8.28 | Storage-based re-entrancy locks and inline assembly `tstore`/`tload` |
| Unchecked `for` loop counters by default | 0.8.22 | Manual `unchecked { ++i; }` |
| Named mapping parameters: `mapping(address user => uint256 balance)` | 0.8.18 | Unnamed mappings |
| `string.concat(...)` | 0.8.12 | `string(abi.encodePacked(...))` |
| Custom errors (`error X();`) | 0.8.4 | `require(cond, "message")` |

### Avoid these (deprecated since 0.8.31, to be removed in 0.9.0)

| Deprecated | Use instead |
|------------|-------------|
| `addr.transfer(x)` / `addr.send(x)` | `(bool ok, ) = addr.call{value: x}(""); require(ok, ...);` |
| `contractA == contractB` | `address(contractA) == address(contractB)` |
| `virtual` modifiers | A modifier that calls an overridable `virtual` internal function |
| `pragma abicoder v1` | Nothing: ABI coder v2 is already the default |

Also avoid naming anything `at`, `error`, `layout`, `leave`, `super`, `transient` or `this` (future keywords, warned since 0.8.35).

### EVM version

Each compiler version targets an EVM version by default. Since 0.8.31 the default is `osaka`, the latest Ethereum mainnet upgrade. When you deploy to a chain (usually an L2 or sidechain) that hasn't adopted the newest opcodes, set the matching `evmVersion` in your compiler settings (Remix: *Advanced Configurations*; Foundry: `evm_version` in `foundry.toml`; Hardhat: `solidity.settings.evmVersion`). Otherwise deployment can fail with "invalid opcode".

---

## 16. Style conventions

From the [official style guide](https://docs.soliditylang.org/en/latest/style-guide.html):

| Element | Convention | Example |
|---------|-----------|---------|
| Contracts, structs, events, errors, enums | `CapWords` | `Will`, `HeirAdded`, `NotOwner` |
| Functions, variables, modifiers | `mixedCase` | `claimInheritance`, `lastHeartbeat`, `onlyOwner` |
| Constants | `UPPER_CASE` | `MAX_HEIRS` |
| Private / internal functions | leading underscore | `_sendEth` |
| Indentation | 4 spaces | |

**Layout order inside a contract:** type declarations, state variables, events, errors, modifiers, constructor, `receive`, `fallback`, then `external`, `public`, `internal` and `private` functions (with `view`/`pure` last within each group).

---

**Next steps:** read [`Will/Will.sol`](Will/Will.sol) for these concepts working together in a real contract, and keep the [official Solidity docs](https://docs.soliditylang.org) nearby.

---

## Sources

Every version number and deprecation in this guide was checked against the official release notes, and every snippet compiles with solc 0.8.37.

**Official documentation**

- [Solidity documentation (latest)](https://docs.soliditylang.org/en/latest/)
- [Types](https://docs.soliditylang.org/en/latest/types.html): value types, reference types, data locations, conversions, literals
- [Expressions and Control Structures](https://docs.soliditylang.org/en/latest/control-structures.html): control flow, checked/unchecked arithmetic, error handling, try/catch
- [Contracts](https://docs.soliditylang.org/en/latest/contracts.html): visibility, modifiers, events, errors, inheritance, interfaces, libraries, transient storage
- [Units and Globally Available Variables](https://docs.soliditylang.org/en/latest/units-and-global-variables.html): ether/time units, `msg`, `block`, `tx`, ABI and hashing functions
- [Style Guide](https://docs.soliditylang.org/en/latest/style-guide.html): naming and layout conventions

**Release notes** (where each labeled feature or deprecation comes from)

- [All Solidity releases (GitHub)](https://github.com/ethereum/solidity/releases)
- [0.8.37 release announcement](https://www.soliditylang.org/blog/2026/09/10/solidity-0.8.37-release-announcement/): latest version this guide targets
- [0.8.35 release announcement](https://www.soliditylang.org/blog/2026/04/29/solidity-0.8.35-release-announcement/): identifiers reserved for future keywords
- [0.8.31 release announcement](https://www.soliditylang.org/blog/2025/12/03/solidity-0.8.31-release-announcement/): deprecation of `transfer`/`send`, contract-type comparisons, virtual modifiers and ABI coder v1; default EVM version `osaka`
- [0.8.28 release announcement](https://www.soliditylang.org/blog/2024/10/09/solidity-0.8.28-release-announcement/): `transient` state variables
- [0.8.27 release announcement](https://www.soliditylang.org/blog/2024/09/04/solidity-0.8.27-release-announcement/): `require(bool, Error)` in the legacy pipeline
- [0.8.26 release announcement](https://www.soliditylang.org/blog/2024/05/21/solidity-0.8.26-release-announcement/): `require(bool, Error)` introduced (via-IR only)
- [v0.8.22 release notes](https://github.com/ethereum/solidity/releases/tag/v0.8.22): unchecked loop increments
- [v0.8.18 release notes](https://github.com/ethereum/solidity/releases/tag/v0.8.18): named mapping parameters
- [v0.8.12 release notes](https://github.com/ethereum/solidity/releases/tag/v0.8.12): `string.concat`
- [v0.8.8 release notes](https://github.com/ethereum/solidity/releases/tag/v0.8.8): `type(E).min` / `type(E).max` for enums
- [v0.8.4 release notes](https://github.com/ethereum/solidity/releases/tag/v0.8.4): custom errors and `bytes.concat`

**Ethereum Improvement Proposals**

- [EIP-7702: Set Code for EOAs](https://eips.ethereum.org/EIPS/eip-7702): why wallets can now have code
- [EIP-1153: Transient storage opcodes](https://eips.ethereum.org/EIPS/eip-1153): the EVM feature behind `transient`
