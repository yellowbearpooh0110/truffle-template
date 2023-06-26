// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./MultiCallExtended.sol";

import "./interfaces/IMyROCKS.sol";
import "./interfaces/IMyUSD.sol";
import "./interfaces/ITreasury.sol";

// Check out https://github.com/Fantom-foundation/Artion-Contracts/blob/5c90d2bc0401af6fb5abf35b860b762b31dfee02/contracts/FantomMarketplace.sol
// For a full decentralized nft marketplace

error PriceNotMet(address nftAddress, uint256 tokenId, uint256 price);
error ItemNotForSale(address nftAddress, uint256 tokenId);
error NotListed(address nftAddress, uint256 tokenId);
error AlreadyListed(address nftAddress, uint256 tokenId);
error NoProceeds();
error NotOwner();
error NotLister(address nftAddress, uint256 tokenId);
error NotApprovedForMarketplace();
error PriceMustBeAboveZero();
error NotCorrectWithdrawAmount();

// Error thrown for isNotOwner modifier
// error IsNotOwner()

contract NftMarketplace is
    ReentrancyGuard,
    IERC721Receiver,
    Ownable,
    MulticallExtended
{
    using SafeMath for uint256;
    struct Listing {
        address currency;
        uint256 price;
        address seller;
        uint256 timestamp;
    }

    event ItemListed(
        address indexed seller,
        address indexed nftAddress,
        uint256 indexed tokenId,
        address currencyAddress,
        uint256 price
    );

    event ItemCanceled(
        address indexed seller,
        address indexed nftAddress,
        uint256 indexed tokenId
    );

    event ItemBought(
        address indexed buyer,
        address indexed nftAddress,
        uint256 indexed tokenId,
        address currencyAddress,
        uint256 price
    );

    mapping(address => mapping(uint256 => Listing)) private listings;
    address public myRocksAddress;
    address public myUsdAddress;
    address public treasuryAddress;
    uint256 public aprPerRock = 150 * 1e18;

    constructor(
        address _myRocksAddress,
        address _myUsdAddress,
        address _treasuryAddress
    ) {
        myRocksAddress = _myRocksAddress;
        myUsdAddress = _myUsdAddress;
        treasuryAddress = _treasuryAddress;
    }

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    modifier notListed(address nftAddress, uint256 tokenId) {
        Listing memory listing = listings[nftAddress][tokenId];
        if (listing.price > 0) {
            revert AlreadyListed(nftAddress, tokenId);
        }
        _;
    }

    modifier isListed(address nftAddress, uint256 tokenId) {
        Listing memory listing = listings[nftAddress][tokenId];
        if (listing.price <= 0) {
            revert NotListed(nftAddress, tokenId);
        }
        _;
    }

    modifier isOwner(
        address nftAddress,
        uint256 tokenId,
        address spender
    ) {
        IERC721 nft = IERC721(nftAddress);
        address owner = nft.ownerOf(tokenId);
        if (spender != owner) {
            revert NotLister(nftAddress, tokenId);
        }
        _;
    }

    modifier isLister(
        address nftAddress,
        uint256 tokenId,
        address spender
    ) {
        Listing memory listing = listings[nftAddress][tokenId];
        if (listing.seller != spender) {
            revert NotListed(nftAddress, tokenId);
        }
        _;
    }

    // IsNotOwner Modifier - Nft Owner can't buy his/her NFT
    // Modifies buyItem function
    // Owner should only list, cancel listing or update listing
    /* modifier isNotOwner(
        address nftAddress,
        uint256 tokenId,
        address spender
    ) {
        IERC721 nft = IERC721(nftAddress);
        address owner = nft.ownerOf(tokenId);
        if (spender == owner) {
            revert IsNotOwner();
        }
        _;
    } */

    function updateContractAddresses(
        address _myRocksAddress,
        address _myUsdAddress,
        address _treasuryAddress
    ) external onlyOwner {
        myRocksAddress = _myRocksAddress;
        myUsdAddress = _myUsdAddress;
        treasuryAddress = _treasuryAddress;
    }

    function updateAprPerRock(uint256 _aprPerRock) external onlyOwner {
        aprPerRock = _aprPerRock;
    }

    /////////////////////
    // Main Functions //
    /////////////////////
    /*
     * @notice Method for listing NFT
     * @param nftAddress Address of NFT contract
     * @param tokenId Token ID of NFT
     * @param price sale price for each item
     */
    function listItem(
        address nftAddress,
        uint256 tokenId,
        address currencyAddress,
        uint256 price
    )
        external
        notListed(nftAddress, tokenId)
        isOwner(nftAddress, tokenId, msg.sender)
    {
        if (price <= 0) {
            revert PriceMustBeAboveZero();
        }
        IERC721 nft = IERC721(nftAddress);
        if (nft.getApproved(tokenId) != address(this)) {
            revert NotApprovedForMarketplace();
        }
        listings[nftAddress][tokenId] = Listing(
            currencyAddress,
            price,
            msg.sender,
            block.timestamp
        );
        emit ItemListed(
            msg.sender,
            nftAddress,
            tokenId,
            currencyAddress,
            price
        );
    }

    /*
     * @notice Method for cancelling listing
     * @param nftAddress Address of NFT contract
     * @param tokenId Token ID of NFT
     */
    function cancelListing(
        address nftAddress,
        uint256 tokenId
    )
        external
        isListed(nftAddress, tokenId)
        isLister(nftAddress, tokenId, msg.sender)
    {
        IERC721(nftAddress).safeTransferFrom(
            address(this),
            msg.sender,
            tokenId
        );
        delete (listings[nftAddress][tokenId]);
        emit ItemCanceled(msg.sender, nftAddress, tokenId);
    }

    /*
     * @notice Method for buying listing
     * @notice The owner of an NFT could unapprove the marketplace,
     * which would cause this function to fail
     * Ideally you'd also have a `createOffer` functionality.
     * @param nftAddress Address of NFT contract
     * @param tokenId Token ID of NFT
     */
    function buyItem(
        address nftAddress,
        uint256 tokenId
    )
        external
        payable
        isListed(nftAddress, tokenId)
        // isNotOwner(nftAddress, tokenId, msg.sender)
        nonReentrant
    {
        // Challenge - How would you refactor this contract to take:
        // 1. Abitrary tokens as payment? (HINT - Chainlink Price Feeds!)
        // 2. Be able to set prices in other currencies?
        // 3. Tweet me @PatrickAlphaC if you come up with a solution!
        Listing memory listedItem = listings[nftAddress][tokenId];
        if (listedItem.currency == address(0)) {
            if (msg.value < listedItem.price.mul(12).div(10)) {
                revert PriceNotMet(nftAddress, tokenId, listedItem.price);
            }
            payable(listedItem.seller).transfer(msg.value.mul(8).div(10));
            // s_proceeds[listedItem.seller] += msg.value.mul(8).div(10);
            // Could just send the money...
            // https://fravoll.github.io/solidity-patterns/pull_over_push.html
        } else {
            if (
                IERC20(listedItem.currency).allowance(
                    msg.sender,
                    address(this)
                ) < listedItem.price.mul(12).div(10)
            ) {
                revert NotApprovedForMarketplace();
            }
            IERC20(listedItem.currency).transferFrom(
                msg.sender,
                listedItem.seller,
                listedItem.price.mul(8).div(10)
            );
            IERC20(listedItem.currency).transferFrom(
                msg.sender,
                address(this),
                listedItem.price.mul(4).div(10)
            );
        }
        delete (listings[nftAddress][tokenId]);
        IERC721(nftAddress).safeTransferFrom(
            address(this),
            msg.sender,
            tokenId
        );
        emit ItemBought(
            msg.sender,
            nftAddress,
            tokenId,
            listedItem.currency,
            listedItem.price
        );
    }

    /*
     * @notice Method for updating listing
     * @param nftAddress Address of NFT contract
     * @param tokenId Token ID of NFT
     * @param newPrice Price in Wei of the item
     */
    function updateListing(
        address nftAddress,
        uint256 tokenId,
        address newCurrencyAddress,
        uint256 newPrice
    )
        external
        isListed(nftAddress, tokenId)
        nonReentrant
        isLister(nftAddress, tokenId, msg.sender)
    {
        //We should check the value of `newPrice` and revert if it's below zero (like we also check in `listItem()`)
        if (newPrice <= 0) {
            revert PriceMustBeAboveZero();
        }
        listings[nftAddress][tokenId].price = newPrice;
        listings[nftAddress][tokenId].currency = newCurrencyAddress;
        emit ItemListed(
            msg.sender,
            nftAddress,
            tokenId,
            newCurrencyAddress,
            newPrice
        );
    }

    /*
     * @notice Method for withdrawing proceeds from sales
     */
    // function withdrawProceeds() external {
    //     uint256 proceeds = s_proceeds[msg.sender];
    //     if (proceeds <= 0) {
    //         revert NoProceeds();
    //     }
    //     s_proceeds[msg.sender] = 0;
    //     (bool success, ) = payable(msg.sender).call{value: proceeds}("");
    //     require(success, "Transfer failed");
    // }

    /////////////////////
    // Getter Functions //
    /////////////////////

    function getListing(
        address nftAddress,
        uint256 tokenId
    ) external view returns (Listing memory) {
        return listings[nftAddress][tokenId];
    }

    // function getProceeds(address seller) external view returns (uint256) {
    //     return s_proceeds[seller];
    // }

    function distributeRewards() external onlyOwner {
        uint256[] memory tokenIds = IMyROCKS(myRocksAddress).walletOfOwner(
            address(this)
        );
        uint256 currentTimestamp = block.timestamp;
        uint256 pegPrice = ITreasury(treasuryAddress).getMyUSDUpdatedPrice();
        for (uint256 i = 0; i < tokenIds.length; i++) {
            Listing memory listing = listings[myRocksAddress][tokenIds[i]];
            uint256 oldTimestamp = listings[myRocksAddress][tokenIds[i]]
                .timestamp;
            if (currentTimestamp > oldTimestamp) {
                if (pegPrice > 1e18) {
                    IMyUSD(myUsdAddress).mint(
                        listing.seller,
                        aprPerRock.mul(currentTimestamp - oldTimestamp).div(
                            31536000000
                        )
                    );
                }
                listings[myRocksAddress][tokenIds[i]]
                    .timestamp = currentTimestamp;
            }
        }
    }

    function withdrawBNB(uint256 value) external onlyOwner {
        address owner = owner();
        if (address(this).balance < value) {
            revert NotCorrectWithdrawAmount();
        }
        payable(owner).transfer(value);
    }

    function withdrawToken(address token, uint256 value) external onlyOwner {
        address owner = owner();
        if (IERC20(token).balanceOf(address(this)) < value) {
            revert NotCorrectWithdrawAmount();
        }
        IERC20(token).transferFrom(msg.sender, owner, value);
    }
}
