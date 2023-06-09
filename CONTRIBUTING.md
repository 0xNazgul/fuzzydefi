# Contributing to Fuzzy DeFi

First, thanks for your interest in contributing to this repository! I welcome and appreciate all contributions, including bug reports, feature suggestions, tutorials/blog posts, and code improvements.

If you're unsure where to start, I recommend taking a look at our [issue tracker](https://github.com/0xNazgul/FuzzyDeFi/issues). If you find an issue or proposal that you feel you can do, assign yourself to it.

## Bug reports and feature suggestions

Bug reports and feature suggestions can be submitted to our issue tracker. For bug reports, adding as much information as you can will help me in debugging and resolving the issue quickly.

## Questions

Questions can be submitted to the issue tracker or message me on twitter [@0xNazgul](https://twitter.com/0xNazgul).

## Code

This repository uses the pull request contribution model. Please create an account on Github if you don't have one already, fork this repository, and submit your contributions via pull requests. For more documentation, look [here](https://guides.github.com/activities/forking/).

Some pull request guidelines:
- Create a new branch from the [`main`](https://github.com/0xNazgul/FuzzyDeFi/tree/main) branch. If you are submitting a new feature, prefix the new branch name with `dev` (for example, `dev-add-properties-for-erc20-transfers`). If your submission is a bug fix, prefix the new branch name with `fix` (for example, `fix-typo-in-readme`). Please be descriptive in the branch name, avoid confusing or unclear names such as `mypatch2` or `bugfix`.
- Minimize irrelevant changes (formatting, whitespace, etc) to code that would otherwise not be touched by this patch. Save formatting or style corrections for a separate pull request that does not make any semantic changes.
- When possible, large changes should be split up into smaller focused pull requests.
- Fill out the pull request description with a summary of what your patch does, key changes that have been made, and any further points of discussion, if applicable. If your pull request solves an open issue, add "Fixes #xxx" at the end.
- Title your pull request with a brief description of what it's changing. "Fixes #123" is a good comment to add to the description, but makes for an unclear title on its own.
- If your are unsure about something, don't hesitate to ask!

## Adding a new protocol or invariant to another protocol

When adding a new protocol make sure to follow the [Directory Structure](#directory-structure), [Test File Structure](#test-file-structure) and [Properties Structure](#properties-structure). Explicitly note the required setup in a `README.md` file. I don't require you to add your own protocol notes in that same `README.md` file if you don't want to or if you just didn't. 

When adding a new invariant make sure to follow the [Test File Structure](#test-file-structure) (specifically the testFuzz function format) and [Properties Structure](#properties-structure).

## Directory Structure

Below is a rough outline of the directory structure:

```text
.
├── protocols                                   # Parent folder for contracts
│   ├── uniswap-v2                              # Properties for Uniswap-v2 contracts
│   │   ├── lib                                 # Required dependencies
│   │   ├── script                              # Scripts if any, mostly empty
│   │   ├── src                                 # All slightly modified Project contracts 
│   │   ├── test                                # Location of test files
│   │   │   ├── mocks                           # Any other mocks you may need
│   │   │   └── core.t.sol                      # Core test file with all properties
│   │   └── ...                                 # Other testing specific files
│   ├── Olympus DAO                             # Properties for Olympus DAO contracts
│   │   └── ...                                 # Same format  
│   └── Other protocols
└── ...
```

Please follow this structure in your collaborations.

## Test File Structure

Below is a rough outline of the test file structure:

```Solidity
// SPDX-License-Identifier: UNLICENSED

// Adjust pragma version as needed
pragma solidity >=0.6.0;

// Test Helpers
import "forge-std/Test.sol";

// Import protocol files as needed

// Name should remain CoreTest 
contract CoreTest is Test {
    uint256 MAX = type(uint256).max;

    function setUp() public {
        // Add your own signature name if you want
        vm.label(address(this), "THE_FUZZANATOR");

        // Setup protocol contracts as needed 
    }

    // Used to make sure contracts are deploying correctly
    function testON() public {}

    /* INVARIANTS: FUNCTION_NAME should:
     * Invariant 1
     * Invariant 2
     * ...
    */
    function testFuzz_FUNCTION_NAME() public {
        // PRECONDITIONS:
        
        // Anything that needs to be done prior to the action.
        // Values that need to be fetched and stored into memory before the action
        uint256 amount = _between(_amount, 1, MAX);

        // ACTION:
        
        // Calling the function to be fuzzed
        try Contract.FUNCTION_NAME() {
            // POSTCONDTIONS:
            
            // Values that need to be fetched again after the action 
            // assert invariant conditions hold
            assertEq(a, b, "A IS EQUAL TO B CHECK");

        // Catch any overflow. Depending on what is being tested comment out assert(false) or assert properly
        } catch {/*assert(false)*/ }// overflow
    }

    // Bounding function similar to vm.assume but is more efficient regardless of the fuzzing framework
    // This is also a guarantee bound of the input unlike vm.assume which can only be used for narrow checks     
    function _between(uint256 random, uint256 low, uint256 high) public pure returns (uint256) {
        return low + random % (high-low);
    }  
}
```

Please follow this structure in your collaborations. 

## Properties Structure

Below is a rough outline of the properties file structure:

| ID | Name | Invariant tested |
| --- | --- | --- |
BLA-001 | [testFuzz_FUNCTIONNAME]() | FUNCTIONNAME should: <ul><li>Invariant 1</li><li>Invariant 2</li><li>...</li></ul> 
BLA-002 | [testFuzz_FUNCTIONNAME2]() | FUNCTIONNAME2 should: <ul><li>Invariant 1</li><li>Invariant 2</li><li>...</li></ul> 
... | ... | ...

Please follow this structure in your collaborations. 

## Protocol Notes
These are mostly for myself to get a stronger understanding of how the protocol works. If you want add more useful information or maybe I misunderstood something. Feel free to submit an issue or a PR updating those readme files.