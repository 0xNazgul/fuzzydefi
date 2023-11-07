// SPDX-License-Identifier: NONE
pragma solidity ^0.8.10;

// Test Helpers
import "forge-std/Test.sol";

// Comptroller, Unitroller
import "@compound/Comptroller.sol";
import "@compound/Unitroller.sol";

// Goverance
import "@compound/Governance/Comp.sol";
//import "@compound/Governance/GovernorAlpha.sol";
import "@compound/Governance/GovernorBravoDelegate.sol";
import "@compound/Governance/GovernorBravoDelegator.sol";
import "@compound/Timelock.sol";

// Lens
import {CompoundLens} from "@compound/Lens/CompoundLens.sol";

// Interest Models
import "@compound/WhitePaperInterestRateModel.sol";
import {JumpRateModelV2} from "@compound/JumpRateModelV2.sol";

// CToken, Underlying, Price Oracle
import "@compound/CErc20.sol";
import "./mocks/ERC20.sol";
import "@compound/SimplePriceOracle.sol";

contract TestCore is Test {
    uint256 MAX = type(uint256).max;
    address RANDO = address(0x8008);

    // Comptroller, Unitroller, Lens
    Comptroller testComptroller;
    Unitroller testUnitroller;
    CompoundLens testCompLens;

    // Goverance
    Comp comp;
    // GovernorAlpha testGovAlpha;
    GovernorBravoDelegator testGovBravoDelegator;
    GovernorBravoDelegate testGovBravoDelegate;
    Timelock testTimelock;

    // Interest Model, CToken, Underlying, Price Oracle
    WhitePaperInterestRateModel wpirm;
    JumpRateModelV2 jrm2;
    CErc20 ctoken;
    ERC20 underlying;
    ERC20 randoToken; 
    SimplePriceOracle testOracle;

    function setUp() public {
        vm.label(address(this), "THE_FUZZANATOR");
        vm.label(address(RANDO), "RANDO");

        // Deploy Comptroller, Unitroller, Lens
        testUnitroller = new Unitroller();
        vm.label(address(testUnitroller), "UNITROLLER");

        testComptroller = new Comptroller();
        testComptroller._setBorrowCapGuardian(address(this));
        testComptroller._setPauseGuardian(address(this));
        vm.label(address(testComptroller), "COMPTROLLER");

        testCompLens = new CompoundLens();
        vm.label(address(testCompLens), "COMPOUND LENS");        

        // Deploy Governance contracts
        comp = new Comp(address(this));
        vm.label(address(comp), "COMP");

        testTimelock = new Timelock(address(this), 2 days);
        vm.label(address(testTimelock), "TIMELOCK");

        /*testGovAlpha = new GovernorAlpha(address(timelock), address(comp), address(this));
        vm.label(address(testGovAlpha), "GOVERNOR ALPHA");*/

        testGovBravoDelegate = new GovernorBravoDelegate();
        vm.label(address(testGovBravoDelegate), "GOVERNOR BRAVO HARNESS");

        // Also deploys and initializes GovernorBravoDelegate.sol should find a way to assign that to something
        testGovBravoDelegator = new GovernorBravoDelegator(address(testTimelock), address(comp), address(this), address(testGovBravoDelegate), 17280, 1, 100000000000000000000000);
        vm.label(address(testGovBravoDelegator), "GOVERNOR BRAVO DELEGATOR");

        // Deploy Interest Model, CToken, Underlying, Price Oracle
        wpirm = new WhitePaperInterestRateModel(50000, 50000);
        vm.label(address(wpirm), "INTERSET RATE MODEL");

        jrm2 = new JumpRateModelV2(2102400, 2102400, 2102400, 1, address(this));
        vm.label(address(jrm2), "INTERSET RATE MODEL");

        underlying = new StandardToken(0, "UNDERLYING", 18, "UNDERLYING");
        vm.label(address(underlying), "UNDERLYING");

        randoToken = new StandardToken(0, "RANDO", 18, "RANDO");
        vm.label(address(randoToken), "UNDERLYING");        

        ctoken = new CErc20();
        ctoken.initialize(address(underlying), ComptrollerInterface(address(testComptroller)), InterestRateModel(address(wpirm)), 50000, "CTOKEN", "CTOKEN", 18);
        vm.label(address(ctoken), "CTOKEN");

        testOracle = new SimplePriceOracle(); 
        vm.label(address(testOracle), "ORACLE");

        testComptroller._setPriceOracle(PriceOracle(testOracle));
        testComptroller._supportMarket(CToken(ctoken));
    }

    function testON() public {}

    /* INVARIANTS: cToken mint should:
     * Increase cToken TotalSupply
     * Increase User cToken Balance
     * Decrease User underlying Balance
     * Update Supply Index in Comptroller
     * Update Comp Supplier Index in Comptroller
     * Update supplier compAccrued in Comptroller
     * Update Supply block Number in Comptroller
     * Update cToken accrualBlockNumber
     * Update cToken borrowIndex
     * Update cToken totalBorrows
     * Update cToken totalReserves
    */
    function testFuzz_mint(uint _amount) public {
        // PRECONDITIONS:
        uint256 amount = _between(_amount, 1, MAX);
        
        if(!setUnderlying) {
            initUnderlying(amount);
            underlying.approve(address(ctoken), amount);
        }

        uint totalSupplyBefore = ctoken.totalSupply();
        uint userCTokenBalanceBefore = ctoken.balanceOf(address(this));
        uint userUnderlyingBalanceBefore = underlying.balanceOf(address(this));
        (uint224 indexBefore, ) = testComptroller.compSupplyState(address(ctoken));
        uint compAccruedBefore = testComptroller.compAccrued(address(this));
        uint compSupplierIndexBefore = testComptroller.compSupplierIndex(address(ctoken), address(this));
        (bool isListed, , ) = testComptroller.markets(address(ctoken));  

        if (!isListed) {
            assert(false);
        }
        
        (uint borrowIndexAfter, uint totalBorrowsAfter, uint totalReservesAfter) = this.accrueIntrestHelper(userUnderlyingBalanceBefore + ctoken.getCashPriorpub());        
        
        // ACTION:
        try ctoken.mint(amount) {
            // POSTCONDTIONS:
            uint totalSupplyAfter = ctoken.totalSupply();
            uint userCTokenBalanceAfter = ctoken.balanceOf(address(this));
            uint userUnderlyingBalanceAfter = underlying.balanceOf(address(this));

            assertGt(userCTokenBalanceAfter, userCTokenBalanceBefore, "USER CTOKEN BALANCE CHECK");
            assertLt(userUnderlyingBalanceAfter, userUnderlyingBalanceBefore, "USER UNDERLYING BALANCE CHECK");
            assertGt(totalSupplyAfter, totalSupplyBefore, "TOTALSUPPLY CHECK");

            this.accrualHelper(borrowIndexAfter, totalBorrowsAfter, totalReservesAfter);
            this.mintHelper(indexBefore, compAccruedBefore, compSupplierIndexBefore);
        } catch {/*assert(false);*/}// overflow
    }

    /* INVARIANTS: redeem should:
     * Decrease cToken TotalSupply
     * Decrease User cToken Balance
     * Increase User underlying Balance
     * Update Supply Index in Comptroller
     * Update Comp Supplier Index in Comptroller
     * Update supplier compAccrued in Comptroller
     * Update Supply block Number in Comptroller
     * Update cToken accrualBlockNumber
     * Update cToken borrowIndex
     * Update cToken totalBorrows
     * Update cToken totalReserves
    */
    function testFuzz_redeem(uint _amount) public {
        // PRECONDITIONS:
        uint256 amount = _between(_amount, 1, MAX);
        uint userUnderlyingBalanceBefore = underlying.balanceOf(address(this));

        if(!setUnderlying) {
            // I do this because of the first deposit bug and only want happy paths
            if (amount < 1000) {
                uint newAmount = amount + (1000 - amount);
                initUnderlying(newAmount);
                underlying.approve(address(ctoken), newAmount);
                try ctoken.mint(newAmount) {} catch {/*assert(false);*/}// overflow
            }

            initUnderlying(amount);
            underlying.approve(address(ctoken), amount); 
        }        

        try ctoken.mint(amount) {} catch {/*assert(false);*/}// overflow    

        uint totalSupplyBefore = ctoken.totalSupply();
        uint userCTokenBalanceBefore = ctoken.balanceOf(address(this));         
        (uint224 indexBefore, ) = testComptroller.compSupplyState(address(ctoken));
        uint compAccruedBefore = testComptroller.compAccrued(address(this));
        uint compSupplierIndexBefore = testComptroller.compSupplierIndex(address(ctoken), address(this));
        (bool isListed, , ) = testComptroller.markets(address(ctoken));

        if (!isListed) {
            assert(false);
        }       

        (uint borrowIndexAfter, uint totalBorrowsAfter, uint totalReservesAfter) =this.accrueIntrestHelper(userUnderlyingBalanceBefore + ctoken.getCashPriorpub());        

        // ACTION:
        try ctoken.redeem(amount) {
            // POSTCONDTIONS:
            uint totalSupplyAfter = ctoken.totalSupply();
            uint userCTokenBalanceAfter = ctoken.balanceOf(address(this));
            uint userUnderlyingBalanceAfter = underlying.balanceOf(address(this));

            this.accrualHelper(borrowIndexAfter, totalBorrowsAfter, totalReservesAfter);
            this.redeemHelper(indexBefore, compAccruedBefore, compSupplierIndexBefore);

            assertLt(userCTokenBalanceAfter, userCTokenBalanceBefore, "USER CTOKEN BALANCE CHECK");
            assertLt(totalSupplyAfter, totalSupplyBefore, "TOTALSUPPLY CHECK");
            assertGe(userUnderlyingBalanceAfter, userUnderlyingBalanceBefore, "USER UNDERLYING BALANCE CHECK");
        } catch {/*assert(false);*/}// overflow    
    }
    
    /* INVARIANTS: borrow should:
     * Update borrow index in Comptroller
     * Update borrow block in Comptroller
     * Update borrower compAccrued in Comptroller
     * Update compBorrowerIndex in Comptroller
     * Add user to market in Comptroller
     * Add cToken to users accountAssets in Comptroller
     * Increase accountBorrows principal
     * Update accountBorrows interestIndex
     * Increase totalBorrows
     * Increase User underlying Balance
    */
    function testFuzz_borrow(uint _amount, uint _price) public {
        // PRECONDITIONS:
        uint256 amount = _between(_amount, 1, MAX);
        uint256 price = _between(_price, 1, MAX);

        uint userUnderlyingBalanceBefore = underlying.balanceOf(address(this));
        (uint224 indexBefore, ) = testComptroller.compBorrowState(address(ctoken));
        uint compAccruedBefore = testComptroller.compAccrued(address(this));
        uint compBorrowIndexBefore = testComptroller.compBorrowerIndex(address(ctoken), address(this));
        (bool isListed, , ) = testComptroller.markets(address(ctoken));
        (uint userPrincipalBefore, uint userInterestIndexBefore) = ctoken.getAccountBorrows(address(this));
        uint totalBorrowsBefore = ctoken.totalBorrows();

        if(!setUnderlying) {
            try underlying.mint(address(ctoken), amount) {} catch {/*assert(false);*/}// overflow
            initUnderlying(amount);
            testOracle.setDirectPrice(address(underlying), price);
            underlying.approve(address(ctoken), amount);
            try ctoken.mint(amount) {} catch {/*assert(false);*/}// overflow
        }        

        if (!isListed) {
            assert(false);
        }
        
        (uint borrowIndexAfter, uint totalBorrowsAfter, uint totalReservesAfter) = this.accrueIntrestHelper(userUnderlyingBalanceBefore + ctoken.getCashPriorpub());

        // ACTION:
        try ctoken.borrow(amount) {
            // POSTCONDTIONS:
            (uint224 indexAfter, uint32 block) = testComptroller.compBorrowState(address(ctoken));
            uint compBorrowIndexAfter = testComptroller.compBorrowerIndex(address(ctoken), address(this));
            uint compAccruedAfter = testComptroller.compAccrued(address(this));

            this.accrualHelper(borrowIndexAfter, totalBorrowsAfter, totalReservesAfter);
            this.borrowHelper(totalBorrowsBefore, userPrincipalBefore, userInterestIndexBefore);

            assertGe(indexAfter, indexBefore, "BORROW INDEX CHECK");
            assertGe(compBorrowIndexAfter, compBorrowIndexBefore, "COMP BORROW INDEX CHECK");
            assertGe(compAccruedAfter, compAccruedBefore, "BORROW COMP ACCRUED CHECK");
            assertEq(block, uint32(testComptroller.getBlockNumber()), "BLOCK CHECK");
        } catch {/*assert(false);*/}// overflow        
    }
    
    /* INVARIANTS: repayBorrow should:
     * Update borrow index in Comptroller
     * Update borrow block in Comptroller
     * Update borrower compAccrued in Comptroller
     * Update compBorrowerIndex in Comptroller
     * Add user to market in Comptroller
     * Add cToken to users accountAssets in Comptroller
     * Increase accountBorrows principal
     * Update accountBorrows interestIndex
     * Increase totalBorrows
     * Increase User underlying Balance
    */
    function testFuzz_repayBorrow(uint _amount, uint _price) public {
        // PRECONDITIONS:
        uint256 amount = _between(_amount, 1, MAX);
        uint256 price = _between(_price, 1, MAX);

        uint userUnderlyingBalanceBefore = underlying.balanceOf(address(this));

        if(!setUnderlying) {
            initUnderlying(amount);
            testOracle.setDirectPrice(address(underlying), price);
            underlying.approve(address(ctoken), amount);
            try ctoken.mint(amount) {} catch {/*assert(false);*/}// overflow
            
            try underlying.mint(address(this), amount) {} catch {/*assert(false);*/}// overflow
            underlying.approve(address(ctoken), amount);
        }        
        (bool isListed, , ) = testComptroller.markets(address(ctoken));

        if (!isListed) {
            assert(false);
        }
        
        (uint borrowIndexAfter, uint totalBorrowsAfter, uint totalReservesAfter) = this.accrueIntrestHelper(userUnderlyingBalanceBefore + ctoken.getCashPriorpub());
        
        try ctoken.borrow(amount) {} catch {/*assert(false);*/}// overflow

        (uint224 indexBefore, ) = testComptroller.compBorrowState(address(ctoken));
        uint compAccruedBefore = testComptroller.compAccrued(address(this));
        uint compBorrowIndexBefore = testComptroller.compBorrowerIndex(address(ctoken), address(this));
        (uint userPrincipalBefore, uint userInterestIndexBefore) = ctoken.getAccountBorrows(address(this));
        uint totalBorrowsBefore = ctoken.totalBorrows();        

        // ACTION:
        try ctoken.repayBorrow(amount) {
            // POSTCONDTIONS:
            (uint224 indexAfter, uint32 block) = testComptroller.compBorrowState(address(ctoken));
            uint compBorrowIndexAfter = testComptroller.compBorrowerIndex(address(ctoken), address(this));
            uint compAccruedAfter = testComptroller.compAccrued(address(this));

            this.accrualHelper(borrowIndexAfter, totalBorrowsAfter, totalReservesAfter);
            this.repayBorrowHelper(totalBorrowsBefore, userPrincipalBefore, userInterestIndexBefore);

            assertGe(indexAfter, indexBefore, "BORROW INDEX CHECK");
            assertGe(compBorrowIndexAfter, compBorrowIndexBefore, "COMP BORROW INDEX CHECK");
            assertGe(compAccruedAfter, compAccruedBefore, "BORROW COMP ACCRUED CHECK");
            assertEq(block, uint32(testComptroller.getBlockNumber()), "BLOCK CHECK");
        } catch {/*assert(false);*/}// overflow   
    }

    /* INVARIANTS: RepayBorrowBehalf should:
     * Update borrow index in Comptroller
     * Update borrow block in Comptroller
     * Update borrower compAccrued in Comptroller
     * Update compBorrowerIndex in Comptroller
     * Add user to market in Comptroller
     * Add cToken to users accountAssets in Comptroller
     * Increase accountBorrows principal
     * Update accountBorrows interestIndex
     * Increase totalBorrows
     * Increase User underlying Balance
    */
    function testFuzz_RepayBorrowBehalf(uint _amount, uint _price) public {
        // PRECONDITIONS:
        uint256 amount = _between(_amount, 1, MAX);
        uint256 price = _between(_price, 1, MAX);

        uint userUnderlyingBalanceBefore = underlying.balanceOf(address(this));

        if(!setUnderlying) {
            initUnderlying(amount);
            testOracle.setDirectPrice(address(underlying), price);
            underlying.approve(address(ctoken), amount);
            try ctoken.mint(amount) {} catch {/*assert(false);*/}// overflow
            
            try underlying.mint(address(this), amount) {} catch {/*assert(false);*/}// overflow
            underlying.approve(address(ctoken), amount);
        }
        (bool isListed, , ) = testComptroller.markets(address(ctoken));

        if (!isListed) {
            assert(false);
        }
        
        (uint borrowIndexAfter, uint totalBorrowsAfter, uint totalReservesAfter) = this.accrueIntrestHelper(userUnderlyingBalanceBefore + ctoken.getCashPriorpub());
        
        try ctoken.borrow(amount) {} catch {/*assert(false);*/}// overflow

        (uint224 indexBefore, ) = testComptroller.compBorrowState(address(ctoken));
        uint compAccruedBefore = testComptroller.compAccrued(address(this));
        uint compBorrowIndexBefore = testComptroller.compBorrowerIndex(address(ctoken), address(this));
        (uint userPrincipalBefore, uint userInterestIndexBefore) = ctoken.getAccountBorrows(address(this));
        uint totalBorrowsBefore = ctoken.totalBorrows();        

        // ACTION:
        // borrower address can be adjusted but does more or less the same
        // Would just need to update the varibles here to adjust for the changed address
        try ctoken.repayBorrowBehalf(address(this), amount) {
            // POSTCONDTIONS:
            (uint224 indexAfter, uint32 block) = testComptroller.compBorrowState(address(ctoken));
            uint compBorrowIndexAfter = testComptroller.compBorrowerIndex(address(ctoken), address(this));
            uint compAccruedAfter = testComptroller.compAccrued(address(this));

            this.accrualHelper(borrowIndexAfter, totalBorrowsAfter, totalReservesAfter);
            this.repayBorrowHelper(totalBorrowsBefore, userPrincipalBefore, userInterestIndexBefore);

            assertGe(indexAfter, indexBefore, "BORROW INDEX CHECK");
            assertGe(compBorrowIndexAfter, compBorrowIndexBefore, "COMP BORROW INDEX CHECK");
            assertGe(compAccruedAfter, compAccruedBefore, "BORROW COMP ACCRUED CHECK");
            assertEq(block, uint32(testComptroller.getBlockNumber()), "BLOCK CHECK");
        } catch {/*assert(false);*/}// overflow   
    }        
    
    /* INVARIANTS: liquidateBorrow should:
     * Update cToken accrualBlockNumber
     * Update cToken borrowIndex
     * Update cToken totalBorrows
     * Increase totalReserves
     * Decrease cToken totalSupply
     * Decrease borrower accountTokens
     * Increase liquidator accountTokens
    */
    function testFuzz_liquidateBorrow(uint _amount, uint _price) public {
        // PRECONDITIONS:
        uint256 amount = _between(_amount, 1, MAX);
        uint256 price = _between(_price, 1, MAX);

        if(!setUnderlying) {          
            initUnderlying(amount);
            testOracle.setDirectPrice(address(underlying), price);
            underlying.approve(address(ctoken), amount);
            try ctoken.mint(amount) {} catch {/*assert(false);*/}// overflow

            try underlying.mint(address(RANDO), amount) {} catch {/*assert(false);*/}// overflow
            vm.startPrank(RANDO);
            underlying.approve(address(ctoken), amount);
            try ctoken.mint(amount) {} catch {/*assert(false);*/}// overflow
            try ctoken.borrow(amount) {} catch {/*assert(false);*/}// overflow
            
            try testComptroller.liquidateCalculateSeizeTokens(address(ctoken), address(ctoken), amount) returns(uint error, uint seizeTokens) {
                if (seizeTokens == 0 || error > 0) {
                    testOracle.setDirectPrice(address(underlying), price / 2);
                }
            } catch {/*assert(false);*/}// overflow
            vm.stopPrank();         
        }

        (bool isListed, , ) = testComptroller.markets(address(ctoken));

        if (!isListed) {
            assert(false);
        }        
        
        uint totalReservesBefore = ctoken.totalReserves();
        uint totalSupplyBefore = ctoken.totalSupply();
        uint borrowerBalBefore = ctoken.balanceOf(RANDO);
        uint liquidatorBalBefore = ctoken.balanceOf(address(this));

        (uint borrowIndexAfter, uint totalBorrowsAfter, uint totalReservesAfter) = this.accrueIntrestHelper(borrowerBalBefore + ctoken.getCashPriorpub());

        try ctoken.liquidateBorrow(RANDO, amount, CTokenInterface(address(ctoken))) {
            uint totalReservesAfter = ctoken.totalReserves();
            uint totalSupplyAfter = ctoken.totalSupply();
            uint borrowerBalAfter = ctoken.balanceOf(RANDO);
            uint liquidatorBalAfter = ctoken.balanceOf(address(this));

            this.accrualHelper(borrowIndexAfter, totalBorrowsAfter, totalReservesAfter);

            assertGt(totalReservesAfter, totalReservesBefore, "TOTAL RESERVES CHECK");
            assertLt(totalSupplyAfter, totalSupplyBefore, "TOTAL SUPPLY CHECK");
            assertLt(borrowerBalAfter, borrowerBalBefore, "BORROWER BALANCE CHECK");
            assertGt(liquidatorBalAfter, liquidatorBalBefore, "LIQUIDATOR BALANCE CHECK");

        } catch {/*assert(false);*/}// overflow   
    }

    /* INVARIANTS: sweepToken should:
     * Decrease ctoken random token balance
     * Increase Admin random token balance
    */
    function testFuzz_sweepToken(uint _amount) public {
        // PRECONDITIONS:
        uint256 amount = _between(_amount, 1, MAX);

        if(!setToken) {
            initToken(amount);
        }

        uint adminBalBefore = randoToken.balanceOf(address(this));
        uint ctokenContractBalBefore = randoToken.balanceOf(address(ctoken));        

        // ACTION:
        try ctoken.sweepToken(EIP20NonStandardInterface(address(randoToken))) {
            // POSTCONDTIONS:
            uint ctokenContractBalAfter = randoToken.balanceOf(address(ctoken));
            uint adminBalAfter = randoToken.balanceOf(address(this));

            assertGt(adminBalAfter, adminBalBefore, "ADMIN TOKEN BALANCE CHECK");
            assertLt(ctokenContractBalAfter, ctokenContractBalBefore, "CONTRACT TOKEN BALANCE CHECK");
        } catch {/*assert(false);*/}// overflow   
    }    

    /* INVARIANTS: addReserves should:
     * Update cToken accrualBlockNumber
     * Update cToken borrowIndex
     * Update cToken totalBorrows
     * Update cToken totalReserves (after accrueInterest)
     * Decease User balance
     * Increase ctoken underlying balance
    */
    function testFuzz_addReserves(uint _amount) public {
        // PERECONDITIONS:
        uint256 amount = _between(_amount, 1, MAX);

        if(!setUnderlying) {
            this.initUnderlying(amount);
            underlying.approve(address(ctoken), amount);
        }
        (uint borrowIndexAfter, uint totalBorrowsAfter, uint totalReservesAfter) = this.accrueIntrestHelper(ctoken.getCashPriorpub());
        
        uint userBalBefore = underlying.balanceOf(address(this));
        uint ctokenBalBefore = underlying.balanceOf(address(ctoken));
        uint totalReservesBefore = ctoken.totalReserves();

        // ACTION:
        try ctoken._addReserves(amount) {
            // POSTCONDITIONS:
            uint userBalAfter = underlying.balanceOf(address(this));
            uint ctokenBalAfter = underlying.balanceOf(address(ctoken));
            uint totalReservesAfter = ctoken.totalReserves();   

            this.accrualHelper(borrowIndexAfter, totalBorrowsAfter, totalReservesAfter);         

            assertLe(userBalAfter, userBalBefore, "USER BAL CHECK");
            assertGt(ctokenBalAfter, ctokenBalBefore, "CTOKEN BAL CHECK");
            assertGt(totalReservesAfter, totalReservesBefore, "TOTAL RESERVES CHECK");
        } catch {/*assert(false);*/}// overflow   
    }    
    
    /* INVARIANTS: transfer should:
     * Decrease from address accountTokens
     * Increase to address accountTokens
    */
    function testFuzz_transfer(uint _amount) public {
        // PRECONDITIONS:
        uint256 amount = _between(_amount, 1, MAX);      

        if(!setUnderlying) {
            initUnderlying(amount);
            underlying.approve(address(ctoken), amount);
            try ctoken.mint(amount) {} catch {/*assert(false);*/}// overflow
        }        

        uint userBalBefore = ctoken.balanceOf(address(this));
        uint otherUserBalBefore = ctoken.balanceOf(RANDO);  

        // ACTION:
        try ctoken.transfer(RANDO, amount) {
            // POSTCONDTIONS:
            uint userBalAfter = ctoken.balanceOf(address(this));
            uint otherUserBalAfter = ctoken.balanceOf(RANDO);            

            assertGt(otherUserBalAfter, otherUserBalBefore, "OTHER USER BALANCE CHECK");
            assertLt(userBalAfter, userBalBefore, "USER BALANCE CHECK");
        } catch {/*assert(false);*/}// overflow   
    }

    /* INVARIANTS: transfer should:
     * Decrease from address accountTokens
     * Increase to address accountTokens
     * Decrease transferAllowances if != type(uint).max
    */
    function testFuzz_transferFrom(uint _amount) public {
        // PRECONDITIONS:
        uint256 amount = _between(_amount, 1, MAX);

        if(!setUnderlying) {
            initUnderlying(amount);
            underlying.approve(address(ctoken), amount);
            try ctoken.mint(amount) {} catch {/*assert(false);*/}// overflow
        }        

        uint userBalBefore = ctoken.balanceOf(address(this));
        uint otherUserBalBefore = ctoken.balanceOf(RANDO);  

        ctoken.approve(RANDO, amount);
        uint otherUserAllowanceBefore = ctoken.allowance(address(this), RANDO);

        // ACTION:
        vm.startPrank(RANDO);
        try ctoken.transferFrom(address(this), RANDO, amount) {
            // POSTCONDTIONS:
            uint userBalAfter = ctoken.balanceOf(address(this));
            uint otherUserBalAfter = ctoken.balanceOf(RANDO);   
            uint otherUserAllowanceAfter = ctoken.allowance(address(this), RANDO);  

            if (otherUserAllowanceBefore == MAX) {
                assertEq(otherUserAllowanceAfter, MAX, "USER ALLOWANCE CHECK");
            } else {
                assertLt(otherUserAllowanceAfter, otherUserAllowanceBefore, "USER ALLOWANCE CHECK");
            }      
    
            assertGt(otherUserBalAfter, otherUserBalBefore, "OTHER USER BALANCE CHECK");
            assertLt(userBalAfter, userBalBefore, "USER BALANCE CHECK");
        } catch {/*assert(false);*/}// overflow
    }    

    // Helper functions
    function accrualHelper(uint borrowIndexAfter, uint totalBorrowsAfter, uint totalReservesAfter) public {
        uint accrualBlockNumberAfter = ctoken.accrualBlockNumber();
        uint borrowIndex = ctoken.borrowIndex();
        uint totalBorrows = ctoken.totalBorrows();
        uint totalReserves = ctoken.totalReserves();
        
        assertEq(accrualBlockNumberAfter, uint32(testComptroller.getBlockNumber()), "BLOCK CHECK");  
        assertEq(borrowIndex, borrowIndexAfter, "BORROW INDEX CHECK");  
        assertGe(totalBorrows, totalBorrowsAfter, "TOTAL BORROWS CHECK");  
        assertEq(totalReserves, totalReservesAfter, "TOTAL RESERVES CHECK"); 
    }

    function mintHelper(uint indexBefore, uint compAccruedBefore, uint compSupplierIndexBefore) public {
        (uint224 indexAfter, uint32 block) = testComptroller.compSupplyState(address(ctoken));
        uint compSupplierIndexAfter = testComptroller.compSupplierIndex(address(ctoken), address(this));
        uint compAccruedAfter = testComptroller.compAccrued(address(this));

        assertGe(indexAfter, indexBefore, "SUPPLY INDEX CHECK");
        assertGe(compSupplierIndexAfter, compSupplierIndexBefore, "COMP SUPPLIER INDEX CHECK");
        assertGe(compAccruedAfter, compAccruedBefore, "SUPPLIER COMP ACCRUED CHECK");
        assertEq(block, uint32(testComptroller.getBlockNumber()), "BLOCK CHECK");    
    }   

    function redeemHelper(uint indexBefore, uint compAccruedBefore, uint compSupplierIndexBefore) public {
        (uint224 indexAfter, uint32 block) = testComptroller.compSupplyState(address(ctoken));
        uint compSupplierIndexAfter = testComptroller.compSupplierIndex(address(ctoken), address(this));
        uint compAccruedAfter = testComptroller.compAccrued(address(this));

        assertGe(indexAfter, indexBefore, "SUPPLY INDEX CHECK");
        assertGe(compSupplierIndexAfter, compSupplierIndexBefore, "COMP SUPPLIER INDEX CHECK");
        assertLe(compAccruedAfter, compAccruedBefore, "SUPPLIER COMP ACCRUED CHECK");
        assertEq(block, uint32(testComptroller.getBlockNumber()), "BLOCK CHECK");    
    }        

    function borrowHelper(uint totalBorrowsBefore, uint userPrincipalBefore, uint userInterestIndexBefore) public {
        (uint userPrincipalAfter, uint userInterestIndexAfter) = ctoken.getAccountBorrows(address(this));
        uint totalBorrowsAfter = ctoken.totalBorrows();

        assertGt(totalBorrowsAfter, totalBorrowsBefore, "TOTAL BORROWS CHECK");
        assertGe(userPrincipalAfter, userPrincipalBefore, "USER PRINCIPAL CHECK");
        assertGe(userInterestIndexAfter, userInterestIndexBefore, "USER INTEREST INDEX CHECK");
    }      

    function repayBorrowHelper(uint totalBorrowsBefore, uint userPrincipalBefore, uint userInterestIndexBefore) public {
        (uint userPrincipalAfter, uint userInterestIndexAfter) = ctoken.getAccountBorrows(address(this));
        uint totalBorrowsAfter = ctoken.totalBorrows();

        assertLt(totalBorrowsAfter, totalBorrowsBefore, "TOTAL BORROWS CHECK");
        assertLe(userPrincipalAfter, userPrincipalBefore, "USER PRINCIPAL CHECK");
        assertLe(userInterestIndexAfter, userInterestIndexBefore, "USER INTEREST INDEX CHECK");
    }          

    function accrueIntrestHelper(uint userUnderlyingBalanceBefore) public  returns(uint borrowIndexAfter, uint totalBorrowsAfter, uint totalReservesAfter){
        // Taken from cToken and reworked to function here
        
        /* Calculate the current borrow interest rate */
        uint borrowRateMantissa = wpirm.getBorrowRate(userUnderlyingBalanceBefore, ctoken.totalBorrows(), ctoken.totalReserves());
        // 0.0005e16 is the borrowRateMaxMantissa in CTokenInterFaces.sol
        require(borrowRateMantissa <= 0.0005e16, "borrow rate is absurdly high");

        /* Calculate the number of blocks elapsed since the last accrual */
        uint accrualBlockNumberPrior = ctoken.accrualBlockNumber();
        uint blockDelta = block.number - accrualBlockNumberPrior;

        /*
         * Calculate the interest accumulated into borrows and reserves and the new index:
         *  simpleInterestFactor = borrowRate * blockDelta
         *  interestAccumulated = simpleInterestFactor * totalBorrows
         *  totalBorrowsNew = interestAccumulated + totalBorrows
         *  totalReservesNew = interestAccumulated * reserveFactor + totalReserves
         *  borrowIndexNew = simpleInterestFactor * borrowIndex + borrowIndex
         */
        Exp memory simpleInterestFactor = mul_(Exp({mantissa: borrowRateMantissa}), blockDelta);
        uint interestAccumulated = mul_ScalarTruncate(simpleInterestFactor, ctoken.totalBorrows());
        totalBorrowsAfter = interestAccumulated + ctoken.totalBorrows();
        totalReservesAfter = mul_ScalarTruncateAddUInt(Exp({mantissa: ctoken.reserveFactorMantissa()}), interestAccumulated, ctoken.totalReserves());
        borrowIndexAfter = mul_ScalarTruncateAddUInt(simpleInterestFactor, ctoken.borrowIndex(), ctoken.borrowIndex());        
    }

    // Helper functions to mint tokens when necessary
    bool setUnderlying;
    function initUnderlying(uint256 amount) public {
        try underlying.mint(address(this), amount) {} catch {/*assert(false);*/}// overflow
        setUnderlying = true;
    }

    // Helper functions to mint tokens when necessary
    bool setToken;
    function initToken(uint256 amount) public {
        try randoToken.mint(address(ctoken), amount) {} catch {/*assert(false);*/}// overflow
        setToken = true;
    }     

    // Mantissa helper
    struct Exp {
        uint mantissa;
    }    

    // Math Helpers taken from ExponentialNoError.sol to be used here
    function truncate(Exp memory exp) pure internal returns (uint) {
        // Note: We are not using careful math here as we're performing a division that cannot fail
        // 1e18 is the expScale in ExponentialNoError.sol 
        return exp.mantissa / 1e18;
    }

    function mul_ScalarTruncate(Exp memory a, uint scalar) pure internal returns (uint) {
        Exp memory product = mul_(a, scalar);
        return truncate(product);
    }    

    function mul_(Exp memory a, Exp memory b) pure internal returns (Exp memory) {
        return Exp({mantissa: mul_(a.mantissa, b.mantissa) / 1e18});
    }

    function mul_(Exp memory a, uint b) pure internal returns (Exp memory) {
        return Exp({mantissa: mul_(a.mantissa, b)});
    }

    function mul_(uint a, Exp memory b) pure internal returns (uint) {
        return mul_(a, b.mantissa) / 1e18;
    }

    function mul_(uint a, uint b) pure internal returns (uint) {
        return a * b;
    }

    function mul_ScalarTruncateAddUInt(Exp memory a, uint scalar, uint addend) pure internal returns (uint) {
        Exp memory product = mul_(a, scalar);
        return add_(truncate(product), addend);
    }    

    function add_(Exp memory a, Exp memory b) pure internal returns (Exp memory) {
        return Exp({mantissa: add_(a.mantissa, b.mantissa)});
    }    

    function add_(uint a, uint b) pure internal returns (uint) {
        return a + b;
    }      


    // Bounding function similar to vm.assume but is more efficient regardless of the fuzzying framework
	// This is also a guarante bound of the input unlike vm.assume which can only be used for narrow checks     
	function _between(uint256 random, uint256 low, uint256 high) public pure returns (uint256) {
		return low + random % (high-low);
	}    
}