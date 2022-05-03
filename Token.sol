// SPDX-License-Identifier: MIT

// IGNORE THIS FILE FOR MVP - TOKEN ONLY APPLIES FOR NFT FRATIONALIZATION 

import "./utils/ERC20/ERC20.sol";
import "./utils/Ownable.sol";

import "./NFT_2.0.sol";

pragma solidity >=0.7.0 <0.9.0;

contract Token is ERC20, Ownable {
    address public nftAddress;
    uint256 public supplyPerNFT;

    constructor(
        string memory _name,
        stirng memory _symbol,
        address nftAddress,
        uint256 supplyPerNFT
    ) ERC20(_name, _symbol) {
        supplyPerNFT = _supplyPerNFT;
        nftAddress = _nftAddress;
    }

    function convertToTokens(uint256 _tokenId) public {
        NFT(nftAddress).transferFrom(msg.sender, address(this), _tokenId);
        _mint(msg.sender, supplyPerNFT);
    }
}
