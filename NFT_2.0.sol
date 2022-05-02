// SPDX-License-Identifier: MIT

// For batch minting compatibility
import "./utils/Context.sol";
import "./utils/Ownable.sol";
import "./utils/ERC165/IERC165.sol";
import "./utils/ERC165/ERC165.sol";
import "./utils/ERC721/ERC721Enumerable.sol";
import "./utils/ERC721/IERC721Enumerable.sol";
import "./utils/ERC721/IERC721Metadata.sol";
import "./utils/ERC721/IERC721.sol";
import "./utils/ERC721/ERC721.sol";
import "./utils/ERC721/IERC721Receiver.sol";
import "./utils/Strings.sol";
import "./utils/Address.sol";

// For Royaltis (check redundancies)
import "./utils/ERC721/ERC721.sol";
import "./utils/ERC721/ERC721Enumerable.sol";
import "./utils/Ownable.sol";


pragma solidity >=0.7.0 <0.9.0;

// NFT 1.0
// contract NFT is ERC721URIStorage {
//     uint public tokenCount;
//     constructor() ERC721("DApp NFT", "DAPP"){}
//     function mint(string memory _tokenURI) external returns(uint) {
//         tokenCount ++;
//         _safeMint(msg.sender, tokenCount);
//         _setTokenURI(tokenCount, _tokenURI);
//         return(tokenCount);
//     }
// }