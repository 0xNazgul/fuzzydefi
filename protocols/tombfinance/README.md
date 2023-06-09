# **Setup**
# Setup
1. `forge install foundry-rs/forge-std`
2. `forge install OpenZeppelin/openzeppelin-contracts`
3. `forge test --mc TestCore`

## Integration
1. Follow setup
2. Add test helpers functions:

| Contract | Function |
| --- | --- |
[Masonry.sol](./src/Masonry.sol) | [getCashPriorpub()](./src/Masonry.sol#L210)
[Oracle.sol](./src/Oracle.sol) | [getCashPriorpub()](./src/Oracle.sol#L85)
[Treasury.sol](./src/Treasury.sol) | [getCashPriorpub()](./src/Treasury.sol#L287)
[Treasury.sol](./src/Treasury.sol) | [getCashPriorpub()](./src/Treasury.sol#L551)
[TShare.sol](./src/TShare.sol) | [getCashPriorpub()](./src/TShare.sol#L124)

3. Remove test helpers from contracts before deploying 
* I'm not responsible for what happens if you leave them in


# **Notes on Tomb Finance**
Tomb is a protocal that serves `TOMB` as an algorithmic token pegged to `FTM`. It's underlying mechanics are to adjust `TOMB`'s supply by moving the price up or down relativve to `FTM`'s price. Inspired by [Basis](https://www.basis.io/) and currently consists of three tokens, `TOMB`, `TSHARE` and `TBOND`. `TOMB` 

## **TOMB Token**:
Main token that is algorithmic stablecoin pegged to `FTM`. When it's price is about 1 `FTM` (adjusted to a TWAP over 6 hour periods) this is the expansion phase/inflation phase. To bring the price down more `TOMB` is minted at a percentage of supply. 
* 18% is sent to the DAO (for buybacks when price is below peg) 
* 2% for development/marketing fund
* 80% is distributed into the Masonry for users to receive `TOMB` for staking `TSHARE`

Every time `TOMB` is sold and creating LPs that are resent to the DAO or instantly burned will have a tax by the Gatekeeper system. 

## **TSHARE Token**:
`TSHARE` is used to pair with `FTM` and provides liquidity to Cemetery to earn `TSHARE` rewards. It's other use is to stake in the Masonry. Every 6 hours during the expansion phase `TOMB` is paid out to `TSHARE` stakers in the masonry. Lock times are of 36 hours and 18 hours for claiming rewards. 

Holders also have voting rights on proposals to improve the protocol. There is a maximum total supply of 70_000 distributed as:
1. DAO Allocation: 500 `TSHARE` vested linearly 12 months
2. Team Allocation: 5_000 `TSHARE` vested linearly over 12 months
3. Remaining 59_500 `TSHARE` are allocated for incentivizing Liquidity Providers in two shares pools for 12 months

## **TBONDS Token**:
During reduction phase/deflationary phase or when `TOMB` price falls below 1 `FTM`. Users can burn supply themselves and profit when the price goes back above the peg. In doing so the user recieves `TBOND` tokens. Users can then redeem their `TBOND`s for `TOMB` with a bonus multiplier starting once the price is above 1. 

* Available for purchase in the Pit R (bonus multiplier) can be calculated in the formula as shown below:
    * `R=1+[(TOMB(​twapprice)−1)∗coeff)]`
		* Where coeff = 0.7

### **Masonry**:
* Epoch duration: 6 hours
* Deposits / Withdrawal of `TSHARE` into/from Masonry will lock:
	* `TSHARE` for 6 epochs and 
	* `TOMB` rewards for 3 epochs
*  `TOMB` rewards claim will lock staked `TSHARE` for 6 epochs and the next `TOMB` rewards can only be claimed 3 epochs later
* Distribution of `TOMB` during Expansion
	* 80% as Reward for Boardroom `TSHARE` Stakers
	* 18% goes to DAO fund
	* 2% goes to DEV fund
* Epoch Expansion: Current expansion cap base on `TOMB` supply, if there are bonds to be redeemed: 
	* 65% of minted `TOMB` goes to treasury until its sufficiently full to meet bond redemption. 
	* If there is no debt it will follow max capped expansion rate

### **Cemetery**:
* Stake your LP to earn `TSHARE` tokens
* Shares Pools (Shares Reward) available for 12 months:
	* `TOMB-FTM LP`: 35500 Shares
	* `TSHARE-FTM LP`: 24000 Shares

### **Extra Links**:
[Tomb Docs](https://docs.tomb.com/)
[Tomb overview](https://tombfinance.medium.com/what-is-tomb-finance-82e8b3db2c09)

### **Audit Links**:
[Rekt artical](https://rekt.news/tomb-finance-rekt/)
[Post Mortem](https://tombfinance.medium.com/tomb-finance-post-mortem-480fa68375b2)
[Post Mortem pt2](https://tombfinance.medium.com/the-postmortem-revival-of-tomb-finance-past-present-and-future-f78cd19d48bd)
[TombSwap](https://tombfinance.medium.com/tombswap-has-arrived-aa9816b455a1)


### **Invariants TODO:**
* `TombGenesisRewardPool.sol`
	1. `deposit()`
		* Update pool reward variables
		* Decrease User bal of token
		* Update User rewardDebt
		* Increase user bal amount 
	2. `withdraw()`
		* Update pool reward variables
		* Increase User bal of token
		* Update User rewardDebt
		* Decrease user bal amount 
	3. `emergencyWithdraw()`
		* Increase User bal of token
		* Decrease User rewardDebt
		* Decrease user bal amount 
	5. `governanceRecoverUnsupported()`
		* Decrease contract bal of token 	
		* Increase to User bal of token
* `TombRewardPool.sol`
	1. `deposit()`
		* Update pool reward variables
		* Decrease User bal of token
		* Increase User rewardDebt
		* Increase user bal amount 
	2. `withdraw()`
		* Update pool reward variables
		* Increase User bal of token
		* Update User rewardDebt
		* Decrease user bal amount 
	3. `emergencyWithdraw()`
		* Increase User bal of token
		* Decrease User rewardDebt
		* Decrease user bal amount
	5. `governanceRecoverUnsupported()`
		* Decrease contract bal of token 	
		* Increase to User bal of token
* `TShareRewardPool.sol`
	1. `deposit()`
		* Update pool reward variables
		* Decrease User bal of token
		* Increase User rewardDebt
		* Increase user bal amount 
	2. `withdraw()`
		* Update pool reward variables
		* Increase User bal of token
		* Update User rewardDebt
		* Decrease user bal amount 
	3. `emergencyWithdraw()`
		* Increase User bal of token
		* Decrease User rewardDebt
		* Decrease user bal amount
	5. `governanceRecoverUnsupported()`
		* Decrease contract bal of token 	
		* Increase to User bal of token
* `Masonry.sol`
	1. `stake()`
		* Increase totalSupply
		* Increase User staked bal
		* Decrease User tbond amount
	2. `withdraw()`
		* Decrease totalSupply
		* Decrease User staked bal
		* Increase User tbond amount
	3. `claimReward()`
		* Decrease User Reward
		* Increase tomb bal
		* Update User epochTimerStart
	4. `exit()`
		* Decrease totalSupply
		* Decrease User staked bal
		* Increase User tbond amount
	5. `allocateSeigniorage()`
		* Update nextRPS
		* Update time
		* Decrease from User tomb bal
		* Increase contracts tomb bal
	6. `governanceRecoverUnsupported()`
		* Decrease contract bal of token 	
		* Increase to User bal of token 
* `Treasury.sol`
	1. `buyBonds()`
		* Decrease User tomb bal
		* Increase User tbond bal
		* Decrease epochSupplyContractionLeft
	2. `redeemBonds()`
		* Decrease User tbond bal
		* Increase User tomb bal
		* Decrease epochSupplyContractionLeft	
	3. `allocateSeigniorage()`
		* Update previousEpochTombPrice
		* If `_savedForBond > 0`, increase contract tomb bal 
		* If `_savedForMasonry > 0 && daoFundSharedPercent > 0` increase daoFund tomb bal
		* If `_savedForMasonry > 0 && devFundSharedPercent > 0` increase devFund tomb bal 
		* Update masonry's allowance 
	4. `governanceRecoverUnsupported()`
		* Decrease contract bal of token 
		* Increase to User bal of token 
* `TShare.sol`
	1. `claimRewards()`
		* Increase totalSupply 
		* If `_pending > 0 && communityFund != address(0)` increase communityFund tshare bal
		* If `_pending > 0 && devFund != address(0)` increase devFund tshare bal
	2. `distributeReward()`
		* Update rewardPoolDistributed to true
		* Increase totalSupply
		* Increase farmingIncentiveFund bal
	3. `burn()`
		* Decrease User Balance
		* Decrease Total Supply
	4. `governanceRecoverUnsupported()`
		* Decrease contract bal of token 
		* Increase to User bal of token 