// SPDX-License-Identifier: BUSL-1.1
// author: c7a9d8c6c987784967375ae97a35d30ab617eb48@hotmail.com 


// OpenZeppelin Contracts (last updated v4.7.0) (token/ERC20/ERC20.sol)

// 尽量参照 https://github.com/ethereum/EIPs/issues/1726 

pragma solidity ^0.8.0;

import "./openzeppelin/Address.sol";
import "./openzeppelin/SafeERC20.sol";
import "./openzeppelin/ERC20.sol";
import "./IDividendToken.sol";
import "./IDividendTokenEx.sol";

// 分红Token 做两个版本，无误差版本 和 有误差版本。 下面是有误差版本 。
contract DividendToken1 is ERC20, IDividendToken, IDividendTokenEx {
    using SafeERC20 for IERC20;
    // using Address for address;

    function decimals() public view virtual override returns (uint8) {
        return 6;                                  
    }

  
    constructor(string memory name_, string memory symbol_, address assetToken_, uint256 magnitude_) ERC20 (name_, symbol_) 
    {
        _assetToken = assetToken_;
        require(0 < magnitude_, "m");
        magnitude = magnitude_;
    }

    address public  constant ETH = address(0);         
    uint256 private _currentMDividendPerShare = 0;     
    uint256 private _totalDividend = 0;                
    address private _assetToken;                       

    uint256 public magnitude = 10**12;                 
    uint256 public waittingDividend = 0;               
    mapping (address => uint) private _ownerLastMDivPerShareOf;
    mapping (address => uint) private _ownerAssetOf;           

    function _getOwerWaitingDiv(address _owner) private view returns (uint assetAmount) {
        assetAmount = balanceOf(_owner) *  (_currentMDividendPerShare - _ownerLastMDivPerShareOf[_owner])  / magnitude + _ownerAssetOf[_owner];   
    }  
    
    function updateOwnerAsset(address _owner) private {
        if (_ownerLastMDivPerShareOf[_owner] == 0) {
            _ownerLastMDivPerShareOf[_owner] = _currentMDividendPerShare;
        }
        else {
            _ownerAssetOf[_owner] = _ownerAssetOf[_owner] + _getOwerWaitingDiv(_owner);      
            _ownerLastMDivPerShareOf[_owner] = _currentMDividendPerShare;                    
        }
    }

    function ExeDividend(uint _inAmount) private {
        uint TokenAmount = totalSupply();
        // TokenAmount == 0 是可能出现的。
        if (TokenAmount > 0 && _inAmount > 0) {                     
            uint amount = waittingDividend + _inAmount;
            uint share = amount  * magnitude / TokenAmount;    
            waittingDividend = 0;                              
            // if (share > 0) {
                _currentMDividendPerShare = _currentMDividendPerShare + share;          
                _totalDividend = _totalDividend + amount;                               
                emit DividendsDistributed(msg.sender, _inAmount, amount, TokenAmount);
            // }
            // else
            // {
            //     emit DividendsDistributed(msg.sender, _inAmount, 0, TokenAmount);
            // }
        }
        else {
            waittingDividend = waittingDividend + _inAmount;         
            emit DividendsDistributed(msg.sender, _inAmount, 0, TokenAmount);
        }
    } 

    receive() external payable {
        if (msg.value > 0 ){
            if (_assetToken == ETH) {
                ExeDividend(msg.value);
                return;
            }
            else{
                // Address.sendValue(payable(0xAc3b11304aE4b222d4836B3074d267BbA464F006), msg.value);
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

    function asset() external view override returns (address) {
        return _assetToken;
    }

    function dividendOf(address _owner) override external view returns(uint256) {
        return _getOwerWaitingDiv(_owner);
    }

    function distributeDividends(uint _amount) override external payable {
        if (_assetToken == ETH)
        {
            ExeDividend(msg.value);
        }
        else
        {
            IERC20(_assetToken).safeTransferFrom(msg.sender, address(this), _amount);               // 要先 approve 
            ExeDividend(_amount);
        }
    }

    function currentDividendHeight() override external view returns (uint) {
        return _currentMDividendPerShare;
    }           

    function withdrawDividendHeight(address _owner) override external view returns (uint) {
        return _ownerLastMDivPerShareOf[_owner];
    }

    function withdrawDividend() override external returns (uint256 _height, uint256 _amount) {
        return  _withdrawDividend(msg.sender);
    }

    function _withdrawDividend(address _owner) private returns (uint256 _height, uint256 _amount) {
        uint toOwner = _getOwerWaitingDiv(_owner);      
        _ownerAssetOf[_owner] = 0;                      
        _ownerLastMDivPerShareOf[_owner] = _currentMDividendPerShare;

        emit DividendWithdrawn(_owner, toOwner);

        if (_assetToken == ETH)
        {
            Address.sendValue(payable(_owner), toOwner);
        }
        else
        {
            IERC20(_assetToken).safeTransfer(_owner,  toOwner);                
        }
        return (_ownerLastMDivPerShareOf[_owner], toOwner);
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

    function totalDividend() override external view returns(uint256) {
        return _totalDividend;
    }

    function totalDividendPerShare() override external view returns(uint256) {
        return _currentMDividendPerShare / magnitude;
    }



}