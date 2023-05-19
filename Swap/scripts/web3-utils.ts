import assert from 'assert';
import { ContractReceipt, Signer } from 'ethers';
import { getContractAddress } from 'ethers/lib/utils';
import fs from 'fs';

const DEPLOYMENTS_DIR = `../deployments`;

export function save(name: string, contract: any, network: string) {
  if (!fs.existsSync(`${DEPLOYMENTS_DIR}/${network}`)) {
    fs.mkdirSync(`${DEPLOYMENTS_DIR}/${network}`, { recursive: true });
  }
  fs.writeFileSync(
    `${DEPLOYMENTS_DIR}/${network}/${name}.json`,
    JSON.stringify(
      {
        address: contract.address,
      },
      null,
      4,
    ),
  );
}

export function load(name: string, network: string) {
  const { address } = JSON.parse(
    fs.readFileSync(`${DEPLOYMENTS_DIR}/${network}/${name}.json`).toString(),
  );
  return address;
}

export function asDec(address: string): string {
  return BigInt(address).toString();
}

export async function deploy(
  hre: any,
  name: string,
  calldata: any = [],
  options: any = {},
  saveName = '',
) {
  console.log(`Deploying: ${name}...`);
  const contractFactory = await hre.ethers.getContractFactory(name, options);
  const contract = await contractFactory.deploy(...calldata);
  save(saveName || name, contract, hre.network.name);

  console.log(`Deployed: ${name} to: ${contract.address}`);
  await contract.deployed();
  return contract;
}

export async function waitForTx(tx: Promise<any>): Promise<ContractReceipt> {
  const resolvedTx = await tx;
  return await resolvedTx.wait();
}
