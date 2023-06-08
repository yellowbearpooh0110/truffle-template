// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IERC721 is IERC165 {
    /**
     * @dev Emitted when `tokenId` token is transferred from `from` to `to`.
     */
    event Transfer(
        address indexed from,
        address indexed to,
        uint256 indexed tokenId
    );

    /**
     * @dev Emitted when `owner` enables `approved` to manage the `tokenId` token.
     */
    event Approval(
        address indexed owner,
        address indexed approved,
        uint256 indexed tokenId
    );

    /**
     * @dev Emitted when `owner` enables or disables (`approved`) `operator` to manage all of its assets.
     */
    event ApprovalForAll(
        address indexed owner,
        address indexed operator,
        bool approved
    );

    /**
     * @dev Returns the number of tokens in ``owner``'s account.
     */
    function balanceOf(address owner) external view returns (uint256 balance);

    /**
     * @dev Returns the owner of the `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function ownerOf(uint256 tokenId) external view returns (address owner);

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be have been allowed to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    /**
     * @dev Transfers `tokenId` token from `from` to `to`.
     *
     * WARNING: Usage of this method is discouraged, use {safeTransferFrom} whenever possible.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 tokenId) external;

    /**
     * @dev Gives permission to `to` to transfer `tokenId` token to another account.
     * The approval is cleared when the token is transferred.
     *
     * Only a single account can be approved at a time, so approving the zero address clears previous approvals.
     *
     * Requirements:
     *
     * - The caller must own the token or be an approved operator.
     * - `tokenId` must exist.
     *
     * Emits an {Approval} event.
     */
    function approve(address to, uint256 tokenId) external;

    /**
     * @dev Returns the account approved for `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function getApproved(
        uint256 tokenId
    ) external view returns (address operator);

    /**
     * @dev Approve or remove `operator` as an operator for the caller.
     * Operators can call {transferFrom} or {safeTransferFrom} for any token owned by the caller.
     *
     * Requirements:
     *
     * - The `operator` cannot be the caller.
     *
     * Emits an {ApprovalForAll} event.
     */
    function setApprovalForAll(address operator, bool _approved) external;

    /**
     * @dev Returns if the `operator` is allowed to manage all of the assets of `owner`.
     *
     * See {setApprovalForAll}
     */
    function isApprovedForAll(
        address owner,
        address operator
    ) external view returns (bool);

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes calldata data
    ) external;

    function totalSupply() external view returns (uint256);

    function transfer(address to, uint256 tokenId) external;

    function mint(uint256 _count) external;

    function price() external returns (uint256);
}

interface IPair {
    function balanceOf(address owner) external view returns (uint256);

    function totalSupply() external view returns (uint256);

    function getReserves()
        external
        view
        returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);

    function approve(address spender, uint256 value) external returns (bool);

    function transfer(address to, uint256 amount) external;

    function transferFrom(address from, address to, uint256 tokenId) external;
}

interface IRouter {
    function getAmountsIn(
        uint256 amountOut,
        address[] memory path
    ) external view returns (uint256[] memory amounts);

    function getAmountsOut(
        uint256 amountIn,
        address[] memory path
    ) external view returns (uint256[] memory amounts);
}

error InsufficientBalance();
error TransferFailed();

contract Referral is IERC721Receiver, Ownable {
    struct ReferralData {
        uint256 noOfRefrees;
        uint256 lpEarned;
        uint256 noOfrockSold;
    }

    IERC20 private BRICKS;
    IERC20 private USDC;
    IERC721 private ROCK;
    IPair private Pair;
    IRouter private Router;
    address private immutable WBNB;
    address private immutable tokenReceiver =
        0x000000000000000000000000000000000000dEaD;

    mapping(address => address) public refer;
    mapping(address => bool) public whitelist;
    mapping(address => bool) public brickReward;
    mapping(address => ReferralData) public referralInfo;

    constructor(
        address _ROCK,
        address _BRICKS,
        address _USDC,
        address _Pair,
        address _WBNB,
        address _Router
    ) {
        BRICKS = IERC20(_BRICKS);
        USDC = IERC20(_USDC);
        ROCK = IERC721(_ROCK);
        Pair = IPair(_Pair);
        WBNB = _WBNB;
        Router = IRouter(_Router);
    }

    function addWhiteList(address[] memory _team) public onlyOwner {
        require(_team.length > 0, "no team users added");
        uint256 length = _team.length;

        for (uint256 i; i < length; i++) {
            whitelist[_team[i]] = true;
        }
    }

    function buyNFT(uint256 _quantity) public {
        if (whitelist[_msgSender()] == true) {
            if (USDC.balanceOf(_msgSender()) < (ROCK.price() * _quantity)) {
                revert InsufficientBalance();
            }

            uint256 amount = ROCK.price() * _quantity;

            bool success = USDC.transferFrom(
                _msgSender(),
                address(this),
                amount
            );

            if (!success) {
                revert TransferFailed();
            }

            USDC.approve(address(ROCK), amount);

            uint256 counter = ROCK.totalSupply() + 1;
            ROCK.mint(_quantity);

            if (_quantity > 1) {
                for (uint256 i = counter; i <= ROCK.totalSupply(); i++) {
                    ROCK.safeTransferFrom(address(this), _msgSender(), i);
                }
            } else {
                ROCK.safeTransferFrom(
                    address(this),
                    _msgSender(),
                    ROCK.totalSupply()
                );
            }

            Pair.transferFrom(
                owner(),
                _msgSender(),
                (LPCalculation() * _quantity)
            );

            oneTimeBricksReward(_msgSender());
        } else if (
            whitelist[_msgSender()] == false &&
            refer[_msgSender()] != address(0)
        ) {
            if (USDC.balanceOf(_msgSender()) < (ROCK.price() * _quantity)) {
                revert InsufficientBalance();
            }

            uint256 amount = ROCK.price() * _quantity;

            bool success = USDC.transferFrom(
                _msgSender(),
                address(this),
                amount
            );

            if (!success) {
                revert TransferFailed();
            }

            USDC.approve(address(ROCK), amount);

            uint256 counter = ROCK.totalSupply() + 1;
            ROCK.mint(_quantity);

            if (_quantity > 1) {
                for (uint256 i = counter; i <= ROCK.totalSupply(); i++) {
                    ROCK.safeTransferFrom(address(this), _msgSender(), i);
                }
            } else {
                ROCK.safeTransferFrom(
                    address(this),
                    _msgSender(),
                    ROCK.totalSupply()
                );
            }

            Pair.transferFrom(
                owner(),
                refer[_msgSender()],
                (LPCalculation() * _quantity)
            );
            ReferralData memory data = referralInfo[refer[_msgSender()]];
            data.lpEarned += 25 * _quantity;
            data.noOfrockSold += _quantity;
            referralInfo[refer[_msgSender()]] = data;
            oneTimeBricksReward(_msgSender());
        } else {
            if (USDC.balanceOf(_msgSender()) < (ROCK.price() * _quantity)) {
                revert InsufficientBalance();
            }

            uint256 amount = ROCK.price() * _quantity;

            bool success = USDC.transferFrom(
                _msgSender(),
                address(this),
                amount
            );

            if (!success) {
                revert TransferFailed();
            }

            USDC.approve(address(ROCK), amount);

            uint256 counter = ROCK.totalSupply() + 1;
            ROCK.mint(_quantity);

            if (_quantity > 1) {
                for (uint256 i = counter; i <= ROCK.totalSupply(); i++) {
                    ROCK.safeTransferFrom(address(this), _msgSender(), i);
                }
            } else {
                ROCK.safeTransferFrom(
                    address(this),
                    _msgSender(),
                    ROCK.totalSupply()
                );
            }

            oneTimeBricksReward(_msgSender());
        }
    }

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    function oneTimeBricksReward(address _user) private {
        if (
            BRICKS.balanceOf(_user) >= BricksCalculation(200) &&
            brickReward[_user] == false
        ) {
            bool success = BRICKS.transferFrom(
                _user,
                tokenReceiver,
                BricksCalculation(50)
            ); //can't send tokens to address(0)
            if (!success) {
                revert TransferFailed();
            }
            brickReward[_user] = true;
            Pair.transferFrom(owner(), _user, LPCalculation());
        }
    }

    function addReferral(address _address) public {
        require(
            _address != address(0) &&
                _address != _msgSender() &&
                refer[_msgSender()] == address(0),
            "Please provide correct link"
        );
        refer[_msgSender()] = _address;
        ReferralData memory data = referralInfo[_address];
        data.noOfRefrees += 1;
        referralInfo[_address] = data;
    }

    function LPCalculation() public view returns (uint256) {
        (uint256 reserve0, uint256 reserve1, ) = Pair.getReserves();
        uint256 supply = Pair.totalSupply();
        uint256 onemyUSDPrice = ((reserve0 * 1 ether) / (reserve1));
        uint256 totalMyUSDPrice = (reserve1 * onemyUSDPrice) / 1 ether;
        uint256 oneLPTokenPrice = (((reserve0 * 1 ether) +
            (totalMyUSDPrice * 1 ether)) / supply);
        return (((25 ether) * 1 ether) / oneLPTokenPrice);
    }

    function BricksCalculation(uint256 _value) public view returns (uint256) {
        address[] memory path = new address[](2);
        path[0] = address(USDC);
        path[1] = WBNB;
        uint256[] memory amount = Router.getAmountsOut(
            (_value * 10 ** 18),
            path
        );
        address[] memory temp = new address[](2);
        temp[0] = WBNB;
        temp[1] = address(BRICKS);
        uint256[] memory amount2 = Router.getAmountsOut(amount[1], temp);
        return amount2[1];
    }
}
