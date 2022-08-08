// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

// token 的图标。 一般是创建时候指定，不可更改。
interface ITokenIcon {

    // // 图片保存在网络，例如ipfs，bt，等， 返回网络的地址，      成本很低
    // function iconUri() external view returns (string memory);

    // // 图片以 bytes 形式保存到区块链网上                       成本很高
    // function iconImage() external view returns (bytes memory);

    event IconImage(address _sender, string _fileName, bytes _data);        //通过事件跑出去，成本低

}