// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
}

contract P2PExchangeGSA {
    address public GSA = 0xC1e2859c9D20456022ADe2d03f2E48345cA177C2;

    struct Offer {
        address seller;
        uint256 amount;
        uint256 price; // Total price in MATIC for the amount of tokens
        bool active; // Indicates whether the offer is active or canceled
    }

    Offer[] public offers;

    event OfferCreated(uint256 offerId, address seller, uint256 amount, uint256 price);
    event OfferBought(uint256 offerId, address buyer);
    event OfferCanceled(uint256 offerId, address seller);

    function createOffer(uint256 amount, uint256 price) external {
        require(amount > 0, "Amount must be greater than zero");
        require(price > 0, "Price must be greater than zero");

        offers.push(Offer({
            seller: msg.sender,
            amount: amount,
            price: price,
            active: true
        }));

        uint256 offerId = offers.length - 1;

        // Transfer the tokens to the contract for escrow
        require(IERC20(GSA).transferFrom(msg.sender, address(this), amount), "Token transfer failed");

        emit OfferCreated(offerId, msg.sender, amount, price);
    }

    function buyOffer(uint256 offerId) external payable {
        require(offerId < offers.length, "Offer does not exist");
        Offer storage offer = offers[offerId];

        require(offer.active, "Offer is not active");
        require(msg.value == offer.price, "Incorrect MATIC value sent");

        // Transfer MATIC to the seller
        payable(offer.seller).transfer(msg.value);

        // Transfer tokens to the buyer
        require(IERC20(GSA).transfer(msg.sender, offer.amount), "Token transfer failed");

        // Mark the offer as inactive
        offer.active = false;

        emit OfferBought(offerId, msg.sender);
    }

    function cancelOffer(uint256 offerId) external {
        require(offerId < offers.length, "Offer does not exist");
        Offer storage offer = offers[offerId];

        require(offer.seller == msg.sender, "Only the seller can cancel this offer");
        require(offer.active, "Offer is not active");

        // Transfer tokens back to the seller
        require(IERC20(GSA).transfer(offer.seller, offer.amount), "Token transfer failed");

        // Mark the offer as inactive
        offer.active = false;

        emit OfferCanceled(offerId, msg.sender);
    }

    function getOfferCount() external view returns (uint256) {
        return offers.length;
    }

    function getOffer(uint256 offerId) external view returns (address, uint256, uint256, bool) {
        require(offerId < offers.length, "Offer does not exist");
        Offer storage offer = offers[offerId];
        return (offer.seller, offer.amount, offer.price, offer.active);
    }
}
