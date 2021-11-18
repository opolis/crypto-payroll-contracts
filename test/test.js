const { expect } = require("chai");
const { ethers } = require("hardhat");

const opolisDest = "0x7136fbDdD4DFfa2369A9283B6E90A040318011Ca";
const zeroAddress = "0x0000000000000000000000000000000000000000";
const nonWhitelistedToken = (newAddress =
  "0x2DaA35962A6D43EB54C48367b33d0B379C930E5e");

describe("payroll works", function () {
  let testToken;
  let payroll;
  let opolisAdmin;
  let opolisHelper;
  let opolisMember1;
  let opolisMember2;

  const payrollID1 = 001;
  const payrollID2 = 002;

  const payrollAmt1 = ethers.utils.parseUnits("2500000000000000000000");
  const payrollAmt2 = ethers.utils.parseUnits("3000000000000000000000");

  beforeEach(async () => {
    const TestToken = await ethers.getContractFactory("TestToken");
    const OpolisPay = await ethers.getContractFactory("OpolisPay");
    [opolisAdmin, opolisHelper, opolisMember1, opolisMember2] =
      await ethers.getSigners();

    testToken = await TestToken.deploy();
    await testToken.deployed();

    payroll = await OpolisPay.deploy(
      opolisDest,
      opolisAdmin.address,
      opolisHelper.address,
      [testToken.address]
    );
    await payroll.deployed();
  });

  describe("contract setup", () => {
    it("Destination addresses should be set correctly", async function () {
      expect(await payroll.destination()).to.equal(opolisDest);
    });

    it("OpolisAdmin addresses should be set correctly", async function () {
      const [opolisAdmin] = await ethers.getSigners();
      expect(await payroll.opolisAdmin()).to.equal(opolisAdmin.address);
    });

    it("OpolisHelper addresses should be set correctly", async function () {
      const [, opolisHelper] = await ethers.getSigners();
      expect(await payroll.opolisHelper()).to.equal(opolisHelper.address);
    });

    it("TestToken should be whitelisted", async function () {
      expect(await payroll.supportedTokens(0)).to.equal(testToken.address);
    });

    it("Can't send eth directly to contract", async () => {
      await expect(
        opolisMember1.sendTransaction({
          to: payroll.address,
          value: ethers.utils.parseEther("1.0"),
        })
      ).to.be.revertedWith("DirectTransfer()");
    });
  });

  describe("pay payroll", () => {
    let payment;

    beforeEach(async () => {
      await testToken.mint(opolisMember1.address, payrollAmt1);
      await testToken
        .connect(opolisMember1)
        .approve(payroll.address, payrollAmt1);
      payment = await payroll
        .connect(opolisMember1)
        .payPayroll(testToken.address, payrollAmt1, payrollID1);
    });

    it("Let's you pay payroll with correct inputs", async function () {
      expect(payment)
        .to.emit(payroll, "Paid")
        .withArgs(
          opolisMember1.address,
          testToken.address,
          payrollID1,
          payrollAmt1
        );
      expect(await payroll.payrolls(payrollID1)).to.equal(payrollAmt1);
    });

    it("Requires you pay with a whitelisted token", async function () {
      await expect(
        payroll
          .connect(opolisMember1)
          .payPayroll(nonWhitelistedToken, payrollAmt1, payrollID1)
      ).to.be.revertedWith("NotWhitelisted()");
    });

    it("Requires you to enter a valid, non-duplicative payroll Id", async function () {
      await expect(
        payroll
          .connect(opolisMember1)
          .payPayroll(testToken.address, payrollAmt1, payrollID1)
      ).to.be.revertedWith("AlreadyPaid()");
    });

    it("Requires you to send a payroll amount above 0", async function () {
      await expect(
        payroll
          .connect(opolisMember1)
          .payPayroll(testToken.address, payrollAmt1, 0)
      ).to.be.revertedWith("InvalidPayroll()");
    });
  });

  describe("stake", () => {
    beforeEach(async () => {
      await testToken.mint(opolisMember1.address, payrollAmt1);
      await testToken
        .connect(opolisMember1)
        .approve(payroll.address, payrollAmt1);
    });

    it("Let's you stake with correct inputs", async function () {
      const stake = await payroll
        .connect(opolisMember1)
        .memberStake(testToken.address, payrollAmt1, payrollID1);
      expect(stake)
        .to.emit(payroll, "Staked")
        .withArgs(
          opolisMember1.address,
          testToken.address,
          payrollAmt1,
          payrollID1
        );
      expect(await payroll.stakes(opolisMember1.address)).to.equal(payrollAmt1);
    });

    it("Requires you pay with a whitelisted token or ETH", async function () {
      await expect(
        payroll
          .connect(opolisMember1)
          .memberStake(nonWhitelistedToken, payrollAmt1, payrollID1)
      ).to.be.revertedWith("InvalidStake()");

      const stake = await payroll
        .connect(opolisMember1)
        .memberStake(zeroAddress, payrollAmt1, payrollID1, {
          value: ethers.utils.parseEther("1.0"),
        });
      expect(stake)
        .to.emit(payroll, "Staked")
        .withArgs(opolisMember1.address, zeroAddress, payrollAmt1, payrollID1);
      expect(await payroll.stakes(opolisMember1.address)).to.equal(payrollAmt1);
    });

    it("Requires you stake with a memberId", async function () {
      await expect(
        payroll
          .connect(opolisMember1)
          .memberStake(testToken.address, payrollAmt1, 0)
      ).to.be.revertedWith("NotMember()");
    });

    it("Can't stake twice", async function () {
      await payroll
        .connect(opolisMember1)
        .memberStake(testToken.address, payrollAmt1, payrollID1);
      await expect(
        payroll
          .connect(opolisMember1)
          .memberStake(testToken.address, payrollAmt1, payrollID1)
      ).to.be.revertedWith("AlreadyStaked()");
    });

    it("Requires you to stake with an amount over 0", async function () {
      await expect(
        payroll
          .connect(opolisMember1)
          .memberStake(testToken.address, 0, payrollID1)
      ).to.be.revertedWith("InvalidStake()");
      await expect(
        payroll
          .connect(opolisMember1)
          .memberStake(zeroAddress, payrollAmt1, payrollID1, {
            value: ethers.utils.parseEther("0"),
          })
      ).to.be.revertedWith("InvalidStake()");
    });
  });

  describe("admin accounting functions", () => {
    it.skip("Can withdraw one payroll", async function () {});

    it.skip("Can withdraw more than one payrolls", async function () {});

    it.skip("Cannot withdraw a payroll with a bad payrollId'", async function () {});

    it("Can clear balance if admin'", async function () {
      await testToken.mint(opolisMember1.address, payrollAmt1);
      await testToken
        .connect(opolisMember1)
        .approve(payroll.address, payrollAmt1);

      await testToken.mint(opolisMember2.address, payrollAmt2);
      await testToken
        .connect(opolisMember2)
        .approve(payroll.address, payrollAmt2);

      expect(Number(await testToken.balanceOf(payroll.address))).to.equal(0);
      await payroll
        .connect(opolisMember1)
        .payPayroll(testToken.address, payrollAmt1, payrollID1);
      await payroll
        .connect(opolisMember2)
        .payPayroll(testToken.address, payrollAmt2, payrollID2);
      expect((await testToken.balanceOf(payroll.address)).toString()).to.equal(
        payrollAmt1.add(payrollAmt2).toString()
      );
      await payroll.clearBalance();
      expect(Number(await testToken.balanceOf(payroll.address))).to.equal(0);
    });
  });

  describe("Admin update parameter functions", () => {
    it("valid destination, admin, helper addresses", async () => {
      await expect(payroll.updateDestination(zeroAddress)).to.be.revertedWith(
        "ZeroAddress()"
      );
      await expect(payroll.updateAdmin(zeroAddress)).to.be.revertedWith(
        "ZeroAddress()"
      );
      await expect(payroll.updateHelper(zeroAddress)).to.be.revertedWith(
        "ZeroAddress()"
      );
    });

    it("onlyAdmin", async () => {
      await expect(
        payroll.connect(opolisMember1).updateDestination(newAddress)
      ).to.be.revertedWith("NotPermitted()");
      await expect(
        payroll.connect(opolisMember1).updateAdmin(newAddress)
      ).to.be.revertedWith("NotPermitted()");
      await expect(
        payroll.connect(opolisMember1).updateHelper(newAddress)
      ).to.be.revertedWith("NotPermitted()");
      await expect(
        payroll.connect(opolisMember1).addTokens([newAddress])
      ).to.be.revertedWith("NotPermitted()");
      await expect(
        payroll.connect(opolisMember1).clearBalance()
      ).to.be.revertedWith("NotPermitted()");
    });

    it("update destination", async () => {
      const tx = await payroll.updateDestination(newAddress);
      expect(tx).to.emit(payroll, "NewDestination").withArgs(newAddress);
      expect(await payroll.destination()).to.equal(newAddress);
    });

    it("update admin", async () => {
      const tx = await payroll.updateAdmin(newAddress);
      expect(tx).to.emit(payroll, "NewAdmin").withArgs(newAddress);
      expect(await payroll.opolisAdmin()).to.equal(newAddress);
    });

    it("update helper", async () => {
      const tx = await payroll.updateHelper(newAddress);
      expect(tx).to.emit(payroll, "NewHelper").withArgs(newAddress);
    });

    it("add tokens", async () => {
      const tokens = [
        "0x0bc529c00C6401aEF6D220BE8C6Ea1667F6Ad93e",
        "0x7D1AfA7B718fb893dB30A3aBc0Cfc608AaCfeBB0",
        "0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984",
      ];
      const tx = await payroll.addTokens(tokens);
      expect(tx).to.emit(payroll, "NewToken").withArgs(tokens);
      expect(await payroll.supportedTokens(1)).to.equal(tokens[0]);
      expect(await payroll.supportedTokens(2)).to.equal(tokens[1]);
      expect(await payroll.supportedTokens(3)).to.equal(tokens[2]);
    });
  });
});
