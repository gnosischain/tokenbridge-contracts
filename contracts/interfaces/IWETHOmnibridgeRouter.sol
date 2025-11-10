// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IWETHOmnibridgeRouter {
    function wrapAndRelayTokens(address _receiver) external payable;
}
