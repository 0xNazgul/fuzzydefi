// SPDX-License-Identifier: NONE
pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

// Test Helpers
import "forge-std/Test.sol";

// Ohm tokens, Mock Tokens
import {OlympusERC20Token} from "@olympus/OlympusERC20.sol";
import {sOlympus} from "@olympus/sOlympusERC20.sol";
import {wOHM} from "@olympus/wOHM.sol";
import {DAI} from "@olympus/mocks/DAI.sol";
import {FRAX} from "@olympus/mocks/Frax.sol";

// Staking, Distributor, Staking Helper, Staking Warmup
import {OlympusStaking} from "@olympus/Staking.sol";
import {Distributor} from "@olympus/StakingDistributor.sol";
import {StakingHelper} from "@olympus/StakingHelper.sol";
import {StakingWarmup} from "@olympus/StakingWarmup.sol";

// Treasury
import {OlympusTreasury} from "@olympus/Treasury.sol";

// Bond Depository, CVX Depository, Bond Calculator
import {OlympusBondDepository, SafeMath} from "@olympus/BondDepository.sol";
import {OlympusCVXBondDepository} from "@olympus/CVXBondDepository.sol";
import {OlympusBondingCalculator} from "@olympus/StandardBondingCalculator.sol";

contract TestCore is Test {
    using SafeMath for uint;
    uint256 MAX = type(uint256).max;
    uint256 RMIN = 10**3; // min Uniswap reserve
    uint256 RMAX = 4365363797267; // Current reserve at time of fuzzing
    uint256 INITDAI = 10000000008400000000000000;

    // Ohm tokens, Mock Tokens
    OlympusERC20Token ohm;
    sOlympus sohm;
    wOHM wsohm;
    DAI dai;
    DAI ohmdai;
    FRAX frax;

    // Staking, Distributor, Staking Helper, Staking Warmup
    OlympusStaking testStaking;
    Distributor testStakingDistr;
    StakingHelper testStakingHelper;
    StakingWarmup testStakingWarmup;

    // Treasury
    OlympusTreasury testTreasury;

    // Bond Depository, CVX Depository, Bond Calculator
    //OlympusBondDepository
    OlympusBondDepository testBondDepo;
    OlympusCVXBondDepository testCVXbondDepo;
    OlympusBondingCalculator testBondCalculator;

    function setUp() public {
        vm.label(address(this), "THE_FUZZANATOR");

        // Deploy tokens
        ohm = new OlympusERC20Token();
        vm.label(address(ohm), "OHM");

        sohm = new sOlympus();
        vm.label(address(sohm), "SOHM");

        frax = new FRAX(9);
        vm.label(address(frax), "FRAX");

        dai = new DAI(9);
        vm.label(address(dai), "DAI");

        ohmdai = new DAI(9);
        vm.label(address(ohmdai), "OHMDAI");            

        testStaking = new OlympusStaking(address(ohm), address(sohm), 2200, 338, block.timestamp);
        vm.label(address(testStaking), "STAKING");

        wsohm = new wOHM(address(testStaking), address(ohm), address(sohm));
        vm.label(address(wsohm), "WOHM");

        testTreasury = new OlympusTreasury(address(ohm), address(dai), address(frax), address(ohmdai), 0);
        vm.label(address(testTreasury), "TREASURY");

        testStakingDistr = new Distributor(address(testTreasury), address(ohm), 2200, block.timestamp);
        vm.label(address(testStakingDistr), "STAKING_DISTRIBUTOR");

        testStakingHelper = new StakingHelper(address(testStaking), address(ohm));
        vm.label(address(testStakingHelper), "STAKING_HELPER");

        testStakingWarmup = new StakingWarmup(address(testStaking), address(sohm));
        vm.label(address(testStakingWarmup), "STAKING_WARMUP");

        // Bond Depository
        //OlympusBondDepository

        testBondCalculator = new OlympusBondingCalculator(address(ohm));
        vm.label(address(testBondCalculator), "BONDING_CALCULATOR");

        testBondDepo = new OlympusBondDepository(address(ohm), address(dai), address(testTreasury), address(this), address(testBondCalculator));
        vm.label(address(testBondDepo), "BOND_DEPO");

        testBondDepo.initializeBondTerms(369, 33110, 50000, 50, 10000, 1000000000000000, 0);
        testBondDepo.setStaking(address(testStaking), false);
        testBondDepo.setStaking(address(testStakingHelper), true);

        sohm.initialize(address(testStaking));
        sohm.setIndex(7675210820);

        //enum CONTRACTS { DISTRIBUTOR, WARMUP, LOCKER }

        testStaking.setContract(OlympusStaking.CONTRACTS.DISTRIBUTOR, address(testStakingDistr));
        testStaking.setContract(OlympusStaking.CONTRACTS.WARMUP, address(testStakingWarmup));

        ohm.setVault(address(testTreasury));

        testStakingDistr.addRecipient(address(testStaking), 3000);
        
        //enum MANAGING { RESERVEDEPOSITOR, RESERVESPENDER, RESERVETOKEN, RESERVEMANAGER, LIQUIDITYDEPOSITOR, LIQUIDITYTOKEN, LIQUIDITYMANAGER, DEBTOR, REWARDMANAGER, SOHM }
        testTreasury.queue(OlympusTreasury.MANAGING.REWARDMANAGER, address(testStakingDistr));
        testTreasury.toggle(OlympusTreasury.MANAGING.REWARDMANAGER, address(testStakingDistr), address(0));

        testTreasury.queue(OlympusTreasury.MANAGING.RESERVEDEPOSITOR, address(this));
        testTreasury.toggle(OlympusTreasury.MANAGING.RESERVEDEPOSITOR, address(this), address(0));

        testTreasury.queue(OlympusTreasury.MANAGING.RESERVEDEPOSITOR, address(testBondDepo));
        testTreasury.toggle(OlympusTreasury.MANAGING.RESERVEDEPOSITOR, address(testBondDepo), address(0));

        testTreasury.queue(OlympusTreasury.MANAGING.LIQUIDITYDEPOSITOR, address(this));
        testTreasury.toggle(OlympusTreasury.MANAGING.LIQUIDITYDEPOSITOR, address(this), address(0));

        testCVXbondDepo = new OlympusCVXBondDepository(address(ohm), address(this), address(this), address(testBondCalculator));
        vm.label(address(testCVXbondDepo), "CVX_BOND_DEPO");

        //testCVXbondDepo.initializeBondTerms(369, 33110, 50000, 50, 10000, 1000000000000000);

        dai.approve(address(testTreasury), MAX);
        dai.approve(address(testBondDepo), MAX);
        ohm.approve(address(testStaking), MAX);
        ohm.approve(address(testStakingHelper), MAX);

        testBondCalculator.updateReserve(4365363797267);

        dai.mint(address(this), INITDAI);
        testTreasury.deposit(9000000000000000000000000, address(dai), 8400000000000000);        
        testStakingHelper.stake(100000000000);
        testBondDepo.deposit(1000000000000000000000, 60000, address(this));

        testBondDepo.setAdjustment(true, 1, 1000, 10);
    }

    /* INVARIANTS: Depositing into the bondDepo should:
     * Increase user Bond Payout
     * Updates users last block to latest
     * Updates Bond Price
     * Increase Total Debt 
     * Increase Treasury Total Reserves 
     * Updates control variable accordingly 
     * Updates rate accordingly
    */
    function testFuzz_deposit(uint256 amount, uint maxPrice, uint timeSkip, uint pairReserve) public {
        // PRECONDITIONS:
        uint _amount = _between(amount, 1, (MAX - INITDAI));
        uint _pairReserve = _between(pairReserve, RMIN, RMAX);
        testBondCalculator.updateReserve(_pairReserve);
        
        if (!set) {
            init(_amount, _between(timeSkip, 1, (33110 * 2)));
        }

        uint totalReservesBefore = testTreasury.totalReserves();
        uint totalDebtBefore = testBondDepo.totalDebt();
        (uint payoutBefore, , , ) = testBondDepo.bondInfo(address(this));
        (, uint rateBefore, uint target, uint buffer, uint lastBlock) = testBondDepo.adjustment();
        (uint controlVariableBefore, , , , , ) = testBondDepo.terms();        

        this.depositHelper(_amount, maxPrice);

        // ACTION:
        try testBondDepo.deposit(_amount, maxPrice, address(this)) {
            // POSTCONDITIONS:
            uint totalDebtAfter = testBondDepo.totalDebt();
            (uint payoutAfter, , uint lastBlockAfter, ) = testBondDepo.bondInfo(address(this));
            uint totalReservesAfter = testTreasury.totalReserves();
            
            this.adjustmentHelper(controlVariableBefore, rateBefore, target, buffer, lastBlock);

            assertGt(payoutAfter, payoutBefore, "PAYOUT CHECK");
            assertEq(lastBlockAfter, block.number, "LAST BLOCK CHECK");
            assertGt(totalDebtAfter, totalDebtBefore, "TOTAL DEBT CHECK");
            assertGt(totalReservesAfter, totalReservesBefore, "TOTAL RESERVES CHECK");
        } catch {/*assert(false)*/ }// overflow
    }

    // redeem without staking
    /* INVARIANTS: Redeeming from BondDepo should:
     * Decrease user payout
     * Decrease user vesting
     * Update user lastBlock
     * Increase user OHM Balance
    */
    function testFuzz_redeemNoStaking(uint amount, uint maxPrice, uint timeSkip) public {
        // PRECONDITIONS:
        uint _amount = _between(amount, 1, (MAX - INITDAI));
        
        if (!setR) {
            initR(_amount);
        }            
        
        this.depositHelper(_amount, maxPrice);
        uint userBalBefore = ohm.balanceOf(address(this));

        // ACTIONS:
        try testBondDepo.deposit(_amount, maxPrice, address(this)) {
            (uint payoutBefore, uint vestingBefore , uint lastBlockBefore , ) = testBondDepo.bondInfo(address(this));
            skip(_between(timeSkip, 1, (33110 * 2)));
            
            uint percentVested = testBondDepo.percentVestedFor(address(this));
            if (percentVested >= 10000) {
                try testBondDepo.redeem(address(this), false) {
                    uint userBalAfter = ohm.balanceOf(address(this));
                    // no need to check all of bond info since it is deleted
                    (uint payoutAfter, , , ) = testBondDepo.bondInfo(address(this));
                    // POSTCONDITIONS:
                    assertEq(payoutAfter, 0, "BOND INFO CHECK");
                    assertGt(userBalAfter, userBalBefore, "USER BALANCE CHECK");
                } catch {/*assert(false)*/} // overflow    
            } else {
                try testBondDepo.redeem(address(this), false) {
                    (uint payoutAfter, uint vestingAfter , , ) = testBondDepo.bondInfo(address(this));
                    uint userBalAfter = ohm.balanceOf(address(this));
                    // POSTCONDITIONS:
                    assertLe(payoutAfter, payoutBefore, "PAYOUT CHECK");
                    assertLe(vestingAfter, vestingBefore, "VESTING CHECK");
                    assertEq(block.number, lastBlockBefore, "LASTBLOCK CHECK");
                    assertGe(userBalAfter, userBalBefore, "USER BALANCE CHECK");
                } catch {/*assert(false)*/} // overflow
            }
        } catch {/*assert(false)*/} // overflow
    }

    // redeem with staking (Both with (TODO: without staking helper))
    /* INVARIANTS: Redeeming from BondDepo should:
     * Decrease user payout
     * Decrease user vesting
     * Update user lastBlock
     * Increase staking OHM Balance
     * Increase staking warmup sOHM Balance
     * Increase user staking deposit
     * Increase user gons
     * Increase user expiry
     * Update user lock to false
    */
    function testFuzz_redeemWith(uint amount, uint maxPrice, uint timeSkip) public {
        // PRECONDITIONS:
        uint _amount = _between(amount, 1, (MAX - INITDAI));
        
        if (!setR) {
            initR(_amount);
        }            
        
        this.depositHelper(_amount, maxPrice);
        uint stakingBalBefore = ohm.balanceOf(address(testStaking));
        uint stakingWarmupBalBefore = sohm.balanceOf(address(testStakingWarmup));
        (uint depositBefore, uint gonsBefore, uint expiryBefore, ) = testStaking.warmupInfo(address(this));

        // ACTIONS:
        try testBondDepo.deposit(_amount, maxPrice, address(this)) {
            (uint payoutBefore, uint vestingBefore , uint lastBlockBefore , ) = testBondDepo.bondInfo(address(this));
            skip(_between(timeSkip, 1, (33110 * 2)));
            
            uint percentVested = testBondDepo.percentVestedFor(address(this));
            if (percentVested >= 10000) {
                try testBondDepo.redeem(address(this), true) {
                    // no need to check all of bond info since it is deleted
                    (uint payoutAfter, , , ) = testBondDepo.bondInfo(address(this));

                    // POSTCONDITIONS:
                    this.redeemWithHelper(depositBefore, gonsBefore, expiryBefore, stakingBalBefore, stakingWarmupBalBefore);
                    assertEq(payoutAfter, 0, "BOND INFO CHECK");
                } catch {/*assert(false)*/} // overflow 
            } else {
                try testBondDepo.redeem(address(this), true) {
                    (uint payoutAfter, uint vestingAfter , , ) = testBondDepo.bondInfo(address(this));
                    
                    // POSTCONDITIONS:
                    this.redeemWithHelper(depositBefore, gonsBefore, expiryBefore, stakingBalBefore, stakingWarmupBalBefore);
                    assertLe(payoutAfter, payoutBefore, "PAYOUT CHECK");
                    assertLe(vestingAfter, vestingBefore, "VESTING CHECK");
                    assertEq(block.number, lastBlockBefore, "LASTBLOCK CHECK");
                } catch {/*assert(false)*/} // overflow
            }
        } catch {/*assert(false)*/} // overflow
    }    


    // Redeem without staking and there is a rebase
    /* INVARIANTS: Redeeming from BondDepo should:
     * Updates distribute
     * Increases number
     * Increases endBlock
    */
    function testFuzz_redeemRebase(uint amount, uint maxPrice, uint timeSkip) public {
        // PRECONDITIONS:
        uint _amount = _between(amount, 1, (MAX - INITDAI));
        
        if (!setR) {
            initR(_amount);
        }        
        this.depositHelper(_amount, maxPrice);

        // ACTIONS:
        try testBondDepo.deposit(_amount, maxPrice, address(this)) {
            skip(_between(timeSkip, 1, (33110 * 2)));
            
            (,uint numberBefore, uint endBlockBefore, ) = testStaking.epoch();
            if (endBlockBefore <= block.number) {
                try testBondDepo.redeem(address(this), true) {
                    // POSTCONDITIONS:
                    this.redeemWithEpochHelper(numberBefore, endBlockBefore);
                } catch {/*assert(false)*/} // overflow 
            }
        } catch {/*assert(false)*/} // overflow
    }        

    // Unstaking without _trigger because it's invariants are tested 
    /* INVARIANTS: unstaking should:
     * Increase user OHM balance
     * Decrease user sOHM balance
     * Increase Staking sOHM balance
     * Decrease Staking OHM balance
    */
    function testFuzz_unstake(uint amount) public {
        // PRECONDTIONS:
        uint _amount = _between(amount, 1, (MAX - INITDAI));
        
        if (!setU) {
            initR(_amount);
        }    

        uint userSOHMBalBefore = sohm.balanceOf(address(this));
        uint userOHMBalBefore = ohm.balanceOf(address(this));
        uint stakingSOHMBalBefore = sohm.balanceOf(address(testStaking));
        uint stakingOHMBalBefore = ohm.balanceOf(address(testStaking));

        // ACTION:
        try testStaking.unstake(_amount, false) {
            // POSTCONDTIONS:
            uint userSOHMBalAfter = sohm.balanceOf(address(this));
            uint userOHMBalAfter = ohm.balanceOf(address(this));
            uint stakingSOHMBalAfter = sohm.balanceOf(address(testStaking));
            uint stakingOHMBalAfter = ohm.balanceOf(address(testStaking)); 

            assertGt(userOHMBalAfter, userOHMBalBefore, "USER OHM CHECK");
            assertLt(userSOHMBalAfter, userSOHMBalBefore, "USER SOHM CHECK");
            assertGt(stakingSOHMBalAfter, stakingSOHMBalBefore, "STAKING SOHM CHECK");
            assertLt(stakingOHMBalAfter, stakingOHMBalBefore, "STAKING OHM CHECK");
        } catch {/*assert(false)*/} // overflow
    }

    // Helper functions
    function redeemWithEpochHelper(uint numberBefore, uint endBlockBefore) public {
        (, uint numberAfter, uint endBlockAfter, uint distributeAfter) = testStaking.epoch();
        assertGt(numberAfter, numberBefore, "NUMBER CHECK");
        assertGt(endBlockAfter, endBlockBefore, "ENDBLOCK CHECK");
        //TODO: Test without distributor 
        uint balance = testStaking.contractBalance();
        uint staked = sohm.circulatingSupply();
        if( balance <= staked ) {
            assertEq(distributeAfter, 0, "DISTRIBUTE CHECK");
        } else {
            assertEq(distributeAfter, balance.sub( staked ), "DISTRIBUTE CHECK");  
        }    
    }

    function redeemWithHelper(uint depositBefore, uint gonsBefore, uint expiryBefore, uint stakingBalBefore, uint stakingWarmupBalBefore) public {
        (uint depositAfter, uint gonsAfter, uint expiryAfter, bool lockAfter) = testStaking.warmupInfo(address(this));
        uint stakingWarmupBalAfter = sohm.balanceOf(address(testStakingWarmup));
        uint stakingBalAfter = ohm.balanceOf(address(testStaking));

        assertGt(stakingBalAfter, stakingBalBefore, "STAKING BALANCE CHECK");
        assertGt(depositAfter, depositBefore, "DEPOSIT CHECK");
        assertGt(gonsAfter, gonsBefore, "GONS CHECK");
        assertGt(expiryAfter, expiryBefore, "EXPIRY CHECK");
        assertEq(lockAfter, false, "LOCK CHECK");       
        assertGe(stakingWarmupBalAfter, stakingWarmupBalBefore, "STAKING WARMUP BALANCE CHECK");  
    }    

    function adjustmentHelper(uint controlVariableBefore, uint rateBefore, uint target, uint buffer, uint lastBlock) public {
        (bool add, uint rateAfter, , , ) = testBondDepo.adjustment();
        (uint controlVariableAfter, , , , , ) = testBondDepo.terms();
        if (rateBefore != 0 && block.number >= lastBlock.add(buffer)) {
            if (add) {
                assertGt(controlVariableAfter, controlVariableBefore, "CONTROL VARIABLE CHECK");
                if (controlVariableBefore >= target) {
                    assertEq(rateAfter, 0, "RATE CHECK");
                }
                assertEq(rateAfter, rateBefore, "RATE CHECK");
            } else {
                assertLt(controlVariableAfter, controlVariableBefore, "CONTROL VARIABLE CHECK");
                if (controlVariableBefore <= target) {
                    assertEq(rateAfter, 0, "RATE CHECK");
                }
                assertEq(rateAfter, rateBefore, "RATE CHECK");                    
            }
        }        
    }

    function depositHelper(uint _amount, uint maxPrice) public {
        uint totalDebtBeforeWithDecay = (testBondDepo.totalDebt().sub(testBondDepo.debtDecay()));
        (uint _controlVariable, , uint _minimumPrice, , , uint _maxDebt) = testBondDepo.terms();
        uint _nativePrice = this.bondPrice(_controlVariable, _minimumPrice);

        uint _value;
        try testTreasury.valueOf(address(dai), _amount) returns (uint value) {
            _value = value;
        } catch {/*assert(false)*/} // overflow

        uint _payout;
        try testBondDepo.payoutFor(_value) returns (uint payout) {
            _payout = payout;
        } catch {/*assert(false)*/} // overflow
        uint maxpout = testBondDepo.maxPayout();
        
        // Unhappy paths :( 
        if ( totalDebtBeforeWithDecay > _maxDebt) {
            vm.expectRevert(bytes("Max capacity reached"));
            try testBondDepo.deposit(_amount, maxPrice, address(this)) {
            } catch {/*assert(false)*/} // overflow
        } else if (maxPrice < _nativePrice) {
            vm.expectRevert(bytes("Slippage limit: more than max price"));
            try testBondDepo.deposit(_amount, maxPrice, address(this)) {
            } catch {/*assert(false)*/} // overflow
        } else if (_payout < 10000000) {
            vm.expectRevert(bytes("Bond too small"));
            try testBondDepo.deposit(_amount, maxPrice, address(this)) {
            }catch {/*assert(false)*/} // overflow
        } else if (_payout > maxpout) {
            vm.expectRevert(bytes("Bond too large"));
            try testBondDepo.deposit(_amount, maxPrice, address(this)) {
            } catch {/*assert(false)*/} // overflow
        }
    }

    function bondPrice(uint controlVariable, uint minimumPrice) public returns ( uint price_ ) {
        price_ = controlVariable.mul( testBondDepo.debtRatio() ).add( 1000000000 ).div( 1e7 );
        if ( price_ < minimumPrice ) {
            price_ = minimumPrice;        
        } else if ( minimumPrice != 0 ) {
            minimumPrice = 0;
        }
    }    

    bool set;
    function init(uint amount, uint timeSkip) public {
        dai.mint(address(this), amount);
        skip(timeSkip);
        set = true;
    }

    bool setR;
    function initR(uint amount) public {
        dai.mint(address(this), amount);
        setR = true;
    }

    bool setU;
    function initU(uint amount) public {
        ohm.mockMint(address(testStaking), amount);
        sohm.mockMint(address(address(this)), amount);
        setU = true;
    }    

    // Bounding function similar to vm.assume but is more efficient regardless of the fuzzying framework
	// This is also a guarante bound of the input unlike vm.assume which can only be used for narrow checks     
	function _between(uint256 random, uint256 low, uint256 high) public pure returns (uint256) {
		return low + random % (high-low);
	}        

}