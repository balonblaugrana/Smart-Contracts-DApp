// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "src/AristoswapTestnet.sol";
import "src/mock/MockERC20.sol";
import "src/mock/MockERC721.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployTestnetScript is Script {
    address internal dao = 0xe06e6dF9A66a2a631Ea5e8FD587A59e13CC36750;

    function run() public {
        uint256 deployerKey = vm.envUint("DEPLOYER_KEY");
        vm.startBroadcast(deployerKey);

        MockERC20 biscouitToken = new MockERC20();
        MockERC20 wcro = new MockERC20();

        MockERC721 aristodogs = new MockERC721();
        MockERC721 dogHouses = new MockERC721();

        AristoswapTestnet implementation = new AristoswapTestnet();
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), "");
        AristoswapTestnet swap = AristoswapTestnet(address(proxy));
        swap.initialize([address(aristodogs), address(dogHouses)], dao, address(biscouitToken), address(wcro));
        vm.stopPrank();
    }
}
