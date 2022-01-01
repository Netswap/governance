# NETTFarm - 2xReward Farms

NETTFarm is a modified version of MasterChefJoeV2, which allows farms to offer two rewards instead of one.

For example, instead of just rewarding NETT, it has the ability to offer NETT **and** your project's token.

## How It Works

The only thing you need to get this to work with NETTFarm is to implement a contract that conforms to the IRewarder interface.

This interface describes two functions:

```sol
interface IRewarder {
  using SafeERC20 for IERC20;
  function onNETTReward(address user, uint256 newLpAmount) external;
  function pendingTokens(address user) external view returns (uint256 pending);
}
```

`pendingTokens` is purely for displaying stats on the frontend.

The most important is `onNETTReward`, which is called whenever a user harvests from our NETTFarm.

It is in this function where you would want to contain the logic to mint/transfer your project's tokens to the user.

The implementation is completely up to you and we suggest rewards should be distributed per second, which is better on Layer2.

But to make your life easier, we have implemented the SimpleRewarderPerSecond and MasterChefRewarderPerSec.

Examples:

- [contracts/rewarders/SimpleRewarderPerSec.sol](contracts/rewarders/SimpleRewarderPerSec.sol) (recommended)
- [contracts/rewarders/MasterChefRewarderPerSec.sol](contracts/rewarders/MasterChefRewarderPerSec.sol)

## Example: Simple Rewarder (recommended)

- [contracts/rewarders/SimpleRewarderPerSec.sol](contracts/rewarders/SimpleRewarderPerSec.sol) (recommended)

This is the version we recommend simply because it's the easiest and less prone to accidental failures.

The concept is simple: a fixed amount of reward tokens is transferred to the contract prior. Then our NETTFarm will
distribute it according to the reward rate set on it. This requires no coordination with your own masterchef whatsoever.

Key points:

- Easy setup, no coordination with your masterchef.
- Needs to be funded with your reward tokens beforehand.
- Once the rewarder is funded with your reward tokens, there is **no** way to get them back.

Setup:

1. The rewarder contract is deployed.
2. A fixed amount of your token is transferred to the contract.
3. The reward rate is set on the rewarder contract.
4. The rewarder contract is added to the pool on our NETTFarm.
5. Users will now be able to claim double rewards when they start staking.

To stop:

1. Set reward rate on rewarder contract to 0.

## Example: MasterChef Rewarder

- [contracts/rewarders/MasterChefRewarderPerSec.sol](contracts/rewarders/MasterChefRewarderPerSec.sol)

This is only applicable if your project uses a Sushi-style MasterChef contract.

Even if it does, we still recommend the Simple Rewarder. But in some cases, your project may not be able to pre-fund the rewarder.
In this case, the MasterChef Rewarder is suitable.

It works by creating a proxy pool in your own MasterChef using a dummy token, which the MasterChef Rewarder contract deposits in order
to receive your reward tokens. Once it harvests your reward tokens, it is then able to distribute them to the users.

Key points:

- Requires coordination with your masterchef.
- Does not need pre-funding beforehand.
- **Highly recommend** not to change any pool weights and/or add new pools in your MasterChef for the duration of the rewarder is live. If you do need to change any pool's weights or add new pools, please inform us as it requires coordination to ensure users don't under/over harvest rewards.

Setup:

1. Create a new dummy token, `DUMMY`, with supply of 1 (in Wei).
2. Transfer 1 `DUMMY` to the deployer and then renounce ownership of the token.
3. Create a new pool in your MasterChef for `DUMMY`.
4. Deploy the rewarder contract.
5. Approve the rewarder contract to spend 1 `DUMMY`.
6. Call the `init()` method in IRewarder contract, passing in the `DUMMY` token address - this will allow the rewarder to deposit the dummy token into your MasterChef and start receiving your rewards.
7. The rewarder contract is added to the pool on our NETTFarm.
8. Users will now be able to claim double rewards when they start staking.

To stop:

1. Set allocation point of dummy pool on your MasterChef to 0.
2. Call `updatePool` on rewarder contract.
3. Set reward rate on rewarder contract to 0.
4. Set allocation point on rewarder contract to 0.