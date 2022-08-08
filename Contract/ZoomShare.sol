// SPDX-License-Identifier: BUSL-1.1
// author: c7a9d8c6c987784967375ae97a35d30ab617eb48@hotmail.com 


pragma solidity ^0.8.0;


import "./Administrator.sol";


// 缩放持有量  ， 例如 股票中的一股拆分为 10 股， 或者 100 股再送3股。 如果继承 ECR20 合约，需要重写较多代码(和分红Token有点不一样，banlanceOf 要重写)，暂时不处理。
// 也有其他一些方式实现类似的功能，例如换一个Token，按照比列兑换。但缩放操作很频繁的话，换Token这种方式很费劲。
// token支持多位小数位，在某种情况下让扩股或缩股变得没有那么强的吸引力了。
contract ZoomShare is  Administrator {
  
    // address public Admin;

    // modifier onlyAdmin {
    //     require(msg.sender == Admin);
    //     _;
    // }

    uint public constant BaseZoom = 1e18;
    uint public CurrentZoom = 1e18;
  
    constructor(address admin_, address superAdmin_)  
    {
         Admin = admin_;
        SuperAdmin = superAdmin_;
    }

    event ZoomUpdated(address _admin, uint256 _zoom);

    function updateZoom(uint256 value_) onlyAdmin external {        //这里直接设置值。设置为上一次的倍数更直观一点，但处理会麻烦点。
        CurrentZoom = value_;
        emit ZoomUpdated(msg.sender, value_);
    }

    // 用户的股份，需要记录对应zoom的值 通过这两个值计算当前的股份数量(getCurrentShare)。
    mapping (address => uint256) public ownerZoomOf;        // user => zoom                  用户在某个时刻点的股份放大倍数
    mapping (address => uint256) public ownerShareOf;       // user => Share(TokenAmount)    用户在某个时刻点的股份数量

    function updateOwnerZoom(address _owner)  private {
        if (ownerZoomOf[_owner] == 0 || ownerShareOf[_owner] == 0) {
            ownerZoomOf[_owner] = CurrentZoom;
        }
        else {
            // uint256 Zoom1Amount = ownerShareOf[_owner];
            // uint256 Zoom2Amount = ownerShareOf[_owner] * CurrentZoom / ownerZoomOf[_owner];
            ownerShareOf[_owner] = ownerShareOf[_owner] * CurrentZoom / ownerZoomOf[_owner];
            ownerZoomOf[_owner] = ownerZoomOf[_owner] ;
        }
    } 

    function getCurrentShare(address _owner) public view returns (uint) {
        return ownerShareOf[_owner] * CurrentZoom / ownerZoomOf[_owner];
    }

  

}