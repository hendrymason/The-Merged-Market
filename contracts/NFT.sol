// SPDX-License-Identifier: MIT

import "./utils/ERC721/ERC721URIStorage.sol";

pragma solidity >=0.7.0 <0.9.0;

contract NFT is ERC721URIStorage {
    uint public tokenCount;
    
    constructor() ERC721("DApp NFT", "DAPP"){}
    
    function mint(string memory _tokenURI) external returns(uint) {
        tokenCount ++;
        _safeMint(msg.sender, tokenCount);
        _setTokenURI(tokenCount, _tokenURI);
        return(tokenCount);
    }
}