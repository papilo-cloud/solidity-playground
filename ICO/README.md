## Overview of ICOToken.sol

This is an `ERC20` smart contract that functions as a simple [ICO](https://www.investopedia.com/terms/i/initial-coin-offering-ico.asp) token smart contract. Essentially, this smart contract allows the public to buy its tokens using ETH after the smart contract is deployed, i.e. sale starts. The **price of 1 token is 0.1 ETH**, i.e. if a buyer would like to purchase 30 tokens, he would need to send 3 ETH.

The sale duration only lasts for a day; following which the public will not be able to purchase tokens anymore. However, the owner will be able to freely mint tokens using a separate function.

You’ll be needing to implement the 3 functions below.

**constructor()**

Your `constructor` function should achieve the following components:

- Takes in one argument - uint256 _amount
- Call the `constructor` of the `ERC20` contract, passing in your StackUp username as the token name and “ICO” as the token symbol.
- Store the value of the address of the contract deployer in `owner`
- Call the `_mint()` function the `ERC20` contract, minting _amount of tokens to the contract deployer
- Store the value of the current block timestamp in `startTime`

**ownerMint()**

This is a function that only the owner can access. This function allows the owner to mint more tokens freely. This function should have the following components:

- The `ownerMint()` function should have the visibility of `external` and should take in one argument - `uint256 _amount`
- It should have a `require` statement that checks whether the function caller is the owner; if it is not, it should return the error message “Not the owner”
- Once the `require` statement is passed, it should call the `_mint() `function of the ERC20 contract to mint `_amount` of tokens to the owner

**buyTokens**

This is the function that the public will use to buy tokens during the sale period. Your function should have the following components:

- The `buyTokens()` function should have the function modifiers of `external` and `payable`. Similar to the previous two functions, it takes as input only one argument - `uint256 _amount`
- This function has two `require` statements. The first checks whether the current block timestamp is less than or equal to the start time of the sale + sale duration. If the check fails, then it should return the error message “Sale has expired”
- The second `require` statement checks whether the correct amount of ETH is sent. Recall that the price of 1 token is 0.1 ETH, therefore this `require` statement checks whether the amount of ETH submitted along with the transaction is equal to 10% of the amount of tokens the function caller wishes to purchase, as defined with `_amount`. If the check fails, then it should return the error message “Wrong amount of ETH sent”
- Once both of these `require` statements are passed, it should call the `_mint()` function of the ERC20 contract to mint `_amount` of tokens to the function caller