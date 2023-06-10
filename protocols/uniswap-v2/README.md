# **Setup**
# Setup
1. `forge install OpenZeppelin/openzeppelin-contracts`
2. `forge install foundry-rs/forge-std`
3. `forge test --mc TestCore`

## Integration
1. Follow setup
2. Add test helpers functions:

| Contract | Function |
| --- | --- |
[Masonry.sol](./src/UniswapV2ERC20.sol) | [getCashPriorpub()](./src/UniswapV2ERC20.sol#L96)

3. Remove test helpers from contract before deploying 
* I'm not responsible for what happens if you leave them in

# **Notes on Uniswap v2**
Uniswap v2 is an AMM but some major changes and updates to the original. It's powered by a constant product formula `x*y=Z`.

## **Pairs**:
Unlike Uniswap V1 where liquidity pools were between ETH and a single ERC20 token. It can now users can swap between any ERC20 and now uses WETH (wrapped Ether) instead of native ETH.
* Useful for liuidity providers to maintain more diverse ERC20 token positions without any exposure to ETH. 
* Also improves prices because of routing through ETH for a swap between two other assets (fees & slippage on 2 separate pairs instead of one).
	* If two tokens are not paired directly and don't have a common pair between them they can be swapped along a path that could exist.

## **Oracles**:
This is a new implementation that offers decentralized manipulation-resistant on-chain price feeds.
* It measures prices when they are expensive to manipulate and accumulating historical data
* Offers gas-efficient time-weighted averages of uniswp prices for any time interval
* Uniswap v1 can't be used safely as a price oracle because the price can move significantly in a short period of time
* It measures (not store) market price at the beginning of each block (before any trades take place). 
	* Thus making it expensive to manipulate because it was set by the last Tx in a previous block.
	* They would also have to make a bad trade at the end of the previous block and then be able to arbitrage it back in the next block
	* Attackers will lose to arbitrageurs and would have to selfishly mine two blocks in a row (has not be observed to date).
* The end-of-block price is added to a single cumulative-price bariable in the core contact weighted by the amount of time this price existed.
	* It represents a sum of the price for every second in the entire history of the contract.
	* This can be used by externl contracts to track TWAPs across any time interval.
	* `(priceCumulative2 - priceCumulative1) / (timestamp2 - timestamp1) = TWAP`
	* Can be used for directly or as basis for moving averages (EMAs and SMAs)
* Cost of attack: 
	* Moving the price 5% on a 1-hour TWAP is about equal to the amount lost to arbitrage and fess for moving the price 5% every block for 1 hour.

Flash Swaps:
Similar to flash loans where a user can with no upfront capital or constraints can borrow => arbitrage => return either of the token in the pair.

## **Split into Core & Periphery**:
* Core in where one can find the Pair and Factory contracts.
* Periphery where one can find the router, oracle, migrator.

## **Changes From UNIv1-UNIv2**:
![UniTable](/assets/Uni-table.webp "Table from link below")

### **Extra Links**:
[Uniswap v2 Blog](https://blog.uniswap.org/uniswap-v2) 

[Uniswap v2 whitepaper](https://uniswap.org/whitepaper.pdf) 

[Uniswap v2 Overview](https://docs.uniswap.org/contracts/v2/overview) 

[Uniswap V1 to V3](https://medium.com/auditless/uniswap-v1-to-v3-a-table-80d71d1303d2) 
