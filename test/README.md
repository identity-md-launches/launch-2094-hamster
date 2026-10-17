# HAMSTER tests

The existing deployment, ERC-20, launch-transfer, and forbidden-entry-point tests
remain in `HamsterToken.t.sol`. `HamsterToken.properties.t.sol` adds:

- One-wei and full-supply delegated transfers, including an exhausted approval
  that must stay exhausted after the owner receives tokens again.
- The distinction between the largest finite allowance and infinite allowance.
- Self-approval requirements for an owner calling `transferFrom`.
- Transfer round trips between funded holders, with approvals unchanged.
- Equivalence of split and single delegated transfers.
- Replacement and revocation of infinite approvals.
- Failure followed by successful retry after funding an empty holder.
- Overdraw rejection even for an unlimited delegated self-transfer.
- Zero-value delegated transfers with arbitrary existing approvals.

The six new fuzz properties each run 1,000 cases. Inputs use `bound`, including
the full `uint256` allowance range; the tests use actual token transfers to fund
holders rather than modifying token storage.

## Stateful properties

`HamsterToken.invariant.t.sol` runs 256 sequences of 64 handler calls with four
holders. Only the ten specified handler selectors are targeted. The independent
balance and allowance ledgers are checked after every handler action:

- Supply remains exactly `1_000_000_000 * 10**18`.
- All four balances match the ledger and together equal the entire supply.
- Every owner/spender allowance matches the ledger, including self-approvals,
  revocation, and infinite approvals. Zero-address allowances remain zero.

Actions mix transfers and approvals with overdraws, excessive delegated spends,
revocations, and invalid recipients/spenders. Successful preparatory approvals
update the ledger; rejected transfers must leave it unchanged. Expected failures
assert the precise ERC-20 error, and unexpected handler reverts fail the suite.
`approveAndSpend` always chooses a funded holder and moves a positive amount, so
delegated-success coverage does not depend on randomly finding an approved pair.

## Run

No additional dependencies or configuration changes are required. Build outputs
can be kept in the disposable scratch directory:

```sh
export FOUNDRY_OUT=test/scratch/out
export FOUNDRY_CACHE_PATH=test/scratch/cache
export FOUNDRY_FUZZ_SEED=0x1731d44f696f6f40c43fc27fc184757468f27614a3f8959317e1e6a823bca4af
forge build --offline
forge test --offline
```

The local suite exercises token behavior. Actual pool initialization and swaps
belong to the separately supplied protected launch harness; no pool contracts or
network forks are introduced here.
