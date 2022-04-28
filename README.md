# crypto-payroll-contracts
Simple way for tracking crypto payroll payments for Opolis crypto payroll. This contract is primarily for tracking verses a full payroll system for dealing with withholding and taxes. 

The idea is verify when a payroll has been paid based on the user paying their payroll via our UI, where we'll programmatically submit the payrollId along with the actual payment. The other goal is to give our operations team a way to ensure 1) new member deposit in crypto are either immediately sent to Wyre, if paid in ETH, or 2) withdraw batches of new member stakes and crypto payrolls at their discretion. 

## Deploying: 
Steps for getting up and running: 

1. Pull repo from github
2. `yarn install`
3. Create a `./config.json` and fill in using the example file 
4. Run `yarn test` to run test coverage 
5. Launch with `npx hardhat run ./scripts/deploy-tests.js` for tests or `npx hardhat run ./scripts/deploy.js --network {{network}}`

## Deployments:

Mainnet: [0x87C91ac511688138E1452C942663f52cD5E2AbC5](https://etherscan.io/address/0x87C91ac511688138E1452C942663f52cD5E2AbC5)

Ropsten: [0x51E9210d7Ee7a8e7064C8a71F0cb0baA2205F298](https://ropsten.etherscan.io/address/0x77c7678911647eD74A9997C5412A4DAE2d6BEE77)

Mumbai: [0x347434c2BbBa4193bd56184bD768f4a4139Da39c](https://mumbai.polygonscan.com/address/0x347434c2BbBa4193bd56184bD768f4a4139Da39c)

## Core Functions 

payParoll() - Function to allow a transfer of whitelisted ERC20 tokens along with the corresponding payrollID for that members' payroll. We just use payrollID rather than other information to make it harder to associate a payroll with any particular member. 

NB: We only expect to accept stable coins / ERC20s for payroll. 

memberStake() - Function to allow a new member to make a deposit to cover their last month of benefits. Here we accept both ERC20 tokens and ETH. With ETH we want to immediately transfer it to Wyre (the destination) where it can be liquidated. For stable coins we want our Ops team to have the option to withdraw the stakes in batches when required. 

withdrawPayrolls() - Function to allow our ops team to withdraw amounts of tokens associated with paid payrolls. Here we're relying on the ops team to input arrays of the correct amounts and tokens associated with each payrollID.

NB: We decided against saying a more informational payroll object for gas minimization reasons. 

withdrawStakes() - Function to allow our opts team to withdraw amounts of tokens associated with paid member staking deposits. Here we're relying on the ops team to input arrays of the correct amounts and tokens associated with members' stakes.

clearBalance() - This is a safety function to withdraw all amounts of whitelisted tokens in the contract. 

## Modifiers 

OnlyOpolis - is meant to allow either a multi-sig controlled by our Ops team or a bot that we set up to call OnlyOpolis Functions 

OnlyAdmin - is meant to restrict these functions to only being called by a multi-sig that is controlled by our Ops team. 

## Other important info 

destination - is the address provided by Wyre where we can send tokens and ETH for auto-liquidation. 

supportedTokens[] - is the list of ERC20 tokens we'll accept. Admins will have the ability to update this list. 
