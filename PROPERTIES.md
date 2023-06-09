# Introduction
Here is a list of the property tests for the top five forked protocols. For each property, there is a permalink to the file implementing it in the repository and a small description of the invariant tested. 

This may not be a complete list and there may be some more invariants to test. I focused more on functions that transferred funds or of major state updates. Also note that there are still some invariants listed here that needs to be implemented. Within each project folder `README.md` one can find what is left under `Invariants TODO` section.

## Table of contents

- [Introduction](#introduction)
  - [Table of contents](#table-of-contents)
  - [Uniswap v2](#uniswap-v2)
  - [Olympus DAO](#olympus-dao)
  - [Compound v2](#compound-v2)
  - [Tomb Finance](#tomb-finance)

## Uniswap v2

| ID | Name | Invariant tested |
| --- | --- | --- |
UNI-001 | [testFuzz_AddLiq](/protocols/uniswap-v2/src/test/core.t.sol#L88) | Adding liquidity to a pair should: <ul><li>Increase reserves</li><li>Increase address to balance</li><li>Increase totalSupply</li><li>Increase k</li></ul> 
UNI-002 | [testFuzz_ETHAddLiq](/protocols/uniswap-v2/src/test/core.t.sol#L124) | Same as adding liquidity
UNI-003 | [testFuzz_RemoveLiq](/protocols/uniswap-v2/src/test/core.t.sol#L161) | Removing liquidity from a pair should: <ul><li>Decrease reserves</li><li>Decrease address to balance</li><li>Decrease totalSupply</li><li>Decrease K</li></ul>
UNI-004 | [testFuzz_ETHRemoveLiq](/protocols/uniswap-v2/src/test/core.t.sol#L199) | Same as removing liquidity
UNI-005 | [testFuzz_removeLiqWithPermit](/protocols/uniswap-v2/src/test/core.t.sol#L237) | Same as removing liquidity
UNI-006 | [testFuzz_removeLiquidityETHWithPermit](/protocols/uniswap-v2/src/test/core.t.sol#L124) | Same as removing liquidity
UNI-007 | [testFuzz_removeLiqETHSupportingFeeOnTransferTokens](/protocols/uniswap-v2/src/test/core.t.sol#L415) | Same as removing liquidity
UNI-008 | [testFuzz_removeLiqETHWithPermitSupportingFeeOnTransferTokens](/protocols/uniswap-v2/src/test/core.t.sol#L453) | Same as removing liquidity
UNI-009 | [testFuzz_swapExactTokensForTokens](/protocols/uniswap-v2/src/test/core.t.sol#L541) | Swapping within a pair should: <ul><li>Decrease balance of user for token 2</li><li>Increase balance of user for token 1</li><li>Decrease/leave k unchanged</li></ul>
UNI-010 | [testFuzz_swapExactETHForTokens](/protocols/uniswap-v2/src/test/core.t.sol#L582) | Same as Swap
UNI-011 | [testFuzz_swapTokensForExactETH](/protocols/uniswap-v2/src/test/core.t.sol#L625) | Same as Swap
UNI-012 | [testFuzz_swapExactTokensForETH](/protocols/uniswap-v2/src/test/core.t.sol#L668) | Same as Swap
UNI-013 | [testFuzz_swapETHForExactTokens](/protocols/uniswap-v2/src/test/core.t.sol#L711) | Same as Swap
UNI-014 | [testFuzz_swapExactTokensForTokensSupportingFeeOnTransferTokens](/protocols/uniswap-v2/src/test/core.t.sol#L754) | Same as Swap
UNI-015 | [testFuzz_swapExactETHForTokensSupportingFeeOnTransferTokens](/protocols/uniswap-v2/src/test/core.t.sol#L796) | Same as Swap
UNI-016 | [testFuzz_swapExactTokensForETHSupportingFeeOnTransferTokens](/protocols/uniswap-v2/src/test/core.t.sol#L842) | Same as Swap

## Olympus DAO

| ID | Name | Invariant tested |
| --- | --- | --- |
OLY-001 | [testFuzz_deposit](/protocols/olympus-v1/test/core.t.sol#L163) | Depositing into the BondDepo should:<ul><li>Increase user Bond Payout</li><li>Updates users last block to latest</li><li>Updates Bond Price</li><li>Increase Total Debt</li><li>Increase Treasury Total Reserves</li><li>Updates control variable accordingly</li><li>Updates rate accordingly</li></ul>
OLY-002 | [testFuzz_redeemNoStaking](/protocols/olympus-v1/test/core.t.sol#L204) | Redeeming without  staking from BondDepo should:<ul><li>Decrease user payout</li><li>Decrease user vesting</li><li>Update user lastBlock</li><li>Increase user OHM Balance</li></ul>
OLY-003 | [testFuzz_redeemWith](/protocols/olympus-v1/test/core.t.sol#L256) | Redeeming with staking from BondDepo should:<ul><li>Decrease user payout</li><li>Decrease user vesting</li><li>Update user lastBlock</li><li>Increase staking OHM Balance</li><li>Increase staking warmup sOHM Balance</li><li>Increase user staking deposit</li><li>Increase user gons</li><li>Increase user expiry</li><li>Update user lock to false</li></ul>
OLY-004 | [testFuzz_redeemRebase](/protocols/olympus-v1/test/core.t.sol#L305) | Redeeming from BondDepo should:<ul><li>Updates distribute</li><li>Increases number</li><li>Increases endBlock</li></ul>
OLY-005 | [testFuzz_unstake](/protocols/olympus-v1/test/core.t.sol#L335) | Unstaking should:<ul><li>Increase user OHM balance</li><li>Decrease user sOHM balance</li><li>Increase Staking sOHM balance</li><li>Decrease Staking OHM balance</li></ul>

## Compound v2
| ID | Name | Invariant tested |
| --- | --- | --- |
COM-001 | [testFuzz_mint](/protocols/compound-v2/test/core.t.sol#L126) | Calling mint Should: <ul><li>Increase cToken TotalSupply</li><li>Increase User cToken Balance</li><li>Decrease User underlying Balance</li><li>Update Supply Index in Comptroller</li><li>Update Comp Supplier Index in Comptroller</li><li>Update supplier compAccrued in Comptroller</li><li>Update Supply block Number in Comptroller</li><li>Update cToken accrualBlockNumber</li><li>Update cToken borrowIndex</li><li>Update cToken totalBorrows</li><li>Update cToken totalReserves</li></ul>
COM-002 | [testFuzz_redeem](/protocols/compound-v2/test/core.t.sol#L178) | Calling redeem Should:<ul><li>Decrease cToken TotalSupply</li><li>Decrease User cToken Balance</li><li>Increase User underlying Balance</li><li>Update Supply Index in Comptroller</li><li>Update Comp Supplier Index in Comptroller</li><li>Update supplier compAccrued in Comptroller</li><li>Update Supply block Number in Comptroller</li><li>Update cToken accrualBlockNumber</li><li>Update cToken borrowIndex</li><li>Update cToken totalBorrows</li><li>Update cToken totalReserves</li></ul>
COM-003 | [testFuzz_borrow](/protocols/compound-v2/test/core.t.sol#L239) | Calling borrow Should:<ul><li>Update borrow index in Comptroller</li><li>Update borrow block in Comptroller</li><li>Update borrower compAccrued in Comptroller</li><li>Update compBorrowerIndex in Comptroller</li><li>Add user to market in Comptroller</li><li>Add cToken to users accountAssets in Comptroller</li><li>Increase accountBorrows principal</li><li>Update accountBorrows interestIndex</li><li>Increase totalBorrows</li><li>Increase User underlying Balance</li></ul>
COM-004 | [testFuzz_repayBorrow](/protocols/compound-v2/test/core.t.sol#L295) | Calling repayBorrow Should:<ul><li>Update borrow index in Comptroller</li><li>Update borrow block in Comptroller</li><li>Update borrower compAccrued in Comptroller</li><li>Update compBorrowerIndex in Comptroller</li><li>Add user to market in Comptroller</li><li>Add cToken to users accountAssets in Comptroller</li><li>Increase accountBorrows principal</li><li>Update accountBorrows interestIndex</li><li>Increase totalBorrows</li><li>Increase User underlying Balance</li></ul>
COM-005 | [testFuzz_liquidateBorrow](/protocols/compound-v2/test/core.t.sol#L416) | Calling liquidateBorrow Should:<ul><li>Update cToken accrualBlockNumber</li><li>Update cToken borrowIndex</li><li>Update cToken totalBorrows</li><li>Increase totalReserves</li><li>Decrease cToken totalSupply</li><li>Decrease borrower accountTokens</li><li>Increase liquidator accountTokens</li></ul>
COM-006 | [testFuzz_repayBorrowBehalf](/protocols/compound-v2/test/core.t.sol#L356) | Calling repayBorrowBehalf Should:<ul><li>Update borrow index in Comptroller</li><li>Update borrow block in Comptroller</li><li>Update borrower compAccrued in Comptroller</li><li>Update compBorrowerIndex in Comptroller</li><li>Add user to market in Comptroller</li><li>Add cToken to users accountAssets in Comptroller</li><li>Increase accountBorrows principal</li><li>Update accountBorrows interestIndex</li><li>Increase totalBorrows</li><li>Increase User underlying Balance</li></ul>
COM-007 | [testFuzz_sweepToken](/protocols/compound-v2/test/core.t.sol#L474) | Calling sweepToken Should:<ul><li>Decrease ctoken random token balance</li><li>Increase Admin random token balance</li></ul>
COM-008 | [testFuzz_addReserves](/protocols/compound-v2/test/core.t.sol#L504) | Calling addReserves Should:<ul><li>Update cToken accrualBlockNumber</li><li>Update cToken borrowIndex</li><li>Update cToken totalBorrows</li><li>Update cToken totalReserves (after accrueInterest)</li><li>Decease User balance</li><li>Increase ctoken underlying balance</li></ul>
COM-009 | [testFuzz_transfer](/protocols/compound-v2/test/core.t.sol#L537) | Calling transfer Should:<ul><li>Decrease from address accountTokens</li><li>Increase to address accountTokens</li></ul>
COM-010 | [testFuzz_transferFrom](/protocols/compound-v2/test/core.t.sol#L566) | Calling transferFrom Should:<ul><li>Decrease from address accountTokens</li><li>Increase to address accountTokens</li></ul>

## Tomb Finance

| ID | Name | Invariant tested |
| --- | --- | --- |
TMF-001 | [testFuzz_tombMint](/protocols/tombfinance/test/core.t.sol#L182) | Tomb mint should: <ul><li>Increase User Balance</li><li>Increase Total Supply</li>
TMF-002 | [testFuzz_tombBurn](/protocols/tombfinance/test/core.t.sol#L203) | Tomb burn should:<ul><li>Decrease User Balance</li><li>Decrease Total Supply</li>
TMF-003 | [testFuzz_tombBurnFrom](/protocols/tombfinance/test/core.t.sol#L228) | Tomb burnFrom should:<ul><li>Decrease User Balance</li><li>Decrease Total Supply</li> 
TMF-004 | [testFuzz_tombTransferFrom](/protocols/tombfinance/test/core.t.sol#L254) | Tomb transferFrom without `autoCalculateTax & currentTaxRate == 0` should:<ul><li>Decrease from User Balance</li><li>Increase to User Balance</li><li>Total Supply should remain the same</li>
TMF-005 | [testFuzz_tombTaxTransferFrom](/protocols/tombfinance/test/core.t.sol#L284) | Tomb transferFrom with autoCalculateTax should:<ul><li>Decrease from User Balance</li><li>Increase to User Balance</li><li>Decrease Total Supply</li> 
TMF-006 | [testFuzz_tBondMint](/protocols/tombfinance/test/core.t.sol#L316) | TBond mint should:<ul><li>Increase User Balance</li><li>Increase Total Supply</li> 
TMF-007 | [testFuzz_tBondBurn](/protocols/tombfinance/test/core.t.sol#L337) | TBond burn should:<ul><li>Decrease User Balance</li><li>Decrease Total Supply</li>
TMF-008 | [testFuzz_tBondBurnFrom](/protocols/tombfinance/test/core.t.sol#L362) | TBond burnFrom should:<ul><li>Decrease User Balance</li><li>Decrease Total Supply</li>
TMF-009 | [testFuzz_tombGenesisRewardPoolDeposit](/protocols/tombfinance/test/core.t.sol#L389) | Depositing into TombGenesisRewardPool Should: <ul><li>Update pool reward variables</li><li>Decrease User bal of token</li><li>Update User rewardDebt</li><li>Increase user bal amount</li></ul>
TMF-010 | [testFuzz_tombGenesisRewardPoolWithdraw](/protocols/tombfinance/test/core.t.sol#L430) | Withdrawing from TombGenesisRewardPool Should: <ul><li>Update pool reward variables</li><li>Increase User bal of token</li><li>Update User rewardDebt</li><li>Decrease user bal amount</li></ul>
TMF-011 | [testFuzz_tombGenesisRewardPoolEmergencyWithdraw](/protocols/tombfinance/test/core.t.sol#L372) | Emergency withdrawing from TombGenesisRewardPool Should: <ul><li>Increase User bal of token</li><li>Decrease User rewardDebt</li><li>Decrease user bal amount</li></ul>
TMF-012 | [testFuzz_tombGenesisRewardPooGovernanceRecoverUnsupported](/protocols/tombfinance/test/core.t.sol#L498) | TombGenesisRewardPool Governance recover Should: <ul><li>Decrease contract bal of token</li><li>Increase to User bal of token</li></ul>
TMF-013 | [testFuzz_tombRewardPoolDeposit]() | Depositing into TombRewardPool Should: <ul><li>Update pool reward variables</li><li>Decrease User bal of token</li><li>Increase User rewardDebt</li><li>Increase user bal amount</li></ul>
TMF-014 | [testFuzz_tombRewardPoolWithdraw](/protocols/tombfinance/test/core.t.sol#L541) | Withdrawing from TombRewardPool Should: <ul><li>Update pool reward variables</li><li>Increase User bal of token</li><li>Update User rewardDebt</li><li>Decrease user bal amount</li></ul>
TMF-015 | [testFuzz_tombRewardPoolEmergencyWithdraw](/protocols/tombfinance/test/core.t.sol#L582) | Emergency withdrawing from TombRewardPool Should: <ul><li>Increase User bal of token</li><li>Decrease User rewardDebt</li><li>Decrease user bal amount</li></ul>
TMF-016 | [testFuzz_tombRewardPoolGovernanceRecoverUnsupported](/protocols/tombfinance/test/core.t.sol#L650) | TombRewardPool Governance recover Should: <ul><li>Decrease contract bal of token</li><li>Increase to User bal of token</li></ul>
TMF-017 | [testFuzz_tShareRewardPoolDeposit](/protocols/tombfinance/test/core.t.sol#L694) | Depositing into TShareRewardPool Should: <ul><li>Update pool reward variables</li><li>Decrease User bal of token</li><li>Increase User rewardDebt</li><li>Increase user bal amount</li></ul>
TMF-018 | [testFuzz_tShareRewardPoolWithdraw](/protocols/tombfinance/test/core.t.sol#L735) | Withdrawing from TShareRewardPool Should:  <ul><li>Update pool reward variables</li><li>Increase User bal of token</li><li>Update User rewardDebt</li><li>Decrease user bal amount</li></ul>
TMF-019 | [testFuzz_tShareRewardPoolEmergencyWithdraw](/protocols/tombfinance/test/core.t.sol#L777) | Emergency withdrawing from TShareRewardPool Should: <ul><li>Increase User bal of token</li><li>Decrease User rewardDebt</li><li>Decrease user bal amount</li></ul>
TMF-020 | [testFuzz_testFuzztShareRewardPoolGovernanceRecoverUnsupported](/protocols/tombfinance/test/core.t.sol#L803) | TShareRewardPool Governance recover Should: <ul><li>Decrease contract bal of token</li>	<li>Increase to User bal of token</li></ul>
TMF-021 | [testFuzz_masonryStake](/protocols/tombfinance/test/core.t.sol#L845) | Staking into Masonry Should: <ul><li>Increase totalSupply</li><li>Increase User staked bal</li><li>Decrease User tBond amount</li></ul>
TMF-022 | [testFuzz_masonryWithdraw](/protocols/tombfinance/test/core.t.sol#L879) | Depositing into Masonry Should: <ul><li>Decrease totalSupply</li><li>Decrease User staked bal</li><li>Increase User tBond amount</li></ul>
TMF-023 | [testFuzz_masonryClaimReward](/protocols/tombfinance/test/core.t.sol#L919) | Claiming reward from Masonry Should: <ul><li>Decrease User Reward</li><li>Increase tomb bal</li><li>Update User epochTimerStart</li></ul>
TMF-024 | [testFuzz_masonryExit](/protocols/tombfinance/test/core.t.sol#L967) | Exiting from Masonry Should: <ul><li>Decrease totalSupply</li><li>Decrease User staked bal</li><li>Increase User tBond amount</li></ul>
TMF-025 | [testFuzz_masonryAllocateSeigniorage](/protocols/tombfinance/test/core.t.sol#L1007) |  Masonry Allocate Seigniorage Should: <ul><li>Update nextRPS</li><li>Update time</li><li>Decrease from User tomb bal</li><li>Increase contracts tomb bal</li></ul>
TMF-026 | [testFuzz_masonryGovernanceRecoverUnsupported](/protocols/tombfinance/test/core.t.sol#L1013) | Masonry Governance recover Should: <ul><li>Decrease contract bal of token</li><li>Increase to User bal of token</li></ul>
TMF-027 | [testFuzz_treasuryBuyBonds](/protocols/tombfinance/test/core.t.sol#L1037) | Buying bonds from the Treasury Should: <ul><li>Decrease User tomb bal</li><li>Increase User tBond bal</li><li>Decrease epochSupplyContractionLeft</li></ul>
TMF-028 | [testFuzz_treasuryRedeemBonds](/protocols/tombfinance/test/core.t.sol#L1079) | Redeeming bonds from the Treasury Should: <ul><li>Decrease User tBond bal</li><li>Increase User tomb bal</li><li>Decrease epochSupplyContractionLeft</li></ul>
TMF-029 | [testFuzz_treasuryAllocateSeigniorage](/protocols/tombfinance/test/core.t.sol#L1120) | Treasury Allocate Seigniorage Should: <ul><li>Update previousEpochTombPrice</li><li>If `_savedForBond > 0`, increase contract tomb bal</li><li>If `_savedForMasonry > 0 && daoFundSharedPercent > 0` increase daoFund tomb bal</li><li>If `_savedForMasonry > 0 && devFundSharedPercent > 0` increase devFund tomb bal</li><li>Update masonry's allowance</li></ul>
TMF-030 | [testFuzz_treasuryGovernanceRecoverUnsupported](/protocols/tombfinance/test/core.t.sol#L1126) | Treasury Governance recover Should: <ul><li>Decrease contract bal of token</li><li>Increase to User bal of token</li></ul>
TMF-031 | [testFuzz_tShareClaimRewards](/protocols/tombfinance/test/core.t.sol#L1149) | tShare Claim rewards Should: <ul><li>Increase totalSupply</li><li>If `_pending > 0 && communityFund != address(0)` increase communityFund tShare bal</li><li>If `_pending > 0 && devFund != address(0)` increase devFund tShare bal</li></ul>
TMF-032 | [testFuzz_tShareBurn](/protocols/tombfinance/test/core.t.sol#L1191) | TShare Burn Should: <ul><li>Decrease User Balance</li><li>Decrease Total Supply</li></ul>
TMF-033 | [testFuzz_tShareGovernanceRecoverUnsupported](/protocols/tombfinance/test/core.t.sol#L1216) | Governance recover from TShare Should: <ul><li>Decrease contract bal of token</li><li>Increase to User bal of token</li></ul>
