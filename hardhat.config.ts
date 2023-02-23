import { HardhatUserConfig } from "hardhat/config";
import "@nomiclabs/hardhat-ethers";

import "@nomicfoundation/hardhat-toolbox";

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.17",
    settings: {
      optimizer: {
        
        
        enabled: true,
        runs: 500,
        
        
        
      }
    }
  }
};

export default config;
