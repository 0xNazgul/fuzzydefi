# Setup
1. `forge install foundry-rs/forge-std`
2. `forge install OpenZeppelin/openzeppelin-contracts`
3. `forge install transmissions11/solmate`
4. `forge test --mc TestCore`

## Integration
1. Follow setup
2. No test helpers needed

# **Notes on OlympusDAO v1**
Olympus at a high level is an autonomous and dynamic monetary policy with market operations supported by the protocol-owned Olympus Treasury. It serves the market gap betwen stablecoins and volatile assets. Users will interact with the bond depository where there is a reserve and liquidity bond. One can then buy a bond and redeem OHM. The bond depository always sends assets to the treasury. It is meant to calculate value of the token/LP bonded. It can also mint new OHM for the staking contract to be distributed to stakers. This depends on the amount of reserves no backing any OHM. Excess reserves can be withdraw (yield strategies and allocators) to then create extra revenue.

## **Tokens**
### **OHM**
* Reserve currency with 9 decimals
* Only minted by the vault (treasury)

### **sOHM**
* Staked OHM 
* Rebases every epoch (2,220 blocks)
    * Can rely on block numbers on Ethereum
    * Other chain forks rely on block timestamp
* gons are stakers balance and their external balance is the `gon / gonsPerFragment`
    * This is for gas efficientcy for it is expensive to adjust a staker's balance every rebase
    * rebasing adjusts the gonsPerFragment 
    * less gonsPerFragment == greater balance 
    * rebases the given profit generated for a given epoch (increasing totalSupply)
        * Reducing gonsPerFragment as totalSupply increases
    * This makes sOHM not follow standard and must be done by all transfering functions
        * Each time taking the external balance and converting it to the gon value and adjusting balances from there

### **wsOHM**
Wrapped OHM which is later replaced with gOHM in v2. It doesn't rebase and it's value is based on its underlying sOHM rebases.

### **Bonds**
Bonds are handled by the Bond Depository where users can deposit their assets. The assets are moved to the treasury, calculate the amount of OHM to pay out minus fees. It creates a bond and vests for 5 days where it can then be redeemed for OHM as time reaches.
* Each deposit, debt decays by the amount of debt being vested. 
    * Debt: amount of OHM owed to bonders no yet veested
        * Vested OHM is not considered debt
        * There is a debt ceiling for every bond 
        * total bond debt after debt decay cannot exceed the ceiling
* If debt ceiling is never reached the bond price is calculated for the actual bond price
    * This price in USD is only used for event emission
    * The real price is based on bond control variable and bond depository's debt ratio
        * higher bond control variable & debt ratio == higher price 
        * There is a minimum to the bond price
            * In cents and without the decimals
        * There is a Maximum provided by the user via frontend (not contract)
    * debt ratio == bond depository current debt / total supply of OHM
* Reserve asset is "1 to 1" to OHM
    * However it can trade below or above
* For LP tokens being the Bonded asset the StandardBondingCalculator to calculate the asset value. 
    * Total value of the pool and is then multiplied by the fraction of LP tokens deposited as a % of total LP token supply 
* The total value is 2 times the square root of the LP token’s K value because1
1. x * y = k (Uniswap V2 formula)
2. assuming the LP token is OHM-DAI, and Olympus sees OHM/DAI as 1:1
3. with x = y, x * y = k becomes x^2 = k, x = sqrt(k)
4. y is also equal to sqrt(k) because x = y.
5. so x + y (the value of OHM + DAI) becomes 2 * sqrt(k).
* LP token's value is accounted with this.
* RFV of OHM-DAI is marked down because the LP token consists of OHM and it has a circular dependency
* Payout amount is in OHM is `(deposited asset value / bond price)`
    * A fee is chagered on this payout amount and is minted for the DAO. 
    * Remaining asset value goes to the treasury.
    * Profit here means the asset is not used to back newly minted OHM and is distributed to stakers during rebase or allocated to an yield strategy
    * The bond record is stored for when the user later claims their vested payout 
        * Vesting resets the clock no matter what
            * Even if they have a previous payout maing it not opitmal to bond and vest at the same time
    * Adjust is called after whenever the bond control variable can be updated depending on:
        * Block time buffer between each adjustment
        * Adjustment rate is nonzero
    * If these are true then the bond control variable increases/decreases
    * If it hits the target the rate becomes zero and will remain such until the policy team changes it
* Redeemable OHM depends on the blocks elapsed since the last redeem or the beginning of vesting
    * Redeemed amount is subtracted from the bond's payout and the the redeem block is updated
    * Redeemer can use these tokens for staking or take them
    * The stake function transfers the vested OHM to itself and updates the redeemer's details and finishes by transfering sOHM to the warmup contract 
    * Governor sets the warmup period so that redeemers can receive their sOHM at the end of the period 
        * If there is no warmup period than they receive it that block
    * The claim function is also called and uses the stakingHelper contract
### **Rebasing**
Rebasing hapens every 2,200 blocks that is triggered during staking or by anyone by calling the rebase function. 
* The amount of sOHM to distribute equal to the difference of the staking contract's OHM balance and sOHM's circulating supply (excludes the sOHM balance)
* The amount of OHM minted from the treasury to the staking contract is set by the policy team and is rate. 
    * This should not exceed the treasury's excess reserves and there is a require statment for such
    * After each distribution the rate is adjusted

### **Treasury**
* Approved depositors can deposit assets directly to mint OHM without vesting needed to acquire the initial supply of OHM to create a liquidity pool 
* Approved spenders can withdraw reserve assets by burning OHM (liquidated)
* Approved yield strategies can manage the reserves to move assets to their own contract
* Approved addresses can borrow excess treasury reserves (same as appove but maybe for off-chain tracking )


### **Reserve currencies**:
* Deep liquidity: reserve currencies are highly liquid and easily exchangable for other assets or products
* unit of account: other assets are denominated in the currency
* Preserve purchasing power: provides holders a stable low volatility asset taht grow at a steady rate over the med-to-long term.



### **Extra Links**:
[Dissecting OlympusDAO](https://0xkowloon.substack.com/p/dissecting-the-olympus-protocol)
[OlympusDAO Docs](https://docs.olympusdao.finance/main/overview/intro)
[Primer on Bonding](https://olympusdao.medium.com/a-primer-on-oly-bonds-9763f125c124)
[3,3 Game Theory](https://olympusdao.medium.com/the-game-theory-of-olympus-e4c5f19a77df)
[Empty Set Dollar](https://olympusdao.medium.com/comparison-of-olympus-credits-and-the-empty-set-dollar-590146dcdf8b)

### **Audit Links**:
[PeckShield](https://github.com/peckshield/publications/blob/master/audit_reports/PeckShield-Audit-Report-OlympusDAO-v1.0.pdf)
