const { expect } = require("chai");
const { ethers, network, upgrades } = require("hardhat");
const TimeHelper = require('./utils/time');

describe("VeNETTStaking Contract", function () {

    before(async function () {
        this.signers = await ethers.getSigners();
        this.dev = this.signers[0];
        this.alice = this.signers[1];
        this.bob = this.signers[2];
        this.carol = this.signers[3];

        this.VeNETTStakingCF = await ethers.getContractFactory('VeNETTStaking');
        this.VeNETTCF = await ethers.getContractFactory('VeNETT');
        this.NETTCF = await ethers.getContractFactory('NETT');
    });

    beforeEach(async function () {
        this.veNETT = await this.VeNETTCF.deploy();
        this.nett = await this.NETTCF.deploy();

        // transfer to test accounts
        await this.nett.transfer(this.alice.address, ethers.utils.parseEther("1000"));
        await this.nett.transfer(this.bob.address, ethers.utils.parseEther("1000"));
        await this.nett.transfer(this.carol.address, ethers.utils.parseEther("1000"));

        this.veNETTPerSharePerSec = ethers.utils.parseEther("1");
        this.speedUpVeNETTPerSharePerSec = ethers.utils.parseEther("1");
        this.speedUpThreshold = 5;
        this.speedUpDuration = 50;
        this.maxCapPct = 20000;

        this.veNETTStaking = await upgrades.deployProxy(this.VeNETTStakingCF, [
            this.nett.address,
            this.veNETT.address,
            this.veNETTPerSharePerSec,
            this.speedUpVeNETTPerSharePerSec,
            this.speedUpThreshold,
            this.speedUpDuration,
            this.maxCapPct
        ]);

        // transfer veNETT ownership to veNETTStaking
        await this.veNETT.transferOwnership(this.veNETTStaking.address);

        // approve NETT to staking contract
        await this.nett
            .connect(this.alice)
            .approve(this.veNETTStaking.address, ethers.utils.parseEther("100000"));
        await this.nett
            .connect(this.bob)
            .approve(this.veNETTStaking.address, ethers.utils.parseEther("100000"));
        await this.nett
            .connect(this.carol)
            .approve(this.veNETTStaking.address, ethers.utils.parseEther("100000"));
    });

    describe("setMaxCapPct", function () {
        it("should not allow non-owner to setMaxCapPct", async function () {
            await expect(
                this.veNETTStaking.connect(this.alice).setMaxCapPct(this.maxCapPct + 1)
            ).to.be.revertedWith("Ownable: caller is not the owner");
        });

        it("should not allow owner to set lower maxCapPct", async function () {
            expect(await this.veNETTStaking.maxCapPct()).to.be.equal(this.maxCapPct);

            await expect(
                this.veNETTStaking.connect(this.dev).setMaxCapPct(this.maxCapPct - 1)
            ).to.be.revertedWith(
                "VeNETTStaking: expected new _maxCapPct to be greater than existing maxCapPct"
            );
        });

        it("should not allow owner to set maxCapPct greater than upper limit", async function () {
            await expect(
                this.veNETTStaking.connect(this.dev).setMaxCapPct(10000001)
            ).to.be.revertedWith(
                "VeNETTStaking: expected new _maxCapPct to be non-zero and <= 10000000"
            );
        });

        it("should allow owner to setMaxCapPct", async function () {
            expect(await this.veNETTStaking.maxCapPct()).to.be.equal(this.maxCapPct);

            await this.veNETTStaking
                .connect(this.dev)
                .setMaxCapPct(this.maxCapPct + 100);

            expect(await this.veNETTStaking.maxCapPct()).to.be.equal(
                this.maxCapPct + 100
            );
        });
    });

    describe("setVeNETTPerSharePerSec", function () {
        it("should not allow non-owner to setVeNETTPerSharePerSec", async function () {
            await expect(
                this.veNETTStaking
                    .connect(this.alice)
                    .setVeNETTPerSharePerSec(ethers.utils.parseEther("1.5"))
            ).to.be.revertedWith("Ownable: caller is not the owner");
        });

        it("should not allow owner to set veNETTPerSharePerSec greater than upper limit", async function () {
            await expect(
                this.veNETTStaking
                    .connect(this.dev)
                    .setVeNETTPerSharePerSec(ethers.utils.parseUnits("1", 37))
            ).to.be.revertedWith(
                "VeNETTStaking: expected _veNETTPerSharePerSec to be <= 1e36"
            );
        });

        it("should allow owner to setVeNETTPerSharePerSec", async function () {
            expect(await this.veNETTStaking.veNETTPerSharePerSec()).to.be.equal(
                this.veNETTPerSharePerSec
            );

            await this.veNETTStaking
                .connect(this.dev)
                .setVeNETTPerSharePerSec(ethers.utils.parseEther("1.5"));

            expect(await this.veNETTStaking.veNETTPerSharePerSec()).to.be.equal(
                ethers.utils.parseEther("1.5")
            );
        });
    });

    describe("setSpeedUpThreshold", function () {
        it("should not allow non-owner to setSpeedUpThreshold", async function () {
            await expect(
                this.veNETTStaking.connect(this.alice).setSpeedUpThreshold(10)
            ).to.be.revertedWith("Ownable: caller is not the owner");
        });

        it("should not allow owner to setSpeedUpThreshold to 0", async function () {
            await expect(
                this.veNETTStaking.connect(this.dev).setSpeedUpThreshold(0)
            ).to.be.revertedWith(
                "VeNETTStaking: expected _speedUpThreshold to be > 0 and <= 100"
            );
        });

        it("should not allow owner to setSpeedUpThreshold greater than 100", async function () {
            await expect(
                this.veNETTStaking.connect(this.dev).setSpeedUpThreshold(101)
            ).to.be.revertedWith(
                "VeNETTStaking: expected _speedUpThreshold to be > 0 and <= 100"
            );
        });

        it("should allow owner to setSpeedUpThreshold", async function () {
            expect(await this.veNETTStaking.speedUpThreshold()).to.be.equal(
                this.speedUpThreshold
            );

            await this.veNETTStaking.connect(this.dev).setSpeedUpThreshold(10);

            expect(await this.veNETTStaking.speedUpThreshold()).to.be.equal(10);
        });
    });

    describe("deposit", function () {
        it("should not allow deposit 0", async function () {
            await expect(
                this.veNETTStaking.connect(this.alice).deposit(0)
            ).to.be.revertedWith(
                "VeNETTStaking: expected deposit amount to be greater than zero"
            );
        });

        it("should have correct updated user info after first time deposit", async function () {
            const beforeAliceUserInfo = await this.veNETTStaking.userInfos(
                this.alice.address
            );
            // balance
            expect(beforeAliceUserInfo[0]).to.be.equal(0);
            // rewardDebt
            expect(beforeAliceUserInfo[1]).to.be.equal(0);
            // lastClaimTimestamp
            expect(beforeAliceUserInfo[2]).to.be.equal(0);
            // speedUpEndTimestamp
            expect(beforeAliceUserInfo[3]).to.be.equal(0);

            // Check NETT balance before deposit
            expect(await this.nett.balanceOf(this.alice.address)).to.be.equal(
                ethers.utils.parseEther("1000")
            );

            const depositAmount = ethers.utils.parseEther("100");
            await this.veNETTStaking.connect(this.alice).deposit(depositAmount);
            const depositBlock = await ethers.provider.getBlock();

            // Check NETT balance after deposit
            expect(await this.nett.balanceOf(this.alice.address)).to.be.equal(
                ethers.utils.parseEther("900")
            );

            const afterAliceUserInfo = await this.veNETTStaking.userInfos(
                this.alice.address
            );
            // balance
            expect(afterAliceUserInfo[0]).to.be.equal(depositAmount);
            // debtReward
            expect(afterAliceUserInfo[1]).to.be.equal(0);
            // lastClaimTimestamp
            expect(afterAliceUserInfo[2]).to.be.equal(depositBlock.timestamp);
            // speedUpEndTimestamp
            expect(afterAliceUserInfo[3]).to.be.equal(
                depositBlock.timestamp + this.speedUpDuration
            );
        });

        it("should have correct updated user balance after deposit with non-zero balance", async function () {
            await this.veNETTStaking
                .connect(this.alice)
                .deposit(ethers.utils.parseEther("100"));

            await this.veNETTStaking
                .connect(this.alice)
                .deposit(ethers.utils.parseEther("5"));

            const afterAliceUserInfo = await this.veNETTStaking.userInfos(
                this.alice.address
            );
            // balance
            expect(afterAliceUserInfo[0]).to.be.equal(ethers.utils.parseEther("105"));
        });

        it("should claim pending veNETT upon depositing with non-zero balance", async function () {
            await this.veNETTStaking
                .connect(this.alice)
                .deposit(ethers.utils.parseEther("50"));

            TimeHelper.advanceTimeAndBlock(29);

            // Check veNETT balance before deposit
            expect(await this.veNETT.balanceOf(this.alice.address)).to.be.equal(0);

            await this.veNETTStaking
                .connect(this.alice)
                .deposit(ethers.utils.parseEther("1"));
            
            // Check veNETT balance after deposit
            // Should have sum of:
            // baseVeNETT =  50 * 30 = 1500 veNETT
            // speedUpVeNETT = 50 * 30 = 1500 veNETT
            expect(await this.veNETT.balanceOf(this.alice.address)).to.be.equal(
                ethers.utils.parseEther("3000")
            );
        });

        it("should receive speed up benefits after depositing speedUpThreshold with non-zero balance", async function () {
            await this.veNETTStaking
                .connect(this.alice)
                .deposit(ethers.utils.parseEther("100"));

            TimeHelper.advanceTimeAndBlock(this.speedUpDuration);

            await this.veNETTStaking.connect(this.alice).claim();

            const afterClaimAliceUserInfo = await this.veNETTStaking.userInfos(
                this.alice.address
            );
            // speedUpTimestamp
            expect(afterClaimAliceUserInfo[3]).to.be.equal(0);

            await this.veNETTStaking
                .connect(this.alice)
                .deposit(ethers.utils.parseEther("5"));

            const secondDepositBlock = await ethers.provider.getBlock();
            const seconDepositAliceUserInfo = await this.veNETTStaking.userInfos(
                this.alice.address
            );
            // speedUpTimestamp
            expect(seconDepositAliceUserInfo[3]).to.be.equal(
                secondDepositBlock.timestamp + this.speedUpDuration
            );
        });

        it("should not receive speed up benefits after depositing less than speedUpThreshold with non-zero balance", async function () {
            await this.veNETTStaking
                .connect(this.alice)
                .deposit(ethers.utils.parseEther("100"));

            TimeHelper.advanceTimeAndBlock(this.speedUpDuration);

            await this.veNETTStaking
                .connect(this.alice)
                .deposit(ethers.utils.parseEther("1"));

            const afterAliceUserInfo = await this.veNETTStaking.userInfos(
                this.alice.address
            );
            // speedUpTimestamp
            expect(afterAliceUserInfo[3]).to.be.equal(0);
        });

        it("should receive speed up benefits after deposit with zero balance", async function () {
            await this.veNETTStaking
                .connect(this.alice)
                .deposit(ethers.utils.parseEther("100"));

            TimeHelper.advanceTimeAndBlock(100);

            await this.veNETTStaking
                .connect(this.alice)
                .withdraw(ethers.utils.parseEther("100"));

            TimeHelper.advanceTimeAndBlock(100);

            await this.veNETTStaking
                .connect(this.alice)
                .deposit(ethers.utils.parseEther("1"));

            const secondDepositBlock = await ethers.provider.getBlock();

            const secondDepositAliceUserInfo = await this.veNETTStaking.userInfos(
                this.alice.address
            );
            // speedUpEndTimestamp
            expect(secondDepositAliceUserInfo[3]).to.be.equal(
                secondDepositBlock.timestamp + this.speedUpDuration
            );
        });

        it("should have speed up period extended after depositing speedUpThreshold and currently receiving speed up benefits", async function () {
            await this.veNETTStaking
                .connect(this.alice)
                .deposit(ethers.utils.parseEther("100"));

            const initialDepositBlock = await ethers.provider.getBlock();

            const initialDepositAliceUserInfo = await this.veNETTStaking.userInfos(
                this.alice.address
            );
            const initialDepositSpeedUpEndTimestamp = initialDepositAliceUserInfo[3];

            expect(initialDepositSpeedUpEndTimestamp).to.be.equal(
                initialDepositBlock.timestamp + this.speedUpDuration
            );

            // Increase by some amount of time less than speedUpDuration
            await TimeHelper.advanceTimeAndBlock(this.speedUpDuration / 2);

            // Deposit speedUpThreshold amount so that speed up period gets extended
            await this.veNETTStaking
                .connect(this.alice)
                .deposit(ethers.utils.parseEther("5"));

            const secondDepositBlock = await ethers.provider.getBlock();

            const secondDepositAliceUserInfo = await this.veNETTStaking.userInfos(
                this.alice.address
            );
            const secondDepositSpeedUpEndTimestamp = secondDepositAliceUserInfo[3];

            expect(
                secondDepositSpeedUpEndTimestamp.gt(initialDepositSpeedUpEndTimestamp)
            ).to.be.equal(true);

            expect(secondDepositSpeedUpEndTimestamp).to.be.equal(
                secondDepositBlock.timestamp + this.speedUpDuration
            );
        });

        it("should have lastClaimTimestamp updated after depositing if holding max veNETT cap", async function () {
            await this.veNETTStaking
                .connect(this.alice)
                .deposit(ethers.utils.parseEther("100"));

            // Increase by `maxCapPct` seconds to ensure that user will have max veNETT after claiming
            TimeHelper.advanceTimeAndBlock(this.maxCapPct);

            await this.veNETTStaking.connect(this.alice).claim();

            const claimBlock = await ethers.provider.getBlock();

            const claimAliceUserInfo = await this.veNETTStaking.userInfos(
                this.alice.address
            );
            // lastClaimTimestamp
            expect(claimAliceUserInfo[2]).to.be.equal(claimBlock.timestamp);

            TimeHelper.advanceTimeAndBlock(this.maxCapPct);

            const pendingVeNETT = await this.veNETTStaking.getPendingVeNETT(
                this.alice.address
            );
            expect(pendingVeNETT).to.be.equal(0);

            await this.veNETTStaking
                .connect(this.alice)
                .deposit(ethers.utils.parseEther("5"));

            const secondDepositBlock = await ethers.provider.getBlock();

            const secondDepositAliceUserInfo = await this.veNETTStaking.userInfos(
                this.alice.address
            );

            // lastClaimTimestamp
            expect(secondDepositAliceUserInfo[2]).to.be.equal(
                secondDepositBlock.timestamp
            );
        });
    });

    describe("withdraw", function () {
        it("should not allow withdraw 0", async function () {
            await expect(
                this.veNETTStaking.connect(this.alice).withdraw(0)
            ).to.be.revertedWith(
                "VeNETTStaking: expected withdraw amount to be greater than zero"
            );
        });

        it("should not allow withdraw amount greater than user balance", async function () {
            await expect(
                this.veNETTStaking.connect(this.alice).withdraw(1)
            ).to.be.revertedWith(
                "VeNETTStaking: cannot withdraw greater amount of NETT than currently staked"
            );
        });

        it("should have correct updated user info and balances after withdraw", async function () {
            await this.veNETTStaking
                .connect(this.alice)
                .deposit(ethers.utils.parseEther("100"));
            const depositBlock = await ethers.provider.getBlock();

            expect(await this.nett.balanceOf(this.alice.address)).to.be.equal(
                ethers.utils.parseEther("900")
            );

            TimeHelper.advanceTimeAndBlock(this.speedUpDuration / 2);

            await this.veNETTStaking.connect(this.alice).claim();
            const claimBlock = await ethers.provider.getBlock();

            expect(await this.veNETT.balanceOf(this.alice.address)).to.not.be.equal(0);

            const beforeAliceUserInfo = await this.veNETTStaking.userInfos(
                this.alice.address
            );
            // balance
            expect(beforeAliceUserInfo[0]).to.be.equal(
                ethers.utils.parseEther("100")
            );
            // rewardDebt
            expect(beforeAliceUserInfo[1]).to.be.equal(
                // Divide by 2 since half of it is from the speed up
                (await this.veNETT.balanceOf(this.alice.address)).div(2)
            );
            // lastClaimTimestamp
            expect(beforeAliceUserInfo[2]).to.be.equal(claimBlock.timestamp);
            // speedUpEndTimestamp
            expect(beforeAliceUserInfo[3]).to.be.equal(
                depositBlock.timestamp + this.speedUpDuration
            );

            await this.veNETTStaking
                .connect(this.alice)
                .withdraw(ethers.utils.parseEther("5"));
            const withdrawBlock = await ethers.provider.getBlock();

            // Check user info fields are updated correctly
            const afterAliceUserInfo = await this.veNETTStaking.userInfos(
                this.alice.address
            );
            // balance
            expect(afterAliceUserInfo[0]).to.be.equal(ethers.utils.parseEther("95"));
            // rewardDebt
            expect(afterAliceUserInfo[1]).to.be.equal(
                (await this.veNETTStaking.accVeNETTPerShare()).mul(95)
            );
            // lastClaimTimestamp
            expect(afterAliceUserInfo[2]).to.be.equal(withdrawBlock.timestamp);
            // speedUpEndTimestamp
            expect(afterAliceUserInfo[3]).to.be.equal(0);

            // Check user token balances are updated correctly
            expect(await this.veNETT.balanceOf(this.alice.address)).to.be.equal(0);
            expect(await this.nett.balanceOf(this.alice.address)).to.be.equal(
                ethers.utils.parseEther("905")
            );
        });
    });

    describe("claim", function () {
        it("should not be able to claim with zero balance", async function () {
            await expect(
                this.veNETTStaking.connect(this.alice).claim()
            ).to.be.revertedWith(
                "VeNETTStaking: cannot claim veNETT when no NETT is staked"
            );
        });

        it("should update lastRewardTimestamp on claim", async function () {
            await this.veNETTStaking
                .connect(this.alice)
                .deposit(ethers.utils.parseEther("100"));

            TimeHelper.advanceTimeAndBlock(100);

            await this.veNETTStaking.connect(this.alice).claim();
            const claimBlock = await ethers.provider.getBlock();

            // lastRewardTimestamp
            expect(await this.veNETTStaking.lastRewardTimestamp()).to.be.equal(
                claimBlock.timestamp
            );
        });

        it("should receive veNETT on claim", async function () {
            await this.veNETTStaking
                .connect(this.alice)
                .deposit(ethers.utils.parseEther("100"));

            TimeHelper.advanceTimeAndBlock(49);

            // Check veNETT balance before claim
            expect(await this.veNETT.balanceOf(this.alice.address)).to.be.equal(0);

            await this.veNETTStaking.connect(this.alice).claim();

            // Check veNETT balance after claim
            // Should be sum of:
            // baseVeNETT = 100 * 50 = 5000
            // speedUpVeNETT = 100 * 50 = 5000
            expect(await this.veNETT.balanceOf(this.alice.address)).to.be.equal(
                ethers.utils.parseEther("10000")
            );
        });

        it("should receive correct veNETT if veNETTPerSharePerSec is updated multiple times", async function () {
            await this.veNETTStaking
                .connect(this.alice)
                .deposit(ethers.utils.parseEther("100"));

            TimeHelper.advanceTimeAndBlock(9);

            await this.veNETTStaking
                .connect(this.dev)
                .setVeNETTPerSharePerSec(ethers.utils.parseEther("2"));

            TimeHelper.advanceTimeAndBlock(9);

            await this.veNETTStaking
                .connect(this.dev)
                .setVeNETTPerSharePerSec(ethers.utils.parseEther("1.5"));

            TimeHelper.advanceTimeAndBlock(9);

            // Check veNETT balance before claim
            expect(await this.veNETT.balanceOf(this.alice.address)).to.be.equal(0);

            await this.veNETTStaking.connect(this.alice).claim();

            // Check veNETT balance after claim
            // For baseVeNETT, we're expected to have been generating at a rate of 1 for
            // the first 10 seconds, a rate of 2 for the next 10 seconds, and a rate of
            // 1.5 for the last 10 seconds, i.e.:
            // baseVeNETT = 100 * 10 * 1 + 100 * 10 * 2 + 100 * 10 * 1.5 = 4500
            // speedUpVeNETT = 100 * 30 = 3000
            expect(await this.veNETT.balanceOf(this.alice.address)).to.be.equal(
                ethers.utils.parseEther("7500")
            );
        });
    });

    describe("updateRewardVars", function () {
        it("should have correct reward vars after time passes", async function () {
            await this.veNETTStaking
                .connect(this.alice)
                .deposit(ethers.utils.parseEther("100"));
            
            const block = await ethers.provider.getBlock();
            TimeHelper.advanceTimeAndBlock(29);

            const accVeNETTPerShareBeforeUpdate =
                await this.veNETTStaking.accVeNETTPerShare();
            await this.veNETTStaking.connect(this.dev).updateRewardVars();

            expect(await this.veNETTStaking.lastRewardTimestamp()).to.be.equal(
                block.timestamp + 30
            );

            // Increase should be `secondsElapsed * veNETTPerSharePerSec * ACC_VENETT_PER_SHARE_PER_SEC_PRECISION`:
            // = 30 * 1 * 1e18
            expect(await this.veNETTStaking.accVeNETTPerShare()).to.be.equal(
                accVeNETTPerShareBeforeUpdate.add(ethers.utils.parseEther("30"))
            );
        });
    });

    after(async function () {
        await network.provider.request({
            method: "hardhat_reset",
            params: [],
        });
    });
});