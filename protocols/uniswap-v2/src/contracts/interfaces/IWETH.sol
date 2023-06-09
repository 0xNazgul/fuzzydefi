//pragma solidity >=0.5.0;
pragma solidity ^0.8.0;
interface IWETH {
    function deposit() external payable;
    function transfer(address to, uint value) external returns (bool);
    function withdraw(uint) external;
}
