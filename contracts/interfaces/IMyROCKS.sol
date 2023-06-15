// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IMyROCKS {
    function walletOfOwner(
        address _owner
    ) external view returns (uint256[] memory);
}
