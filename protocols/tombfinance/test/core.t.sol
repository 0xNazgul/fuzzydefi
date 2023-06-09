// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.0;
pragma experimental ABIEncoderV2;

// Test Helpers
import "@tomb/interfaces/IUniswapV2Pair.sol";
import {MockUniPair} from "./MockUniPair.sol";
import "forge-std/Test.sol";

// Mock tokens
import "./MockWeth.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@tomb/DummyToken.sol";

// Protocol Tokens
import {Tomb} from "@tomb/Tomb.sol";
import {TBond} from "@tomb/TBond.sol";
import {TShare} from "@tomb/TShare.sol";
import {TaxOffice} from "@tomb/TaxOffice.sol";

// Timelock, Treasury, Oracle, Masonry
import {Timelock} from  "@tomb/Timelock.sol";
import {Treasury} from "@tomb/Treasury.sol";
import "@tomb/interfaces/ITreasury.sol";
import {Oracle} from "@tomb/Oracle.sol";
import {Masonry} from "@tomb/Masonry.sol";

// Distruibution Pools, Distributor
import {TombGenesisRewardPool} from "@tomb/distribution/TombGenesisRewardPool.sol";
import {TombRewardPool} from "@tomb/distribution/TombRewardPool.sol";
import {TShareRewardPool} from "@tomb/distribution/TShareRewardPool.sol";
import {Distributor} from "@tomb/Distributor.sol";
import "@tomb/interfaces/IDistributor.sol";

contract CoreTest is MockUniPair, Test {
    uint256 MAX = type(uint256).max;
    uint256 INITR = 100000000000000 + 1 ether; // Initial reserve of tomb minted in setup process
    uint INIT = 10**4; // Just above initial reserve for Uniswap
    address RANDO = address(0x8008);
    address COMMUNITYFUND = address(0x8007);
    address DEVFUND = address(0x8006);

    // Mocks
    MockWETH weth;
    DummyToken shiba;
    DummyToken usdt;
    DummyToken usdc;

    // Protocol Tokens, TaxOffice
    TBond tbond;
    Tomb tomb;
    TShare tshare;
    TaxOffice testTaxOffice;    

    // Distruibution Pools, Distributor
    TombGenesisRewardPool testTombGenesisRewardPool;
    TombRewardPool testTombRewardPool;
    TShareRewardPool testTShareRewardPool;
    Distributor testDistributor;

    // Pair
    address tombWethPair;
    address usdtUsdcPair;   

    // Timelock, Treasury, Oracle, Masonry
    Timelock testTimelock;
    Treasury testTreasury;
    Oracle testOracle;
    Masonry testMasonry;

    function setUp() public {
        vm.label(address(this), "THE_FUZZANATOR");
        vm.label(address(RANDO), "RANDO_USER");
        
        // Dummy funds 
        vm.label(address(0x8008), "COMMUNITY_FUND");
        vm.label(address(0x8007), "DEV_FUND");

        // Deploy Mocks
        weth = new MockWETH();
        vm.label(address(weth), "WETH");
        
        shiba = new DummyToken("SHIBA", "SHIBA", 18);
        vm.label(address(shiba), "SHIBA");

        usdc = new DummyToken("USDC", "USDC", 18);
        vm.label(address(usdc), "USDC");

        usdt = new DummyToken("USDT", "USDT", 6);
        vm.label(address(usdt), "USDT");

        // Deploy Protocol Tokens, TaxOffice
        tomb = new Tomb(1, address(this));
        vm.label(address(tomb), "TOMB");

        testTaxOffice = new TaxOffice(address(tomb));
        vm.label(address(testTaxOffice), "TOMB");        

        tomb.setTaxOffice(address(testTaxOffice));

        tbond = new TBond();
        vm.label(address(tbond), "TBOND");
        
        tshare = new TShare(block.timestamp, COMMUNITYFUND, DEVFUND);
        vm.label(address(tbond), "TSHARE");

        // Deploy Distruibution Pools, Distributor
        testTombGenesisRewardPool = new TombGenesisRewardPool(address(tomb), address(shiba), block.timestamp + 1);
        vm.label(address(testTombGenesisRewardPool), "TOMB_GENESIS_POOL");

        testTombRewardPool = new TombRewardPool(address(tomb), block.timestamp + 1);
        vm.label(address(testTombRewardPool), "TOMB_POOL");

        testTShareRewardPool = new TShareRewardPool(address(tshare), block.timestamp + 1);
        vm.label(address(testTShareRewardPool), "TSHARE_POOL");

        IDistributor[] memory pools = new IDistributor[](3);
        pools[0] = IDistributor(address(testTombGenesisRewardPool));
        pools[1] = IDistributor(address(testTombRewardPool));
        pools[2] = IDistributor(address(testTShareRewardPool));
        testDistributor = new Distributor(pools);
        vm.label(address(testDistributor), "DISTRIBUTOR");
        
        // Deploy mock Pairs and reserves
        (address _testPair) = this.deployPair(address(tomb), address(weth));
        tombWethPair = _testPair;  
        vm.label(address(tombWethPair), "TOMB-WETH_PAIR");

        (address _testPair2) = this.deployPair(address(usdt), address(usdc));
        usdtUsdcPair = _testPair2;  
        vm.label(address(usdtUsdcPair), "USDT-USDC_PAIR");        

        // Setup TOMB-WETH reserves
        vm.deal(address(this), INITR);
        weth.deposit{value: INITR}();
        weth.transfer(address(tombWethPair), INITR);
        tomb.mint(address(this), INITR);
        tomb.transfer(address(tombWethPair), INITR);
        IUniswapV2Pair(tombWethPair).mint(address(this));

        // Setup USDT-USDC reserves
        usdt.mint(address(this), INIT);
        usdt.transfer(address(usdtUsdcPair), INIT);
        usdc.mint(address(this), INIT);
        usdc.transfer(address(usdtUsdcPair), INIT);
        IUniswapV2Pair(usdtUsdcPair).mint(address(this));

        // Add LP token to reward pools
        testTombGenesisRewardPool.add(1, IERC20(usdtUsdcPair), false, 0);
        testTombRewardPool.add(1, IERC20(usdtUsdcPair), false, 0);
        testTShareRewardPool.add(1, IERC20(usdtUsdcPair), false, 0);           

        // Timelock, Treasury, Oracle, Masonry, TaxOffice
        testTimelock = new Timelock(address(this), 1 days);
        vm.label(address(testTimelock), "TIMELOCK");

        testTreasury = new Treasury();
        vm.label(address(testTreasury), "TREASURY");        

        testOracle = new Oracle(IUniswapV2Pair(address(_testPair)), 1, block.timestamp);
        vm.label(address(testOracle), "ORACLE");

        tomb.setTombOracle(address(testOracle));
        testOracle.update();
        skip(86400);

        testMasonry = new Masonry();
        vm.label(address(testMasonry), "MASONRY");


        // Finish initialize setup
        testMasonry.initialize(IERC20(address(tomb)), IERC20(address(tshare)), ITreasury(address(testTreasury)));
        testTreasury.initialize(address(tomb), address(tbond), address(tshare), address(testOracle), address(testMasonry), block.timestamp);
    }

    function testON() public {}

    /* INVARIANTS: Tomb mint should:
     * Increase User Balance
     * Increase Total Supply 
    */
    function testFuzz_TombMint(uint256 _amount) public {
        // PRECONDITIONS:
        uint256 amount = _between(_amount, 1, MAX - INITR);
        uint256 userBalBefore = tomb.balanceOf(address(this));
        uint256 totalSupplyBefore =  tomb.totalSupply();

        // ACTION:
        try tomb.mint(address(this), amount) {
            // POSTCONDTIONS:
            uint256 userBalAfter = tomb.balanceOf(address(this));
            uint256 totalSupplyAfter =  tomb.totalSupply();
            
            assertGt(userBalAfter, userBalBefore, "USER BAL CHECK");
            assertGt(totalSupplyAfter, totalSupplyBefore, "TOTAL SUPPLY CHECK");
        } catch {/*assert(false)*/ }// overflow
    }

    /* INVARIANTS: Tomb burn should:
     * Decrease User Balance
     * Decrease Total Supply 
    */
    function testFuzz_TombBurn(uint256 _amount) public {
        // PRECONDITIONS:
        uint256 amount = _between(_amount, 1, MAX - INITR);
        if (!setTomb) {
            initTomb(amount);
        }  

        uint256 userBalBefore = tomb.balanceOf(address(this));
        uint256 totalSupplyBefore =  tomb.totalSupply();

        // ACTION:
        try tomb.burn(amount) {
            // POSTCONDTIONS:
            uint256 userBalAfter = tomb.balanceOf(address(this));
            uint256 totalSupplyAfter =  tomb.totalSupply();
            
            assertLt(userBalAfter, userBalBefore, "USER BAL CHECK");
            assertLt(totalSupplyAfter, totalSupplyBefore, "TOTAL SUPPLY CHECK");
        } catch {/*assert(false)*/ }// overflow
    }
    
    /* INVARIANTS: Tomb burnfrom should:
     * Decrease User Balance
     * Decrease Total Supply 
    */
    function testFuzz_TombBurnFrom(uint256 _amount) public {
        // PRECONDITIONS:
        uint256 amount = _between(_amount, 1, MAX - INITR);
        if (!setTomb) {
            initTomb(amount);
        }  

        uint256 userBalBefore = tomb.balanceOf(address(this));
        uint256 totalSupplyBefore =  tomb.totalSupply();

        // ACTION:
        try tomb.burnFrom(address(this), amount) {
            // POSTCONDTIONS:
            uint256 userBalAfter = tomb.balanceOf(address(this));
            uint256 totalSupplyAfter =  tomb.totalSupply();
            
            assertLt(userBalAfter, userBalBefore, "USER BAL CHECK");
            assertLt(totalSupplyAfter, totalSupplyBefore, "TOTAL SUPPLY CHECK");
        } catch {/*assert(false)*/ }// overflow
    }

    /* INVARIANTS: Tomb transferFrom without autoCalculateTax & currentTaxRate == 0 should:
     * Decrease from User Balance
     * Increase to User Balance
     * Total Supply should remain the same
    */
    function testFuzz_TombTransferFrom(uint256 _amount) public {
        // PRECONDITIONS:
        uint256 amount = _between(_amount, 1, MAX - INITR);
        if (!setTomb) {
            initTomb(amount);
        }  

        uint256 userBalBefore = tomb.balanceOf(address(this));
        uint256 otherUserBalBefore = tomb.balanceOf(address(RANDO));
        uint256 totalSupplyBefore =  tomb.totalSupply();

        // ACTION:
        try tomb.transferFrom(address(this), address(RANDO), amount) {
            // POSTCONDTIONS:
            uint256 userBalAfter = tomb.balanceOf(address(this));
            uint256 otherUserBalAfter = tomb.balanceOf(address(RANDO));
            uint256 totalSupplyAfter =  tomb.totalSupply();
            
            assertLt(userBalAfter, userBalBefore, "USER BAL CHECK");
            assertGt(otherUserBalAfter, otherUserBalBefore, "OTHER USER BAL CHECK");
            assertEq(totalSupplyAfter, totalSupplyBefore, "TOTAL SUPPLY CHECK");
        } catch {/*assert(false)*/ }// overflow
    }

    //TODO get consult to return > 0
    /* INVARIANTS: Tomb transferFrom with autoCalculateTax should:
     * Decrease from User Balance
     * Increase to User Balance
     * Decrease Total Supply 
    */
    function testFuzz_TombTaxTransferFrom(uint256 _amount) public {
        // PRECONDITIONS:
        testTaxOffice.enableAutoCalculateTax();
        uint256 amount = _between(_amount, 1, MAX - INITR);
        if (!setTomb) {
            initTomb(amount);
            skip(86400);
            testOracle.update();
            tomb.approve(address(tomb), amount);
        }  

        uint256 userBalBefore = tomb.balanceOf(address(this));
        uint256 otherUserBalBefore = tomb.balanceOf(address(RANDO));
        uint256 totalSupplyBefore =  tomb.totalSupply();

        // ACTION:
        try tomb.transferFrom(address(this), address(RANDO), amount) {
            // POSTCONDTIONS:
            uint256 userBalAfter = tomb.balanceOf(address(this));
            uint256 otherUserBalAfter = tomb.balanceOf(address(RANDO));
            uint256 totalSupplyAfter =  tomb.totalSupply();
            
            assertLt(userBalAfter, userBalBefore, "USER BAL CHECK");
            assertGt(otherUserBalAfter, otherUserBalBefore, "OTHER USER BAL CHECK");
            assertLt(totalSupplyAfter, totalSupplyBefore, "TOTAL SUPPLY CHECK");
        } catch {/*assert(false)*/ }// overflow
    }    

    /* INVARIANTS: TBond mint should:
     * Increase User Balance
     * Increase Total Supply 
    */
    function testFuzz_TBondMint(uint256 _amount) public {
        // PRECONDITIONS:
        uint256 amount = _between(_amount, 1, MAX);
        uint256 userBalBefore = tbond.balanceOf(address(this));
        uint256 totalSupplyBefore =  tbond.totalSupply();

        // ACTION:
        try tbond.mint(address(this), amount) {
            // POSTCONDTIONS:
            uint256 userBalAfter = tbond.balanceOf(address(this));
            uint256 totalSupplyAfter =  tbond.totalSupply();
            
            assertGt(userBalAfter, userBalBefore, "USER BAL CHECK");
            assertGt(totalSupplyAfter, totalSupplyBefore, "TOTAL SUPPLY CHECK");
        } catch {/*assert(false)*/ }// overflow
    }

    /* INVARIANTS: TBond burn should:
     * Decrease User Balance
     * Decrease Total Supply 
    */
    function testFuzz_TBondBurn(uint256 _amount) public {
        // PRECONDITIONS:
        uint256 amount = _between(_amount, 1, MAX);
        if (!setTbond) {
            initTbond(amount);
        }  

        uint256 userBalBefore = tbond.balanceOf(address(this));
        uint256 totalSupplyBefore =  tbond.totalSupply();

        // ACTION:
        try tbond.burn(amount) {
            // POSTCONDTIONS:
            uint256 userBalAfter = tbond.balanceOf(address(this));
            uint256 totalSupplyAfter =  tbond.totalSupply();
            
            assertLt(userBalAfter, userBalBefore, "USER BAL CHECK");
            assertLt(totalSupplyAfter, totalSupplyBefore, "TOTAL SUPPLY CHECK");
        } catch {/*assert(false)*/ }// overflow
    }
    
    /* INVARIANTS: TBond burnfrom should:
     * Decrease User Balance
     * Decrease Total Supply 
    */
    function testFuzz_TBondBurnFrom(uint256 _amount) public {
        // PRECONDITIONS:
        uint256 amount = _between(_amount, 1, MAX);
        if (!setTbond) {
            initTbond(amount);
        }

        uint256 userBalBefore = tbond.balanceOf(address(this));
        uint256 totalSupplyBefore =  tbond.totalSupply();

        // ACTION:
        try tbond.burnFrom(address(this), amount) {
            // POSTCONDTIONS:
            uint256 userBalAfter = tbond.balanceOf(address(this));
            uint256 totalSupplyAfter =  tbond.totalSupply();
            
            assertLt(userBalAfter, userBalBefore, "USER BAL CHECK");
            assertLt(totalSupplyAfter, totalSupplyBefore, "TOTAL SUPPLY CHECK");
        } catch {/*assert(false)*/ }// overflow
    }     
    
    /* INVARIANTS: Depositing into TombGenesisRewardPool Should: 
     * Update pool reward variables
     * Decrease User bal of token
     * Update User rewardDebt
     * Increase user bal amount
    */   
    function testFuzz_tombGenesisRewardPoolDeposit(uint256 _amount, uint256 skipNum) public {
        // PRECONDITIONS:
        uint256 amount = _between(_amount, 1, MAX);

        uint totalAllocPointBefore = testTombGenesisRewardPool.totalAllocPoint();
        uint userTombBalBefore = tomb.balanceOf(address(this));
        uint userTokenBalBefore = IUniswapV2Pair(usdtUsdcPair).balanceOf(address(this));
        (uint userAmountBefore, uint userRewardDebtBefore) = testTombGenesisRewardPool.userInfo(1, address(this));
        (IERC20 token, uint256 allocPointBefore, uint256 lastRewardTimeBefore, uint256 accTombPerShareBefore, bool isStartedBefore) = testTombGenesisRewardPool.poolInfo(0);

        if (!setReserves) {
            initReserves(amount);

            // Don't want the pool to run out of tomb
            if (tomb.balanceOf(address(testTombGenesisRewardPool)) >  userAmountBefore * accTombPerShareBefore / 1e18 - userRewardDebtBefore) {
                tomb.mint(address(testTombGenesisRewardPool), amount);
            }
            skip(skipNum);
        }       

        // ACTION:
        try testTombGenesisRewardPool.deposit(0, amount) {
            // POSTCONDTIONS:
            if (userAmountBefore > 0) {
                uint userTombBalAfter = tomb.balanceOf(address(this));
                assertGt(userTombBalAfter, userTombBalBefore, "USER TOMB BAL CHECK");
            }
            (uint userAmountAfter, uint userRewardDebtAfter) = testTombGenesisRewardPool.userInfo(1, address(this));
            this.genesisPoolUpdateHelper(totalAllocPointBefore, userTokenBalBefore, userRewardDebtBefore, token, allocPointBefore, lastRewardTimeBefore, accTombPerShareBefore, isStartedBefore, userRewardDebtAfter, false);
            
            assertGt(userAmountAfter, userAmountBefore, "USER BAL CHECK");
            assertGt(userRewardDebtAfter, userRewardDebtBefore, "USER REWARD CHECK");
        } catch {/*assert(false)*/ }// overflow
    }

    /* INVARIANTS: Withdrawing from TombGenesisRewardPool Should: 
     * Update pool reward variables
     * Increase User bal of token
     * Update User rewardDebt
     * Decrease user bal amount
    */     
    function testFuzz_tombGenesisRewardPoolWithdraw(uint _amount, uint256 skipNum) public {
        // PRECONDITIONS:
        uint256 amount = _between(_amount, 1, MAX);

        uint totalAllocPointBefore = testTombGenesisRewardPool.totalAllocPoint();
        uint userTombBalBefore = tomb.balanceOf(address(this));
        uint userTokenBalBefore = IUniswapV2Pair(usdtUsdcPair).balanceOf(address(this));
        (uint userAmountBefore, uint userRewardDebtBefore) = testTombGenesisRewardPool.userInfo(1, address(this));
        (IERC20 token, uint256 allocPointBefore, uint256 lastRewardTimeBefore, uint256 accTombPerShareBefore, bool isStartedBefore) = testTombGenesisRewardPool.poolInfo(0);

        if (!setReserves) {
            initReserves(amount);

            // Don't want the pool to run out of tomb
            if (tomb.balanceOf(address(testTombGenesisRewardPool)) >  userAmountBefore * accTombPerShareBefore / 1e18 - userRewardDebtBefore) {
                tomb.mint(address(testTombGenesisRewardPool), amount);
            }
            skip(skipNum);
        }    
           
        try testTombGenesisRewardPool.deposit(0, amount) {
            // ACTION:
            try testTombGenesisRewardPool.withdraw(0, amount) {
                // POSTCONDTIONS:
                if (userAmountBefore > 0) {
                    uint userTombBalAfter = tomb.balanceOf(address(this));
                    assertGt(userTombBalAfter, userTombBalBefore, "USER TOMB BAL CHECK");
                }
                (uint userAmountAfter, uint userRewardDebtAfter) = testTombGenesisRewardPool.userInfo(1, address(this));
                this.genesisPoolUpdateHelper(totalAllocPointBefore, userTokenBalBefore, userRewardDebtBefore, token, allocPointBefore, lastRewardTimeBefore, accTombPerShareBefore, isStartedBefore, userRewardDebtAfter, true);
            
                assertLt(userAmountAfter, userAmountBefore, "USER BAL CHECK");
                assertGt(userRewardDebtAfter, userRewardDebtBefore, "USER REWARD CHECK");
            } catch {/*assert(false)*/ }// overflow        
        } catch {/*assert(false)*/ }// overflow        
    }

    /* INVARIANTS: Emergency withdrawing from TombGenesisRewardPool Should: 
     * Increase User bal of token
     * Decrease User rewardDebt
     * Decrease user bal amount
    */ 
    function testFuzz_tombGenesisRewardPoolEmergencyWithdraw(uint _amount) public {
        // PRECONDITIONS:
        uint256 amount = _between(_amount, 1, MAX);

        uint userTokenBalBefore = IUniswapV2Pair(usdtUsdcPair).balanceOf(address(this));
        if (!setReserves) {
            initReserves(amount);
        }    
           
        try testTombGenesisRewardPool.deposit(0, amount) {
            // ACTION:
            try testTombGenesisRewardPool.emergencyWithdraw(0) {
                // POSTCONDTIONS:
                (uint userAmountAfter, uint userRewardDebtAfter) = testTombGenesisRewardPool.userInfo(1, address(this));
                uint userTokenBalAfter = IUniswapV2Pair(usdtUsdcPair).balanceOf(address(this));
                assertGt(userTokenBalAfter, userTokenBalBefore, "USER TOKEN BAL CHECK");
                assertEq(userAmountAfter, 0, "USER BAL CHECK");
                assertEq(userRewardDebtAfter, 0, "USER REWARD CHECK");
            } catch {/*assert(false)*/ }// overflow        
        } catch {/*assert(false)*/ }// overflow            
    }

    /* INVARIANTS: TombGenesisRewardPool Governance recover Should: 
     * Decrease contract bal of token
     * Increase to User bal of token
    */     
    function testFuzz_tombGenesisRewardPooGovernanceRecoverUnsupported(uint _amount, uint256 skipNum ) public {
        // PRECONDITIONS:
        uint256 amount = _between(_amount, 1, MAX);

        uint poolEndTime = testTombGenesisRewardPool.poolEndTime();
        uint userTombBalBefore = tomb.balanceOf(address(this));
        uint userTokenBalBefore = shiba.balanceOf(address(this));
        uint userLPTokenBalBefore = IUniswapV2Pair(usdtUsdcPair).balanceOf(address(this));
        if (!setReserves) {
            initReserves(amount);
            try tomb.mint(address(testTombGenesisRewardPool), amount) {}catch {/*assert(false)*/ }// overflow           
            try shiba.mint(address(testTombGenesisRewardPool), amount) {}catch {/*assert(false)*/ }// overflow           
            skip(skipNum);
        }    

        try testTombGenesisRewardPool.deposit(0, amount) {
            // ACTION:
            if (block.timestamp < poolEndTime + 90 days) {
                try testTombGenesisRewardPool.governanceRecoverUnsupported(IERC20(shiba), amount, address(this)) {
                    // POSTCONDTIONS:
                    uint userTokenBalAfter = shiba.balanceOf(address(this));
                    assertGt(userTokenBalAfter, userTokenBalBefore, "USER TOKEN BAL CHECK");                           
                } catch {/*assert(false)*/ }// overflow                      
            }
            try testTombGenesisRewardPool.governanceRecoverUnsupported(IERC20(usdtUsdcPair), amount, address(this)) {
                // POSTCONDTIONS:
                uint userLPTokenBalAfter = IUniswapV2Pair(usdtUsdcPair).balanceOf(address(this));
                assertGt(userLPTokenBalAfter, userLPTokenBalBefore, "USER TOKEN BAL CHECK");                           
            } catch {/*assert(false)*/ }// overflow
            try testTombGenesisRewardPool.governanceRecoverUnsupported(IERC20(tomb), amount, address(this)) {
                // POSTCONDTIONS:
                uint userTombBalAfter = tomb.balanceOf(address(this));
                assertGt(userTombBalAfter, userTombBalBefore, "USER TOMB BAL CHECK");                           
            } catch {/*assert(false)*/ }// overflow                                 
        } catch {/*assert(false)*/ }// overflow           
    }

    /* INVARIANTS: Depositing into TombRewardPool Should: 
     * Update pool reward variables
     * Decrease User bal of token
     * Increase User rewardDebt
     * Increase user bal amount
    */ 
    function testFuzz_tombRewardPoolDeposit(uint _amount, uint skipNum) public {
        // PRECONDITIONS:
        uint256 amount = _between(_amount, 1, MAX);

        uint totalAllocPointBefore = testTombRewardPool.totalAllocPoint();
        uint userTombBalBefore = tomb.balanceOf(address(this));
        uint userTokenBalBefore = IUniswapV2Pair(usdtUsdcPair).balanceOf(address(this));
        (uint userAmountBefore, uint userRewardDebtBefore) = testTombRewardPool.userInfo(1, address(this));
        (IERC20 token, uint256 allocPointBefore, uint256 lastRewardTimeBefore, uint256 accTombPerShareBefore, bool isStartedBefore) = testTombGenesisRewardPool.poolInfo(0);

        if (!setReserves) {
            initReserves(amount);

            // Don't want the pool to run out of tomb
            if (tomb.balanceOf(address(testTombRewardPool)) >  userAmountBefore * accTombPerShareBefore / 1e18 - userRewardDebtBefore) {
                tomb.mint(address(testTombRewardPool), amount);
            }
            skip(skipNum);
        }       

        // ACTION:
        try testTombRewardPool.deposit(0, amount) {
            // POSTCONDTIONS:
            if (userAmountBefore > 0) {
                uint userTombBalAfter = tomb.balanceOf(address(this));
                assertGt(userTombBalAfter, userTombBalBefore, "USER TOMB BAL CHECK");
            }
            (uint userAmountAfter, uint userRewardDebtAfter) = testTombRewardPool.userInfo(1, address(this));
            this.poolUpdateHelper(totalAllocPointBefore, userTokenBalBefore, userRewardDebtBefore, token, allocPointBefore, lastRewardTimeBefore, accTombPerShareBefore, isStartedBefore, userRewardDebtAfter, false);
            
            assertGt(userAmountAfter, userAmountBefore, "USER BAL CHECK");
            assertGt(userRewardDebtAfter, userRewardDebtBefore, "USER REWARD CHECK");
        } catch {/*assert(false)*/ }// overflow        
    }

    /* INVARIANTS: Withdrawing from TombRewardPool Should: 
     * Update pool reward variables
     * Increase User bal of token
     * Update User rewardDebt
     * Decrease user bal amount
    */     
    function testFuzz_tombRewardPoolWithdraw(uint _amount, uint skipNum) public {
        // PRECONDITIONS:
        uint256 amount = _between(_amount, 1, MAX);

        uint totalAllocPointBefore = testTombRewardPool.totalAllocPoint();
        uint userTombBalBefore = tomb.balanceOf(address(this));
        uint userTokenBalBefore = IUniswapV2Pair(usdtUsdcPair).balanceOf(address(this));
        (uint userAmountBefore, uint userRewardDebtBefore) = testTombRewardPool.userInfo(1, address(this));
        (IERC20 token, uint256 allocPointBefore, uint256 lastRewardTimeBefore, uint256 accTombPerShareBefore, bool isStartedBefore) = testTombGenesisRewardPool.poolInfo(0);

        if (!setReserves) {
            initReserves(amount);

            // Don't want the pool to run out of tomb
            if (tomb.balanceOf(address(testTombRewardPool)) >  userAmountBefore * accTombPerShareBefore / 1e18 - userRewardDebtBefore) {
                tomb.mint(address(testTombRewardPool), amount);
            }
            skip(skipNum);
        }    
           
        try testTombRewardPool.deposit(0, amount) {
            // ACTION:
            try testTombRewardPool.withdraw(0, amount) {
                // POSTCONDTIONS:
                if (userAmountBefore > 0) {
                    uint userTombBalAfter = tomb.balanceOf(address(this));
                    assertGt(userTombBalAfter, userTombBalBefore, "USER TOMB BAL CHECK");
                }
                (uint userAmountAfter, uint userRewardDebtAfter) = testTombRewardPool.userInfo(1, address(this));
                this.genesisPoolUpdateHelper(totalAllocPointBefore, userTokenBalBefore, userRewardDebtBefore, token, allocPointBefore, lastRewardTimeBefore, accTombPerShareBefore, isStartedBefore, userRewardDebtAfter, true);
            
                assertLt(userAmountAfter, userAmountBefore, "USER BAL CHECK");
                assertGt(userRewardDebtAfter, userRewardDebtBefore, "USER REWARD CHECK");
            } catch {/*assert(false)*/ }// overflow        
        } catch {/*assert(false)*/ }// overflow          
    }

    /* INVARIANTS: Emergency withdrawing from TombRewardPool Should: 
     * Increase User bal of token
     * Decrease User rewardDebt
     * Decrease user bal amount
    */     
    function testFuzz_tombRewardPoolEmergencyWithdraw(uint _amount) public {
        // PRECONDITIONS:
        uint256 amount = _between(_amount, 1, MAX);
        
        uint userTokenBalBefore = IUniswapV2Pair(usdtUsdcPair).balanceOf(address(this));
        if (!setReserves) {
            initReserves(amount);
        }    
           
        try testTombRewardPool.deposit(0, amount) {
            // ACTION:
            try testTombRewardPool.emergencyWithdraw(0) {
                // POSTCONDTIONS:
                (uint userAmountAfter, uint userRewardDebtAfter) = testTombRewardPool.userInfo(1, address(this));
                uint userTokenBalAfter = IUniswapV2Pair(usdtUsdcPair).balanceOf(address(this));
                assertGt(userTokenBalAfter, userTokenBalBefore, "USER TOKEN BAL CHECK");
                assertEq(userAmountAfter, 0, "USER BAL CHECK");
                assertEq(userRewardDebtAfter, 0, "USER REWARD CHECK");
            } catch {/*assert(false)*/ }// overflow        
        } catch {/*assert(false)*/ }// overflow           
    }

    /* INVARIANTS: TombRewardPool Governance recover Should: 
     * Decrease contract bal of token
     * Increase to User bal of token
    */     
    function testFuzz_tombRewardPoolGovernanceRecoverUnsupported(uint _amount, uint skipNum) public {
        // PRECONDITIONS:
        uint256 amount = _between(_amount, 1, MAX);

        uint epochEndTime = testTombRewardPool.epochEndTimes(1);

        uint userTombBalBefore = tomb.balanceOf(address(this));
        uint userTokenBalBefore = shiba.balanceOf(address(this));
        uint userLPTokenBalBefore = IUniswapV2Pair(usdtUsdcPair).balanceOf(address(this));
        if (!setReserves) {
            initReserves(amount);
            try tomb.mint(address(testTombRewardPool), amount) {}catch {/*assert(false)*/ }// overflow           
            try shiba.mint(address(testTombRewardPool), amount){}catch {/*assert(false)*/ }// overflow           
            skip(skipNum);
        }    

        try testTombRewardPool.deposit(0, amount) {
            // ACTION:
            if (block.timestamp < epochEndTime + 30 days) {
                try testTombRewardPool.governanceRecoverUnsupported(IERC20(shiba), amount, address(this)) {
                    // POSTCONDTIONS:
                    uint userTokenBalAfter = shiba.balanceOf(address(this));
                    assertGt(userTokenBalAfter, userTokenBalBefore, "USER TOKEN BAL CHECK");                           
                } catch {/*assert(false)*/ }// overflow                      
            }
            try testTombRewardPool.governanceRecoverUnsupported(IERC20(usdtUsdcPair), amount, address(this)) {
                // POSTCONDTIONS:
                uint userLPTokenBalAfter = IUniswapV2Pair(usdtUsdcPair).balanceOf(address(this));
                assertGt(userLPTokenBalAfter, userLPTokenBalBefore, "USER TOKEN BAL CHECK");                           
            } catch {/*assert(false)*/ }// overflow    
            try testTombGenesisRewardPool.governanceRecoverUnsupported(IERC20(tomb), amount, address(this)) {
                // POSTCONDTIONS:
                uint userTombBalAfter = tomb.balanceOf(address(this));
                assertGt(userTombBalAfter, userTombBalBefore, "USER TOMB BAL CHECK");                           
            } catch {/*assert(false)*/ }// overflow             
        } catch {/*assert(false)*/ }// overflow            
    }

    /* INVARIANTS: Depositing into TShareRewardPool Should: 
     * Update pool reward variables
     * Decrease User bal of token
     * Increase User rewardDebt
     * Increase user bal amount
    */     
    function testFuzz_tShareRewardPoolDeposit(uint _amount, uint skipNum) public {
        // PRECONDITIONS:
        uint256 amount = _between(_amount, 1, MAX);

        uint totalAllocPointBefore = testTShareRewardPool.totalAllocPoint();
        uint userTShareBalBefore = tshare.balanceOf(address(this));
        uint userTokenBalBefore = IUniswapV2Pair(usdtUsdcPair).balanceOf(address(this));
        (uint userAmountBefore, uint userRewardDebtBefore) = testTShareRewardPool.userInfo(1, address(this));
        (IERC20 token, uint256 allocPointBefore, uint256 lastRewardTimeBefore, uint256 accTSharePerShareBefore, bool isStartedBefore) = testTShareRewardPool.poolInfo(0);

        if (!setReserves) {
            initReserves(amount);
            
            // Don't want the pool to run out of tshare
            if (tshare.balanceOf(address(testTShareRewardPool)) >  userAmountBefore * accTSharePerShareBefore / 1e18 - userRewardDebtBefore) {
                tshare.mint(address(testTShareRewardPool), amount);
            }
            skip(skipNum);
        }       

        // ACTION:
        try testTShareRewardPool.deposit(0, amount) {
            // POSTCONDTIONS:
            if (userAmountBefore > 0) {
                uint userTShareBalAfter = tshare.balanceOf(address(this));
                assertGt(userTShareBalAfter, userTShareBalBefore, "USER TSHARE BAL CHECK");
            }
            (uint userAmountAfter, uint userRewardDebtAfter) = testTShareRewardPool.userInfo(1, address(this));
            this.genesisPoolUpdateHelper(totalAllocPointBefore, userTokenBalBefore, userRewardDebtBefore, token, allocPointBefore, lastRewardTimeBefore, accTSharePerShareBefore, isStartedBefore, userRewardDebtAfter, false);
            
            assertGt(userAmountAfter, userAmountBefore, "USER BAL CHECK");
            assertGt(userRewardDebtAfter, userRewardDebtBefore, "USER REWARD CHECK");
        } catch {/*assert(false)*/ }// overflow        
    }

    /* INVARIANTS: Withdrawing from TShareRewardPool Should:  
     * Update pool reward variables
     * Increase User bal of token
     * Update User rewardDebt
     * Decrease user bal amount
    */     
    function testFuzz_tShareRewardPoolWithdraw(uint _amount, uint skipNum) public {
        // PRECONDITIONS:
        uint256 amount = _between(_amount, 1, MAX);

        uint totalAllocPointBefore = testTShareRewardPool.totalAllocPoint();
        uint userTShareBalBefore = tshare.balanceOf(address(this));
        uint userTokenBalBefore = IUniswapV2Pair(usdtUsdcPair).balanceOf(address(this));
        (uint userAmountBefore, uint userRewardDebtBefore) = testTShareRewardPool.userInfo(1, address(this));
        (IERC20 token, uint256 allocPointBefore, uint256 lastRewardTimeBefore, uint256 accTSharePerShareBefore, bool isStartedBefore) = testTShareRewardPool.poolInfo(0);

        if (!setReserves) {
            initReserves(amount);

            // Don't want the pool to run out of tshare
            if (tshare.balanceOf(address(testTShareRewardPool)) >  userAmountBefore * accTSharePerShareBefore / 1e18 - userRewardDebtBefore) {
                tshare.mint(address(testTShareRewardPool), amount);
            }
            skip(skipNum);
        }    
           
        try testTShareRewardPool.deposit(0, amount) {
            // ACTION:
            try testTShareRewardPool.withdraw(0, amount) {
                // POSTCONDTIONS:
                if (userAmountBefore > 0) {
                    uint userTShareBalAfter = tshare.balanceOf(address(this));
                    assertGt(userTShareBalAfter, userTShareBalBefore, "USER TSHARE BAL CHECK");
                }
                (uint userAmountAfter, uint userRewardDebtAfter) = testTShareRewardPool.userInfo(1, address(this));
                this.genesisPoolUpdateHelper(totalAllocPointBefore, userTokenBalBefore, userRewardDebtBefore, token, allocPointBefore, lastRewardTimeBefore, accTSharePerShareBefore, isStartedBefore, userRewardDebtAfter, true);
            
                assertLt(userAmountAfter, userAmountBefore, "USER BAL CHECK");
                assertGt(userRewardDebtAfter, userRewardDebtBefore, "USER REWARD CHECK");
            } catch {/*assert(false)*/ }// overflow        
        } catch {/*assert(false)*/ }// overflow          
    }

    /* INVARIANTS: Emergency withdrawing from TShareRewardPool Should: 
     * Increase User bal of token
     * Decrease User rewardDebt
     * Decrease user bal amount
    */     
    function testFuzz_tShareRewardPoolEmergencyWithdraw(uint _amount) public {
        // PRECONDITIONS:
        uint256 amount = _between(_amount, 1, MAX);
        
        uint userTokenBalBefore = IUniswapV2Pair(usdtUsdcPair).balanceOf(address(this));
        if (!setReserves) {
            initReserves(amount);
        }    
           
        try testTShareRewardPool.deposit(0, amount) {
            // ACTION:
            try testTShareRewardPool.emergencyWithdraw(0) {
                // POSTCONDTIONS:
                (uint userAmountAfter, uint userRewardDebtAfter) = testTShareRewardPool.userInfo(1, address(this));
                uint userTokenBalAfter = IUniswapV2Pair(usdtUsdcPair).balanceOf(address(this));
                assertGt(userTokenBalAfter, userTokenBalBefore, "USER TOKEN BAL CHECK");
                assertEq(userAmountAfter, 0, "USER BAL CHECK");
                assertEq(userRewardDebtAfter, 0, "USER REWARD CHECK");
            } catch {/*assert(false)*/ }// overflow        
        } catch {/*assert(false)*/ }// overflow        
    }

    /* INVARIANTS:TShareRewardPool Governance recover Should: 
     * Decrease contract bal of token
     * Increase to User bal of token
    */     
    function testFuzz_testFuzztShareRewardPoolGovernanceRecoverUnsupported(uint _amount, uint skipNum) public {
        // PRECONDITIONS:
        uint256 amount = _between(_amount, 1, MAX);

        uint poolEndTime = testTShareRewardPool.poolEndTime();
        uint userTShareBalBefore = tshare.balanceOf(address(this));
        uint userTokenBalBefore = shiba.balanceOf(address(this));
        uint userLPTokenBalBefore = IUniswapV2Pair(usdtUsdcPair).balanceOf(address(this));
        if (!setReserves) {
            initReserves(amount);
            try shiba.mint(address(testTShareRewardPool), amount){}catch {/*assert(false)*/ }// overflow           
            skip(skipNum);
        }    

        try testTShareRewardPool.deposit(0, amount) {
            // ACTION:
            if (block.timestamp < poolEndTime + 90 days) {
                try testTShareRewardPool.governanceRecoverUnsupported(IERC20(shiba), amount, address(this)) {
                    // POSTCONDTIONS:
                    uint userTokenBalAfter = shiba.balanceOf(address(this));
                    assertGt(userTokenBalAfter, userTokenBalBefore, "USER TOKEN BAL CHECK");                           
                } catch {/*assert(false)*/ }// overflow                      
            }
            try testTShareRewardPool.governanceRecoverUnsupported(IERC20(usdtUsdcPair), amount, address(this)) {
                // POSTCONDTIONS:
                uint userLPTokenBalAfter = IUniswapV2Pair(usdtUsdcPair).balanceOf(address(this));
                assertGt(userLPTokenBalAfter, userLPTokenBalBefore, "USER TOKEN BAL CHECK");                           
            } catch {/*assert(false)*/ }// overflow      
            try testTShareRewardPool.governanceRecoverUnsupported(IERC20(tshare), amount, address(this)) {
                // POSTCONDTIONS:
                uint userTShareBalAfter = tshare.balanceOf(address(this));
                assertGt(userTShareBalAfter, userTShareBalBefore, "USER TSHARE BAL CHECK");                           
            } catch {/*assert(false)*/ }// overflow                                   
        } catch {/*assert(false)*/ }// overflow      
    }

    /* INVARIANTS: Staking into Masonry Should: 
     * Increase totalSupply
     * Increase User staked bal
     * Decrease User tBond amount
     * Set user epoch timer Start     
    */ 
    function testFuzz_masonryStake(uint _amount) public {
        // PRECONDITIONS:
        uint256 amount = _between(_amount, 1, MAX);
        
        if (!setTShare) {
            initTShare(amount);
            vm.roll(10);
        }  

        uint userTShareBalBefore = tshare.balanceOf(address(this));
        uint userMasonryBalBefore = testMasonry.balanceOf(address(this));
        uint totalSupplyBefore = testMasonry.totalSupply();

        // ACTION:
        try testMasonry.stake(amount) {
            // POSTCONDTIONS:
            uint userTShareBalAfter = tshare.balanceOf(address(this));
            uint userMasonryBalAfter = testMasonry.balanceOf(address(this));
            uint totalSupplyAfter = testMasonry.totalSupply();
            ( , , uint epochTimerStartAfter) = testMasonry.masons(address(this));

            assertEq(epochTimerStartAfter, testTreasury.epoch(), "USER EPOCH TIMER CHECK");
            assertLt(userTShareBalAfter, userTShareBalBefore, "USER TSHARE BAL CHECK");
            assertGt(userMasonryBalAfter, userMasonryBalBefore, "USER MASONRY BAL CHECK");
            assertGt(totalSupplyAfter, totalSupplyBefore, "MASONRY TOTALSUPPLY BAL CHECK");

        } catch {/*assert(false)*/ }// overflow
    }

    /* INVARIANTS: Depositing into Masonry Should: 
     * Decrease totalSupply
     * Decrease User staked bal
     * Increase User tshare amount
    */     
    function testFuzz_masonryWithdraw(uint _amount) public {
        // PRECONDITIONS:
        uint256 amount = _between(_amount, 1, MAX);
        
        if (!setTShare) {
            initTShare(amount);
        }  

        try testMasonry.stake(amount) {
            uint userTShareBalBefore = tshare.balanceOf(address(this));
            uint userMasonryBalBefore = testMasonry.balanceOf(address(this));
            uint totalSupplyBefore = testMasonry.totalSupply();            
            
            if (!(testMasonry.canWithdraw(address(this)))) {
                ( , , uint epochTimerStart) = testMasonry.masons(address(this));
                uint withdrawLockupEpochs = testMasonry.withdrawLockupEpochs();
                uint skipNum = epochTimerStart + withdrawLockupEpochs;
                testTreasury.moveEpoch(skipNum);
                vm.roll(10);
            }
            // ACTION:
            try testMasonry.withdraw(amount) {
                // POSTCONDTIONS:
                uint userTShareBalAfter = tshare.balanceOf(address(this));
                uint userMasonryBalAfter = testMasonry.balanceOf(address(this));
                uint totalSupplyAfter = testMasonry.totalSupply();

                assertGt(userTShareBalAfter, userTShareBalBefore, "USER TSHARE BAL CHECK");
                assertLt(userMasonryBalAfter, userMasonryBalBefore, "USER MASONRY BAL CHECK");
                assertLt(totalSupplyAfter, totalSupplyBefore, "MASONRY TOTALSUPPLY BAL CHECK");
            } catch {/*assert(false)*/ }// overflow
        } catch {/*assert(false)*/ }// overflow        
    }

    /* INVARIANTS: Claiming reward from Masonry Should: 
     * Decrease User Reward
     * Increase tomb bal
     * Update User epochTimerStart
     * Decrease User reward Earned
    */     
    function testFuzz_masonryClaimReward(uint _amount) public {
        // PRECONDITIONS:
        uint256 amount = _between(_amount, 1, MAX);
        
        if (!setTShare) {
            initTShare(amount);
            vm.roll(10);
        }  

        uint userTombBalBefore = tomb.balanceOf(address(this));
        uint masonryTombBalBefore = tomb.balanceOf(address(testMasonry));

        try testMasonry.stake(amount) {  

            if (!(testMasonry.canClaimReward(address(this)))) {
                ( , , uint epochTimerStart) = testMasonry.masons(address(this));
                uint rewardLockupEpochs = testMasonry.rewardLockupEpochs();
                uint skipNum = epochTimerStart + rewardLockupEpochs;
                testTreasury.moveEpoch(skipNum);

                ( , uint userRewardEarnedBefore, ) = testMasonry.masons(address(this));            

                if (userRewardEarnedBefore > 0 ) {
                    try testMasonry.earning(amount, address(this)) {} catch {/*assert(false)*/ }// overflow 
                    try tomb.mint(address(testMasonry), amount) {} catch {/*assert(false)*/ }// overflow 
                    // ACTION:
                    try testMasonry.claimReward() {
                        // POSTCONDTIONS:
                        uint userTombBalAfter = tomb.balanceOf(address(this));
                        uint masonryTombBalAfter = tomb.balanceOf(address(testMasonry));
                        ( , uint userRewardEarnedAfter, uint epochTimerStartAfter) = testMasonry.masons(address(this));

                        assertEq(userRewardEarnedAfter, 0, "USER REWARD CHECK");
                        assertEq(epochTimerStartAfter, testTreasury.epoch(), "USER EPOCH TIMER CHECK");                
                        assertGt(userTombBalAfter, userTombBalBefore, "USER TOMB BAL CHECK");
                        assertLt(masonryTombBalAfter, masonryTombBalBefore, "USER TOMB BAL CHECK");

                    } catch {/*assert(false)*/ }// overflow               
                }
            }
        } catch {/*assert(false)*/ }// overflow               
    }

    /* INVARIANTS: Exiting from Masonry Should: 
     * Decrease totalSupply
     * Decrease User staked bal
     * Increase User tBond amount
    */     
    function testFuzz_masonryExit(uint _amount) public {
        // PRECONDITIONS:
        uint256 amount = _between(_amount, 1, MAX);
        
        if (!setTShare) {
            initTShare(amount);
        }  

        try testMasonry.stake(amount) {
            uint userTShareBalBefore = tshare.balanceOf(address(this));
            uint userMasonryBalBefore = testMasonry.balanceOf(address(this));
            uint totalSupplyBefore = testMasonry.totalSupply();            
            
            if (!(testMasonry.canWithdraw(address(this)))) {
                ( , , uint epochTimerStart) = testMasonry.masons(address(this));
                uint withdrawLockupEpochs = testMasonry.withdrawLockupEpochs();
                uint skipNum = epochTimerStart + withdrawLockupEpochs;
                testTreasury.moveEpoch(skipNum);
                vm.roll(10);
            }
            // ACTION:
            try testMasonry.exit() {
                // POSTCONDTIONS:
                uint userTShareBalAfter = tshare.balanceOf(address(this));
                uint userMasonryBalAfter = testMasonry.balanceOf(address(this));
                uint totalSupplyAfter = testMasonry.totalSupply();

                assertGt(userTShareBalAfter, userTShareBalBefore, "USER TSHARE BAL CHECK");
                assertLt(userMasonryBalAfter, userMasonryBalBefore, "USER MASONRY BAL CHECK");
                assertLt(totalSupplyAfter, totalSupplyBefore, "MASONRY TOTALSUPPLY BAL CHECK");
            } catch {/*assert(false)*/ }// overflow
        } catch {/*assert(false)*/ }// overflow          
    }

    /* INVARIANTS: Masonry Allocate Seigniorage 
     * Should: Update nextRPS
     * Update time
     * Decrease from User tomb bal
     * Increase contracts tomb bal
    */     
    function testFuzz_masonryAllocateSeigniorage() public {}//TODO

    /* INVARIANTS: Masonry Governance recover Should: 
     * Decrease contract bal of token
     * Increase to User bal of token
    */     
    function testFuzz_masonryGovernanceRecoverUnsupported(uint _amount) public {
        // PRECONDITIONS:
        uint256 amount = _between(_amount, 1, MAX);

        uint userTokenBalBefore = shiba.balanceOf(address(this));

        if (!setShiba) {
            initShiba(address(testMasonry), amount);
        }    

        try testMasonry.governanceRecoverUnsupported(IERC20(shiba), amount, address(this)) {
            // POSTCONDTIONS:
            uint userTokenBalAfter = shiba.balanceOf(address(this));
            assertGt(userTokenBalAfter, userTokenBalBefore, "USER TOKEN BAL CHECK");                           
        } catch {/*assert(false)*/ }// overflow                                   
    }

    /* INVARIANTS: Buying bonds from the Treasury Should: 
     * Decrease User tomb bal
     * Decrease tomb totalSupply
     * Increase User tBond bal
     * Increase tBond totalSupply
     * Decrease epochSupplyContractionLeft
    */     
    function testFuzz_treasuryBuyBonds(uint _amount) public {
        // PRECONDITIONS:
        uint256 amount = _between(_amount, 1, MAX);

        if (!setTomb) {
            initTomb(amount);
            setOperatorsHelper();
            tomb.approve(address(testTreasury), MAX);
            testTreasury.setepochSupplyContractionLeft(amount);
            testOracle.setPrice(1);
        }    

        uint tombTotalSupplyBefore = tomb.totalSupply();
        uint userTBondBalBefore = tbond.balanceOf(address(this));
        uint tBondTotalSupplyBefore = tbond.totalSupply();
        uint userTombBalBefore = tomb.balanceOf(address(this));
        uint epochSupplyContractionLeftBefore = testTreasury.epochSupplyContractionLeft();        

        uint targetPrice = testTreasury.getTombPrice();

        try testTreasury.buyBonds(amount, targetPrice) {
            // POSTCONDTIONS:
            uint userTombBalAfter = tomb.balanceOf(address(this));
            uint tombTotalSupplyAfter = tomb.totalSupply();
            uint userTBondBalAfter = tbond.balanceOf(address(this));
            uint tBondTotalSupplyAfter = tbond.totalSupply();
            uint epochSupplyContractionLeftAfter = testTreasury.epochSupplyContractionLeft();

            assertLt(userTombBalAfter, userTombBalBefore, "USER TOMB BAL CHECK");                           
            assertLe(tombTotalSupplyAfter, tombTotalSupplyBefore, "TOMB TOTALSUPPLY CHECK");
            assertGt(userTBondBalAfter, userTBondBalBefore, "USER TBOND BAL CHECK");                           
            assertGt(tBondTotalSupplyAfter, tBondTotalSupplyBefore, "TBOND TOTALSUPPLYS CHECK");        
            assertLt(epochSupplyContractionLeftAfter, epochSupplyContractionLeftBefore, "EPOCH SUPPLY CONTRACTION CHECK");
        } catch {/*assert(false)*/ }// overflow               
    }

    /* INVARIANTS: Redeeming bonds from the Treasury Should: 
     * Decrease User tBond bal
     * Decrease tBond totalSupply
     * Increase User tomb bal
     * Increase tomb totalSupply
    */     
    function testFuzz_treasuryRedeemBonds(uint _amount) public {
        // PRECONDITIONS:
        uint256 amount = _between(_amount, 1, MAX);

        if (!setTbond) {
            initTbond(amount);
            try tomb.mint(address(testTreasury), amount) {} catch {/*assert(false)*/ }// overflow               
            setOperatorsHelper();
            tbond.approve(address(testTreasury), MAX);
            testOracle.setPrice(2);
        }    

        uint tombTotalSupplyBefore = tomb.totalSupply();
        uint userTBondBalBefore = tbond.balanceOf(address(this));
        uint tBondTotalSupplyBefore = tbond.totalSupply();
        uint userTombBalBefore = tomb.balanceOf(address(this));

        uint targetPrice = testTreasury.getTombPrice();

        try testTreasury.redeemBonds(amount, targetPrice) {
            // POSTCONDTIONS:
            uint userTombBalAfter = tomb.balanceOf(address(this));
            uint tombTotalSupplyAfter = tomb.totalSupply();
            uint userTBondBalAfter = tbond.balanceOf(address(this));
            uint tBondTotalSupplyAfter = tbond.totalSupply();
            uint epochSupplyContractionLeftAfter = testTreasury.epochSupplyContractionLeft();

            assertGt(userTombBalAfter, userTombBalBefore, "USER TOMB BAL CHECK");                           
            assertGt(tombTotalSupplyAfter, tombTotalSupplyBefore, "TOMB TOTALSUPPLY CHECK");
            assertLt(userTBondBalAfter, userTBondBalBefore, "USER TBOND BAL CHECK");                           
            assertLt(tBondTotalSupplyAfter, tBondTotalSupplyBefore, "TBOND TOTALSUPPLYS CHECK");        
        } catch {/*assert(false)*/ }// overflow               
    }

    /* INVARIANTS: reasury Allocate Seigniorage Should: 
     * Update previousEpochTombPrice
     * If `_savedForBond > 0`, increase contract tomb bal
     * If `_savedForMasonry > 0 && daoFundSharedPercent > 0` increase daoFund tomb bal
     * If `_savedForMasonry > 0 && devFundSharedPercent > 0` increase devFund tomb bal
     * Update masonry's allowance
    */ 
    function testFuzz_treasuryAllocateSeigniorage() public {} //TODO

    /* INVARIANTS: Treasury Governance recover Should: 
     * Decrease contract bal of token
     * Increase to User bal of token
    */     
    function testFuzz_treasuryGovernanceRecoverUnsupported(uint _amount) public {
        // PRECONDITIONS:
        uint256 amount = _between(_amount, 1, MAX);

        uint userTokenBalBefore = shiba.balanceOf(address(this));

        if (!setShiba) {
            initShiba(address(testTreasury), amount);
        }    

        try testTreasury.governanceRecoverUnsupported(IERC20(shiba), amount, address(this)) {
            // POSTCONDTIONS:
            uint userTokenBalAfter = shiba.balanceOf(address(this));
            assertGt(userTokenBalAfter, userTokenBalBefore, "USER TOKEN BAL CHECK");                           
        } catch {/*assert(false)*/ }// overflow                
    }

    /* INVARIANTS: tShare Claim rewards Should: 
     * Increase totalSupply
     * If `_pending > 0 && communityFund != address(0)` increase communityFund tShare bal
     * If `_pending > 0 && devFund != address(0)` increase devFund tShare bal
     * Update last claimed time
    */     
    function testFuzz_tShareClaimRewards(uint skipNum) public {
        // PRECONDITIONS:
        bool timeMove;
        if (!timeMove) {
            skip(skipNum);
        }  

        uint256 communityBalBefore = tshare.balanceOf(address(COMMUNITYFUND));
        
        uint256 devBalBefore = tshare.balanceOf(address(DEVFUND));
        uint256 totalSupplyBefore =  tshare.totalSupply();

        uint unclaimedTreasury = tshare.unclaimedTreasuryFund();
        uint unclaimedDev = tshare.unclaimedDevFund();
        // ACTION:
        try tshare.claimRewards() {
            // POSTCONDTIONS:
            if (unclaimedTreasury > 0 ) {
                uint256 communityBalAfter = tshare.balanceOf(address(COMMUNITYFUND));
                uint256 communityFundLastClaimed = tshare.communityFundLastClaimed();

                assertGt(communityBalAfter, communityBalBefore, "COMMUNITY FUND CHECK");
                assertEq(communityFundLastClaimed, block.timestamp, "COMMUNITY FUND TIME CHECK");
            } 

            if (unclaimedDev > 0 ) {
                uint256 devBalAfter = tshare.balanceOf(address(DEVFUND));
                uint256 devFundLastClaimed = tshare.devFundLastClaimed();

                assertGt(devBalAfter, devBalBefore, "DEV FUND CHECK");
                assertEq(devFundLastClaimed, block.timestamp, "DEV FUND TIME CHECK");
            }
            
            uint256 totalSupplyAfter =  tshare.totalSupply();
            assertGt(totalSupplyAfter, totalSupplyBefore, "TOTAL SUPPLY CHECK");
        } catch {/*assert(false)*/ }// overflow        
    }   

    /* INVARIANTS: TShare Burn Should: 
     * Decrease User Balance
     * Decrease Total Supply
    */     
    function testFuzz_tShareBurn(uint _amount) public {
        // PRECONDITIONS:
        uint256 amount = _between(_amount, 1, MAX - INITR);
        if (!setTShare) {
            initTShare(amount);
        }  

        uint256 userBalBefore = tshare.balanceOf(address(this));
        uint256 totalSupplyBefore =  tshare.totalSupply();

        // ACTION:
        try tshare.burn(amount) {
            // POSTCONDTIONS:
            uint256 userBalAfter = tshare.balanceOf(address(this));
            uint256 totalSupplyAfter =  tshare.totalSupply();
            
            assertLt(userBalAfter, userBalBefore, "USER BAL CHECK");
            assertLt(totalSupplyAfter, totalSupplyBefore, "TOTAL SUPPLY CHECK");
        } catch {/*assert(false)*/ }// overflow
    }

    /* INVARIANTS: Governance recover from TShare Should: 
     * Decrease contract bal of token
     * Increase to User bal of token
    */     
    function testFuzz_tShareGovernanceRecoverUnsupported(uint _amount) public {
        // PRECONDITIONS:
        uint256 amount = _between(_amount, 1, MAX);

        uint userTokenBalBefore = shiba.balanceOf(address(this));

        if (!setShiba) {
            initShiba(address(tshare), amount);
        }    

        try tshare.governanceRecoverUnsupported(IERC20(shiba), amount, address(this)) {
            // POSTCONDTIONS:
            uint userTokenBalAfter = shiba.balanceOf(address(this));
            assertGt(userTokenBalAfter, userTokenBalBefore, "USER TOKEN BAL CHECK");                           
        } catch {/*assert(false)*/ }// overflow          
    }


    // Helpers to init funds and other small setup
    bool setTomb;
    function initTomb(uint amount) public {
        try tomb.mint(address(this), amount) {} catch {/*assert(false)*/ }// overflow
        setTomb = true;
    }

    bool setTbond;
    function initTbond(uint amount) public {
        try tbond.mint(address(this), amount) {} catch {/*assert(false)*/ }// overflow
        setTbond = true;
    }

    bool setTShare;
    function initTShare(uint amount) public {
        try tshare.mint(address(this), amount) {} catch {/*assert(false)*/ }// overflow 
        tshare.approve(address(testMasonry), amount);
        setTShare = true;
    }    

    bool setShiba;
    function initShiba(address who, uint amount) public {
        try shiba.mint(address(who), amount){}catch {/*assert(false)*/ }// overflow               
        setShiba = true;
    }

    bool setReserves;
    function initReserves(uint amount) public {
        try usdt.mint(address(this), amount) {
            try usdt.transfer(address(usdtUsdcPair), amount) {} catch {/*assert(false)*/ }// overflow
            try usdc.mint(address(this), amount) {
                try usdc.transfer(address(usdtUsdcPair), amount) {} catch {/*assert(false)*/ }// overflow
                try IUniswapV2Pair(usdtUsdcPair).mint(address(this)) {} catch {/*assert(false)*/ }// overflow
            } catch {/*assert(false)*/ }// overflow
        } catch {/*assert(false)*/ }// overflow
        setReserves =   true;
    }

    function setOperatorsHelper() public {
        tomb.transferOperator(address(testTreasury));
        tbond.transferOperator(address(testTreasury));
        tshare.transferOperator(address(testTreasury));
        testMasonry.setOperator(address(testTreasury));
    }    

    // Helpers to avoid stack too deep
    function genesisPoolUpdateHelper(uint totalAllocPointBefore, uint userTokenBalBefore, uint userRewardDebtBefore, IERC20 token, uint allocPointBefore, uint lastRewardTimeBefore, uint accTombPerShareBefore, bool isStartedBefore, uint userRewardDebtAfter, bool withdraw) public {
        ( , , uint256 lastRewardTimeAfter, uint256 accTombPerShareAfter, bool isStartedAfter) = testTombGenesisRewardPool.poolInfo(0);
        this.poolUpdateHelper2(userTokenBalBefore, withdraw);

        if (block.timestamp <= lastRewardTimeBefore) {
            this.poolUpdateHelper3(allocPointBefore, lastRewardTimeBefore, accTombPerShareBefore);
        } else {
            if(IERC20(token).balanceOf(address(testTombGenesisRewardPool)) == 0) {
                assertEq(lastRewardTimeAfter, block.timestamp, "LAST REWARD TIME UNCHANGED CHECK");
            } 
            if(!isStartedBefore) {
                this.poolUpdateHelper4(isStartedAfter, totalAllocPointBefore);
            }
            if (totalAllocPointBefore > 0) {
                genesisGeneratedRewardHelper(userRewardDebtBefore, accTombPerShareBefore, userRewardDebtAfter, lastRewardTimeBefore, accTombPerShareAfter);
            }
        }
        assertEq(lastRewardTimeAfter, block.timestamp, "LAST REWARD TIME CHECK");
    }

    function poolUpdateHelper(uint totalAllocPointBefore, uint userTokenBalBefore, uint userRewardDebtBefore, IERC20 token, uint allocPointBefore, uint lastRewardTimeBefore, uint accTombPerShareBefore, bool isStartedBefore, uint userRewardDebtAfter, bool withdraw) public {
        ( , , uint256 lastRewardTimeAfter, uint256 accTombPerShareAfter, bool isStartedAfter) = testTombGenesisRewardPool.poolInfo(0);
        this.poolUpdateHelper2(userTokenBalBefore, withdraw);

        if (block.timestamp <= lastRewardTimeBefore) {
            this.poolUpdateHelper3(allocPointBefore, lastRewardTimeBefore, accTombPerShareBefore);
        } else {
            if(IERC20(token).balanceOf(address(testTombGenesisRewardPool)) == 0) {
                assertEq(lastRewardTimeAfter, block.timestamp, "LAST REWARD TIME UNCHANGED CHECK");
            } 
            if(!isStartedBefore) {
                this.poolUpdateHelper4(isStartedAfter, totalAllocPointBefore);
            }
            if (totalAllocPointBefore > 0) {
                generatedRewardHelper(lastRewardTimeBefore, accTombPerShareBefore, accTombPerShareAfter, userRewardDebtBefore, userRewardDebtAfter);
            }
        }
        assertEq(lastRewardTimeAfter, block.timestamp, "LAST REWARD TIME CHECK");
    }    

    function poolUpdateHelper2(uint userTokenBalBefore, bool withdraw) public {
        uint userTokenBalAfter = IUniswapV2Pair(usdtUsdcPair).balanceOf(address(this));
        if (withdraw) {
            assertGt(userTokenBalAfter, userTokenBalBefore, "USER TOKEN BAL CHECK");
        } else {
            assertLt(userTokenBalAfter, userTokenBalBefore, "USER TOKEN BAL CHECK");
        }         
    }    

    function poolUpdateHelper3(uint allocPointBefore, uint lastRewardTimeBefore, uint accTombPerShareBefore) public {
        ( , uint256 allocPointAfter, uint256 lastRewardTimeAfter, uint256 accTombPerShareAfter, ) = testTombGenesisRewardPool.poolInfo(0);
        assertEq(allocPointBefore, allocPointAfter, "ALLOC POINT UNCHANGED CHECK");
        assertEq(lastRewardTimeAfter, lastRewardTimeBefore, "LAST REWARD TIME UNCHANGED CHECK");
        assertEq(accTombPerShareAfter, accTombPerShareBefore, "ACCTOMB PER SHARE UNCHANGED CHECK");
    }

    function poolUpdateHelper4(bool isStartedAfter, uint totalAllocPointBefore) public { 
        uint totalAllocPointAfter = testTombGenesisRewardPool.totalAllocPoint();
        assertEq(isStartedAfter, true, "IS STARTED CHECK");
        assertGt(totalAllocPointAfter, totalAllocPointBefore, "TOTAL ALLOC POINT CHECK");          
    }

    function genesisGeneratedRewardHelper(uint userRewardDebtBefore, uint accTombPerShareBefore, uint userRewardDebtAfter, uint lastRewardTimeBefore, uint accTombPerShareAfter) public {
        uint poolStartTime = testTombGenesisRewardPool.poolStartTime();
        uint poolEndTime = testTombGenesisRewardPool.poolEndTime();        
        if(lastRewardTimeBefore >= block.timestamp){
            assertEq(accTombPerShareAfter, accTombPerShareBefore, "ACCTOMB PER SHARE UNCHANGED CHECK");
        } else if (block.timestamp >= poolEndTime) {
            if (lastRewardTimeBefore >= poolEndTime) {
                assertEq(accTombPerShareAfter, accTombPerShareBefore, "ACCTOMB PER SHARE UNCHANGED CHECK");
            } else if (lastRewardTimeBefore <= poolStartTime) {
                assertGt(accTombPerShareAfter, accTombPerShareBefore, "ACCTOMB PER SHARE CHECK");
                assertGt(userRewardDebtAfter, userRewardDebtBefore, "USER REWARD CHECK");
            } else {
                assertGt(accTombPerShareAfter, accTombPerShareBefore, "ACCTOMB PER SHARE CHECK");
                assertGt(userRewardDebtAfter, userRewardDebtBefore, "USER REWARD CHECK");
            }
        } else {
            if(block.timestamp <= poolStartTime) {
                assertEq(accTombPerShareAfter, accTombPerShareBefore, "ACCTOMB PER SHARE UNCHANGED CHECK");
            } else if (lastRewardTimeBefore <= poolStartTime){
                assertGt(accTombPerShareAfter, accTombPerShareBefore, "ACCTOMB PER SHARE CHECK");
                assertGt(userRewardDebtAfter, userRewardDebtBefore, "USER REWARD CHECK");
            } else {
                assertGt(accTombPerShareAfter, accTombPerShareBefore, "ACCTOMB PER SHARE CHECK");
                assertGt(userRewardDebtAfter, userRewardDebtBefore, "USER REWARD CHECK");
            }
        }
    }

    function generatedRewardHelper(uint lastRewardTimeBefore, uint accTombPerShareBefore, uint accTombPerShareAfter, uint userRewardDebtBefore, uint userRewardDebtAfter) public {
        uint[] memory epochEndTimes;
        epochEndTimes[0] = testTombRewardPool.epochEndTimes(0); 
        epochEndTimes[1] = testTombRewardPool.epochEndTimes(1);

        for (uint8 epochId = 2; epochId >= 1; --epochId) {
            if (block.timestamp >= epochEndTimes[epochId - 1]) {
                if (lastRewardTimeBefore >= epochEndTimes[epochId - 1]) {
                    assertGt(accTombPerShareAfter, accTombPerShareBefore, "ACCTOMB PER SHARE CHECK");
                    assertGt(userRewardDebtAfter, userRewardDebtBefore, "USER REWARD CHECK");
                } else if (epochId == 1) {
                    assertGt(accTombPerShareAfter, accTombPerShareBefore, "ACCTOMB PER SHARE CHECK");
                    assertGt(userRewardDebtAfter, userRewardDebtBefore, "USER REWARD CHECK");
                } 
                for (epochId = epochId - 1; epochId >= 1; --epochId) {
                    if (lastRewardTimeBefore >= epochEndTimes[epochId - 1]) {
                        assertGt(accTombPerShareAfter, accTombPerShareBefore, "ACCTOMB PER SHARE CHECK");
                        assertGt(userRewardDebtAfter, userRewardDebtBefore, "USER REWARD CHECK");                        
                    }
                }
                assertGt(accTombPerShareAfter, accTombPerShareBefore, "ACCTOMB PER SHARE CHECK");
                assertGt(userRewardDebtAfter, userRewardDebtBefore, "USER REWARD CHECK");
            }
        }
        assertGt(accTombPerShareAfter, accTombPerShareBefore, "ACCTOMB PER SHARE CHECK");
        assertGt(userRewardDebtAfter, userRewardDebtBefore, "USER REWARD CHECK");
    }

    // Bounding function similar to vm.assume but is more efficient regardless of the fuzzying framework
	// This is also a guarante bound of the input unlike vm.assume which can only be used for narrow checks     
	function _between(uint256 random, uint256 low, uint256 high) public pure returns (uint256) {
		return low + random % (high-low);
	}  
}
