<div align="center">

<img src="public/images/learn-web-3-thumbnail.png" alt="Learn Web3 With Me: my personal web3 learning log with roadmap" width="100%" />

<h1>Learn Web3 With Me</h1>

<p>
  <strong>Real code. Real progress. In public.</strong><br/>
  <sub>Smart contracts, blockchains, tokens, DeFi and dApps, where every file doubles as a study note.</sub>
</p>

<p>
  <img src="https://img.shields.io/badge/Solidity-0.8.37-363636?style=flat-square&logo=solidity&logoColor=white" alt="Solidity 0.8.37" />
  <img src="https://img.shields.io/badge/learning-in%20public-7B3FE4?style=flat-square" alt="Learning in public" />
</p>

<p><sub><b>BUILDING WITH</b></sub></p>

<p>
  <img src="https://img.shields.io/badge/Solidity-363636?style=for-the-badge&logo=solidity&logoColor=white" alt="Solidity" />
  <img src="https://img.shields.io/badge/Ethereum-3C3C3D?style=for-the-badge&logo=ethereum&logoColor=white" alt="Ethereum" />
  <img src="https://img.shields.io/badge/Remix_IDE-2B2B2B?style=for-the-badge" alt="Remix IDE" />
</p>

<p><sub><b>ON THE ROADMAP</b></sub></p>

<p>
  <img src="https://img.shields.io/badge/Foundry-2B2B2B?style=for-the-badge" alt="Foundry" />
  <img src="https://img.shields.io/badge/Hardhat-FFF100?style=for-the-badge" alt="Hardhat" />
  <img src="https://img.shields.io/badge/OpenZeppelin-4E5EE4?style=for-the-badge&logo=openzeppelin&logoColor=white" alt="OpenZeppelin" />
  <img src="https://img.shields.io/badge/Chainlink-375BD2?style=for-the-badge&logo=chainlink&logoColor=white" alt="Chainlink" />
  <img src="https://img.shields.io/badge/ethers.js-2535A0?style=for-the-badge&logo=ethers&logoColor=white" alt="ethers.js" />
  <img src="https://img.shields.io/badge/viem-2B2B2B?style=for-the-badge" alt="viem" />
  <img src="https://img.shields.io/badge/Wagmi-000000?style=for-the-badge&logo=wagmi&logoColor=white" alt="Wagmi" />
  <img src="https://img.shields.io/badge/MetaMask-F6851B?style=for-the-badge" alt="MetaMask" />
</p>

<p>
  <a href="QUICK_SYNTAX_GUIDE.md">Syntax Guide</a> &middot;
  <a href="Will/Will.sol">First Contract</a> &middot;
  <a href="#roadmap">Roadmap</a> &middot;
  <a href="#glossary">Glossary</a>
</p>

</div>

---

Hellooooooooo!

It's me **M. Yousuf** ([yousuf-dev.com](https://yousuf-dev.com)), a software engineer who's finally jumping down the web3 rabbit hole. Smart contracts, blockchains, tokens, DeFi, all of it. I'm very excited about this stuff, and this repo is where I'm learning it in public.

Let's cook. 🍳

---

## What is this repo?

My personal web3 learning log. Every contract, guide and experiment I write while learning ends up here.

Code in this repo is **heavily commented on purpose**: each file is meant to double as study notes, explaining the *what* and the *why* the first time a concept shows up. You should be able to open any file and learn from it without jumping to a tutorial.

## Why?

- **To learn by building.** Reading docs is fine, but writing real contracts is where things click.
- **To keep notes I'll actually reuse.** Explaining something in writing is the best test of whether I understand it.
- **To help others starting out.** If you already know a language like JavaScript or Python and want to get into Solidity, this repo is written for exactly you.

## Getting started

No setup needed for now. Everything so far runs in the browser:

1. Open [Remix IDE](https://app.remix.live).
2. Copy any `.sol` file from this repo into a new file there.
3. Compile, deploy on the built-in "Remix VM", and play with the functions.

Each contract has a "Trying it in Remix" section in its header comment with exact steps.

---

## Roadmap

What I'm planning to cover. Checked items already have content in the repo, and this list will change as I go.

### Solidity fundamentals
- [x] Syntax essentials and control structures, for people coming from JS/Python
- [x] First contract: state, functions, modifiers, events, custom errors
- [x] Handling ETH: `receive`, `payable`, pull payments, Checks-Effects-Interactions
- [ ] Inheritance, interfaces and libraries in practice
- [ ] Gas optimization basics

### Tooling
- [x] Remix IDE
- [ ] Foundry (`forge`, `cast`, `anvil`)
- [ ] Hardhat
- [ ] Writing tests: unit, fuzz and invariant tests
- [ ] Deploying to a testnet (Sepolia) and verifying on Etherscan

### Token standards
- [ ] ERC-20 (fungible tokens)
- [ ] ERC-721 (NFTs)
- [ ] ERC-1155 (multi-token)
- [ ] Building on OpenZeppelin Contracts

### Security
- [ ] Common vulnerabilities: re-entrancy, access control, oracle manipulation and friends
- [ ] Reading audit reports and doing a self-review

### Going deeper
- [ ] Upgradeable contracts (proxies, namespaced storage)
- [ ] Oracles (Chainlink)
- [ ] DeFi building blocks: AMMs, lending, staking
- [ ] Account abstraction (ERC-4337, EIP-7702)
- [ ] Layer 2s and rollups

### Building dApps
- [ ] Connecting a frontend: wallets, viem / ethers, wagmi
- [ ] Reading events and indexing on-chain data

---

## Glossary

A map of everything in the repo. Start at the top if you're new.

| File | What it is | What you'll learn |
|------|-----------|-------------------|
| [`QUICK_SYNTAX_GUIDE.md`](QUICK_SYNTAX_GUIDE.md) | Solidity syntax guide for developers who already know JS or Python | Types, control structures, functions, data locations, error handling, inheritance, a JS/Python-to-Solidity cheat sheet, and what's new or deprecated as of Solidity 0.8.37 |
| [`Will/Will.sol`](Will/Will.sol) | My first contract: an on-chain will ("dead man's switch") that pays heirs if the owner stops checking in | State variables, `constant`/`immutable`, mappings and arrays, events, custom errors, modifiers, `receive()`, sending ETH safely, pull payments, re-entrancy protection |

---

## Repo structure

```
learn-web3/
├── Readme.md               ← you are here
├── QUICK_SYNTAX_GUIDE.md   ← Solidity syntax reference
├── public/
│   └── images/             ← README and docs images
└── Will/
    └── Will.sol            ← project 1: inheritance "dead man's switch"
```

---

*This README grows with the repo. New files get added to the glossary and the roadmap gets checked off as I go.*
