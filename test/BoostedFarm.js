const { expect } = require("chai");
const { ethers, network, upgrades } = require("hardhat");
const TimeHelper = require('./utils/time');

const ADDRESS_ZERO = "0x0000000000000000000000000000000000000000"

describe("BoostedNETTFarm", function () {

    before(async function () {
        this.signers = await ethers.getSigners();
        this.alice = this.signers[0];
        this.bob = this.signers[1];
        this.carol = this.signers[2];
        this.dev = this.signers[3];
        this.minter = this.signers[4];

        this.NTFCF = await ethers.getContractFactory('NETTFarm', this.dev);
        this.BNTFCF = await ethers.getContractFactory('BoostedNETTFarm', this.dev);

        this.NETTCF = await ethers.getContractFactory('NETT');
        this.veNETTCF = await ethers.getContractFactory('VeNETT');
        this.ERC20MockCF = await ethers.getContractFactory("ERC20Mock", this.minter);

        this.nettPerSec = 100;
    });

    beforeEach(async function () {
        this.nett = await this.NETTCF.deploy();
        await this.nett.deployed();
        const startTimestamp = await await TimeHelper.latestBlockTimestamp();
        this.ntf = await this.NTFCF.deploy(
            this.nett.address,
            this.dev.address,
            this.nettPerSec,
            startTimestamp,
        );
        await this.ntf.deployed();

        await this.nett.addMinter(this.ntf.address);
        this.dummyToken = await this.ERC20MockCF.connect(this.dev).deploy("NETT Dummy", "DUMMY", 1);
        this.veNETT = await this.veNETTCF.connect(this.dev).deploy();
        await this.ntf.add(100, this.dummyToken.address, ADDRESS_ZERO);

        this.bntf = await upgrades.deployProxy(this.BNTFCF, [this.ntf.address, this.nett.address, this.veNETT.address, 0]);
        await this.bntf.deployed();

        await this.veNETT.connect(this.dev).setBoostedNETTFarm(this.bntf.address);

        await this.dummyToken.connect(this.dev).approve(this.bntf.address, 1);
        expect(await this.bntf.connect(this.dev).init(this.dummyToken.address))
            .to.emit(this.bntf, "Init")
            .withArgs(1);

        this.lp = await this.ERC20MockCF.deploy("LP Token", "LP", 10000000000);
        await this.lp.deployed();
        await this.lp.transfer(this.alice.address, 1000);
        await this.lp.transfer(this.bob.address, 1000);
        await this.lp.transfer(this.carol.address, 1000);

        await this.bntf.connect(this.dev).add(100, 5000, this.lp.address, ADDRESS_ZERO);
    });

    it("should revert if init called twice", async function () {
        await this.dummyToken.connect(this.dev).approve(this.bntf.address, 1);
        expect(this.bntf.connect(this.dev).init(this.dummyToken.address)).to.be.revertedWith(
            "BoostedNETTFarm: Already has a balance of dummy token"
        );
    });

    it("should adjust total factor when deposit", async function () {
        let pool;
        // User has no veNETT
        await this.lp.connect(this.alice).approve(this.bntf.address, 1000);
        await this.bntf.connect(this.alice).deposit(0, 1000);
        pool = await this.bntf.poolInfo(0);
        expect(pool.totalFactor).to.equal(0);
        expect(pool.totalLpSupply).to.equal(1000);
        expect((await this.bntf.userInfo(0, this.alice.address)).factor).to.equal(0);

        // Transfer some veNETT to bob
        await this.veNETT.connect(this.dev).mint(this.bob.address, 1000);

        // Bob enters the pool
        await this.lp.connect(this.bob).approve(this.bntf.address, 1000);
        await this.bntf.connect(this.bob).deposit(0, 1000);
        pool = await this.bntf.poolInfo(0);
        expect(pool.totalFactor).to.equal(1000);
        expect(pool.totalLpSupply).to.equal(2000);
        expect((await this.bntf.userInfo(0, this.bob.address)).factor).to.equal(1000);
    });

    it("should adjust factor balance when deposit first", async function () {
        // Transfer some veNETT to bob
        await this.veNETT.connect(this.dev).mint(this.bob.address, 100);

        // Bob enters the pool
        await this.lp.connect(this.bob).approve(this.bntf.address, 100);
        await this.bntf.connect(this.bob).deposit(0, 100);
        const pool = await this.bntf.poolInfo(0);
        expect(pool.totalFactor).to.equal(100);
        expect(pool.totalLpSupply).to.equal(100);
        expect((await this.bntf.userInfo(0, this.bob.address)).factor).to.equal(100);
    });

    it("should adjust factor balance on second deposit", async function () {
        let pool;
        // Transfer some veNETT to bob
        await this.veNETT.connect(this.dev).mint(this.bob.address, 1000);

        // Bob enters the pool
        await this.lp.connect(this.bob).approve(this.bntf.address, 1000);
        await this.bntf.connect(this.bob).deposit(0, 10);
        pool = await this.bntf.poolInfo(0);
        expect(pool.totalFactor).to.equal(100);
        expect(pool.totalLpSupply).to.equal(10);
        // sqrt(10, 1000)
        expect((await this.bntf.userInfo(0, this.bob.address)).factor).to.equal(100);

        await this.bntf.connect(this.bob).deposit(0, 990);
        pool = await this.bntf.poolInfo(0);
        expect(pool.totalFactor).to.equal(1000);
        expect(pool.totalLpSupply).to.equal(1000);
        // sqrt(1000, 1000)
        expect((await this.bntf.userInfo(0, this.bob.address)).factor).to.equal(1000);
    });

    it("should adjust boost balance when withdraw", async function () {
        await this.lp.connect(this.alice).approve(this.bntf.address, 1000);
        await this.bntf.connect(this.alice).deposit(0, 1000);
        // Transfer some veNETT to bob
        await this.veNETT.connect(this.dev).mint(this.bob.address, 10);
        // Bob enters the pool
        await this.lp.connect(this.bob).approve(this.bntf.address, 1000);
        await this.bntf.connect(this.bob).deposit(0, 1000);

        await this.bntf.connect(this.bob).withdraw(0, 1000);
        const pool = await this.bntf.poolInfo(0);
        expect(pool.totalFactor).to.equal(0);
        expect(pool.totalLpSupply).to.equal(1000);
    });

    it("should adjust boost balance when partial withdraw", async function () {
        await this.lp.connect(this.alice).approve(this.bntf.address, 1000);
        await this.bntf.connect(this.alice).deposit(0, 1000);
        // Transfer some veNETT to bob
        await this.veNETT.connect(this.dev).mint(this.bob.address, 10);
        // Bob enters the pool
        await this.lp.connect(this.bob).approve(this.bntf.address, 1000);
        await this.bntf.connect(this.bob).deposit(0, 1000);

        await this.bntf.connect(this.bob).withdraw(0, 990);
        const pool = await this.bntf.poolInfo(0);
        expect(pool.totalFactor).to.equal(10);
        expect(pool.totalLpSupply).to.equal(1010);
    });

    it("should return correct pending tokens according to boost", async function () {
        // Transfer some veNETT to bob
        await this.veNETT.connect(this.dev).mint(this.bob.address, 100);

        await this.lp.connect(this.alice).approve(this.bntf.address, 1000);
        await this.bntf.connect(this.alice).deposit(0, 1000);
        await this.lp.connect(this.bob).approve(this.bntf.address, 1000);
        await this.bntf.connect(this.bob).deposit(0, 1000);

        // alice withdraw previous rewards
        await this.bntf.connect(this.alice).deposit(0, 0);
        await this.bntf.connect(this.bob).deposit(0, 0);

        const alicePerSec = await this.bntf.pendingTokens(0, this.alice.address);

        await TimeHelper.advanceTimeAndBlock(1);

        // bob should have 2.5x the pending tokens as alice.
        const bobPending = await this.bntf.pendingTokens(0, this.bob.address);

        // Bob receives the same amount of NETT from alice, and all the veNETT side
        expect(alicePerSec[0].add(alicePerSec[0] * 2)).to.be.closeTo(bobPending[0], 10);
    });

    it("should record the correct reward debt on withdraw", async function () {
        await this.veNETT.connect(this.dev).mint(this.bob.address, 100);
        await this.lp.connect(this.bob).approve(this.bntf.address, 1000);

        await this.bntf.connect(this.bob).deposit(0, 1000);
        // Make sure contract has NETT to emit
        await this.bntf.connect(this.dev).harvestFromNETTFarm();
        await TimeHelper.advanceTimeAndBlock(60 * 60);

        await this.bntf.connect(this.bob).withdraw(0, 0);
        await TimeHelper.advanceTimeAndBlock(1);

        const bobInfo = await this.bntf.userInfo(0, this.bob.address);
        const nettBalOfBob = await this.nett.balanceOf(this.bob.address);
        expect(nettBalOfBob).to.equal(bobInfo.rewardDebt);
    });

    it("should claim reward on deposit", async function () {
        await this.veNETT.connect(this.dev).mint(this.bob.address, 1000);
        await this.lp.connect(this.bob).approve(this.bntf.address, 1000);
        await this.bntf.connect(this.bob).deposit(0, 10);

        await TimeHelper.advanceTimeAndBlock(60);
        await this.bntf.connect(this.bob).deposit(0, 10);
        expect((await this.nett.balanceOf(this.bob.address)).gt(0)).to.be.true
    });

    it("should change rate when vNETT mints", async function () {
        let pool;
        await this.lp.connect(this.alice).approve(this.bntf.address, 1000);
        await this.bntf.connect(this.alice).deposit(0, 1000);

        pool = await this.bntf.poolInfo(0);
        expect(pool.totalFactor).to.equal(0);
        expect(pool.totalLpSupply).to.equal(1000);
        expect((await this.bntf.userInfo(0, this.alice.address)).factor).to.equal(0);

        // Bob enters the pool
        await this.lp.connect(this.bob).approve(this.bntf.address, 1000);
        await this.bntf.connect(this.bob).deposit(0, 1000);

        pool = await this.bntf.poolInfo(0);
        expect(pool.totalFactor).to.equal(0);
        expect(pool.totalLpSupply).to.equal(2000);
        expect((await this.bntf.userInfo(0, this.bob.address)).factor).to.equal("0");

        // Mint some veNETT to bob
        await this.veNETT.connect(this.dev).mint(this.bob.address, 10);

        pool = await this.bntf.poolInfo(0);
        expect(pool.totalFactor).to.equal(100);
        expect(pool.totalLpSupply).to.equal(2000);
        expect((await this.bntf.userInfo(0, this.bob.address)).factor).to.equal(100);
    });

    it("should change rate when vNETT burns", async function () {
        let pool;
        await this.lp.connect(this.alice).approve(this.bntf.address, 1000);
        await this.bntf.connect(this.alice).deposit(0, 1000);

        pool = await this.bntf.poolInfo(0);
        expect(pool.totalFactor).to.equal(0);
        expect(pool.totalLpSupply).to.equal(1000);
        expect((await this.bntf.userInfo(0, this.alice.address)).factor).to.equal(0);

        // Bob enters the pool with veNETT balance
        await this.veNETT.connect(this.dev).mint(this.bob.address, 10);
        await this.lp.connect(this.bob).approve(this.bntf.address, 1000);
        await this.bntf.connect(this.bob).deposit(0, 1000);

        pool = await this.bntf.poolInfo(0);
        expect(pool.totalFactor).to.equal(100);
        expect(pool.totalLpSupply).to.equal(2000);
        expect((await this.bntf.userInfo(0, this.bob.address)).factor).to.equal(100);

        // burn veNETT of bob
        await this.veNETT.connect(this.dev).burnFrom(this.bob.address, 10);

        pool = await this.bntf.poolInfo(0);
        expect(pool.totalFactor).to.equal(0);
        expect(pool.totalLpSupply).to.equal(2000);
        expect((await this.bntf.userInfo(0, this.bob.address)).factor).to.equal(0);
    });

    it("should pay out rewards in claimable", async function () {
        // Bob enters the pool with veNETT balance
        await this.veNETT.connect(this.dev).mint(this.bob.address, 10);
        await this.lp.connect(this.bob).approve(this.bntf.address, 1000);
        await this.bntf.connect(this.bob).deposit(0, 1000);

        await TimeHelper.advanceTimeAndBlock(3600);

        const pending = await this.bntf.pendingTokens(0, this.bob.address);
        expect(pending[0].gt(0)).to.be.true;

        // transfer another 10 veNETT to bob;
        await this.veNETT.connect(this.dev).mint(this.bob.address, 10);
        let claimable = await this.bntf.claimableNETT(0, this.bob.address);
        // Close to as 1 second passes after the mint.
        expect(pending[0]).to.be.closeTo(claimable, 100);
    });

    it("should stop boosting if burn veNETT", async function () {
        // Bob enters the pool with veNETT balance
        await this.veNETT.connect(this.dev).mint(this.bob.address, 10);
        await this.lp.connect(this.bob).approve(this.bntf.address, 1000);
        await this.bntf.connect(this.bob).deposit(0, 1000);

        await TimeHelper.advanceTimeAndBlock(3600);
        
        let bobInfo
        bobInfo = await this.bntf.userInfo(0, this.bob.address);
        expect(bobInfo.factor).to.equal(100);

        await this.veNETT.connect(this.dev).burnFrom(this.bob.address, 10)
        bobInfo = await this.bntf.userInfo(0, this.bob.address)
        expect(bobInfo.factor).to.equal(0);

        let pending = await this.bntf.pendingTokens(0, this.bob.address);
        let claimable = await this.bntf.claimableNETT(0, this.bob.address);
        // Close to as 1 second passes after the mint.
        expect(pending[0]).to.be.closeTo(claimable, 100);
    });

    it("it should update the totalAllocPoint when calling set", async function () {
        await this.bntf.set(0, 1000, 4000, ADDRESS_ZERO, 0);
        expect(await this.bntf.totalAllocPoint()).to.equal(1000);
        expect((await this.bntf.poolInfo(0)).allocPoint).to.equal(1000);
    });

    it("it should never decrease pending tokens", async function () {
        // Bob enters the pool with veNETT balance
        await this.veNETT.connect(this.dev).mint(this.bob.address, 10);
        await this.lp.connect(this.bob).approve(this.bntf.address, 1000);
        await this.bntf.connect(this.bob).deposit(0, 1000);

        await TimeHelper.advanceTimeAndBlock(3600);
        const pending0 = await this.bntf.pendingTokens(0, this.bob.address);

        // Alice enters the pool with more veNETT than Bob's
        await this.veNETT.connect(this.dev).mint(this.alice.address, 100);
        await this.lp.connect(this.alice).approve(this.bntf.address, 1000);
        await this.bntf.connect(this.alice).deposit(0, 1000);

        const pending1 = await this.bntf.pendingTokens(0, this.bob.address);

        expect(pending1[0] > pending0[0]).to.be.true;
    });

    it("it should allow deposits if contract has balance", async function () {
        await this.lp.transfer(this.bntf.address, 100);
        await this.bntf.updatePool(0);
        await this.lp.connect(this.bob).approve(this.bntf.address, 100);
        await this.bntf.connect(this.bob).deposit(0, 100);
        const bobInfo = await this.bntf.userInfo(0, this.bob.address);
        expect(bobInfo[0]).to.equal(100);
    })

    after(async function () {
        await network.provider.request({
            method: "hardhat_reset",
            params: [],
        })
    });
});