# Setup
1. `forge install`
2. `forge test --mc TestCore`

## Integration
1. Follow setup
2. Add test helpers functions:

| Contract | Function |
| --- | --- |
[CErc20.sol](./src/CErc20.sol) | [getCashPriorpub()](./src/CErc20.sol#L153)

3. Remove test helpers from contract before deploying 
* I'm not responsible for what happens if you leave them in

# **Notes on Compound v2**
Compound was created on the bases of being a decentralized system for borrowing of token without flaws of existing approaches:

* Centralized exchanges 
* Peer to peer protocols that have high costs and added frictions onto users
* Borrowing mechanisms were limited
* Assets having negative yield without natural interest rates to offset them.

It's meant to establish money markets (pools of tokens) with derived interest rates based on supply and demand for the token. 

* Suppliers earn a floating interest rate without dealing with maturity, interest rate or collateral with a peer
* borrowers pay the floating interest rate without dealing with a peer

### **Supplying**:
Compound aggregates the supply of each user:

* When a user supplies a token it becomes a resource
* Offers liquidity 
* Can withdraw at any time without loan maturity

Balances accrue interest based on the supply interest rate of the asset. When a user updates there balance, accrued interest is converted into principal and paid. This gives users with long-term investments a chance to gain additional returns. 

### **Borrowing**:
Users can borrow using collateralized lines of credit. There are no specific terms and they only have to specify the wanted assets amount. The cost of such is determined by the floating interest rate set by the market.

* Each account must have a balance that  covers the outstanding borrowed amount (collateral ratio). 
    * This can be brought below the ratio by borrowing or withdrawing
    * This can be increased when users repay borrowed asset in whole or part at any time
    * Balances held even being used as collateral still accrue interest
Users whose `(supplied assets / outstanding borrowing) < collateral ratio` leave their collateral and borrowed assets up for purchase at `(current market price - liquidation discount)`. 
* Incentivizes arbitrageurs to reduce borrower's exposure and lower protocol's risk.
* Any user with the borrowed asset can liquidate in whole or part. Exchanging their asset for the borrower's collateral.

The main use of this is to be able to hold new assets without selling or rearranging a portfolio giving users abilities of:
* Not having to wait for order fills or off-chain behavior. Allowing dApps to borrow tokens to use.
* Traders can finance new ICO investments by borrowing and using their existing portfolio as collateral
* Traders can short token by borrowing it sending it to an exchange and sell the token

### **Interest Rate Model**:
The protocol achieves an efficient interest rate equilibrium for each market based on supply and demand of individual assets. This utilization ratio U unifies supply and demand into a single variable:
* `U = Borrows / (Cash + Borrows)`

Interest rates should increase as a function of demand:
* When demand is low rates should be low
* When demand is high rates should be high

This curve is codified through governance and updated by the chief economist. It is expressed as a function of utilization:
* `Borrowing interest Rate = 10% + U * 30%`

The total amount of interest earned by suppliers must be < total interest product by borrowers. Supply interest rate is a function of borrowing interest rate including a spread S representing the economic profit of the protocol:
* `Supply Interest Rate = Borrowing Interest Rate * U * (1 - S)`

### **cTokens**:
This is a EIP-20 compliant contract that keeps track of balances supplied to the protocol. Users can mint cTokens to earn interest from the cTokens exchange rate that increases in value relative to the asset. Users can also use the cTokens as collateral.
* All mints, redeems, borrow, repays a borrow, liquidates a borrow or transfers are done via the cToken.
* Two types of cTokens CErc20 (wraps the underlying ERC-20 asset)and CEther (wraps ether)

### **Comptroller**:
Comptroller is the risk management contract that determines the amount of collateral a user must have to maintain or if they can be liquidated. When a user interacts with a cToken the comptroller is asked to approve/deny it. 

It also maps user balances to prices (price oracle) to risk weight for making the determinations. Users can list which assets they would like to include in their risk scoring.

### **Governance**:
The protocol is governed by COMP holders and has three components:
1. COMP token
2. Governance module by Governor Bravo
3. Timelock
These give COMP holders the ability to propose, vote and implement changes. Proposals can modify anything in the protocol. Holders can delegate to any address of their choice. Delegation has its limits where an address must have at least 25,000 COMP to create a proposal or any address can lock 100 COMP to create an Autonomous Proposal. This allows other users to delegate to it to crate a proposal after the 25,000 COMP is reached. 

The proposal process is as follows:
* 2 day review period
* Voting weights are recorded and voting begins
* Voting last 3 days
* If a majority and at least 400,000 votes are cast for the proposal it is queued in the Timelock
* It can than be implemented 2 days later
* Total about one week

Comp itself is an ERC-20 token that has voting rights.

### **Open Price Feed**:
Accounts price data for the protocol and is used by the comptroller as a source of truth for prices. Compound uses a price feed to verify the reported prices are withing bounds of TWAP of the pair on Uniswap v2 (sanity check or Anchor price).

Chainlink price feeds submit prices for each cToken through an individual validatorProxy. This is the only valid reporter for the underlying asset price.

Open Price Feed has two main contracts:
1. ValidatorProxy which queries Uniswap v2 to check if the new price is within the TWAP anchor. If valid it updates the asset price and discards the price data elsewise
2. UiswapAnchoredView only stores prices withing the bound of the TWAP and are signed by a reporter. Handles upscaling prices into the comptroller formant.

Allows multiple views to use the same underlying price data and verify the prices in their own way.

* Stablecoins are fixed at $1. SAI is fixed at 0.005285 ETH.
* Compound multisig has the ability to switch market's primary oracle from Chainlink price feeds to uniswap v2 during a failover.

### **Extra Links**:
[Whitpaper](https://github.com/compound-finance/compound-money-market/blob/master/docs/CompoundWhitepaper.pdf)
[Protocol High level](https://github.com/compound-finance/compound-protocol/blob/master/docs/CompoundProtocol.pdf)
[Documents](https://docs.compound.finance/v2/)

### **Audit Links**:
[audits](https://docs.compound.finance/v2/security/)
