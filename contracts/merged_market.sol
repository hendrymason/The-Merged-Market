// SPDX-License-Identifier: MIT

/*
 *
 * This is the main marketplace contract integrating moralis_marketplace functions
 * additional functionality has been added for offers aka. bidding auction style
 *
 */

import "./utils/ERC721/IERC721.sol";
import "./utils/ReentrancyGuard.sol";

pragma solidity >=0.7.0 <0.9.0;

contract Marketplace is ReentrancyGuard {

    // Variables
    address payable public immutable feeAccount; // the account that receives fees
    uint public immutable feePercent; // the fee percentage on sales 
    uint public listingsCount; // *changed name from itemCount

    // *change Item to Listing
    struct Listing {
        uint listingId;
        IERC721 nft;
        uint tokenId;
        uint price;
        address payable seller;
        bool sold;
        bool active;
        uint256 index;
    }

    struct Offer {
        uint offerId;
        uint listingId;
        uint price;
        address payable buyer;
        bool accepted;
        bool active;
        uint256 index;
    }
    
    // storage for all listings created
    Listing[] listings;
    // storage for all offers created
    Offer[] offers;

    // mapping for locating listings currently on sale: listingId -> listing
    mapping(uint => Listing) public listingsForSale;
    // mapping for locating listing associated with tokenId: tokenId -> listingId ****
    mapping(uint => uint) public tokenListings;

    // mapping for locating offers that are active: offerId -> offer
    mapping(uint => Offer) public pendingOffers;

    // Events
    event setListing(
        uint listingId,
        address indexed nft,
        uint tokenId,
        uint price,
        address indexed seller
    );

    event endListing(
        uint listingId,
        address indexed nft,
        uint tokenId
    );

    event madeOffer(
        uint listingId,
        address indexed nft,
        uint tokenId,
        uint price,
        address indexed buyer
    );

    event removedOffer(
        uint listingId,
        address indexed buyer
    );

    event acceptedOffer(
        uint offerId,
        uint listingId,
        address indexed nft,
        uint price
    );

    event Bought(
        uint listingId,
        address indexed nft,
        uint tokenId,
        uint price,
        address indexed seller,
        address indexed buyer
    );

    constructor(uint _feePercent) {
        feeAccount = payable(msg.sender);
        feePercent = _feePercent;
    }

    // Make listing to offer on the marketplace
    function createListing(IERC721 _nft, uint _tokenId, uint _price) external nonReentrant {
        require(_price > 0.009 ether, "Price must be greater than 0.01");
        
        // increment listingsCount
        listingsCount ++;
        // transfer nft
        _nft.transferFrom(msg.sender, address(this), _tokenId);
        // add new listing to listings mapping
        Listing memory newListing = Listing(
            listingsCount,
            _nft,
            _tokenId,
            _price,
            payable(msg.sender),
            false,
            true,
            listings.length
        );

        // add listnig to storage
        listings.push(newListing);
        listingsForSale[listingsCount] = newListing;
        
        // emit listing creation event
        emit setListing(listingsCount, address(_nft), _tokenId, _price, msg.sender);
    }

    function purchaseListing(uint _listingId) public payable nonReentrant {
        uint _totalPrice = getTotalPrice(_listingId);
        Listing storage listing = listingsForSale[_listingId];
        require(_listingId > 0 && _listingId <= listingsCount, "listing doesn't exist");
        require(msg.value >= _totalPrice, "not enough ether to cover listing price and market fee");
        require(!listing.sold, "listing already sold");
        
        // pay seller and feeAccount
        listing.seller.transfer(listing.price);
        feeAccount.transfer(_totalPrice - listing.price);
        // update listing to sold
        listing.sold = true;
        // transfer nft to buyer
        listing.nft.transferFrom(address(this), msg.sender, listing.tokenId);
        
        // emit purchased listing event
        emit Bought(_listingId, address(listing.nft), listing.tokenId, listing.price, listing.seller, msg.sender);
    }

    function removeListing(uint256 _listingId) public {
        //require that msg.sender is owner of nft listing to remove listing
        Listing memory listing = listingsForSale[_listingId];
        require(
            listing.seller == msg.sender, 
            "You cannot remove a listing of an NFT you do not own."
            );
        require(
            !listing.sold, 
            "lisitng is already sold, you cannot remove."
            );
        // remove listing from storage
        delete listingsForSale[listing.listingId];
        listings[listingsForSale[_listingId].index].active = false;
        
        // emit remove listing event
        emit endListing(_listingId, address(listing.nft), listing.tokenId);
    }

    /*
     * Allow buyers to make a bid on the listing with an offer
     */
    function makeOffer(uint256 _offerPrice, uint256 _listingId) public {
        Listing memory listing = listingsForSale[_listingId];
        require(msg.sender != listing.seller, "You cannot make a bid on your own NFT");
        require(_offerPrice > 0, "Your bid must be greater than 0");

        Offer memory _offer = Offer(
            offers.length,
            _listingId,
            _offerPrice,
            payable(msg.sender),
            false,
            true,
            offers.length
        );

        // place offer in storage
        pendingOffers[_offer.offerId] = _offer;
        offers.push(_offer);

        // emit offer creation event
        emit madeOffer(_listingId, address(listing.nft), listing.tokenId, _offerPrice, msg.sender);
    }

    /*
     * Allow sellers to remove an offer that is unsatisfactory and buyers to remove an offer they made previously
     */
    function removeOffer(uint256 _offerId) public {
        //require msg.sender to be owner of offer
        Offer memory offer = pendingOffers[_offerId];
        Listing memory listing = listingsForSale[offer.listingId];
        require(
            offer.buyer == msg.sender || listing.seller == msg.sender, 
            "You must be the NFT owner or creator of the offer to remove an offer."
        );
        require(
            !offer.accepted, 
            "Offer is already accepted, you cannot remove."
        );
        
        // update offer mapping -> IMPORTANT: remove the offer form the mapping BEFORE sending funds to prevent reentry attacks
        delete pendingOffers[_offerId];
        offers[pendingOffers[_offerId].index].active = false;

        // emit event for offer removal
        emit removedOffer(offer.listingId, msg.sender);
    }
    
    /*
     * Allow sellers to accept an offer made for their listing
     */
    function acceptOffer(uint256 _offerId) public {
        //require that msg.sender is owner of the listing to accept offer
        Offer memory offer = pendingOffers[_offerId];
        Listing memory listing = listingsForSale[offer.listingId];
        require(
            msg.sender == listing.seller, 
            "You cannot accept an offer on a listing that you do not own"
        );
        
        // purchase listing
        purchaseListing(offer.listingId);

        // remove offer from storage
        delete pendingOffers[_offerId];
        offers[pendingOffers[_offerId].index].active = false;

        // emit event of an accepted offer
        emit acceptedOffer(_offerId, offer.listingId, address(listing.nft), offer.price);
    }

    /*
     * Display all listings for sale
     */
    function getAllListings() public view returns(uint256[] memory allListings) {
        if (listingsCount == 0) {
            return new uint256[](0);
        } else {
            uint256[] memory tokenResults = new uint256[](listingsCount);

            uint256 listingId;

            for (listingId = 0; listingId < listingsCount; listingId++) {
                if(listings[listingId].price != 0) {
                    tokenResults[listingId] = listings[listingId].tokenId;
                }
            }
            return tokenResults;
        }
    }

    /*
     * Display all users listings for sale
     */
    function getUsersListings() public view returns(uint256[] memory usersListings) {
        if (listingsCount == 0) {
            return new uint256[](0);
        } else {
            uint256[] memory usersResults;

            uint256 listingId;

            for (listingId = 0; listingId < listingsCount; listingId++) {
                if(listings[listingId].price != 0 && listings[listingId].seller == msg.sender) {
                    usersResults[listingId] = listings[listingId].tokenId;
                }
            }
            return usersResults;
        }
    }

    function getTotalPrice(uint _listingId) view public returns(uint){
        return((listings[_listingId].price*(100 + feePercent))/100);
    }
}