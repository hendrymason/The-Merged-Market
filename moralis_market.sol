// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

import "./NFT.sol";

import "./utils/Ownable.sol";
import "./utils/SafeMath.sol";
/*
 * Market place to trade kitties (could **in theory** be used for any ERC721 token)
 * It needs an existing NFT contract to interact with
 * Note: it does not inherit from the NFT contracts
 * Note: It takes ownership of the NFT for the duration that it is on the marketplace
 */

contract NFTMarketPlace is Ownable {

    using SafeMath for uint256;
    
    NFT private _NFTContract;

    struct Offer {
        address payable seller;
        uint256 price;
        uint256 index;
        uint256 tokenId;
        bool active;
    }

    Offer[] offers;

    event MarketTransaction(string TxType, address owner, uint256 tokenId);
    
    /*
     * Keep track of all NFTs for sale
     * Once an NFT has an offer set for it, it will appear in tokenIdToOffer
     * After an NFT is purchased or the offer is removed, it will be deleted from tokenIdToOffer
     */
    mapping(uint256 => Offer) tokenIdToOffer;
    /**
     * Keeps track of the sellers balance.
     * Once a NFT is sold, the seller balance increases.
     * Seller will then be able to withdraw.
     */
    mapping(address => uint256) sellersBalance;

    function setNFTContract(address _NFTContractAddress) public onlyOwner {
      _NFTContract = NFTCore(_NFTContractAddress);
    }

    constructor(address _NFTContractAddress) public {
      setNFTContract(_NFTContractAddress);
    }


    function getOffer(uint256 _tokenId)
        public
        view
        returns
    (
        address seller,
        uint256 price,
        uint256 index,
        uint256 tokenId,
        bool activate
    ) {
        Offer storage offer = tokenIdToOffer[_tokenId];
        return (
            offer.seller,
            offer.price,
            offer.index,
            offer.tokenId,
            offer.active
        );
    }

    function getAllTokenOnSale() public view returns(uint256[] memory listOfOffers){
      uint256 totalOffers = offers.length;

      if (totalOffers == 0) {
          return new uint256[](0);
      } else {

        uint256[] memory result = new uint256[](totalOffers);

        uint256 offerId;

        for (offerId = 0; offerId < totalOffers; offerId++) {
          if(offers[offerId].active == true){
            result[offerId] = offers[offerId].tokenId;
          }
        }
        return result;
      }
    }

    function _ownsNFT(address _address, uint256 _tokenId)
        internal
        view
        returns (bool)
    {
        return (_NFTContract.ownerOf(_tokenId) == _address);
    }

    /*
     * Create a new offer based for the given tokenId and price
     */
    function setOffer(uint256 _price, uint256 _tokenId) public {
        require(
            _ownsNFT(msg.sender, _tokenId),
            "You are not the owner of that NFT"
        );
        require(tokenIdToOffer[_tokenId].price == 0, "There is already an offer for tokenId");
        require(_NFTContract.isApprovedForAll(msg.sender, address(this)), "Contract needs to be approved to transfer the NFT in the future");

        Offer memory _offer = Offer({
          seller: msg.sender,
          price: _price,
          active: true,
          tokenId: _tokenId,
          index: offers.length
        });


        tokenIdToOffer[_tokenId] = _offer;
        offers.push(_offer);

        emit MarketTransaction("Create offer", msg.sender, _tokenId);
    }

    /*
     * Remove an existing offer
     */
    function removeOffer(uint256 _tokenId) public {
        Offer memory offer = tokenIdToOffer[_tokenId];
        require(
            offer.seller == msg.sender,
            "You are not the seller of that NFT"
        );

        delete tokenIdToOffer[_tokenId];
        offers[tokenIdToOffer[_tokenId].index].active = false;

        emit MarketTransaction("Remove offer", msg.sender, _tokenId);
    }

    /*
     * Accept an offer and buy the NFT
     */
    function buyNFT(uint256 _tokenId) public payable {
        Offer memory offer = tokenIdToOffer[_tokenId];
        require(msg.value == offer.price, "The price is incorrect");

        // Important: delete the NFT from the mapping BEFORE paying out to prevent reentry attacks
        delete tokenIdToOffer[_tokenId];
        offers[tokenIdToOffer[_tokenId].index].active = false;

        if (offer.price > 0) {
          sellersBalance[offer.seller] = sellersBalance[offer.seller].add(offer.price);
        }

        // Transfer ownership of the NFT
        _NFTContract.transferFrom(offer.seller, msg.sender, _tokenId);

        emit MarketTransaction("Buy", msg.sender, _tokenId);
    }

    /**
     * Allows sellers to withdraw their funds
    */
    function withdraw(uint256 _amount) public {
      require (sellersBalance[msg.sender] >= _amount,"Not enough balance");
      sellersBalance[msg.sender] = sellersBalance[msg.sender].sub(_amount);
      msg.sender.transfer(_amount);
    }
}