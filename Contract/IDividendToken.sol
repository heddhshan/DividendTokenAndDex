// SPDX-License-Identifier: MIT
// author: he.d.d.shan@hotmail.com 

// 来自 https://github.com/ethereum/EIPs/issues/1726 ，有小改动，就不用标记出来了。

pragma solidity ^0.8.0;

import "./openzeppelin/ERC20.sol";
import "./openzeppelin/IERC20Metadata.sol";

// 细节之一：本接口的风格和ERC20有点不一样
/// @title Dividend-Paying Token Interface
/// @author Roger Wu (https://github.com/roger-wu)
/// @dev An interface for a dividend-paying token contract.
interface IDividendToken {
// interface IDividendToken is IERC20, IERC20Metadata {            

    // 资产Token，必须是ERC20Token
    function asset() external view returns (address);

    // 待领取分红金额 也类似于 previewWithdraw withdrawableDividendOf 等，
    /// @notice View the amount of dividend in wei that an address can withdraw.
    /// @param _owner The address of a token holder.
    /// @return The amount of dividend in wei that `_owner` can withdraw. 
    function dividendOf(address _owner) external view returns(uint256);

    // 发放分红
    // @notice Distributes ether to token holders as dividends.
    // @dev SHOULD distribute the paid ether to token holders as dividends.
    //  SHOULD NOT directly transfer ether to token holders in this function.
    //  MUST emit a `DividendsDistributed` event when the amount of distributed ether is greater than 0.
    function distributeDividends(uint _amount) external payable;

    //最新的分红高度
    function currentDividendHeight() external view returns (uint);              

    //用户领取分红后的分红高度 , 和 最新 高度比较，可以知道分红是否领取完成 更简单做法判断dividendOf(address _owner)是否为0 但是这个不准确，某些条件下不严谨
    function withdrawDividendHeight(address _owner) external view returns (uint);    

    // 领取分红，一次性全部领完 只能自己执行
    /// @notice Withdraws the ether distributed to the sender.
    /// @dev SHOULD transfer `dividendOf(msg.sender)` wei to `msg.sender`, and `dividendOf(msg.sender)` SHOULD be 0 after the transfer.
    ///  MUST emit a `DividendWithdrawn` event if the amount of ether transferred is greater than 0.
    function withdrawDividend() external returns (uint256 _height, uint256 _amount);

    // 授权别人能够帮你执行分红的提现 
    function approvalWithdraw(address _spender, bool _isWithdrawable) external ;

    function allowanceWithdraw(address owner, address spender) external view returns (bool);

    // 第三方执行分红，只能分给 owner               可以放到 IDividendTokenEx ？
    function withdrawDividendTo(address _owner) external returns (uint256 _height, uint256 _amount);
    // 授权第三方， key 转账 和 帮忙领取 分红       可以放到 IDividendTokenEx ？
    function approvalAll(address _spender, uint256 _amount, bool _isWithdrawable) external;

    // 发放分红事件
    // @dev This event MUST emit when ether is distributed to token holders.
    // @param from The address which sends ether to this contract.
    // @param weiAmount The amount of distributed ether in wei.
    event DividendsDistributed(
        address indexed from,
        uint256 inAssets,                          // 打入的所有资金
        uint256 dividendAssets,                    // 分红的所有资金, 这两个金额不一定一样
        uint256 currentTokenAmount                 // 当前的分红Token数量,每次分红这个数量不一定相同 currentBalance 这个名称可能更好?
    );

    // 领取分红事件
    // @dev This event MUST emit when an address withdraws their dividend.
    // @param to The address which withdraws ether from this contract.
    // @param weiAmount The amount of withdrawn ether in wei.
    event DividendWithdrawn(
        address indexed to,
        uint256 assets
    );

    event WithdrawApproval(address indexed owner, address indexed spender, bool isWithdrawable);


}
