// SPDX-License-Identifier: BUSL-1.1
// author: c7a9d8c6c987784967375ae97a35d30ab617eb48@hotmail.com 


pragma solidity ^0.8.0;

import "./Administrator.sol";
import "./DividendToken0.sol";
import "./ITokenIcon.sol";
import "./openzeppelin/Strings.sol";

// ShareToken 分红无误差 , 
contract ShareToken is DividendToken0, Administrator, ITokenIcon {

    uint8 private _decimals = 3;
    
    function decimals() public view override returns (uint8) {
        return _decimals;                                               
    }

    constructor(string memory name_, string memory symbol_, uint8 decimals_, 
        address assetToken_, address admin_, address superAdmin_, string memory _notice) DividendToken0 (name_, symbol_, assetToken_) 
    {
        _decimals = decimals_;
        Admin = admin_;
        SuperAdmin = superAdmin_;

        _publishNotice(_notice);
    }

    function setIcon(string memory iconFileName_, bytes memory iconData_) external onlyAdmin {
        require(0 < bytes(iconFileName_).length && bytes(iconFileName_).length <= 128, "F");
        require(0 < iconData_.length, "I");
        emit IconImage(msg.sender, iconFileName_, iconData_);
    }

    uint256 public NoticeId = 0;

    event NoticePublish(address _sender, uint256 _noticeId,  string _notice);

    // 发布公告
    function publishNotice(string memory _notice) external  onlyAdmin  {
        _publishNotice(_notice);
    }

    function _publishNotice(string memory _notice) private  {
        NoticeId++;
        emit NoticePublish(msg.sender, NoticeId, _notice);
    }

    function mint(address account, uint256 amount, string memory _notice) onlyAdmin external {
        _mint(account, amount); 

        bytes32 bh = blockhash(block.number);          
        bytes memory b = abi.encodePacked(Strings.toHexString(uint256(bh)) , " => mint  => ", Strings.toString(amount), " => ", "\n", _notice );    
        string memory s = string(b);
        // string memory  s = string.concat(Strings.toHexString(uint256(bh)) , " => mint  => ", Strings.toString(amount), " => ", "\n", _notice );    
        _publishNotice(s);
    }

}



contract ShareTokenFactory  {

    event ShareTokenNew(address indexed _sender, address _tokenAddrss); 
 
    function newShareToken(string memory tokenName_, string memory tokenSymbol_, uint8 decimals_, 
        address tokenAssetToken_, address tokenAdmin_, address tokenSuperAdmin_, string memory _notice) external returns (address) 
    {
        ShareToken token = new ShareToken(tokenName_,  tokenSymbol_, decimals_, tokenAssetToken_, tokenAdmin_, tokenSuperAdmin_, _notice);
        emit ShareTokenNew(msg.sender, address(token)); 
        return address(token);
    }

    address public  constant ETH = address(0);              

    function getDivRecommendedDecimals(address assetToken_) public view returns (uint8) {
        if (assetToken_ == ETH) {
            return uint8(6);              
        }

        uint8 d1 = IERC20Metadata(assetToken_).decimals();
        if (12 <= d1) {
            return uint8(6);                
        }
        else if (6 <= d1) {
            return uint8(d1 - 6);         
        }
        return uint8(0);            
    }


}



