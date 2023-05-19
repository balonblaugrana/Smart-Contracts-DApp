import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@nomicfoundation/hardhat-chai-matchers";
import "@openzeppelin/hardhat-upgrades";
import { config as dotenvConfig } from 'dotenv';

dotenvConfig();

const config: HardhatUserConfig = {
  solidity: "0.8.18",
  paths: {
    artifacts: "./out",
    sources: "./src",
    cache: "./cache_hardhat",
    tests: "./test",
  },
};

export default config;
