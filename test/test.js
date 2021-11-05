const { expect } = require("chai");
const { ethers } = require("hardhat");

const opolisDest = '0x7136fbDdD4DFfa2369A9283B6E90A040318011Ca';
const zeroAddress = '0x0000000000000000000000000000000000000000';


describe("payroll works", function () {
    let testToken;
    let payroll;
    let opolisAdmin;
    let opolisHelper;

    const payrollID1 = 001;
    const payrollID2 = 002;

    const payrollAmt1 = ethers.utils.parseUnits("2500000000000000000000")
    const payrollAmt2 = ethers.utils.parseUnits("3000000000000000000000")



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

    it("Destination addresses should be set correctly", async function () {
        expect(await payroll.destination()).to.equal(opolisDest);
    });

    it("OpolisAdmin addresses should be set correctly", async function () {
        const [opolisAdmin] = await ethers.getSigners();
        expect(await payroll.opolisAdmin()).to.equal(opolisAdmin.address);
    });

    it("OpolisHelper addresses should be set correctly", async function () {
        const [,opolisHelper] = await ethers.getSigners();
        expect(await payroll.opolisHelper()).to.equal(opolisHelper.address);
    });

    it("TestToken should be whitelisted", async function () {
        expect(await payroll.supportedTokens(0)).to.equal(testToken.address);
    });

    it("Let's you pay payroll with correct inputs", async function () {
        const payment = await ethers.payPayroll(testToken.address, payrollAmt1, payrollID1);
        expect(await payment.token).to.equal(testToken.address);
        expect(payment.amount).to.equal(payrollAmt1);
        expect(payment.payrollId).to.equal(payrollID1);
    });

    it("Requires you pay with a whitelisted token", async function () {
        const payment = await ethers.payPayroll(testToken.address, payrollAmt1, payrollID1);
        
    });

    it("Requires you to enter a valid, non-duplicative payroll Id", async function () {
        const payment = await ethers.payPayroll(testToken.address, payrollAmt1, payrollID1);
        
    });

    it("Requires you to send a payroll amount above 0", async function () {
        const payment = await ethers.payPayroll(testToken.address, payrollAmt1, payrollID1);
        
    });

    it("Let's you stake with correct inputs", async function () {
        const payment = await ethers.payPayroll(testToken.address, payrollAmt1, payrollID1);
        expect(await payment.token).to.equal(testToken.address);
        expect(payment.amount).to.equal(payrollAmt1);
        expect(payment.payrollId).to.equal(payrollID1);
    });

    it("Requires you pay with a whitelisted token or ETH", async function () {
        const payment = await ethers.payPayroll(testToken.address, payrollAmt1, payrollID1);
        
    });

    it("Requires you stake with a memberId", async function () {
        const payment = await ethers.payPayroll(testToken.address, payrollAmt1, payrollID1);
        
    });

    it("Requires you to stake with an amount over 0", async function () {
        const payment = await ethers.payPayroll(testToken.address, payrollAmt1, payrollID1);
        
    });

    it("Can withdraw one payroll", async function () {
        const payment = await ethers.payPayroll(testToken.address, payrollAmt1, payrollID1);
        
    });

    it("Can withdraw more than one payrolls", async function () {
       
        
    });


    it("Cannot withdraw a payroll with a bad payrollId'", async function () {
        
        
    });

    it("Can clear balance if admin'", async function () {
        
        
    });

    it("Only Admin can update configs'", async function () {
        
        
    });

    it("Not admin, cannot update configuration", async function () {
        
        
    });




 


})