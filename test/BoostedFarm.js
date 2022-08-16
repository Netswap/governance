const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");
const TimeHelper = require('./utils/time');

describe("BoostedFarm", function () {

    before(async function () {
        this.signers = await ethers.getSigners();
        this.minter = this.signers[0]
        this.alice = this.signers[1]
        this.bob = this.signers[2]
        this.carol = this.signers[3]
        this.daniel = this.signers[4]
    });
});