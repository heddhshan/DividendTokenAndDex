// SPDX-License-Identifier: BUSL-1.1
// author: c7a9d8c6c987784967375ae97a35d30ab617eb48@hotmail.com 


// 分红Token的交易所，分两部分：交易对 ， 交易对的类工厂 。

pragma solidity ^0.8.0;

import "./openzeppelin/Math.sol";
import "./openzeppelin/Address.sol";
import "./openzeppelin/SafeERC20.sol";
import "./openzeppelin/ERC20.sol";
import "./IDividendToken.sol";
import "./IDividendTokenEx.sol";

interface IDividendTokenExchangePair {
    
    function dividendToken() external view returns (address);

    function assetToken() external view returns (address);

    function paused() external view returns (bool); 
}


contract Pausable {
    bool internal isPaused = false;

    modifier whenNotPaused() {
        require(!isPaused, "P");
        _;
    }

    function doPause() internal  {    
        isPaused = true;
    }
 }


contract DivExPair is Pausable, IDividendTokenExchangePair {
    using SafeERC20 for IERC20;
    // using Address for address;

    function paused() external override view  returns (bool) {
        return isPaused;
    }

    address private _dividendToken;
    function dividendToken() external view override returns (address) {
        return _dividendToken;    
    }
    
    address private _assetToken;

    function assetToken() external view override returns (address) {
        return _assetToken;
    }

    constructor(address dividendToken_, uint256 powerM_) 
    {
        _dividendToken = dividendToken_;
        _assetToken = IDividendToken(_dividendToken).asset();         
        
        require(powerM_ <= 32, "M1");                                  
        magnitude = 10 ** powerM_;
    }

    function chckAssetToken() public view returns (bool) {
        require(_assetToken == IDividendToken(_dividendToken).asset(), "T");
        return true;
    }

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////    

    bool private unlocked = true;          
    modifier lock() {
        require(unlocked == true, 'L');
        unlocked = false;
        _;
        unlocked = true;
    }

    uint256 public totalLiqAmount = 0;                     
    mapping(address => uint) public userLiqAmountOf;       

    uint256 public liqAssetTokenAmount = 0;                       

    function realLiqAssetAmount() public view returns(uint256) {                        
        uint WaitingDiv = IDividendToken(_dividendToken).dividendOf(address(this));     
        if (liqAssetTokenAmount < WaitingDiv) {
            return 0;
        }
        else {
            return (liqAssetTokenAmount - WaitingDiv);                                   
        }
    }

    function liqDividendTokenAmount() public view returns (uint256) {      
        return IERC20(_dividendToken).balanceOf(address(this));
    }

    uint public constant  MinValue = 10**3;              

    event LiquidityAdd(address indexed owner, uint amountDiv, uint amountAss, uint liq, uint divTokenHeight);

    function addLiquidity(
        uint _amountDiv,
        uint _amountAssMin,
        uint _amountAssMax,
        uint _deadline
    ) external whenNotPaused lock payable returns (uint amountAss_, uint256 liq_) {         
        require(block.timestamp <= _deadline, "L");
        uint h1 = _UpdateDividend();        
        require(!isPaused, "P1");

        (uint h2,  ) = IDividendToken(_dividendToken).withdrawDividendTo(msg.sender);            
        updateOwnerAsset(msg.sender);                                                     

        uint256 OldDivTokenAmount = IERC20(_dividendToken).balanceOf(address(this));
        _deposit(_dividendToken, _amountDiv);       //1 _deposit

        if (totalLiqAmount == 0) {
            amountAss_ = _amountAssMax;                               
            liq_ =  Math.sqrt(_amountDiv * amountAss_) - MinValue;    
            totalLiqAmount = MinValue;                                
        }
        else {
            amountAss_ = _amountDiv * liqAssetTokenAmount / OldDivTokenAmount;
            require(_amountAssMin <= amountAss_ && amountAss_ <= _amountAssMax, "price limit");
            uint256 liq_1 = _amountDiv * totalLiqAmount / OldDivTokenAmount;
            uint256 liq_2 = amountAss_ * totalLiqAmount / liqAssetTokenAmount;
            liq_ = Math.min(liq_1, liq_2);
        }

        if(_assetToken == ETH) {
            require(amountAss_ <= msg.value, "MV1");
            _deposit(_assetToken, msg.value);         
            _ownerAssetOf[msg.sender] = _ownerAssetOf[msg.sender] + msg.value - amountAss_;   
        }
        else
        {
            require(msg.value == 0, "MV2");
            _deposit(_assetToken, amountAss_);     
        }

        require(0 < liq_, "L");
        require(MinValue < _amountDiv, "D");
        require(MinValue < amountAss_, "A");
        userLiqAmountOf[msg.sender] = userLiqAmountOf[msg.sender] + liq_;    
        totalLiqAmount = totalLiqAmount + liq_;
        liqAssetTokenAmount = liqAssetTokenAmount + amountAss_;

        uint h3 = IDividendToken(_dividendToken).currentDividendHeight();                      
        require(h1 == h2 && h2 == h3, "H");

        emit LiquidityAdd(msg.sender, _amountDiv, amountAss_, liq_, h1);
    }

    function getLiqAmount(address _owner) public view returns (uint256) {
        return userLiqAmountOf[_owner];
    }

    event LiquidityRemove(address indexed owner, uint liq, uint amountDiv, uint amountAss, uint withdrawAss, uint divTokenHeight);

    function removeLiquidity(
        uint _liq,
        uint _amountDivMin,
        uint _amountAssMin,
        uint _deadline
    ) external lock returns (uint amountDiv_, uint amountAss_) {                   
        require(block.timestamp <= _deadline, "L");
        require(0 < _liq && _liq <= userLiqAmountOf[msg.sender], "Q");
        uint h1 = _UpdateDividend();        
        (uint h2, ) = IDividendToken(_dividendToken).withdrawDividendTo(msg.sender);         
        updateOwnerAsset(msg.sender);                                                              
        
        amountDiv_ = _liq * IERC20(_dividendToken).balanceOf(address(this)) / totalLiqAmount;
        amountAss_ = _liq * liqAssetTokenAmount / totalLiqAmount;
        require(_amountDivMin <= amountDiv_, "D");
        require(_amountAssMin <= amountAss_, "A");

        userLiqAmountOf[msg.sender] = userLiqAmountOf[msg.sender]- _liq;        
        totalLiqAmount = totalLiqAmount - _liq;                                 
        _withdraw(_dividendToken, msg.sender, amountDiv_);         
         
        if (!isPaused) {                                                        
            liqAssetTokenAmount = liqAssetTokenAmount - amountAss_;              
        }
        uint OwnerAss = _ownerAssetOf[msg.sender]  + amountAss_;
        _ownerAssetOf[msg.sender] = 0;
        _withdraw(_assetToken, msg.sender, OwnerAss);          

        uint h3 = IDividendToken(_dividendToken).currentDividendHeight();                      
        require(h1 == h2 && h2 == h3, "H");

        emit LiquidityRemove(msg.sender, _liq, amountDiv_, amountAss_, OwnerAss , h1);
    }

    uint constant public Tax1000 = 3;      
    // uint constant public Fee = 0;

    event TokenSwap(address indexed owner, address tokenIn, uint256 amountDiv, uint256 amountAss);

    function swap(
        uint256 _amountDivIn,
        uint256 _amountAssIn,
        uint256 _amountMinDivOut,
        uint256 _amountMinAssOut,
        uint256 _deadline
    ) external payable  whenNotPaused lock returns (address tokenIn_, uint256 amountDiv_, uint256 amountAss_) {
        require(block.timestamp <= _deadline, "L");
        uint h1 = _UpdateDividend();       
        require(!isPaused, "P1");

        (uint h2, ) = IDividendToken(_dividendToken).withdrawDividendTo(msg.sender); 

        require( (0 < _amountDivIn && 0 == _amountAssIn) || (0 == _amountDivIn &&  0 < _amountAssIn), "A");            
        
        uint LiqDiv = IERC20(_dividendToken).balanceOf(address(this));
        uint k = LiqDiv * liqAssetTokenAmount;                                         

        if (0 < _amountDivIn) {
            _deposit(_dividendToken, _amountDivIn);

            amountDiv_ = _amountDivIn;
            tokenIn_ = _dividendToken;
            amountAss_ = (liqAssetTokenAmount - (k / (LiqDiv + _amountDivIn)))  * (1000 - Tax1000) / 1000;

            require(_amountMinAssOut <= amountAss_ && 0 < amountAss_, "M1");            
            
            liqAssetTokenAmount = liqAssetTokenAmount - amountAss_;              
            
            uint OwnerAss = _ownerAssetOf[msg.sender]  + amountAss_;
            _ownerAssetOf[msg.sender] = 0;
            _withdraw(_assetToken, msg.sender, OwnerAss);                 

            emit TokenSwap(msg.sender, tokenIn_, amountDiv_, amountAss_);
        }
        else {
            _deposit(_assetToken, _amountAssIn);   
            if(_assetToken != ETH) {
                require(msg.value == 0, "MV2");
            }

            amountAss_ = _amountAssIn;
            tokenIn_ = _assetToken;
            amountDiv_ = (LiqDiv - (k / (liqAssetTokenAmount + amountAss_)))  * (1000 - Tax1000) / 1000; 
            require(_amountMinDivOut <= amountDiv_ && 0 < amountDiv_, "M2");  

            _withdraw(_dividendToken, msg.sender, amountDiv_);               
            liqAssetTokenAmount = liqAssetTokenAmount + amountAss_;             

            emit TokenSwap(msg.sender, tokenIn_, amountDiv_, amountAss_);
        }

        require(0 < amountDiv_ && 0 < amountAss_, "AO");   

        uint h3 = IDividendToken(_dividendToken).currentDividendHeight();                      
        require(h1 == h2 && h2 == h3, "H");      
    }


    function getSwapAmountOut(
        uint256 _amountDivIn,
        uint256 _amountAssIn
    ) external view returns (address tokenIn_, uint256 amountDiv_, uint256 amountAss_) {
        require( (0 < _amountDivIn && 0 == _amountAssIn) || (0 == _amountDivIn &&  0 < _amountAssIn), "A");               
        
        uint WaitingDiv = IDividendToken(_dividendToken).dividendOf(address(this));     
        require(WaitingDiv + MinValue <= liqAssetTokenAmount, "W");                     
        uint256 RealLiqAssetAmount = liqAssetTokenAmount - WaitingDiv;                  

        uint256 LiqDiv = IERC20(_dividendToken).balanceOf(address(this));              
        uint k = LiqDiv * RealLiqAssetAmount;                                          
        if (0 < _amountDivIn) {
            amountDiv_ = _amountDivIn;
            tokenIn_ = _dividendToken;
            amountAss_ = (RealLiqAssetAmount - (k / (LiqDiv + _amountDivIn)))  * (1000 - Tax1000) / 1000;
        }
        else {
            amountAss_ = _amountAssIn;
            tokenIn_ = _assetToken;
            amountDiv_ = (LiqDiv - (k / (RealLiqAssetAmount + amountAss_)))  * (1000 - Tax1000) / 1000; 
        }

        require(0 < amountDiv_ && 0 < amountAss_, "AO");    
    }

    function _deposit(address _token, uint256 _amount) private   {         
        if (_token == ETH) {
            require(msg.value == _amount, "V");              
        }
        else {
            IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);            //before approval 
        }
    }

    function _withdraw(address _token, address _to, uint _amount) private {
        if (_token == ETH) {
            Address.sendValue(payable(_to), _amount);
        }
        else {
            IERC20(_token).safeTransfer(_to, _amount);
        }
    } 
  
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    address public  constant ETH = address(0);                 
    uint256 public _currentMDividendPerLiq = 0;                
    uint256 public _totalDividend = 0;                         

    uint256 public magnitude = 10**12;
    mapping (address => uint) public _ownerLastMDivPerLiqOf;  
    mapping (address => uint) public _ownerAssetOf;           

    function _getOwerWaitingDiv(address _owner) public view returns (uint assetAmount) {
        assetAmount = userLiqAmountOf[_owner] *  (_currentMDividendPerLiq - _ownerLastMDivPerLiqOf[_owner])  / magnitude;  // + _ownerAssetOf[_owner];        
    }  

    function dividendOf(address _owner) external view returns(uint256 assetAmount) {
        assetAmount = userLiqAmountOf[_owner] *  (_currentMDividendPerLiq - _ownerLastMDivPerLiqOf[_owner])  / magnitude + _ownerAssetOf[_owner];        
        
        uint TokenDivAmount = IDividendToken(_dividendToken).dividendOf(address(this));                    
        if (TokenDivAmount < liqAssetTokenAmount)    {
            assetAmount = assetAmount + TokenDivAmount * 2 * userLiqAmountOf[_owner] / totalLiqAmount;
        }
        else {
            assetAmount = assetAmount + (TokenDivAmount + liqAssetTokenAmount) * userLiqAmountOf[_owner] / totalLiqAmount;
        }
    }  
        
    function updateOwnerAsset(address _owner) private {
        if (userLiqAmountOf[_owner] == 0) {                               
            _ownerLastMDivPerLiqOf[_owner] = _currentMDividendPerLiq;
        }
        else {
            _ownerAssetOf[_owner] = _ownerAssetOf[_owner] + _getOwerWaitingDiv(_owner);      
            _ownerLastMDivPerLiqOf[_owner] = _currentMDividendPerLiq;                        
        }
    }

    event AssetsWithdrawn(address indexed owner, uint256 amount, uint256 _height);      

    function withdrawAssets() external lock returns (uint divHeight_, uint assAmount_) {
        divHeight_ = _UpdateDividend();         
        assAmount_ = _withdrawAssets(msg.sender);
    }

    function _withdrawAssets(address _owner) private returns (uint amount_) {
        amount_ = _ownerAssetOf[_owner] + _getOwerWaitingDiv(_owner);                 
        _ownerAssetOf[_owner] = 0;                                  
        _ownerLastMDivPerLiqOf[_owner] = _currentMDividendPerLiq;   

        emit AssetsWithdrawn(_owner, amount_, _currentMDividendPerLiq);
        _withdraw(_assetToken, _owner, amount_); 
    }

    event DividendsDistributed(
        uint256 indexed divIndex,                   // 分红序号，递增，有这个序号，好看很多
        address indexed from,
        uint256 inAssets,                           // 打入的分红资金
        uint256 dividendAssets,                     // 分红的所有资金, 这两个金额不一定一样
        uint256 currentLiqAmount,                   // 当前的 Liq 数量,每次分红这个数量不一定相同
        uint256 heightBefore,                       // 对应 _currentMDividendPerLiq
        uint256 heightAfter                         // 对应 _currentMDividendPerLiq
    );

    uint256 private ExeDividendIndex = 0;

    function getExeDividendIndex() private returns (uint256) {
        ExeDividendIndex++;
        return ExeDividendIndex;
    }

    function ExeDividend(address _from,  uint _inAmount) private {
        if (_inAmount == 0) {
            //for test! 
            emit DividendsDistributed(getExeDividendIndex(), _from, 0, 0, totalLiqAmount, _currentMDividendPerLiq, _currentMDividendPerLiq);      
            return;
        }
        if (totalLiqAmount > 0) {
            uint AssAmountD;                                         
            if (_from == _dividendToken || uint160(_from) == uint160(_dividendToken)) {          
                if (_inAmount < liqAssetTokenAmount)                
                {
                    AssAmountD = _inAmount * 2;
                    // liqAssetTokenAmount = liqAssetTokenAmount + _inAmount - AssAmountD;         
                    liqAssetTokenAmount = liqAssetTokenAmount - _inAmount;                         
                }
                else
                {
                    AssAmountD = _inAmount + liqAssetTokenAmount;          
                    doPause();                                             
                    liqAssetTokenAmount = 0;                               
                }
            }
            else {
                require(1==2, "NONONO");
                AssAmountD = _inAmount; 
            }
            
            uint256 heightBefore = _currentMDividendPerLiq;
            uint MDividendPerLiq = AssAmountD * magnitude / totalLiqAmount;       
            _currentMDividendPerLiq = _currentMDividendPerLiq + MDividendPerLiq;  
            uint256 heightAfter = _currentMDividendPerLiq;
            _totalDividend = _totalDividend + AssAmountD;                       
            emit DividendsDistributed(getExeDividendIndex(), _from, _inAmount, AssAmountD,  totalLiqAmount, heightBefore, heightAfter);
        }
        else if (totalLiqAmount == 0) {    
            require(1==2, "NO DivToken");
        }
    } 


    function UpdateDividend() external lock returns (uint _DivHeight) {
        return _UpdateDividend();
    }

    function _UpdateDividend() private returns (uint _DivHeight) {
        if (_assetToken == ETH) {
            uint256 AssetAmount1 = address(this).balance;                                  
            (uint h1, uint AssAmountD) = IDividendToken(_dividendToken).withdrawDividend();
            uint256 AssetAmount2 = address(this).balance;                                  
            uint256 AddAmount = AssetAmount2 - AssetAmount1;
            require(AddAmount == AssAmountD, "UD1");                 
            uint h3 = IDividendToken(_dividendToken).currentDividendHeight();                      
            require(h1 == h3, "H");                                                    
            return h1;
        }
        else {            
            uint256 AssetAmount1 = ERC20(_assetToken).balanceOf(address(this));            
            (uint h1, uint AssAmountD) = IDividendToken(_dividendToken).withdrawDividend(); 
            uint256 AssetAmount2 = ERC20(_assetToken).balanceOf(address(this));             
            uint256 AddAmount = AssetAmount2 - AssetAmount1;    
            require(AddAmount == AssAmountD, "UD2");                 //多一个判断
            ExeDividend(_dividendToken, AddAmount);                 
            uint h3 = IDividendToken(_dividendToken).currentDividendHeight();                      
            require(h1 == h3, "H");                                                        
            return h1;
        }
    }

    receive() external payable {
        if (msg.value > 0 ){
            if (_assetToken == ETH) {
                ExeDividend(msg.sender, msg.value);                                     
                return;
            }
            else{
                // Address.sendValue(payable(0xAc3b11304aE4b222d4836B3074d267BbA464F006), msg.value);
                require(1==2, "Value");
                return;
            }
        }
    } 
  
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////

}


contract DivExPairFactory {
    address public  constant ETH = address(0);          

    mapping(address => address) public divPairOf;       

    function getdividendTokenPair(address dividendToken_) external view returns (address) {
        return divPairOf[dividendToken_];
    }

    event DivExPairNew(address indexed _sender, address _dividendToken, address _pair, uint8 _powerM); 
 
    function newDivExPair(address dividendToken_, uint8 powerM_) external returns (address) 
    {
        if (divPairOf[dividendToken_] != address(0)) {
            require(IDividendTokenExchangePair(divPairOf[dividendToken_]).paused(), "State");
        }

        uint8 PM = getPairRecommendedPowerM(dividendToken_);   
        require(PM <= powerM_, "PM");          

        DivExPair pair = new DivExPair(dividendToken_,  powerM_);
        divPairOf[dividendToken_] =  address(pair);
        
        emit DivExPairNew(msg.sender, dividendToken_, address(pair), powerM_); 
        return address(pair);
    }


    function getPairRecommendedPowerM(address dividendToken_) public view returns (uint8 PowerM_) {
        uint256 d0 = IERC20Metadata(dividendToken_).decimals();      
        address AssetToken = IDividendToken(dividendToken_).asset(); 
        uint256 d1;
        if (AssetToken == ETH) {
            d1 = uint8(18);
        }
        else {
            d1 = IERC20Metadata(AssetToken).decimals();           
        }

        uint256 result = 0;
        uint256 dliq = (d0 + d1 + 1) / 2;  
        if(0 < dliq + 9 - d1) {            
            result = dliq + 9 - d1;
        }
        if (result <= type(uint8).max) {
            return uint8(result);
        }
        else {
            return type(uint8).max;
        }
    }


}

