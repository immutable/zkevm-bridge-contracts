// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "./PropertiesBase.sol";

/**
 * @title Properties_PAUSE
 * @author 0xScourgedev
 * @notice Contains all PAUSE invariants
 */
abstract contract Properties_PAUSE is PropertiesBase {
    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                       INVARIANTS                                          //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /**
     * @custom:invariant PAUSE-01: deposit always reverts when the root bridge is paused
     */
    function invariant_PAUSE_01() internal {
        if (states[1].rootBridgePaused) {
            fl.t(false, PAUSE_01);
        }
    }

    /**
     * @custom:invariant PAUSE-02: depositETH always reverts when the root bridge is paused
     */
    function invariant_PAUSE_02() internal {
        if (states[1].rootBridgePaused) {
            fl.t(false, PAUSE_02);
        }
    }

    /**
     * @custom:invariant PAUSE-03: depositTo always reverts when the root bridge is paused
     */
    function invariant_PAUSE_03() internal {
        if (states[1].rootBridgePaused) {
            fl.t(false, PAUSE_03);
        }
    }

    /**
     * @custom:invariant PAUSE-04: depositToETH always reverts when the root bridge is paused
     */
    function invariant_PAUSE_04() internal {
        if (states[1].rootBridgePaused) {
            fl.t(false, PAUSE_04);
        }
    }

    /**
     * @custom:invariant PAUSE-05: finaliseQueuedWithdrawal always reverts when the root bridge is paused
     */
    function invariant_PAUSE_05() internal {
        if (states[1].rootBridgePaused) {
            fl.t(false, PAUSE_05);
        }
    }

    /**
     * @custom:invariant PAUSE-06: finaliseQueuedWithdrawalAggregated always reverts when the root bridge is paused
     */
    function invariant_PAUSE_06() internal {
        if (states[1].rootBridgePaused) {
            fl.t(false, PAUSE_06);
        }
    }

    /**
     * @custom:invariant PAUSE-07: onMessageReceive for the root bridge always reverts when the root bridge is paused
     */
    function invariant_PAUSE_07() internal {
        if (states[1].rootBridgePaused) {
            fl.t(false, PAUSE_07);
        }
    }

    /**
     * @custom:invariant PAUSE-08: withdraw always reverts when the child bridge is paused
     */
    function invariant_PAUSE_08() internal {
        if (states[1].childBridgePaused) {
            fl.t(false, PAUSE_08);
        }
    }

    /**
     * @custom:invariant PAUSE-09: withdrawETH always reverts when the child bridge is paused
     */
    function invariant_PAUSE_09() internal {
        if (states[1].childBridgePaused) {
            fl.t(false, PAUSE_09);
        }
    }

    /**
     * @custom:invariant PAUSE-10: withdrawETHTo always reverts when the child bridge is paused
     */
    function invariant_PAUSE_10() internal {
        if (states[1].childBridgePaused) {
            fl.t(false, PAUSE_10);
        }
    }

    /**
     * @custom:invariant PAUSE-11: withdrawIMX always reverts when the child bridge is paused
     */
    function invariant_PAUSE_11() internal {
        if (states[1].childBridgePaused) {
            fl.t(false, PAUSE_11);
        }
    }

    /**
     * @custom:invariant PAUSE-12: withdrawIMXTo always reverts when the child bridge is paused
     */
    function invariant_PAUSE_12() internal {
        if (states[1].childBridgePaused) {
            fl.t(false, PAUSE_12);
        }
    }

    /**
     * @custom:invariant PAUSE-13: withdrawTo always reverts when the child bridge is paused
     */
    function invariant_PAUSE_13() internal {
        if (states[1].childBridgePaused) {
            fl.t(false, PAUSE_13);
        }
    }

    /**
     * @custom:invariant PAUSE-14: withdrawWIMX always reverts when the child bridge is paused
     */
    function invariant_PAUSE_14() internal {
        if (states[1].childBridgePaused) {
            fl.t(false, PAUSE_14);
        }
    }

    /**
     * @custom:invariant PAUSE-15: withdrawWIMXTo always reverts when the child bridge is paused
     */
    function invariant_PAUSE_15() internal {
        if (states[1].childBridgePaused) {
            fl.t(false, PAUSE_15);
        }
    }

    /**
     * @custom:invariant PAUSE-16: onMessageReceive for the child bridge always reverts when the child bridge is paused
     */
    function invariant_PAUSE_16() internal {
        if (states[1].childBridgePaused) {
            fl.t(false, PAUSE_16);
        }
    }
}
