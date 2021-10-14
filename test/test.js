const { expect } = require("chai");
const { ethers } = require("hardhat");

const opolisDest = '0x7136fbDdD4DFfa2369A9283B6E90A040318011Ca';
const zeroAddress = '0x0000000000000000000000000000000000000000';

describe("payroll works", function () {
    let testToken;
    let payroll;
    let accounts;

    const payrollID1 = 001;
    const payrollID2 = 002;

    beforeEach(async () => {

        const TestToken = await ethers.getContractFactory("TestToken");
        const OpolisPay = await ethers.getContractFactory("OpolisPay");

        const [opolisAdmin, opolisHelper, opolisMember1, opolisMember2] = await ethers.getSigners();
    
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

    it("Constructor addresses should be set correctly", async function () {
        expect(await payroll.opolisAdmin()).to.equal(accounts[0].address);
        expect(await payroll.opolisHelper()).to.equal(accounts[1].address);
        expect(await payroll.destination()).to.equal(opolisDest);
    });

    it("TestToken should be whitelisted", async function () {
        expect(await payroll.supportedTokens(0)).to.equal(testToken.address);
    });
})