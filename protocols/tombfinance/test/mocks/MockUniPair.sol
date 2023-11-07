// SPDX-License-Identifier: NONE
pragma solidity ^0.6.2;

// Pair factory and Pair
import "@uni/UniswapV2Factory.sol";
import "@uni/UniswapV2Pair.sol";

contract MockUniPair {

    function deployPair(address _token1, address _token2) public returns(address) {
        // Deploy factory and Pairs
        UniswapV2Factory _testFactory = new UniswapV2Factory(address(this));
        UniswapV2Pair _testPair = UniswapV2Pair(_testFactory.createPair(_token1, _token2));
        return(address(_testPair));
    }

    /* 
    Helper if you ever change the pair code. Would also need to then import forge-std
    function testGetInitCode() public {    
        bytes memory bytecode = type(UniswapV2Pair).creationCode;
        emit log_bytes32(keccak256(abi.encodePacked(bytecode)));
    }
    */
}