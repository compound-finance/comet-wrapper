# Comet Wrapper

A wrapped token that converts a rebasing [Compound III](https://github.com/compound-finance/comet) token into a non-rebasing [ERC-4626](https://eips.ethereum.org/EIPS/eip-4626) vault with [ERC-7246](https://github.com/ethereum/EIPs/pull/7246) ([Encumber](https://blog.compoundlabs.xyz/)) support.

## Overview

Compound III tokens like cUSDCv3 and cWETHv3 are rebasing tokens, which means the token balances automatically increase as interest is accrued. However, most protocols are designed to work with non-rebasing tokens. The standard solution to this problem is to use a wrapped token.

This wrapped token allows other protocols to more easily integrate with Compound III tokens and treat it like any standard ERC20 token.

## Features

- **ERC-4626 support**: Converts a Compound III token into a non-rebasing ERC-4626 vault.
- **ERC-7246 (Encumber) support**: The wrapper implements encumberability, which allows it to be used non-custodially in supported protocols.
- **Liquidity mining incentives tracking**: Users that deposit into the wrapper will earn their respective share of incentives for markets that provide them.
- **Signature based operations**: Users can approve and encumber their wrapper tokens gaslessly using signatures.
- **Signature verification for contracts**: All by-signature functions (`permit`, `encumberBySig`) support [EIP-1271](https://eips.ethereum.org/EIPS/eip-1271) signature verification, meaning smart contract wallets can interact with the wrapper through signatures.
- **Controlled by Compound governance**: Each wrapper contract is deployed behind an upgradeable proxy that is managed by Compound governance.

## Design Decisions

`CometWrapper` is designed to nullify [inflation attacks](https://blog.openzeppelin.com/a-novel-defense-against-erc4626-inflation-attacks) which could cause losses for users. It's a method of manipulating the exchange rate of wrapped tokens which enables attackers to steal the underlying tokens from target depositors or make it prohibitively expensive for future depositors to use the contract.

To nullify inflation attacks, `CometWrapper` maintains internal accounting of all Compound III tokens deposited and withdrawn. This internal accounting only gets updated through the `mint`, `redeem`, `deposit` and `withdraw` functions. This means that any direct transfer of Compound III tokens will not be recognized by the `CometWrapper` contract. The tradeoff is that any tokens directly transferred to `CometWrapper` will be locked.

## Deployments

### Mainnets

| Network  | Base Asset | CometWrapper Address                       |
| -------- | ---------- | ------------------------------------------ |
| Mainnet  | USDC       | Upcoming                                   |
| Mainnet  | WETH       | Upcoming                                   |
| Polygon  | USDC       | Upcoming                                   |
| Arbitrum | USDC       | Upcoming                                   |
| Base     | USDC       | Upcoming                                   |
| Base     | WETH       | Upcoming                                   |

### Testnets

| Network  | Base Asset | CometWrapper Address                       |
| -------- | ---------- | ------------------------------------------ |
| Goerli   | USDC       | 0x00674edDE603C5AB9A3F284B41Ef58ff31d1cd7B |
| Mumbai   | USDC       | 0x797D7126C35E0894Ba76043dA874095db4776035 |
| Base     | USDC       | 0xcCB6009A6eC62FEd3091F670c4F9DDe55A0559FE |
| Base     | WETH       | 0x0182621987C4C0D05685EF4E9e3F8323d58D963b |

## Usage

`CometWrapper` implements the ERC-4626 Tokenized Vault Standard and is used like any other ERC-4626 contracts.

### Wrapping Tokens

To wrap a Compound III token like cUSDCv3, you will need to have cUSDCv3 in your wallet and then do the following:

1. `comet.allow(cometWrapperAddress, true)` - allow CometWrapper to move your cUSDCv3 tokens from your wallet to the CometWrapper contract when you call `deposit` or `mint`.
2. `cometWrapper.mint(amount, receiver)` - the first parameter is the amount of Wrapped tokens to be minted.
   OR `cometWrapper.deposit(amount, receiver)` - the first parameter is the amount of Comet tokens that will be deposited.

### Withdrawing Tokens

To withdraw a Compound III token like cUSDCv3, you may use either `withdraw` or `redeem`. For example:

- `cometWrapper.withdraw(amount, receiver, owner)` - `amount` is the number of Compound III tokens to be withdrawn. You can only withdraw tokens that you deposited.
- `cometWrapper.redeem(amount, receiver, owner)` - `amount` is the number of Wrapped Compound III tokens to be redeemed in exchange for the deposited Compound III tokens.

### Claiming Rewards

Comet tokens deposited in CometWrapper will continue to accrue rewards if reward accrual is enabled in Comet. CometWrapper keeps track of users' rewards and users will earn rewards as they would in Comet. The only difference is in claiming of the rewards. Instead of claiming rewards from the CometRewards contract, users will claim it from CometWrapper like so `cometWrapper.claimTo(alice)`.
