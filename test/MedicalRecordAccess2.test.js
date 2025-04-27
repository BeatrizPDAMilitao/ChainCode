const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("MedicalRecordAccess2", function () {
  let contract;
  let doctor, patient, other;

  beforeEach(async () => {
    const Contract = await ethers.getContractFactory("MedicalRecordAccess2");
    contract = await Contract.deploy();
    [doctor, patient, other] = await ethers.getSigners();
  });

  it("should allow a doctor to submit an access request", async () => {
    await contract.connect(doctor).requestAccess(patient.address, "01293", "X-Ray");

    const request = await contract.getAccessRequest(doctor.address, "01293");
    expect(request.doctor).to.equal(doctor.address);
    expect(request.recordType).to.equal("X-Ray");
    expect(request.status).to.equal(0); // enum: Pending
  });

  it("should allow patient to approve a request", async () => {
    await contract.connect(doctor).requestAccess(patient.address, "04567", "MRI");
    await contract.connect(patient).approveAccess(doctor.address, "04567");

    const logs = await contract.getAccessLogs();
    expect(logs[logs.length - 1].recordType).to.equal("MRI");
});

  it("should allow patient to deny a request", async () => {
    await contract.connect(doctor).requestAccess(patient.address, "07891", "Blood Test");
    await contract.connect(patient).denyAccess(doctor.address, "07891");

    const request = await contract.getAccessRequest(doctor.address, "07891");
    expect(request.status).to.equal(2); // Denied
  });

  it("should prevent non-patient from approving/denying", async () => {
    await contract.connect(doctor).requestAccess(patient.address, "06543", "CT Scan");

    await expect(contract.connect(other).approveAccess(doctor.address, "06543")).to.be.revertedWith("Only patient can approve");
    await expect(contract.connect(other).denyAccess(doctor.address, "06543")).to.be.revertedWith("Only patient can deny");
  });

  it("should generate 100 access requests initially", async () => {
    const requests = await contract.getAccessRequests();
    expect(requests.length).to.equal(100);
  });

  it("should preview 3 new requests per sync", async () => {
    const firstBatch = await contract.previewNextAccessRequests();
    await contract.getNextAccessRequests();
    expect(firstBatch.length).to.equal(3);

    const secondBatch = await contract.previewNextAccessRequests();
    await contract.getNextAccessRequests();
    expect(secondBatch.length).to.equal(3);

    // Ensure they're different
    expect(firstBatch[0].doctor).to.not.equal(secondBatch[0].doctor);
  });

  it("should move the sync pointer forward after each sync", async () => {
    await contract.getNextAccessRequests();
    expect(await contract.syncPointer()).to.equal(3);

    await contract.getNextAccessRequests();
    expect(await contract.syncPointer()).to.equal(6);
  });

  it("should return fewer than 3 requests when nearing the end", async () => {
    for (let i = 0; i < 33; i++) {
      await contract.getNextAccessRequests(); // 99 processed
    }

    const finalBatch = await contract.previewNextAccessRequests();
    await contract.getNextAccessRequests();
    expect(finalBatch.length).to.equal(1);

    const emptyBatch = await contract.previewNextAccessRequests();
    expect(emptyBatch.length).to.equal(0);
  });

  it("should keep synced requests in accessRequests array", async () => {
    const preview = await contract.previewNextAccessRequests();
    await contract.getNextAccessRequests();

    const allRequests = await contract.getAccessRequests();
    expect(allRequests.length).to.equal(100);
    expect(allRequests[0].recordType).to.equal(preview[0].recordType);
  });
});
