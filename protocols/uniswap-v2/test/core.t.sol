// SPDX-License-Identifier: NONE
pragma solidity ^0.8.0;

// Test Helpers, Mock Tokens
import "forge-std/Test.sol";
import "./MockWETH.sol";
import {DeflatingERC20} from "@uniPer/test/DeflatingERC20.sol";
import {MockToken} from "./MockToken.sol";

// Pair factory and Pair
import "@uniCore/UniswapV2Factory.sol";
import "@uniCore/UniswapV2Pair.sol";

// Routerss
import "@uniPer/UniswapV2Router02.sol";

contract TestCore is Test {
    uint256 MAX = type(uint256).max; 

    bytes32 public constant PERMIT_TYPEHASH = 0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;
    
    // Mock Tokens
    MockToken usdc;
    MockToken usdt;
    DeflatingERC20 feeToken;
    MockWETH weth;
    
    // Pair factory and Pair
    UniswapV2Pair testStablePair;
    UniswapV2Factory testFactory;
    UniswapV2Pair testWethPair;
    UniswapV2Pair testFeeWethPair;
    UniswapV2Pair testFeePair;

    // Routers
    //UniswapV2Router01 testRouter01;
    UniswapV2Router02 testRouter02;

    function setUp() public {
        vm.label(address(this), "THE_FUZZANATOR");

        // Deploy tokens
        usdc = new MockToken("USDC", "USDC", 18);
        vm.label(address(usdc), "USDC");

        usdt = new MockToken("USDT", "USDT", 6);
        vm.label(address(usdt), "USDT");   

        feeToken = new DeflatingERC20(0);
        vm.label(address(feeToken), "FEE_TOKEN"); 

        weth = new MockWETH();
        vm.label(address(weth), "WETH"); 

        // Deploy factory and Pairs
        testFactory = new UniswapV2Factory(address(this));
        vm.label(address(testFactory), "FACTORY");

        testStablePair = UniswapV2Pair(testFactory.createPair(address(usdc), address(usdt)));
        vm.label(address(testStablePair), "STABLE_PAIR");  

        testWethPair = UniswapV2Pair(testFactory.createPair(address(usdc), address(weth)));
        vm.label(address(testWethPair), "WETH_PAIR");  

        testFeeWethPair = UniswapV2Pair(testFactory.createPair(address(weth), address(feeToken)));
        vm.label(address(testFeeWethPair), "FEEWETH_PAIR");          

        testFeePair = UniswapV2Pair(testFactory.createPair(address(feeToken), address(usdc)));
        vm.label(address(testFeeWethPair), "FEE_PAIR");                  

        // Deploy Router
        testRouter02 = new UniswapV2Router02(address(testFactory), address(weth));
        vm.label(address(testRouter02), "ROUTER");

        // Approve Router
        usdc.approve(address(testRouter02), MAX);
        usdt.approve(address(testRouter02), MAX);
        feeToken.approve(address(testRouter02), MAX);
        weth.approve(address(testRouter02), MAX);
    }

    /* INVARIANT: Adding liquidity to a pair should:
     * Increase reserves
     * Increase address to balance
     * Increase totalSupply
     * Increase K
    */
    function testFuzz_AddLiq(uint amount1, uint amount2) public {
        // PRECONDTION:
        uint _amount1 = this._between(amount1, (10**3), MAX);
        uint _amount2 = this._between(amount2, (10**3), MAX);
        if(!setStable) {
            _init(_amount1, _amount2);
        }        

        (uint reserveABefore, uint reserveBBefore, ) = testStablePair.getReserves();
        (uint totalSupplyBefore) = testStablePair.totalSupply();
        (uint userBalBefore) = testStablePair.balanceOf(address(this));
        uint kBefore = reserveABefore * reserveBBefore;
        
        // ACTION:
        try testRouter02.addLiquidity(address(usdc), address(usdt), _amount1, _amount2, 0, 0, address(this), MAX) {
            
            // POSTCONDTION:
            (uint reserveAAfter, uint reserveBAfter, ) = testStablePair.getReserves();
            (uint totalSupplyAfter) = testStablePair.totalSupply();
            (uint userBalAfter) = testStablePair.balanceOf(address(this));  
            uint kAfter = reserveAAfter * reserveBAfter;

            assertGt(reserveAAfter, reserveABefore, "RESERVE TOKEN A CHECK");
            assertGt(reserveBAfter, reserveBBefore, "RESERVE TOKEN B CHECK");
            assertGt(kAfter, kBefore, "K CHECK");
            assertGt(totalSupplyAfter, totalSupplyBefore, "TOTAL SUPPLY CHECK");
            assertGt(userBalAfter, userBalBefore, "USER BAL CHECK");
        } catch {/*assert(false)*/} // overflow
    }

    /* INVARIANT: Adding ETH liquidity to a pair should:
     * Increase reserves
     * Increase address to balance
     * Increase totalSupply
     * Increase K
    */
    function testFuzz_ETHAddLiq(uint amount) public {
        // PRECONDTION:
        uint _amount = this._between(amount, (10**3), MAX);

        if(!setETH) {
            _initETH(_amount);
        }        

        (uint reserveABefore, uint reserveBBefore, ) = testWethPair.getReserves();
        (uint totalSupplyBefore) = testWethPair.totalSupply();
        (uint userBalBefore) = testWethPair.balanceOf(address(this));
        uint kBefore = reserveABefore * reserveBBefore;
        
        // ACTION:
        try testRouter02.addLiquidityETH{value: _amount}(address(usdc), _amount, 0, 0, address(this), MAX) {
            
            // POSTCONDTION:
            (uint reserveAAfter, uint reserveBAfter, ) = testWethPair.getReserves();
            (uint totalSupplyAfter) = testWethPair.totalSupply();
            (uint userBalAfter) = testWethPair.balanceOf(address(this));  
            uint kAfter = reserveAAfter * reserveBAfter;

            assertGt(reserveAAfter, reserveABefore, "RESERVE TOKEN A CHECK");
            assertGt(reserveBAfter, reserveBBefore, "RESERVE TOKEN B CHECK");
            assertGt(kAfter, kBefore, "K CHECK");
            assertGt(totalSupplyAfter, totalSupplyBefore, "TOTAL SUPPLY CHECK");
            assertGt(userBalAfter, userBalBefore, "USER BAL CHECK");
        } catch {/*assert(false)*/} // overflow
    }    


    /* INVARIANT: Removing liquidity from a pair should:
     * Keep reserves the same
     * Keep the address to balance the same
     * Keep totalSupply the same
     * Keep K the same
    */
    function testFuzz_RemoveLiq(uint amount1, uint amount2) public {
        // PRECONDTION:
        uint _amount1 = this._between(amount1, (10**3), MAX);
        uint _amount2 = this._between(amount2, (10**3), MAX);
        if(!setStable) {
            _init(_amount1, _amount2);
        }        
        
        try testRouter02.addLiquidity(address(usdc), address(usdt), _amount1, _amount2, 0, 0, address(this), MAX) returns(uint, uint, uint liquidity) {
            (uint reserveABefore, uint reserveBBefore, ) = testStablePair.getReserves();
            (uint totalSupplyBefore) = testStablePair.totalSupply();
            (uint userBalBefore) = testStablePair.balanceOf(address(this));
            uint kBefore = reserveABefore * reserveBBefore;            
            
            // ACTION:
            try testRouter02.removeLiquidity(address(usdc), address(usdt), liquidity, 0, 0, address(this), MAX) {
                
                // POSTCONDTION:
                (uint reserveAAfter, uint reserveBAfter, ) = testStablePair.getReserves();
                (uint totalSupplyAfter) = testStablePair.totalSupply();
                (uint userBalAfter) = testStablePair.balanceOf(address(this));  
                uint kAfter = reserveAAfter * reserveBAfter;

                assertLt(reserveAAfter, reserveABefore, "RESERVE TOKEN A CHECK");
                assertLt(reserveBAfter, reserveBBefore, "RESERVE TOKEN B CHECK");
                assertLt(kAfter, kBefore, "K CHECK");
                assertLt(totalSupplyAfter, totalSupplyBefore, "TOTAL SUPPLY CHECK");
                assertLt(userBalAfter, userBalBefore, "USER BAL CHECK");
            } catch {/*assert(false)*/} // overflow
        } catch {/*assert(false)*/} // overflow
    }

    /* INVARIANT: Removing ETH liquidity from a pair should:
     * Keep reserves the same
     * Keep the address to balance the same
     * Keep totalSupply the same
     * Keep K the same
    */
    function testFuzz_ETHRemoveLiq(uint amount) public {
        // PRECONDTION:
        uint _amount = this._between(amount, (10**3), MAX);

        if(!setETH) {
            _initETH(_amount);
        }        
        
        try testRouter02.addLiquidityETH{value: _amount}(address(usdc), _amount, 0, 0, address(this), MAX) returns(uint, uint, uint liquidity) {
            (uint reserveABefore, uint reserveBBefore, ) = testWethPair.getReserves();
            (uint totalSupplyBefore) = testWethPair.totalSupply();
            (uint userBalBefore) = testWethPair.balanceOf(address(this));
            uint kBefore = reserveABefore * reserveBBefore;            

            // ACTION:
            try testRouter02.removeLiquidityETH(address(usdc), liquidity, 0, 0, address(this), MAX) {

                // POSTCONDTION:
                (uint reserveAAfter, uint reserveBAfter, ) = testWethPair.getReserves();
                (uint totalSupplyAfter) = testWethPair.totalSupply();
                (uint userBalAfter) = testWethPair.balanceOf(address(this));  
                uint kAfter = reserveAAfter * reserveBAfter;

                assertLt(reserveAAfter, reserveABefore, "RESERVE TOKEN A CHECK");
                assertLt(reserveBAfter, reserveBBefore, "RESERVE TOKEN B CHECK");
                assertLt(kAfter, kBefore, "K CHECK");
                assertLt(totalSupplyAfter, totalSupplyBefore, "TOTAL SUPPLY CHECK");
                assertLt(userBalAfter, userBalBefore, "USER BAL CHECK");
            } catch {/*assert(false)*/} // overflow
        } catch {/*assert(false)*/} // overflow
    }    

    /* INVARIANT: Removing liquidity from a pair should: 
     * Decrease reserves
     * Decrease address to balance
     * Decrease totalSupply
     * Decrease K
    */
    function testFuzz_removeLiqWithPermit(uint248 privKey, uint amount1, uint amount2, bool approveMax, uint deadline) public {
        // PRECONDTION:
        uint _amount1 = this._between(amount1, (10**3), MAX);
        uint _amount2 = this._between(amount2, (10**3), MAX);
         
        uint256 privateKey = privKey;
        if (deadline < block.timestamp) deadline = block.timestamp;
        if (privateKey == 0) privateKey = 1;

        address owner = vm.addr(privateKey);

        if(!setPermit) {
            _initPermit(owner, _amount1, _amount2);
            vm.startPrank(owner);
            usdc.approve(address(testRouter02), _amount1);
            usdt.approve(address(testRouter02), _amount2);            
        }        
        
        try testRouter02.addLiquidity(address(usdc), address(usdt), _amount1, _amount2, 0, 0, owner, MAX) returns(uint, uint, uint liquidity) {
            (uint reserveABefore, uint reserveBBefore, ) = testStablePair.getReserves();
            (uint totalSupplyBefore) = testStablePair.totalSupply();
            (uint userBalBefore) = testStablePair.balanceOf(address(owner));
            uint kBefore = reserveABefore * reserveBBefore;            
            
            if (approveMax) {
                liquidity = type(uint256).max;
                (uint8 v, bytes32 r, bytes32 s) = vm.sign(
                    privateKey,
                    keccak256(
                        abi.encodePacked(
                            "\x19\x01",
                            testStablePair.DOMAIN_SEPARATOR(),
                            keccak256(abi.encode(PERMIT_TYPEHASH, owner, address(testRouter02), liquidity, 0, deadline))
                        )
                    )
                );
                    
                // ACTION:         
                try testRouter02.removeLiquidityWithPermit(address(usdc), address(usdt), liquidity, 0, 0, owner, MAX, approveMax, v, r, s) {
                        
                    // POSTCONDTION:
                    (uint reserveAAfter, uint reserveBAfter, ) = testStablePair.getReserves();
                    (uint totalSupplyAfter) = testStablePair.totalSupply();
                    (uint userBalAfter) = testStablePair.balanceOf(address(this));  
                    uint kAfter = reserveAAfter * reserveBAfter;

                    assertLt(reserveAAfter, reserveABefore, "RESERVE TOKEN A CHECK");
                    assertLt(reserveBAfter, reserveBBefore, "RESERVE TOKEN B CHECK");
                    assertLt(kAfter, kBefore, "K CHECK");
                    assertLt(totalSupplyAfter, totalSupplyBefore, "TOTAL SUPPLY CHECK");
                    assertLt(userBalAfter, userBalBefore, "USER BAL CHECK");
                } catch {/*assert(false)*/} // overflow                
            } else {
                (uint8 v, bytes32 r, bytes32 s) = vm.sign(
                    privateKey,
                    keccak256(
                        abi.encodePacked(
                            "\x19\x01",
                            testStablePair.DOMAIN_SEPARATOR(),
                            keccak256(abi.encode(PERMIT_TYPEHASH, owner, address(testRouter02), liquidity, 0, deadline))
                        )
                    )
                );
                    
                // ACTION:         
                try testRouter02.removeLiquidityWithPermit(address(usdc), address(usdt), liquidity, 0, 0, owner, MAX, approveMax, v, r, s) {
                        
                    // POSTCONDTION:
                    (uint reserveAAfter, uint reserveBAfter, ) = testStablePair.getReserves();
                    (uint totalSupplyAfter) = testStablePair.totalSupply();
                    (uint userBalAfter) = testStablePair.balanceOf(address(this));  
                    uint kAfter = reserveAAfter * reserveBAfter;

                    assertLt(reserveAAfter, reserveABefore, "RESERVE TOKEN A CHECK");
                    assertLt(reserveBAfter, reserveBBefore, "RESERVE TOKEN B CHECK");
                    assertLt(kAfter, kBefore, "K CHECK");
                    assertLt(totalSupplyAfter, totalSupplyBefore, "TOTAL SUPPLY CHECK");
                    assertLt(userBalAfter, userBalBefore, "USER BAL CHECK");
                } catch {/*assert(false)*/} // overflow                
            }
        } catch {/*assert(false)*/} // overflow        
    }

    /* INVARIANT: Removing liquidity from a pair should: 
     * Decrease reserves
     * Decrease address to balance
     * Decrease totalSupply
     * Decrease K
    */    
    function testFuzz_removeLiqETHWithPermit(uint248 privKey, uint amount, bool approveMax, uint deadline) public {
        // PRECONDTION:
        uint _amount = this._between(amount, (10**3), MAX);

        uint256 privateKey = privKey;
        if (deadline < block.timestamp) deadline = block.timestamp;
        if (privateKey == 0) privateKey = 1;

        address owner = vm.addr(privateKey);

        if(!setPermitETHFee) {
            _initPermitETH(owner, _amount);
            vm.startPrank(owner);
            weth.approve(address(testRouter02), _amount);
            usdc.approve(address(testRouter02), _amount);              
        }                
        
        try testRouter02.addLiquidityETH{value: _amount}(address(usdc), _amount, 0, 0, owner, MAX) returns(uint, uint, uint liquidity) {
            (uint reserveABefore, uint reserveBBefore, ) = testWethPair.getReserves();
            (uint totalSupplyBefore) = testWethPair.totalSupply();
            (uint userBalBefore) = testWethPair.balanceOf(address(this));
            uint kBefore = reserveABefore * reserveBBefore;            

            if (approveMax) {
                liquidity = type(uint256).max;
                (uint8 v, bytes32 r, bytes32 s) = vm.sign(
                    privateKey,
                    keccak256(
                        abi.encodePacked(
                            "\x19\x01",
                            testStablePair.DOMAIN_SEPARATOR(),
                            keccak256(abi.encode(PERMIT_TYPEHASH, owner, address(testRouter02), liquidity, 0, deadline))
                        )
                    )
                );

                // ACTION:
                try testRouter02.removeLiquidityETHWithPermit(address(usdc), liquidity, 0, 0, owner, MAX, approveMax, v, r, s) {

                    // POSTCONDTION:
                    (uint reserveAAfter, uint reserveBAfter, ) = testWethPair.getReserves();
                    (uint totalSupplyAfter) = testWethPair.totalSupply();
                    (uint userBalAfter) = testWethPair.balanceOf(address(this));  
                    uint kAfter = reserveAAfter * reserveBAfter;

                    assertLt(reserveAAfter, reserveABefore, "RESERVE TOKEN A CHECK");
                    assertLt(reserveBAfter, reserveBBefore, "RESERVE TOKEN B CHECK");
                    assertLt(kAfter, kBefore, "K CHECK");
                    assertLt(totalSupplyAfter, totalSupplyBefore, "TOTAL SUPPLY CHECK");
                    assertLt(userBalAfter, userBalBefore, "USER BAL CHECK");
                } catch {/*assert(false)*/} // overflow                

            } else {
                (uint8 v, bytes32 r, bytes32 s) = vm.sign(
                    privateKey,
                    keccak256(
                        abi.encodePacked(
                            "\x19\x01",
                            testStablePair.DOMAIN_SEPARATOR(),
                            keccak256(abi.encode(PERMIT_TYPEHASH, owner, address(testRouter02), liquidity, 0, deadline))
                        )
                    )
                );

                // ACTION:
                try testRouter02.removeLiquidityETHWithPermit(address(usdc), liquidity, 0, 0, owner, MAX, approveMax, v, r, s) {

                    // POSTCONDTION:
                    (uint reserveAAfter, uint reserveBAfter, ) = testWethPair.getReserves();
                    (uint totalSupplyAfter) = testWethPair.totalSupply();
                    (uint userBalAfter) = testWethPair.balanceOf(address(this));  
                    uint kAfter = reserveAAfter * reserveBAfter;

                    assertLt(reserveAAfter, reserveABefore, "RESERVE TOKEN A CHECK");
                    assertLt(reserveBAfter, reserveBBefore, "RESERVE TOKEN B CHECK");
                    assertLt(kAfter, kBefore, "K CHECK");
                    assertLt(totalSupplyAfter, totalSupplyBefore, "TOTAL SUPPLY CHECK");
                    assertLt(userBalAfter, userBalBefore, "USER BAL CHECK");
                } catch {/*assert(false)*/} // overflow
            }
        } catch {/*assert(false)*/} // overflow        
    }

    /* INVARIANT: Removing liquidity from a pair should: 
     * Decrease reserves
     * Decrease address to balance
     * Decrease totalSupply
     * Decrease K
    */    
    function testFuzz_removeLiqETHSupportingFeeOnTransferTokens(uint amount) public {
        // PRECONDTION:
        uint _amount = this._between(amount, (10**3), MAX);

        if(!setETHFee) {
            _initETHFee(_amount);
        }        
        
        try testRouter02.addLiquidityETH{value: _amount}(address(feeToken), _amount, 0, 0, address(this), MAX) returns(uint, uint, uint liquidity) {
            (uint reserveABefore, uint reserveBBefore, ) = testFeePair.getReserves();
            (uint totalSupplyBefore) = testFeePair.totalSupply();
            (uint userBalBefore) = testFeePair.balanceOf(address(this));
            uint kBefore = reserveABefore * reserveBBefore;            

            // ACTION:
            try testRouter02.removeLiquidityETHSupportingFeeOnTransferTokens(address(feeToken), liquidity, 0, 0, address(this), MAX) {

                // POSTCONDTION:
                (uint reserveAAfter, uint reserveBAfter, ) = testFeePair.getReserves();
                (uint totalSupplyAfter) = testFeePair.totalSupply();
                (uint userBalAfter) = testFeePair.balanceOf(address(this));  
                uint kAfter = reserveAAfter * reserveBAfter;

                assertLt(reserveAAfter, reserveABefore, "RESERVE TOKEN A CHECK");
                assertLt(reserveBAfter, reserveBBefore, "RESERVE TOKEN B CHECK");
                assertLt(kAfter, kBefore, "K CHECK");
                assertLt(totalSupplyAfter, totalSupplyBefore, "TOTAL SUPPLY CHECK");
                assertLt(userBalAfter, userBalBefore, "USER BAL CHECK");
            } catch {/*assert(false)*/} // overflow
        } catch {/*assert(false)*/} // overflow    
    }

    /* INVARIANT: Removing liquidity from a pair should: 
     * Decrease reserves
     * Decrease address to balance
     * Decrease totalSupply
     * Decrease K
    */    
    function testFuzz_removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(uint248 privKey, uint amount, bool approveMax, uint deadline) public {
        // PRECONDTION:
        uint _amount = this._between(amount, (10**3), MAX);

        uint256 privateKey = privKey;
        if (deadline < block.timestamp) deadline = block.timestamp;
        if (privateKey == 0) privateKey = 1;

        address owner = vm.addr(privateKey);

        if(!setPermitETHFee) {
            _initPermitETHFee(owner, _amount);
            vm.startPrank(owner);
            weth.approve(address(testRouter02), _amount);
            feeToken.approve(address(testRouter02), _amount);              
        }                
        
        try testRouter02.addLiquidityETH{value: _amount}(address(feeToken), _amount, 0, 0, owner, MAX) returns(uint, uint, uint liquidity) {
            (uint reserveABefore, uint reserveBBefore, ) = testWethPair.getReserves();
            (uint totalSupplyBefore) = testWethPair.totalSupply();
            (uint userBalBefore) = testWethPair.balanceOf(address(this));
            uint kBefore = reserveABefore * reserveBBefore;            

            if (approveMax) {
                liquidity = type(uint256).max;
                (uint8 v, bytes32 r, bytes32 s) = vm.sign(
                    privateKey,
                    keccak256(
                        abi.encodePacked(
                            "\x19\x01",
                            testStablePair.DOMAIN_SEPARATOR(),
                            keccak256(abi.encode(PERMIT_TYPEHASH, owner, address(testRouter02), liquidity, 0, deadline))
                        )
                    )
                );

                // ACTION:
                try testRouter02.removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(address(feeToken), liquidity, 0, 0, owner, MAX, approveMax, v, r, s) {

                    // POSTCONDTION:
                    (uint reserveAAfter, uint reserveBAfter, ) = testWethPair.getReserves();
                    (uint totalSupplyAfter) = testWethPair.totalSupply();
                    (uint userBalAfter) = testWethPair.balanceOf(address(this));  
                    uint kAfter = reserveAAfter * reserveBAfter;

                    assertLt(reserveAAfter, reserveABefore, "RESERVE TOKEN A CHECK");
                    assertLt(reserveBAfter, reserveBBefore, "RESERVE TOKEN B CHECK");
                    assertLt(kAfter, kBefore, "K CHECK");
                    assertLt(totalSupplyAfter, totalSupplyBefore, "TOTAL SUPPLY CHECK");
                    assertLt(userBalAfter, userBalBefore, "USER BAL CHECK");
                } catch {/*assert(false)*/} // overflow                

            } else {
                (uint8 v, bytes32 r, bytes32 s) = vm.sign(
                    privateKey,
                    keccak256(
                        abi.encodePacked(
                            "\x19\x01",
                            testStablePair.DOMAIN_SEPARATOR(),
                            keccak256(abi.encode(PERMIT_TYPEHASH, owner, address(testRouter02), liquidity, 0, deadline))
                        )
                    )
                );

                // ACTION:
                try testRouter02.removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(address(feeToken), liquidity, 0, 0, owner, MAX, approveMax, v, r, s) {

                    // POSTCONDTION:
                    (uint reserveAAfter, uint reserveBAfter, ) = testWethPair.getReserves();
                    (uint totalSupplyAfter) = testWethPair.totalSupply();
                    (uint userBalAfter) = testWethPair.balanceOf(address(this));  
                    uint kAfter = reserveAAfter * reserveBAfter;

                    assertLt(reserveAAfter, reserveABefore, "RESERVE TOKEN A CHECK");
                    assertLt(reserveBAfter, reserveBBefore, "RESERVE TOKEN B CHECK");
                    assertLt(kAfter, kBefore, "K CHECK");
                    assertLt(totalSupplyAfter, totalSupplyBefore, "TOTAL SUPPLY CHECK");
                    assertLt(userBalAfter, userBalBefore, "USER BAL CHECK");
                } catch {/*assert(false)*/} // overflow
            }
        } catch {/*assert(false)*/} // overflow            
    }

    /* INVARIANT: swapExactTokensForTokens within a pair should:
     * Decrease balance of user for token 2
     * Increase balance of user for token 1
     * K should decrease or remain the same 
    */
    function testFuzz_swapExactTokensForTokens(uint amount) public  {
        // PRECONDITIONS:   
        uint _amount = _between(amount, 1, MAX);

        (uint reserveABefore, uint reserveBBefore) = UniswapV2Library.getReserves(address(testFactory), address(usdc), address(usdt));
        uint kBefore = reserveABefore * reserveBBefore; 

        if(!setStable) {
            _init(_amount, _amount);
            // For some reserves
            try usdt.mint(address(testStablePair), 100000) {} catch {/*assert(false)*/} // overflow
            try usdc.mint(address(testStablePair), 100000) {} catch {/*assert(false)*/} // overflow
            testStablePair.sync();
        }             
        address[] memory path = new address[](2);
        path[0] = address(usdc);
        path[1] = address(usdt);

        uint userBalBefore1 = UniswapV2ERC20(path[0]).balanceOf(address(this));
        uint userBalBefore2 = UniswapV2ERC20(path[1]).balanceOf(address(this));
        require(userBalBefore1 > 0, "NO BAL");

        // ACTION: 
        try testRouter02.swapExactTokensForTokens(_amount, 0, path, address(this), MAX) {
            //POSTCONDITIONS:
            uint userBalAfter1 = UniswapV2ERC20(path[0]).balanceOf(address(this));
            uint userBalAfter2  = UniswapV2ERC20(path[1]).balanceOf(address(this));
            (uint reserveAAfter, uint reserveBAfter) = UniswapV2Library.getReserves(address(testFactory), address(usdc), address(usdt));
            uint kAfter = reserveAAfter * reserveBAfter;

            assertGe(kAfter, kBefore, "K CHECK"); 
            assertLt(userBalBefore2, userBalAfter2, "USER BAL 2 CHECK");
            assertGt(userBalBefore1, userBalAfter1, "USER BAL 1 CHECK");
        } catch {/*assert(false)*/} // overflow
    }

    /* INVARIANT: Swapping within a pair should:
     * Decrease balance of user for token 2
     * Increase balance of user for token 1
     * K should decrease or remain the same 
    */
    function testFuzz_swapExactETHForTokens(uint amount) public {
        // PRECONDITIONS:   
        uint _amount = _between(amount, 1, MAX);
        
        if(!setETH) {
            _initETH(_amount);
            // For some reserves
            try usdc.mint(address(testWethPair), 100000000000000) {} catch {/*assert(false)*/} // overflow
            vm.deal(address(this), 100 ether);
            weth.deposit{value: 100 ether}();
            weth.transfer(address(testWethPair), 100);
            testWethPair.sync();            
        }             
        address[] memory path = new address[](2);
        path[0] = address(weth);
        path[1] = address(usdc);

        uint userBalBefore1 = _amount;
        uint userBalBefore2 = UniswapV2ERC20(path[1]).balanceOf(address(this));
        require(userBalBefore1 > 0, "NO BAL");

        (uint reserveABefore, uint reserveBBefore) = UniswapV2Library.getReserves(address(testFactory), address(usdc), address(weth));
        uint kBefore = reserveABefore * reserveBBefore; 

        // ACTION: 
        try testRouter02.swapExactETHForTokens{value: 1 ether}(0, path, address(this), MAX) {
            //POSTCONDITIONS:
            uint userBalAfter1 = weth.balanceOf(address(this));
            uint userBalAfter2  = UniswapV2ERC20(path[1]).balanceOf(address(this));
            (uint reserveAAfter, uint reserveBAfter) = UniswapV2Library.getReserves(address(testFactory), address(usdc), address(weth));
            uint kAfter = reserveAAfter * reserveBAfter;

            assertGe(kAfter, kBefore, "K CHECK"); 
            assertLt(userBalBefore2, userBalAfter2, "USER BAL 2 CHECK");
            assertGt(userBalBefore1, userBalAfter1, "USER BAL 1 CHECK");
        } catch {/*assert(false)*/} // overflow        
    }

    /* INVARIANT: Swapping within a pair should:
     * Decrease balance of user for token 2
     * Increase balance of user for token 1
     * K should decrease or remain the same 
    */ 
    function testFuzz_swapTokensForExactETH(uint amount) public {
        // PRECONDITIONS:   
        uint _amount = _between(amount, 1, MAX);
        
        if(!setETH) {
            _initETH(_amount);
            // For some reserves
            try usdc.mint(address(testWethPair), 100000000000000) {} catch {/*assert(false)*/} // overflow
            vm.deal(address(this), 100 ether);
            weth.deposit{value: 100 ether}();
            weth.transfer(address(testWethPair), 100);
            testWethPair.sync();            
        }             
        address[] memory path = new address[](2);
        path[0] = address(usdc);
        path[1] = address(weth);

        uint userBalBefore1 = UniswapV2ERC20(path[0]).balanceOf(address(this));
        uint userBalBefore2 = _amount;
        require(userBalBefore1 > 0, "NO BAL");

        (uint reserveABefore, uint reserveBBefore) = UniswapV2Library.getReserves(address(testFactory), address(usdc), address(weth));
        uint kBefore = reserveABefore * reserveBBefore; 

        // ACTION: 
        try testRouter02.swapTokensForExactETH(MAX, 0, path, address(this), MAX) {
            //POSTCONDITIONS:
            uint userBalAfter1 = UniswapV2ERC20(path[0]).balanceOf(address(this));
            uint userBalAfter2  = UniswapV2ERC20(path[1]).balanceOf(address(this));
            (uint reserveAAfter, uint reserveBAfter) = UniswapV2Library.getReserves(address(testFactory), address(usdc), address(weth));
            uint kAfter = reserveAAfter * reserveBAfter;

            assertGe(kAfter, kBefore, "K CHECK"); 
            assertLt(userBalBefore2, userBalAfter2, "USER BAL 2 CHECK");
            assertGt(userBalBefore1, userBalAfter1, "USER BAL 1 CHECK");
        } catch {/*assert(false)*/} // overflow                
    }

    /* INVARIANT: Swapping within a pair should:
     * Decrease balance of user for token 2
     * Increase balance of user for token 1
     * K should decrease or remain the same 
    */
    function testFuzz_swapExactTokensForETH(uint amount) public {
        // PRECONDITIONS:   
        uint _amount = _between(amount, 1, MAX);
        
        if(!setETH) {
            _initETH(_amount);
            // For some reserves
            try usdc.mint(address(testWethPair), 100000000000000) {} catch {/*assert(false)*/} // overflow
            vm.deal(address(this), 100 ether);
            weth.deposit{value: 100 ether}();
            weth.transfer(address(testWethPair), 100);
            testWethPair.sync();            
        }             
        address[] memory path = new address[](2);
        path[0] = address(usdc);
        path[1] = address(weth);

        uint userBalBefore1 = UniswapV2ERC20(path[0]).balanceOf(address(this));
        uint userBalBefore2 = _amount;
        require(userBalBefore1 > 0, "NO BAL");

        (uint reserveABefore, uint reserveBBefore) = UniswapV2Library.getReserves(address(testFactory), address(usdc), address(weth));
        uint kBefore = reserveABefore * reserveBBefore; 

        // ACTION: 
        try testRouter02.swapExactTokensForETH(MAX, 0, path, address(this), MAX) {
            //POSTCONDITIONS:
            uint userBalAfter1 = UniswapV2ERC20(path[0]).balanceOf(address(this));
            uint userBalAfter2  = UniswapV2ERC20(path[1]).balanceOf(address(this));
            (uint reserveAAfter, uint reserveBAfter) = UniswapV2Library.getReserves(address(testFactory), address(usdc), address(weth));
            uint kAfter = reserveAAfter * reserveBAfter;

            assertGe(kAfter, kBefore, "K CHECK"); 
            assertLt(userBalBefore2, userBalAfter2, "USER BAL 2 CHECK");
            assertGt(userBalBefore1, userBalAfter1, "USER BAL 1 CHECK");
        } catch {/*assert(false)*/} // overflow           
    }

    /* INVARIANT: Swapping within a pair should:
     * Decrease balance of user for token 2
     * Increase balance of user for token 1
     * K should decrease or remain the same 
    */   
    function testFuzz_swapETHForExactTokens(uint amount) public {
        // PRECONDITIONS:   
        uint _amount = _between(amount, 1, MAX);
        
        if(!setETH) {
            _initETH(_amount);
            // For some reserves
            try usdc.mint(address(testWethPair), 100000000000000) {} catch {/*assert(false)*/} // overflow
            vm.deal(address(this), 100 ether);
            weth.deposit{value: 100 ether}();
            weth.transfer(address(testWethPair), 100);
            testWethPair.sync();            
        }             
        address[] memory path = new address[](2);
        path[0] = address(weth);
        path[1] = address(usdc);

        uint userBalBefore1 = _amount;
        uint userBalBefore2 = UniswapV2ERC20(path[1]).balanceOf(address(this));
        require(userBalBefore1 > 0, "NO BAL");

        (uint reserveABefore, uint reserveBBefore) = UniswapV2Library.getReserves(address(testFactory), address(usdc), address(weth));
        uint kBefore = reserveABefore * reserveBBefore; 

        // ACTION: 
        try testRouter02.swapExactETHForTokens{value: 1 ether}(0, path, address(this), MAX) {
            //POSTCONDITIONS:
            uint userBalAfter1 = weth.balanceOf(address(this));
            uint userBalAfter2  = UniswapV2ERC20(path[1]).balanceOf(address(this));
            (uint reserveAAfter, uint reserveBAfter) = UniswapV2Library.getReserves(address(testFactory), address(usdc), address(weth));
            uint kAfter = reserveAAfter * reserveBAfter;

            assertGe(kAfter, kBefore, "K CHECK"); 
            assertLt(userBalBefore2, userBalAfter2, "USER BAL 2 CHECK");
            assertGt(userBalBefore1, userBalAfter1, "USER BAL 1 CHECK");
        } catch {/*assert(false)*/} // overflow           
    }

    /* INVARIANT: Swapping within a pair should:
     * Decrease balance of user for token 2
     * Increase balance of user for token 1
     * K should decrease or remain the same 
    */   
    function testFuzz_swapExactTokensForTokensSupportingFeeOnTransferTokens(uint amount) public {
        // PRECONDITIONS:   
        uint _amount = _between(amount, 1, MAX);
        uint burnAmount = _amount / 100;

        (uint reserveABefore, uint reserveBBefore) = UniswapV2Library.getReserves(address(testFactory), address(usdc), address(feeToken));
        uint kBefore = reserveABefore * reserveBBefore; 

        if(!setFee) {
            _initFee(_amount, _amount);
            // For some reserves
            try feeToken.mint(address(testFeePair), 100000) {} catch {/*assert(false)*/} // overflow
            try usdc.mint(address(testFeePair), 100000) {} catch {/*assert(false)*/} // overflow
            testFeePair.sync();
        }             
        address[] memory path = new address[](2);
        path[0] = address(usdc);
        path[1] = address(feeToken);

        uint userBalBefore1 = UniswapV2ERC20(path[0]).balanceOf(address(this));
        uint userBalBefore2 = UniswapV2ERC20(path[1]).balanceOf(address(this));
        require(userBalBefore1 > 0, "NO BAL");

        // ACTION: 
        try testRouter02.swapExactTokensForTokensSupportingFeeOnTransferTokens(_amount, 0, path, address(this), MAX) {
            //POSTCONDITIONS:
            uint userBalAfter1 = UniswapV2ERC20(path[0]).balanceOf(address(this));
            uint userBalAfter2  = UniswapV2ERC20(path[1]).balanceOf(address(this));
            (uint reserveAAfter, uint reserveBAfter) = UniswapV2Library.getReserves(address(testFactory), address(usdc), address(feeToken));
            uint kAfter = reserveAAfter * reserveBAfter;

            assertGe(kAfter, kBefore, "K CHECK"); 
            assertLt(userBalBefore2 - burnAmount, userBalAfter2, "USER BAL 2 CHECK");
            assertGt(userBalBefore1, userBalAfter1, "USER BAL 1 CHECK");
        } catch {/*assert(false)*/} // overflow        
    }

    /* INVARIANT: Swapping within a pair should:
     * Decrease balance of user for token 2
     * Increase balance of user for token 1
     * K should decrease or remain the same 
    */   
    function testFuzz_swapExactETHForTokensSupportingFeeOnTransferTokens(uint amount) public {
        // PRECONDTION:
        uint _amount = this._between(amount, (10**3), MAX);
        uint burnAmount = _amount / 100;

        (uint reserveABefore, uint reserveBBefore) = UniswapV2Library.getReserves(address(testFactory), address(weth), address(feeToken));
        uint kBefore = reserveABefore * reserveBBefore;         

        if(!setETHFee) {
            _initETHFee(_amount);
            // For some reserves
            try feeToken.mint(address(testFeeWethPair), 100000) {} catch {/*assert(false)*/} // overflow
            vm.deal(address(this), 100 ether);
            weth.deposit{value: 100 ether}();
            weth.transfer(address(testFeeWethPair), 100);
            testFeeWethPair.sync();            
        }        
      
        address[] memory path = new address[](2);
        path[0] = address(weth);
        path[1] = address(feeToken);

        uint userBalBefore1 = UniswapV2ERC20(path[0]).balanceOf(address(this));
        uint userBalBefore2 = UniswapV2ERC20(path[1]).balanceOf(address(this));
        require(userBalBefore1 > 0, "NO BAL");            

        // ACTION:
        try testRouter02.swapExactETHForTokensSupportingFeeOnTransferTokens{value: _amount}( 0, path, address(this), MAX) {

            // POSTCONDTION:
            uint userBalAfter1 = UniswapV2ERC20(path[0]).balanceOf(address(this));
            uint userBalAfter2  = UniswapV2ERC20(path[1]).balanceOf(address(this));
            (uint reserveAAfter, uint reserveBAfter) = UniswapV2Library.getReserves(address(testFactory), address(usdc), address(feeToken));                uint kAfter = reserveAAfter * reserveBAfter;

            assertGe(kAfter, kBefore, "K CHECK"); 
            assertLt(userBalBefore2 - burnAmount, userBalAfter2, "USER BAL 2 CHECK");
            assertGt(userBalBefore1, userBalAfter1, "USER BAL 1 CHECK");
        } catch {/*assert(false)*/} // overflow
    }


    /* INVARIANT: Swapping within a pair should:
     * Decrease balance of user for token 2
     * Increase balance of user for token 1
     * K should decrease or remain the same 
    */   
    function testFuzz_swapExactTokensForETHSupportingFeeOnTransferTokens(uint amount) public {
        // PRECONDTION:
        uint _amount = this._between(amount, (10**3), MAX);
        uint burnAmount = _amount / 100;

        (uint reserveABefore, uint reserveBBefore) = UniswapV2Library.getReserves(address(testFactory), address(weth), address(feeToken));
        uint kBefore = reserveABefore * reserveBBefore;         

        if(!setETHFee) {
            _initETHFee(_amount);
            // For some reserves
            try feeToken.mint(address(testFeeWethPair), 100000) {} catch {/*assert(false)*/} // overflow
            vm.deal(address(this), 100 ether);
            weth.deposit{value: 100 ether}();
            weth.transfer(address(testFeeWethPair), 100);
            testFeeWethPair.sync();            
        }        
      
        address[] memory path = new address[](2);
        path[0] = address(feeToken);
        path[1] = address(weth);

        uint userBalBefore1 = UniswapV2ERC20(path[0]).balanceOf(address(this));
        uint userBalBefore2 = UniswapV2ERC20(path[1]).balanceOf(address(this));
        require(userBalBefore1 > 0, "NO BAL");            

        // ACTION:
        try testRouter02.swapExactTokensForETHSupportingFeeOnTransferTokens(_amount, 0, path, address(this), MAX) {

            // POSTCONDTION:
            uint userBalAfter1 = UniswapV2ERC20(path[0]).balanceOf(address(this));
            uint userBalAfter2  = UniswapV2ERC20(path[1]).balanceOf(address(this));
            (uint reserveAAfter, uint reserveBAfter) = UniswapV2Library.getReserves(address(testFactory), address(usdc), address(feeToken));                uint kAfter = reserveAAfter * reserveBAfter;

            assertGe(kAfter, kBefore, "K CHECK"); 
            assertLt(userBalBefore2 - burnAmount, userBalAfter2, "USER BAL 2 CHECK");
            assertGt(userBalBefore1, userBalAfter1, "USER BAL 1 CHECK");
        } catch {/*assert(false)*/} // overflow        
    }               

    // Bounding function similar to vm.assume but is more efficient regardless of the fuzzying framework
	// This is also a guarante bound of the input unlike vm.assume which can only be used for narrow checks     
	function _between(uint256 random, uint256 low, uint256 high) public pure returns (uint256) {
		return low + random % (high-low);
	}    

    // Helper functions to mint tokens when necessary
    bool setStable;
    function _init(uint256 amount1, uint256 amount2) internal {
        try usdt.mint(address(this), amount2) {} catch {/*assert(false)*/} // overflow        
        try usdc.mint(address(this), amount1) {} catch {/*assert(false)*/} // overflow        
        setStable = true;
    }

    bool setPermit;
    function _initPermit(address owner, uint256 amount1, uint256 amount2) internal {
        try usdt.mint(owner, amount2) {} catch {/*assert(false)*/} // overflow        
        try usdc.mint(owner, amount1) {} catch {/*assert(false)*/} // overflow        
        setPermit = true;
    }    

    bool setPermitETHFee;
    function _initPermitETHFee(address owner, uint256 amount) internal {
        vm.deal(owner, amount); 
        try feeToken.mint(owner, amount) {} catch {/*assert(false)*/} // overflow        
        setPermitETHFee = true;
    }

    bool setPermitETH;
    function _initPermitETH(address owner, uint256 amount) internal {
        vm.deal(owner, amount); 
        try feeToken.mint(owner, amount) {} catch {/*assert(false)*/} // overflow        
        setPermitETH = true;
    }       

    bool setFee;
    function _initFee(uint256 amount1, uint256 amount2) internal {
        try feeToken.mint(address(this), amount2) {} catch {/*assert(false)*/} // overflow        
        try usdc.mint(address(this), amount1) {} catch {/*assert(false)*/} // overflow        
        setFee = true;
    }    

    bool setETHFee;
    function _initETHFee(uint256 amount) internal {
        vm.deal(address(this), amount); 
        try feeToken.mint(address(this), amount) {} catch {/*assert(false)*/} // overflow        
        setETHFee = true;
    }    

    bool setETH;
    function _initETH(uint256 amount) internal {
        vm.deal(address(this), amount); 
        try usdc.mint(address(this), amount) {} catch {/*assert(false)*/} // overflow        
        setETH = true;
    }
    
    // Helper if any pair code is change
    function testGetInitCode() public {    
        bytes memory bytecode = type(UniswapV2Pair).creationCode;
        emit log_bytes32(keccak256(abi.encodePacked(bytecode)));
    }         
}        