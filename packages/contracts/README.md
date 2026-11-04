# @applove/contracts

SIMULATION. Base Sepolia (chain 84532) with test tokens only. Do not deploy to mainnet.

## Commands (run from this folder)
| Command | What it does |
|---|---|
| `npx hardhat build` | Compile |
| `npx hardhat test` | All tests: Solidity unit, fuzz and invariant tests, plus TypeScript deployment tests |
| `npx hardhat test solidity --coverage` | Solidity tests with coverage report (`coverage/html`) |
| `echo y \| npx hardhat ignition deploy ignition/modules/AppLove.ts --network baseSepoliaFork` | Dry-run deploy on a local fork of live Base Sepolia (no key needed) |
| `npx hardhat ignition deploy ignition/modules/AppLove.ts --network baseSepolia --verify` | Real testnet deploy + BaseScan verification |

## Real deployment needs three values
Set as environment variables (or `npx hardhat keystore set <NAME>`):
- `BASE_SEPOLIA_RPC_URL`: e.g. `https://sepolia.base.org`
- `BASE_SEPOLIA_PRIVATE_KEY`: a throwaway deployer key funded with Base Sepolia ETH from a faucet
- `ETHERSCAN_API_KEY`: Etherscan v2 key, used for BaseScan verification

Optional parameters (oracle signer and reporter addresses, windows) go in an Ignition parameters file.

## Contracts
See `docs/SMART_CONTRACTS.md` for how they fit together and `docs/AUDIT.md` for the security review.
