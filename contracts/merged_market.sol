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
    uint256 public immutable feePercent; // the fee percentage on sales
    uint256 public listingsCount; // the total number of listings thats been listed on the market. Like a listing history
    uint256 public offersCount; // the total number of offers

    // Struct for the listing
    struct Listing {
        uint256 listingId; // the id of the listing. First listing = ID 1
        IERC721 nft; // nft object
        uint256 tokenId; // the id of the token.
        uint256 price; // the price of the listing
        address payable seller; // who posted the listing (whos selling the nft)
        bool sold; // if the listing has been sold or not
        bool active; // if the listing is actually on the marketplace or not. Can be inactive AND not sold.
        uint256 index; // index that the listing is in, in the listing array.
    }

    // Struct for the offer
    struct Offer {
        uint256 offerId; // the id of the offer. First offer = id 1
        uint256 listingId; // the id of the listing we are making an offer on
        uint256 price; // the price that is being offered
        address payable buyer; // who posted the offer (who wants to buy the nft)
        bool accepted; // if the offer was accepted by the seller
        bool active; // if the offer is on the marketplace
        uint256 index; // index that the offer is in, in the offer array
    }

    // storage array for all listings created
    Listing[] listings;
    // storage array for all offers created
    Offer[] offers;

    // MAPPING ONLY DELETED IF THE THING BECOMES INACTIVE OR REMOVED. SOLD STUFF STAYS MAPPED
    // Enter the listing id, get back the Listing Struct. Only valid for listings currently on sale.
    mapping(uint256 => Listing) public listingsForSale;
    // Enter offerId, get back the Offer struct. Only valid for offers that are currently active.
    mapping(uint256 => Offer) public activeOffers;

    // (unused, may use at future instance) -> Enter the tokenid, get back the listingId associated with the token
    //mapping(uint256 => uint256) public tokenListings;

    // Events
    event setListing(
        uint256 listingId,
        address indexed nft,
        uint256 tokenId,
        uint256 price,
        address indexed seller
    );

    event endListing(uint256 listingId, address indexed nft, uint256 tokenId);

    event madeOffer(
        uint256 listingId,
        address indexed nft,
        uint256 tokenId,
        uint256 price,
        address indexed buyer
    );

    event removedOffer(uint256 listingId, address indexed buyer);

    event acceptedOffer(
        uint256 offerId,
        uint256 listingId,
        address indexed nft,
        uint256 price
    );

    event Bought(
        uint256 listingId,
        address indexed nft,
        uint256 tokenId,
        uint256 price,
        address indexed seller,
        address indexed buyer
    );

    // Constructor runs when marketplace contract is deployed
    constructor(uint256 _feePercent) {
        feeAccount = payable(msg.sender); // Fee account is whatever deployed the contract
        feePercent = _feePercent; // fee percent specified in the parameters
    }

    // Create an NFT listing
    function createListing(
        IERC721 _nft,
        uint256 _tokenId,
        uint256 _price
    ) external nonReentrant {
        require(_price > 0.009 ether, "Price must be greater than 0.01"); // Price of nft must be greater than .01

        // Increment listings count
        listingsCount++;
        // Create new Listing struct
        Listing memory newListing = Listing(
            listingsCount, // listingID or the new listing
            _nft, // nft of the listing
            _tokenId, // tokenId associated with NFT
            _price, // price of listing
            payable(msg.sender), // who will receive the money if someone buys the NFT
            false, // sold = false
            true, // active = true
            listings.length // index is the length of the listing array. MIGHT have to do -1, because this isnt the true index since arrays are 0 indexed
        );

        // Add the listing struct to the listings array
        listings.push(newListing);
        // Add listingsCount -> newListing to the mapping
        listingsForSale[listingsCount] = newListing;

        // Transfer NFT from the sender to the marketplace
        _nft.transferFrom(msg.sender, address(this), _tokenId);

        // emit listing creation event
        emit setListing(
            listingsCount,
            address(_nft),
            _tokenId,
            _price,
            msg.sender
        );
    }

    // Purchase a listing on the market
    function purchaseListing(uint256 _listingId) public payable nonReentrant {
        // Get total price required for the listing
        uint256 _totalPrice = getTotalPrice(_listingId);
        // Get the listing from the mapping.
        Listing storage listing = listingsForSale[_listingId];
        // Check if listing actually exists
        require(
            _listingId > 0 && _listingId <= listingsCount,
            "listing doesn't exist"
        );
        // Check if the buyer sent enough funds
        require(
            msg.value >= _totalPrice,
            "not enough ether to cover listing price and market fee"
        );
        // Check if the listing hasn't been sold
        require(!listing.sold, "listing already sold");
        // Check if the listing is active
        require(listing.active, "listing is inactive");

        // Transfer funds from the buyer directly to the seller
        listing.seller.transfer(listing.price);
        // Transfer fees from the buyer to the marketplace
        feeAccount.transfer(_totalPrice - listing.price);

        // maybe we can add code that returns extra money sent if there was?

        // Update listing to sold
        listing.sold = true;
        // Update listing to inactive. Its sold, cant be sold again
        listing.active = false;
        // Transfer the actual NFT to the buyer
        listing.nft.transferFrom(address(this), msg.sender, listing.tokenId);

        // emit purchased listing event
        emit Bought(
            _listingId,
            address(listing.nft),
            listing.tokenId,
            listing.price,
            listing.seller,
            msg.sender
        );
    }

    // Remove listing on the market. Have to be the owner of the listing
    function removeListing(uint256 _listingId) public {
        require(
            _listingId > 0 && _listingId <= listingsCount,
            "listing doesn't exist"
        );

        // Get the listing
        Listing memory listing = listingsForSale[_listingId];
        // Check if sender is the owner of the listing
        require(
            listing.seller == msg.sender,
            "You cannot remove a listing of an NFT you do not own."
        );
        // Check if the listing is sold
        require(!listing.sold, "lisitng is already sold, you cannot remove.");
        // Make listing struct inactive
        listings[listingsForSale[_listingId].index].active = false;
        // Remove listing from the mapping. No way for anyone to access it now
        delete listingsForSale[listing.listingId];

        // emit remove listing event
        emit endListing(_listingId, address(listing.nft), listing.tokenId);
    }

    /*
     * Allow buyers to make a bid on the listing with an offer
     */
    function makeOffer(uint256 _offerPrice, uint256 _listingId) public {
        require(
            _listingId > 0 && _listingId <= listingsCount,
            "listing doesn't exist"
        );


        // Get the listing
        Listing memory listing = listingsForSale[_listingId];
        // Make sure the person isnt trying to bid on his own nft
        require(
            msg.sender != listing.seller,
            "You cannot make a bid on your own NFT"
        );
        
        uint256 totalOfferPrice = getOfferTotalPrice(_offerPrice);
        uint256 _offerPriceCheck = totalOfferPrice - (feePercent * totalOfferPrice);
        // Make sure the offer price is greater than 0
        require(_offerPriceCheck > 0, "Your bid must be greater than 0");
        // Make sure listing isn't already sold
        require(
            !listing.sold,
            "lisitng is already sold, you can't make a bid on it."
        );

        offersCount++;

        // Make the offer struct
        Offer memory _offer = Offer(
            offers.length,
            _listingId,
            _offerPrice,
            payable(msg.sender),
            false,
            true,
            offers.length
        );

        // place offer in storage (array and mapping)
        activeOffers[_offer.offerId] = _offer;
        offers.push(_offer);

        // emit offer creation event
        emit madeOffer(
            _listingId,
            address(listing.nft),
            listing.tokenId,
            _offerPrice,
            msg.sender
        );
    }

    /*
     * Allow sellers to remove an offer that is unsatisfactory and buyers to remove an offer they made previously
     */
    function removeOffer(uint256 _offerId) public {
        require(_offerId > 0 && _offerId <= offersCount, "offer doesn't exist");
        Offer memory offer = activeOffers[_offerId];
        Listing memory listing = listingsForSale[offer.listingId];
        // require msg.sender to be owner of offer or msg.sender to be the owner of the listingID
        require(
            offer.buyer == msg.sender || listing.seller == msg.sender,
            "You must be the NFT owner or creator of the offer to remove an offer."
        );
        // If offer accepted, cant remove
        require(
            !offer.accepted,
            "Offer is already accepted, you cannot remove."
        );

        // update offer mapping -> IMPORTANT: remove the offer form the mapping BEFORE sending funds to prevent reentry attacks
        offers[activeOffers[_offerId].index].active = false;
        delete activeOffers[_offerId];

        // emit event for offer removal
        emit removedOffer(offer.listingId, msg.sender);
    }

    /*
     * Allow sellers to accept an offer made for their listing
     */
    function acceptOffer(uint256 _offerId) public payable nonReentrant {
        //require that msg.sender is owner of the listing to accept offer
        require(_offerId > 0 && _offerId <= offersCount, "offer doesn't exist");

        Offer memory offer = activeOffers[_offerId];
        Listing memory listing = listingsForSale[offer.listingId];
        require(
            msg.sender == listing.seller,
            "You cannot accept an offer on a listing that you do not own"
        );
        // Get total price required for the listing
        uint256 totalPrice = getOfferTotalPrice(_offerId);
        require(
            _offerId > 0 && _offerId <= offersCount,
            "Offer does not exist"
        );
        // Check if the buyer sent enough funds
        require(
            msg.value >= totalPrice,
            "not enough ether to cover listing price and market fee"
        );
        // Check if the listing hasn't been sold
        require(!listing.sold, "listing already sold");
        // Check if the listing is active
        require(listing.active, "listing is inactive");

        // maybe we can add code that returns extra money sent if there was?

        // Update listing to sold
        listing.sold = true;
        // Update listing to inactive. Its sold, cant be sold again
        listing.active = false;

        // remove offer from storage
        offer.active = false;
        offer.accepted = true;
        delete activeOffers[_offerId];

        // Transfer the actual NFT to the buyer
        listing.nft.transferFrom(address(this), msg.sender, listing.tokenId);

        // Transfer funds from the buyer directly to the seller
        listing.seller.transfer(offer.price - (feePercent * offer.price));
        // Transfer fees from the buyer to the marketplace
        feeAccount.transfer(totalPrice - offer.price);

        // emit event of an accepted offer
        emit acceptedOffer(
            _offerId,
            offer.listingId,
            address(listing.nft),
            offer.price
        );

        // emit purchased listing event
        emit Bought(
            offer.listingId,
            address(listing.nft),
            listing.tokenId,
            listing.price,
            listing.seller,
            msg.sender
        );
    }

    function getTotalPrice(uint256 _listingId) public view returns (uint256) {
        return ((listings[_listingId].price * (100 + feePercent)) / 100);
    }

    function getOfferTotalPrice(uint256 _offerId) public view returns (uint256) {
        return ((offers[_offerId].price * (100 + feePercent)) / 100);
    }
}
