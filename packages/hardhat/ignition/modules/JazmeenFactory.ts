import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("JazmeenFactoryModule", (m) => {
  // Get deployer account (bot address)
  const jazmeenDeployer = m.getAccount(0);

  // Deploy JazmeenFactory with jazmeenDeployer as parameter
  const jazmeenFactory = m.contract("JazmeenFactory", [jazmeenDeployer]);

  return { jazmeenFactory };
});
//0x4761e95CA30Ec9BB9271260843a7Cb39BB507133