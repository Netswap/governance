const { ethers } = require("hardhat");

const { BigNumber } = ethers;

const TimeHelper = {
    advanceBlock: async () => {
        return ethers.provider.send("evm_mine", []);
    },
    advanceBlockTo: async (blockNumber) => {
        for (let i = await ethers.provider.getBlockNumber(); i < blockNumber; i++) {
            await advanceBlock();
        }
    },
    increase: async (value) => {
        await ethers.provider.send("evm_increaseTime", [value.toNumber()]);
        await this.advanceBlock();
    },
    latestBlockTimestamp: async () => {
        const block = await ethers.provider.getBlock("latest");
        return BigNumber.from(block.timestamp);
    },
    latestBlockNumber: async () => {
        const block = await ethers.provider.getBlock("latest");
        return BigNumber.from(block.number);
    },
    advanceTimeAndBlock: async (time) => {
        await TimeHelper.advanceTime(time);
        await TimeHelper.advanceBlock();
    },
    advanceTime: async (time) => {
        await ethers.provider.send("evm_increaseTime", [time]);
    }
}

module.exports = TimeHelper;