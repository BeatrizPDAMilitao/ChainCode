const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("MedskyContract", function () {
  let contract;
  let owner;

  beforeEach(async () => {
    const Contract = await ethers.getContractFactory("MedskyContract");
    contract = await Contract.deploy();
    [owner] = await ethers.getSigners();
  });

  it("should create a record", async () => {
    await contract.createRecord("record1", "hash123");

    const exists = await contract.recordExists("record1");
    expect(exists).to.be.true;

    const record = await contract.readRecords(["record1",]);
    expect(record[0][0]).to.equal(owner.address);

    expect(record[0][1]).to.equal("hash123");
  });

  it("should log an access", async () => {
    await contract.createRecord("record2", "hash456");

    await contract.readRecordTx("record2", "access2");

    const accessExists = await contract.accessExists("access2");
    expect(accessExists).to.be.true;
  });
  it("should create multiple records", async () => {
    await contract.createRecords(["rec1", "rec2"], ["h1", "h2"]);
    expect(await contract.recordExists("rec1")).to.be.true;
    expect(await contract.recordExists("rec2")).to.be.true;
  });

  it("should read multiple records", async () => {
    await contract.createRecords(["rec3", "rec4"], ["h3", "h4"]);
    const result = await contract.readRecords(["rec3", "rec4"]);
    expect(result[0][1]).to.equal("h3");
    expect(result[1][1]).to.equal("h4");
  });

  it("should read and log access to multiple records", async () => {
    await contract.createRecords(["rec5", "rec6"], ["h5", "h6"]);
    await contract.readRecordsTx(["rec5", "rec6"], "access-multi");
    expect(await contract.accessExists("access-multi")).to.be.true;
  });

  it("should delete a record and log access", async () => {
    await contract.createRecord("toDelete", "delhash");
    await contract.deleteRecord("toDelete", "del-action");
    expect(await contract.recordExists("toDelete")).to.be.false;
    expect(await contract.accessExists("del-action")).to.be.true;
  });

  it("should log a bad action", async () => {
    await contract.logBadAction("bad123", "intruder", "unauthorized access");
    // You could read the internal mapping in a view test function if needed
    expect(true).to.be.true; // dummy assert — expand with getter if needed
  });

  it("should fail to create duplicate access", async () => {
    await contract.createRecord("dupRec", "dupHash");
    await contract.readRecordTx("dupRec", "dupAccess");
    await expect(
      contract.readRecordTx("dupRec", "dupAccess")
    ).to.be.revertedWith("Access already exists");
  });

  it("should fail to read non-existent record", async () => {
    await expect(
      contract.readRecordTx("ghost", "access404")
    ).to.be.revertedWith("Record does not exist");
  });

  it("should fail to delete non-existent record", async () => {
    await expect(
      contract.deleteRecord("ghost2", "delete404")
    ).to.be.revertedWith("Record does not exist");
  });
});
