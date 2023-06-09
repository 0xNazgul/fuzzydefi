// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface IShare {
    function unclaimedTreasuryFund() external view returns (uint256 _pending);

    function claimRewards() external;
}
