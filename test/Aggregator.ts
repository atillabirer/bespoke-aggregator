import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers'


import { ethers } from "hardhat";
import { expect } from "chai";
import { Permit2, SampleERC20 } from "../typechain-types";
import {
  // permit2 contract address
  PERMIT2_ADDRESS,
  // the type of permit that we need to sign
  PermitTransferFrom,
  // Witness type
  Witness,
  // this will help us get domain, types and values that we need to create a signature
  SignatureTransfer,
  MaxUint160,
  MaxUint256
} from "@uniswap/permit2-sdk";


enum AMM {
  V2, V3, STABLE
};


enum InstructionType {

  EXACT_IN, //ignored for stable, you cant demand exact input
  EXACT_OUT, //ignored for stable, you cant demand exact output
  PERMIT2_TRANSFER, //giving tokens for aggregator to trade with
  PERMIT2_BATCH, //for transferring multiple input tokens at once
  PAY_FEE, // pay us a part of the output in order to pay for gas + gasless service fee
  WRAP_ETH, //turn users GLMR to WGLMR
  UNWRAP_ETH //reverse

}


describe("Aggregator", function () {



  describe("Commands", function () {

    let one: SignerWithAddress
    let two: SignerWithAddress
    let three: SignerWithAddress
    let Permit2: Permit2;
    let SampleToken: SampleERC20;



    this.beforeEach(async () => {
      [one, two, three] = await ethers.getSigners();
      const permit2 = await ethers.getContractFactory(`Permit2`);
      Permit2 = await permit2.deploy();
      //deploy a sample token as signer[0]
      const sampleToken = await ethers.getContractFactory("SampleERC20");
      SampleToken = await sampleToken.deploy(ethers.utils.parseEther("10000"));
      //approving token that doesnt naturally support erc20 permit() to be spent by permit2
      await SampleToken.approve(Permit2.address, ethers.constants.MaxUint256);


    })

    it("fails on wrong amount of inputs", async function () {


      const aggregator = await ethers.getContractFactory('Aggregator');
      const Aggregator = await aggregator.deploy(one.address, two.address, Permit2.address);

      const abi = ethers.utils.defaultAbiCoder;


      const fail = Aggregator.execute([
        {
          amm_type: AMM.V2,
          instruction: InstructionType.EXACT_IN,
          isInAggregator: true
        },
        {
          amm_type: AMM.V3,
          instruction: InstructionType.EXACT_OUT,
          isInAggregator: true
        }
        , {
          amm_type: AMM.STABLE,
          instruction: InstructionType.PERMIT2_TRANSFER,
          isInAggregator: true
        }
      ], [ethers.utils.hexlify(1)]);
      await expect(fail).to.be.revertedWith("Amount of commands must match inputs.");
      const success = Aggregator.execute([
        {
          amm_type: AMM.V2,
          instruction: InstructionType.EXACT_IN,
          isInAggregator: true
        }

      ], [abi.encode(
        ["address", "uint256", "uint256", "bool"],
        [one.address, 1, 2, true]
      )]);
      await expect(success).to.not.be.reverted;





    });

    it("succeeds with right inputs", async function () {



      const aggregator = await ethers.getContractFactory('Aggregator');
      const Aggregator = await aggregator.deploy(one.address, two.address, Permit2.address);

      const abi = ethers.utils.defaultAbiCoder;


      const success = Aggregator.execute([
        {
          amm_type: AMM.V2,
          instruction: InstructionType.EXACT_IN,
          isInAggregator: true
        }

      ], [abi.encode(
        ["address", "uint256", "uint256", "bool"],
        [one.address, 1, 2, true]
      )]);
      await expect(success).to.not.be.reverted;





    });

    it("transfers tokens with permit2 witness", async function () {
      const abi = ethers.utils.defaultAbiCoder;


      const aggregator = await ethers.getContractFactory('Aggregator');
      const Aggregator = await aggregator.connect(one).deploy(one.address, two.address, Permit2.address);
      await Aggregator.deployed();
      //get chainId
      const permit: PermitTransferFrom = {
        permitted: {
          // token we are permitting to be transferred
          token: SampleToken.address,
          // amount we are permitting to be transferred
          amount: ethers.utils.parseEther("100") //large approval
        },
        // who can transfer the tokens
        spender: Aggregator.address,
        nonce: (await Permit2.allowance(one.address, SampleToken.address, Aggregator.address)).nonce,
        // signature deadline
        deadline: ethers.constants.MaxUint256
      };



      const witness: Witness = {
        // type name that matches the struct that we created in contract
        witnessTypeName: 'Witness',
        // type structure that matches the struct
        witnessType: { Witness: [{ name: 'user', type: 'address' }] },
        // the value of the witness.
        // USER_ADDRESS is the address that we want to give the tokens to
        witness: { user: Aggregator.address },
      }

      const { domain, types, values } = SignatureTransfer.getPermitData(permit, Permit2.address, await one.getChainId(), witness);
      let signature = await one._signTypedData(domain, types, values);

      await Aggregator.execute([{
        instruction: InstructionType.PERMIT2_TRANSFER,
        amm_type: AMM.V3,
        isInAggregator: false
      }], [
        abi.encode(
          ["address", "address", "address", "uint256", "uint256", "bytes"],
          [
            one.address,
            Aggregator.address,
            SampleToken.address,
            permit.nonce,
            permit.deadline,
            signature
          ]
        )
      ])





    })

  });

});
