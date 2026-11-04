import hardhatToolboxViemPlugin from "@nomicfoundation/hardhat-toolbox-viem";
import { configVariable, defineConfig } from "hardhat/config";

export default defineConfig({
  plugins: [hardhatToolboxViemPlugin],
  solidity: {
    profiles: {
      default: {
        version: "0.8.28",
        settings: { optimizer: { enabled: true, runs: 200 }, evmVersion: "cancun" },
      },
    },
  },
  test: {
    solidity: {
      fuzz: { runs: 1000 },
      invariant: { runs: 128, depth: 64, failOnRevert: false },
    },
  },
  // Lets the local fork execute Base Sepolia blocks. Isthmus is the newest OP fork this EDR supports.
  chainDescriptors: {
    84532: {
      name: "Base Sepolia",
      chainType: "op",
      hardforkHistory: { isthmus: { timestamp: 1744905600 } },
      blockExplorers: { etherscan: { name: "BaseScan", url: "https://sepolia.basescan.org", apiUrl: "https://api.etherscan.io/v2/api" } },
    },
  },
  networks: {
    // Local fork of live Base Sepolia for dry-run deployments (no keys or funds needed).
    baseSepoliaFork: {
      type: "edr-simulated",
      chainType: "op",
      chainId: 84532,
      forking: { url: "https://sepolia.base.org" },
    },
    baseSepolia: {
      type: "http",
      chainType: "op",
      chainId: 84532,
      url: configVariable("BASE_SEPOLIA_RPC_URL"),
      accounts: [configVariable("BASE_SEPOLIA_PRIVATE_KEY")],
    },
  },
  verify: {
    etherscan: { apiKey: configVariable("ETHERSCAN_API_KEY") },
  },
});
