# Vendored dependencies

All dependencies are ordinary repository files. No install command, submodule,
package manager, or network connection is needed to build with the pinned compiler.

| Dependency | Pinned release | Included files | License |
| --- | --- | --- | --- |
| [OpenZeppelin Contracts](https://github.com/OpenZeppelin/openzeppelin-contracts/tree/v5.0.2) | `v5.0.2` | `ERC20.sol`, `IERC20.sol`, `IERC20Metadata.sol`, `Context.sol`, `draft-IERC6093.sol` | MIT, `lib/openzeppelin-contracts/LICENSE` |
| [Forge Standard Library](https://github.com/foundry-rs/forge-std/tree/v1.9.7) | `v1.9.7` | Upstream `src/` tree (tests only) | MIT or Apache-2.0, both license files in `lib/forge-std/` |

Sources are copied unchanged from the tagged upstream releases. The SHA-256 of
each vendored source and license is recorded in `DEPENDENCIES.sha256`. Check with:

```sh
sha256sum --check DEPENDENCIES.sha256
```

Only the OpenZeppelin ERC-20 dependency closure is part of the production build.
Forge Standard Library is used exclusively by tests. The project itself is MIT
licensed; upstream notices and licenses remain with their sources.
