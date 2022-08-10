// SPDX-License-Identifier: BUSL-1.1
// author: c7a9d8c6c987784967375ae97a35d30ab617eb48@hotmail.com 


// 尽量参照 https://github.com/ethereum/EIPs/issues/1726 

pragma solidity ^0.8.0;

import "./openzeppelin/Address.sol";
import "./openzeppelin/SafeERC20.sol";
import "./openzeppelin/ERC20.sol";
import "./IDividendToken.sol";
import "./IDividendTokenEx.sol";

// 分红Token 做两个版本，无误差版本 和 有误差版本。 下面是无误差版本 。    
// 真实的股票分红是不存在误差的，因为美元、欧元、人民币都只有两位小数；相对应的，只要资产Token的小数位比分红Token的小数位大两位以上就做到了无误差分红。
contract DividendToken0 is ERC20, IDividendToken, IDividendTokenEx {
    using SafeERC20 for IERC20;
    // using Address for address;

    function decimals() public view virtual override  returns (uint8) {
        return 6;                                               //位数要小一点，最好比资产Token的位数少6位以上。
    }

    // function decimals() public view virtual override(ERC20, IERC20Metadata) returns (uint8) {
    //     return 6;                                               //位数要小一点，最好比资产Token的位数少6位以上。
    // }

    constructor(string memory name_, string memory symbol_, address assetToken_) ERC20 (name_, symbol_) 
    {
        _assetToken = assetToken_;
        
        // // 如果资产Token的小数位比分红Token小数位大6位，意味着一个最小单位的分红Token对应着10**6个最小单位的资产Token。这也是 magnitude 可以存在的一个原因。
        // uint8 d1 = decimals();
        // uint8 d2 = IERC20Metadata(_assetToken).decimals();
        // require(d1 + 6 <= d2, "require d1 + 6 <= d2");    

        // _mint(msg.sender, 1000 * 10**decimals());           //挖矿，测试   真实的环境是有其他条件的。 
    }

    address public  constant ETH = address(0);              // 使用 0x0 代表 ETH Token。 

    uint256 public _currentDividendPerShare = 0;           // 实际的每股累加分红 ,  当前每股分红高度
    uint256 public _totalDividend = 0;                     // 总计的分红金额，加上 等待分红的金额 waittingDividend ，等于打入的所有金额。
    address private _assetToken;                            // 资产Token， 分给 DividendToken 持有者
    uint256 public waittingDividend = 0;                    // 等待分红的金额， 没有分下去的金额, 未分红金额。当 magnitude = 1 的时候可以使用;或者DividendToken数量为0时候需要；否则不需要。

    mapping (address => uint) public _ownerLastDivPerShareOf;      //用户的上次资金变动时候的每股（累加）利息(ETH)  user => amount 。
    mapping (address => uint) public _ownerAssetOf;                //用户的未领取的资产  user => amount

    // 计算 owner 拥有的分红金额
    function _getOwerWaitingDiv(address _owner) private view returns (uint assetAmount) {
        assetAmount = balanceOf(_owner) *  (_currentDividendPerShare - _ownerLastDivPerShareOf[_owner]) + _ownerAssetOf[_owner];        //两部分相加
    }  
    
    // 更新用户的资产，同时变更刻度，DividendToken 数量发生变化的地方要用：转账（token数量发生变化），等。
    function updateOwnerAsset(address _owner) private {
        if (_ownerLastDivPerShareOf[_owner] == 0) {
            _ownerLastDivPerShareOf[_owner] = _currentDividendPerShare;
        }
        else {
            _ownerAssetOf[_owner] = _ownerAssetOf[_owner] + _getOwerWaitingDiv(_owner);     //把历史分红金额加进去
            _ownerLastDivPerShareOf[_owner] = _currentDividendPerShare;                     //更新用户的分红刻度
        }
    }

    // 计算并执行分红， 更新 Share 等
    function ExeDividend(uint _inAmount) private {
        uint TokenAmount = totalSupply();
        // TokenAmount == 0 是可能出现的。
        if (TokenAmount > 0 && _inAmount > 0) {                     
            uint amount = waittingDividend + _inAmount;
            uint share = amount / TokenAmount;              // 得到每股分红金额
            uint realamount = share * TokenAmount;          // 真正分下去的金额
            waittingDividend = amount - realamount;         // 更新等待分红的金额
            if (share > 0) {
                _currentDividendPerShare = _currentDividendPerShare + share;        //更新分红高度
                _totalDividend = _totalDividend + realamount;                       //更新分红总金额，其实这个值可以不要，但是有了很方便！
                emit DividendsDistributed(msg.sender, _inAmount, realamount, TokenAmount);
            }
            else
            {
                emit DividendsDistributed(msg.sender, _inAmount, 0, TokenAmount);
            }
        }
        else {
            waittingDividend = waittingDividend + _inAmount;         //留在这里  没有产生分红token的时候
            emit DividendsDistributed(msg.sender, _inAmount, 0, TokenAmount);
        }
    } 

    // ETH 分红的特殊处理
    receive() external payable {
        if (msg.value > 0 ){
            if (_assetToken == ETH) {
                ExeDividend(msg.value);
                return;
            }
            else{
                // Address.sendValue(payable(0xB895B6Bc083E32AD11BCE9127F4561D7c19983F3), msg.value);
                require(1==2, "value");
                return;
            }
        }
    } 

  
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    function _beforeTokenTransfer(address from, address to, uint256 amount ) internal override {
        updateOwnerAsset(from);
        updateOwnerAsset(to);
        amount;
    }

    // function _afterTokenTransfer(address from, address to, uint256 amount ) internal override {
    // }


/////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    // 资产Token，必须是ERC20Token 或者 ETH 
    function asset() external view override returns (address) {
        return _assetToken;
    }

    // 待领取分红金额 也类似于 previewWithdraw withdrawableDividendOf 等，
    function dividendOf(address _owner) override external view returns(uint256) {
        return _getOwerWaitingDiv(_owner);
    }

    // 发放分红 处理 ETH 和 ERC20Token 
    function distributeDividends(uint _amount) override external payable {
        if (_assetToken == ETH)
        {
            // require(msg.value == _amount, "msg.value == _amount");
            ExeDividend(msg.value);
        }
        else
        {
            IERC20(_assetToken).safeTransferFrom(msg.sender, address(this), _amount);               // 要先 approve 
            ExeDividend(_amount);
        }
    }

    //最新的分红高度 不一定采用_currentDividendPerShare 做一个递增计数器也可以的 但会增加变量
    function currentDividendHeight() override external view returns (uint) {
        return _currentDividendPerShare;
    }           

    //用户领取分红后的分红高度 , 和 最新 高度比较，可以知道分红是否领取完成 更简单做法判断dividendOf(address _owner)是否为0 但是这个不准确，某些条件下不严谨
    function withdrawDividendHeight(address _owner) override external view returns (uint256 _height) {
        return  _ownerLastDivPerShareOf[_owner];
    }

    // 领取分红，一次性全部领完
    function withdrawDividend() override external returns (uint256 _height, uint256 _amount) {
        return _withdrawDividend(msg.sender);
    }
  
    function _withdrawDividend(address _owner) private returns (uint256 _height, uint256 _amount) {
        uint toOwner = _getOwerWaitingDiv(_owner);                  // 计算要提取的金额
        // if (toOwner == 0) return  _ownerLastDivPerShareOf[_owner];
        _ownerAssetOf[_owner] = 0;                                  // 更新未领取金额为0    这两行代码和 updateOwnerAsset(msg.sender); 有点像, 逻辑类似。
        _ownerLastDivPerShareOf[_owner] = _currentDividendPerShare; // 更新用户的分红高度

        emit DividendWithdrawn(_owner, toOwner);

        if (_assetToken == ETH)
        {
            Address.sendValue(payable(_owner), toOwner);
        }
        else
        {
            IERC20(_assetToken).safeTransfer(_owner,  toOwner);                
        }

        return (_ownerLastDivPerShareOf[_owner], toOwner);
    }

    mapping (address => mapping(address => bool)) public _allowanceWithdrawOf;          // owner => spender => bool 

    function allowanceWithdraw(address owner, address spender) override external view returns (bool)
    {
        return _allowanceWithdrawOf[owner][spender];
    }

    function approvalWithdraw(address _spender, bool _isWithdrawable) override external {
        _approvalWithdraw(_spender, _isWithdrawable);    
    }

    function _approvalWithdraw(address _spender, bool _isWithdrawable) private {
        _allowanceWithdrawOf[msg.sender][_spender] = _isWithdrawable;
        emit WithdrawApproval(msg.sender, _spender, _isWithdrawable);
    }    

    // 第三者帮忙执行分红
    function withdrawDividendTo(address _owner) override external returns (uint256 _height, uint256 _amount) {
        require(_allowanceWithdrawOf[_owner][msg.sender], "AW");
        return _withdrawDividend(_owner);
    }

    function approvalAll(address _spender, uint256 _amount, bool _isWithdrawable) override external {
        _approve(msg.sender, _spender, _amount);
        _approvalWithdraw(_spender, _isWithdrawable);  
    }



/////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    // 总的分红金额
    function totalDividend() override external view returns(uint256) {
        return _totalDividend;
    }

    // 每股累加分红金额
    function totalDividendPerShare() override external view returns(uint256) {
        return _currentDividendPerShare;
    }



}