// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@perimetersec/fuzzlib/src/FuzzBase.sol";

import "./helper/FuzzStorageVariables.sol";

/**
 * @title FuzzSetup
 * @author 0xScourgedev
 * @notice Setup for the fuzzing suite
 */
contract FuzzSetup is FuzzBase, FuzzStorageVariables {
    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                       SETUP ACTORS                                        //
    ///////////////////////////////////////////////////////////////////////////////////////////////
    function setupActors() internal {
        mintAndApproveTokens();
    }

    function mintAndApproveTokens() private {
        // First send the wrapped native tokens to the harness
        WETH(payable(wETH)).deposit{value: INITIAL_WETH_BALANCE * USERS.length}();
        WIMX(payable(wIMX)).deposit{value: INITIAL_WETH_BALANCE * USERS.length}();

        for (uint256 i = 0; i < USERS.length; i++) {
            for (uint256 j = 0; j < rootTokens.length; j++) {
                // Approvals for rootTokens for all targets
                for (uint256 k = 0; k < targets.length; k++) {
                    vm.prank(USERS[i]);
                    ChildERC20(rootTokens[j]).approve(targets[k], type(uint128).max);
                }

                // WETH is not minted here, so skip it
                if (rootTokens[j] == wETH) {
                    continue;
                }
                // Mint root tokens to the users
                ChildERC20(rootTokens[j]).mint(USERS[i], MAX_ERC20_BALANCE * 10 ** ChildERC20(rootTokens[j]).decimals());
                // Check that the minting was successful
                assert(
                    ChildERC20(rootTokens[j]).balanceOf(USERS[i])
                        == MAX_ERC20_BALANCE * 10 ** ChildERC20(rootTokens[j]).decimals()
                );
            }

            // Can't mint child tokens, since only the bridge can, so just approve them
            for (uint256 j = 0; j < childTokens.length; j++) {
                // Approvals for childTokens for all targets
                for (uint256 k = 0; k < targets.length; k++) {
                    vm.prank(USERS[i]);
                    ChildERC20(childTokens[j]).approve(targets[k], type(uint128).max);
                }
            }

            // Send initial balance of native tokens to the users
            (bool success,) = (USERS[i]).call{value: INITIAL_BALANCE}("");
            assert(success);
            assert(USERS[i].balance == INITIAL_BALANCE);

            // Transfer wrapped native tokens to the users
            WETH(payable(wETH)).transfer(USERS[i], INITIAL_WETH_BALANCE);
            assert(WETH(payable(wETH)).balanceOf(USERS[i]) == INITIAL_WETH_BALANCE);

            WIMX(payable(wIMX)).transfer(USERS[i], INITIAL_WETH_BALANCE);
            assert(WIMX(payable(wIMX)).balanceOf(USERS[i]) == INITIAL_WETH_BALANCE);

            assert(WIMX(payable(wIMX)).allowance(USERS[i], childERC20Bridge) == type(uint128).max);
        }
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                    SETUP CONTRACTS                                        //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function setup() internal {
        createTokenTemplate();
        createMockAdaptors();
        createRootIMXToken();
        createWrappedNatives();
        createChildBridge();
        createRootBridge();
        initializeMockAdaptors();
        createInitialTokens();
        generateMapTokens();
        addTokensToArrays();
        addAddressesToTargets();
    }

    function createTokenTemplate() private {
        tokenTemplate = address(new ChildERC20());
        ChildERC20(tokenTemplate).initialize(address(123), "Test", "TST", 18);
    }

    function createMockAdaptors() private {
        mockAdaptorRoot = address(new MockAdaptor());
        mockAdaptorChild = address(new MockAdaptor());
    }

    function createRootIMXToken() private {
        rootIMXToken = address(new ChildERC20());
        ChildERC20(rootIMXToken).initialize(address(123), "Immutable X", "IMX", 18);
    }

    function createWrappedNatives() private {
        wETH = address(new WETH());
        wIMX = address(new WIMX());
    }

    function createChildBridge() private {
        childERC20Bridge = address(new ChildERC20Bridge(address(this)));
        IChildERC20Bridge.InitializationRoles memory childRoles = IChildERC20Bridge.InitializationRoles({
            defaultAdmin: address(this),
            pauser: address(this),
            unpauser: address(this),
            adaptorManager: address(this),
            initialDepositor: address(this),
            treasuryManager: address(this)
        });
        ChildERC20Bridge(payable(childERC20Bridge)).initialize(
            childRoles, mockAdaptorChild, tokenTemplate, rootIMXToken, wIMX
        );
    }

    function createRootBridge() private {
        rootERC20BridgeFlowRate = address(new RootERC20BridgeFlowRate(address(this)));
        IRootERC20Bridge.InitializationRoles memory rootRoles = IRootERC20Bridge.InitializationRoles({
            defaultAdmin: address(this),
            pauser: address(this),
            unpauser: address(this),
            variableManager: address(this),
            adaptorManager: address(this)
        });
        RootERC20BridgeFlowRate(payable(rootERC20BridgeFlowRate)).initialize(
            rootRoles,
            mockAdaptorRoot,
            childERC20Bridge,
            tokenTemplate,
            address(rootIMXToken),
            address(wETH),
            IMX_DEPOSIT_LIMIT,
            address(this)
        );
    }

    function initializeMockAdaptors() private {
        MockAdaptor(mockAdaptorRoot).initialize(rootERC20BridgeFlowRate);
        MockAdaptor(mockAdaptorChild).initialize(childERC20Bridge);
    }

    function createInitialTokens() private {
        rootSixDecimalInitial = address(new ChildERC20());
        ChildERC20(rootSixDecimalInitial).initialize(address(123), "Six Root Initial", "6RI", 6);

        rootEightDecimalInitial = address(new ChildERC20());
        ChildERC20(rootEightDecimalInitial).initialize(address(123), "Eight Root Initial", "8RI", 8);

        rootEighteenDecimalInitial = address(new ChildERC20());
        ChildERC20(rootEighteenDecimalInitial).initialize(address(123), "Eighteen Root Initial", "18RI", 18);
    }

    function generateMapTokens() private {
        MockAdaptor(mockAdaptorChild).onMessageReceive(
            abi.encode(
                ChildERC20Bridge(payable(childERC20Bridge)).MAP_TOKEN_SIG(),
                rootSixDecimalInitial,
                "Six Child Generated",
                "6CG",
                ChildERC20(rootSixDecimalInitial).decimals()
            )
        );
        childSixDecimalGenerated =
            RootERC20Bridge(payable(rootERC20BridgeFlowRate)).mapToken{value: 1}(IERC20Metadata(rootSixDecimalInitial));

        // Verify that the token was mapped correctly
        assert(
            childSixDecimalGenerated
                == ChildERC20Bridge(payable(childERC20Bridge)).rootTokenToChildToken(rootSixDecimalInitial)
        );

        MockAdaptor(mockAdaptorChild).onMessageReceive(
            abi.encode(
                ChildERC20Bridge(payable(childERC20Bridge)).MAP_TOKEN_SIG(),
                rootEightDecimalInitial,
                "Eight Child Generated",
                "8CG",
                ChildERC20(rootEightDecimalInitial).decimals()
            )
        );
        childEightDecimalGenerated = RootERC20Bridge(payable(rootERC20BridgeFlowRate)).mapToken{value: 1}(
            IERC20Metadata(rootEightDecimalInitial)
        );

        // Verify that the token was mapped correctly
        assert(
            childEightDecimalGenerated
                == ChildERC20Bridge(payable(childERC20Bridge)).rootTokenToChildToken(rootEightDecimalInitial)
        );

        MockAdaptor(mockAdaptorChild).onMessageReceive(
            abi.encode(
                ChildERC20Bridge(payable(childERC20Bridge)).MAP_TOKEN_SIG(),
                rootEighteenDecimalInitial,
                "Eighteen Child Generated",
                "18CG",
                ChildERC20(rootEighteenDecimalInitial).decimals()
            )
        );
        childEighteenDecimalGenerated = RootERC20Bridge(payable(rootERC20BridgeFlowRate)).mapToken{value: 1}(
            IERC20Metadata(rootEighteenDecimalInitial)
        );

        // Verify that the token was mapped correctly
        assert(
            childEighteenDecimalGenerated
                == ChildERC20Bridge(payable(childERC20Bridge)).rootTokenToChildToken(rootEighteenDecimalInitial)
        );

        childETHToken = ChildERC20Bridge(payable(childERC20Bridge)).childETHToken();
        assert(childETHToken != address(0));
    }

    function addTokensToArrays() private {
        allTokens.push(rootSixDecimalInitial);
        allTokens.push(rootEightDecimalInitial);
        allTokens.push(rootEighteenDecimalInitial);
        allTokens.push(childSixDecimalGenerated);
        allTokens.push(childEightDecimalGenerated);
        allTokens.push(childEighteenDecimalGenerated);
        allTokens.push(rootIMXToken);
        allTokens.push(childETHToken);
        allTokens.push(wETH);
        allTokens.push(wIMX);

        rootTokens.push(rootSixDecimalInitial);
        rootTokens.push(rootEightDecimalInitial);
        rootTokens.push(rootEighteenDecimalInitial);
        rootTokens.push(rootIMXToken);
        rootTokens.push(wETH);

        childTokens.push(childSixDecimalGenerated);
        childTokens.push(childEightDecimalGenerated);
        childTokens.push(childEighteenDecimalGenerated);
        childTokens.push(childETHToken);
        childTokens.push(wIMX);
    }

    function addAddressesToTargets() private {
        targets.push(childERC20Bridge);
        targets.push(rootERC20BridgeFlowRate);
        targets.push(mockAdaptorRoot);
        targets.push(mockAdaptorChild);
    }
}
