// SPDX-License-Identifier: MIT
// author: c7a9d8c6c987784967375ae97a35d30ab617eb48@hotmail.com 

 

pragma solidity ^0.8.0;

import "./IDividendToken.sol";

interface IDividendTokenEx is IDividendToken {

    // 总的分红金额
    function totalDividend() external view returns(uint256);

    // 每股累加分红金额
    function totalDividendPerShare() external view returns(uint256);

}