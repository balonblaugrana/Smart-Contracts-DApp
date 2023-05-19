import { task } from 'hardhat/config';

import { Contract } from 'ethers';
import { deploy } from './web3-utils';

export async function deployFull(
  hre: any,
  exchangeName: string,
): Promise<{
  exchange: Contract;
}> {
  const aristodogs = await deploy(hre, 'MockERC721');
  const dogHouses = await deploy(hre, 'MockERC721');
  const biscouitToken = await deploy(hre, 'MockERC20');

  const exchangeImpl = await deploy(
    hre,
    exchangeName,
    [],
    'AristoswapImpl',
  );
  const initializeInterface = new hre.ethers.utils.Interface([
    'function initialize(address[2], address, address)',
  ]);
  const initialize = initializeInterface.encodeFunctionData('initialize', [
    [dogHouses.address, aristodogs.address], 
    "0x0000000000000000000000000000000000000000",
    biscouitToken.address
  ]);
  const exchangeProxy = await deploy(
    hre,
    'ERC1967Proxy',
    [exchangeImpl.address, initialize],
    {},
    'Aristoswap',
  );

  const exchange = new hre.ethers.Contract(
    exchangeProxy.address,
    exchangeImpl.interface,
    exchangeImpl.signer,
  );

  return { exchange };
}