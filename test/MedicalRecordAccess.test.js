const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("MedicalRecordAccess", function () {
  let contract;
  let owner;

  beforeEach(async () => {
    const Contract = await ethers.getContractFactory("MedicalRecordAccess");
    contract = await Contract.deploy();
    [owner] = await ethers.getSigners();
    await contract.resetSyncPointer(); // resets pointer before each test
  });

  it("should initialize with 100 access logs", async () => {
    const logs = await contract.getAccessLogs();
    expect(logs.length).to.equal(100);
  });

  it("should return 3 new logs on each sync", async () => {
    const firstBatch = await contract.previewNextAccessLogs();
    await contract.getNextAccessLogs();
    //console.log("2First batch:", firstBatch[0].doctor);
    //console.log("2First batch:", firstBatch.length)
    expect(firstBatch.length).to.equal(3);

    const secondBatch = await contract.previewNextAccessLogs();
    await contract.getNextAccessLogs();
    //console.log("2Second batch:", secondBatch[0].doctor);
    //console.log("2Second batch:", secondBatch.length);
    expect(secondBatch.length).to.equal(3);

    // Check that logs are not repeating
    expect(firstBatch[0].doctor).to.not.equal(secondBatch[0].doctor);
  });

  it("should move syncPointer forward with each call", async () => {
    await contract.getNextAccessLogs();
    expect(await contract.syncPointer()).to.equal(3);

    await contract.getNextAccessLogs();
    expect(await contract.syncPointer()).to.equal(6);
  });

  it("should return fewer than 3 logs when near the end", async () => {
    // Move pointer close to end
    for (let i = 0; i < 33; i++) {
      await contract.getNextAccessLogs(); // 33 * 3 = 99 logs
    }

    const finalBatch = await contract.previewNextAccessLogs(); // Should only get 1 log left
    await contract.getNextAccessLogs();
    //console.log("4syncPointer:", await contract.syncPointer());
    expect(finalBatch.length).to.equal(1);

    // After all logs are consumed, should return 0
    const emptyBatch = await contract.previewNextAccessLogs();
    expect(emptyBatch.length).to.equal(0);
  });

  it("should allow manual access logging", async () => {
    const addr1 = ethers.Wallet.createRandom().address;
    const addr2 = ethers.Wallet.createRandom().address;

    await contract.logAccess(addr1, addr2, "Blood Test");
    const logs = await contract.getAccessLogs();
    expect(logs.length).to.equal(101);
    expect(logs[100].recordType).to.equal("Blood Test");
  });
});
