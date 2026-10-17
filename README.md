# HAMSTER

HAMSTER is a fixed-supply ERC-20 for the project described as:

> X: @hamsterhourgame — bet on hamster, lose to earn $HAMSTER

## Scope and assumptions

This assignment implements the custom token. The description is treated as project
branding: it does not define wagering rules, race results, reward amounts, funding,
or settlement. No betting, randomness, automatic loss rewards, or application
contracts are implemented. A future game would need its own specification and must
fund any HAMSTER rewards from existing tokens; this token cannot mint rewards.

Ordinary ERC-20 transfers have no tax, fee, rebasing, restriction, or burn. There is
no owner, privileged operator, pause, blacklist, seizure, proxy, or upgrade path.
The deployer receives the initial supply and has the same transfer rights as any
other holder thereafter.

## Contract and deployment parameters

| Parameter | Value |
| --- | --- |
| Solidity contract | `HamsterToken` |
| Source | `src/HamsterToken.sol` |
| Name / symbol | `HAMSTER` / `HAMSTER` |
| Decimals | `18` |
| Supply | `1,000,000,000 HAMSTER` |
| Supply in base units | `1000000000000000000000000000` (`10^27`) |
| Named constant | `INITIAL_SUPPLY = 1_000_000_000 * 10 ** 18` |
| Constructor arguments | None (`[]`) |
| Constructor value | `0` ETH |
| Initial recipient | Immediate constructor caller (`msg.sender`) |
| Launch chain | Ethereum, chain ID `1` |
| Compiler / EVM | Solidity `0.8.26` / Cancun |
| Optimizer | Enabled, `200` runs |
| Metadata hash | `bytecode_hash = "none"` |
| Additional application contracts | None |
| Linked libraries / initialization calls | None |

The constructor emits one `Transfer(address(0), deployer, INITIAL_SUPPLY)` event.
It makes no external calls and works on an empty chain. When the launch factory
creates the token, the factory receives the entire supply, not the transaction
origin or a configured owner. The token constructor makes no allocations itself.

The supplied launch policy handles subsequent distribution: 10% to its swarm
distributor, 30% for pool seeding, and 60% to the supplied remainder recipient
`0xee2aaa315cf7ed169f93148d30d24af9318dbb66`. The pair is IMD at
`0xd34a99bc0f67ae1bbd63c660e6d0b0dd03e263b7`; the supplied opening capitalization
is `800000000000000000000` IMD base units. Pool fee `12500` (1.25%) and tick spacing
`60` are launch settings, not token transfer fees. None of these addresses or
economics are embedded in the token. The launch system prepares its own manifest,
derives the opening price, deploys, and performs the distribution and pool setup.
This repository contains no launch manifest or transaction-broadcast script.

## ERC-20 behavior

- `transfer`, `approve`, and `transferFrom` return `true` on success and revert
  with standard ERC-6093 errors on invalid calls.
- Transfers deliver exactly the requested base units and emit `Transfer`.
  Zero-value transfers between nonzero addresses are supported, including from
  an account with no balance. Transfers to the zero address revert.
- `approve` replaces the caller's allowance and emits `Approval`. Zero revokes
  an allowance. The zero address cannot be approved as a spender.
- `transferFrom` requires the caller's allowance even if the caller deployed
  the token. Finite allowances decrease by the amount spent. Maximum `uint256`
  allowance is treated as unlimited and remains unchanged until replaced.
- A failed delegated transfer rolls back both the balance and allowance changes.
  In the vendored implementation, spending an allowance does not emit `Approval`;
  integrations should read `allowance` for the current value.
- Token transfers make no receiver callbacks. Sending tokens to an arbitrary
  contract does not guarantee that contract can return them.

## Build and test

Foundry and the pinned Solidity compiler must be installed. All Solidity library
sources and their licenses are vendored as ordinary files under `lib/`; building
requires no package downloads, submodules, RPC, credentials, or environment values.
The fuzz seed below is only a runner option; the tests never read or change the
environment.

```sh
forge build
FOUNDRY_FUZZ_SEED=0x1731d44f696f6f40c43fc27fc184757468f27614a3f8959317e1e6a823bca4af forge test
forge fmt --check
```

The default profile runs each fuzz test 1,000 times and each stateful invariant
256 times with depth 64, failing on unexpected handler reverts. Tests cover
metadata, mint events, CREATE2 factory deployment, exact launch-side transfers,
transfer and approval events, zero/full/self transfers, allowance replacement and
revocation, infinite approvals, insufficient balances and allowances, atomic
failure, unauthorized access, rejected admin selectors, native-ETH rejection,
and forbidden runtime opcodes. Stateful tests compare balances and allowances
to an independent ledger across randomized successful and failed operations.

The local launch test checks token movement through factory, distributor, pool,
and holder roles. It is not a Uniswap swap simulation. The provided protected
tests require the network's separate launch harness, manifest, and v4 contracts;
that integration check belongs to the independent verifier. Local tests are
self-contained and do not import the temporary `.imd/reads` inputs.

## After launch

No setters, external services, owner addresses, or post-deployment configuration
are required by the token. No one needs to operate a keeper or administrator.

The launch operator is responsible for deploying the compiled creation bytecode
through the intended factory, verifying the deployed source, confirming the
metadata and exact initial supply, and completing the prescribed distribution
and pool setup. The initial supply belongs entirely to the immediate deployer,
so deploying directly to a wallet instead would give that wallet the whole supply.

Holders are responsible for recipient correctness and spender approvals. Prefer
bounded approvals; an approved spender can transfer the allowed amount. ERC-20
allowance replacement has the usual transaction-ordering risk: when changing an
existing approval, revoke it and confirm the revocation before granting a new one.
There is no recovery function for tokens sent to the token contract or another
inaccessible address. Ordinary native-ETH sends revert; forcibly delivered ETH
also has no withdrawal path.

See [SECURITY.md](SECURITY.md) for the review scope and validation limitations,
and [DEPENDENCIES.md](DEPENDENCIES.md) for dependency versions and licenses.
