// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface ITreasury {
    function getMyUSDUpdatedPrice() external view returns (uint256 _myUsdPrice);

    function getMyUSDPrice() external view returns (uint256 myUsdPrice);
}
