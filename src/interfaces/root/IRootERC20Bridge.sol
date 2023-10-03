// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.17;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

interface IRootERC20Bridge {
    // TODO natspecs
    function mapToken(IERC20Metadata rootToken) external payable returns (address);
    function deposit(IERC20Metadata rootToken, uint256 amount) external;
    function depositTo(IERC20Metadata rootToken, address receiver, uint256 amount) external;
}

interface IRootERC20BridgeEvents {
    // TODO make more events have indexed fields.
    event L1TokenMapped(address rootToken, address childToken);
    event ERC20Deposit(
        address indexed rootToken,
        address indexed childToken,
        address depositor,
        address indexed receiver,
        uint256 amount
    );
}

interface IRootERC20BridgeErrors {
    error ZeroAddress();
    error AlreadyMapped();
}
