// SPDX-License-Identifier: BUSL-1.1
// author: c7a9d8c6c987784967375ae97a35d30ab617eb48@hotmail.com 

pragma solidity ^0.8.0;

import "./openzeppelin/ERC20.sol";


// 用于测试的资产Token
contract MyAssetToken is ERC20 {

    function decimals() public pure override returns (uint8) {
        return 6;                                             
    }


    constructor() ERC20 ("Usdt", "Usdt") 
    {
        //emit IconImage(iconFileName_, iconData_);
        _mint(tx.origin, 1_000_000_000_000 * (10 ** decimals()));  //
    }


    function mint() external {
        _mint(msg.sender, 1 * (10 ** decimals()));  //
    }

}