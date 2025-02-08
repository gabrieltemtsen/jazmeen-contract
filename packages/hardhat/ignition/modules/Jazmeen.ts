import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const JazmeenModule = buildModule("JazmeenModule", (m) => {
  // Get deployer address and any other required parameters

  // Deploy the JazmeenFactory contract with the deployer address
  const jazmeenFactory = m.contract("JazmeenFactory", ['0x285d8f6515FD2cF5F27EeC808E2B5b52F2A5D7c0']);

  return { jazmeenFactory };
});

const deployedContract = '0x3578D4b80852bA28023E6d18B93aD22763c3322A'

export default JazmeenModule;
