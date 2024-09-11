// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "../util/FuzzConstants.sol";
import "../../../src/child/ChildERC20Bridge.sol";
import "../../../src/root/flowrate/RootERC20BridgeFlowRate.sol";
import "../../../src/common/BridgeRoles.sol";
import "../../../src/root/RootERC20Bridge.sol";
import "../../../src/child/ChildERC20.sol";
import "../mocks/MockAdaptor.sol";
import "../../../src/lib/WETH.sol";
import "../../../src/child/WIMX.sol";

/**
 * @title FuzzStorageVariables
 * @author 0xScourgedev
 * @notice Contains all of the storage variables for the fuzzing suite
 */
abstract contract FuzzStorageVariables is FuzzConstants {
    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                         STRUCTS                                           //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                      FUZZ SETTINGS                                        //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    // Turn this off for PoC functions
    bool internal _setActor = true;

    // Turn this to true if running optimization mode
    bool internal constant OPTIMIZATION_ENABLED = false;

    // Turn this on to enable debug mode
    bool internal constant DEBUG = false;

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                      FUZZ VARIABLES                                       //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    address internal currentActor;

    address[] internal allTokens;
    address[] internal rootTokens;
    address[] internal childTokens;
    address[] internal targets;

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                    DEPLOYED CONTRACTS                                     //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    address internal childERC20Bridge;
    address internal rootERC20BridgeFlowRate;
    address internal tokenTemplate;
    address internal mockAdaptorRoot;
    address internal mockAdaptorChild;
    address internal rootIMXToken;
    address internal wETH;
    address internal wIMX;
    address internal childETHToken;

    // Manually deployed token with six decimals on the root chain
    address internal rootSixDecimalInitial;
    // Generated token with mapToken with six decimals on the child chain
    address internal childSixDecimalGenerated;

    // Manually deployed token with eight decimals on the root chain
    address internal rootEightDecimalInitial;
    // Generated token with mapToken with eight decimals on the child chain
    address internal childEightDecimalGenerated;

    // Manually deployed token with eighteen decimals on the root chain
    address internal rootEighteenDecimalInitial;
    // Generated token with mapToken with eighteen decimals on the child chain
    address internal childEighteenDecimalGenerated;
}
