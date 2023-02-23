//SPDX: none
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "hardhat/console.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import {ISignatureTransfer} from "../permit2/src/interfaces/ISignatureTransfer.sol";
import {IAllowanceTransfer} from "../permit2/src/interfaces/IAllowanceTransfer.sol";

import {SignatureVerification} from "../permit2/src/libraries/SignatureVerification.sol";
import {PermitHash} from "../permit2/src/libraries/PermitHash.sol";

import {IUniswapV2Router02} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

import {Multicall2} from "./Multicall2.sol";

enum AMM {
    V2,
    V3,
    STABLE
}

//will the tokens stay in the router for the next command to use or go to user?
enum Destination {
    ROUTER,
    MSG_SENDER
}

//v2 v3 stable etc all use the same commands for simplifying the API
enum InstructionType {
    EXACT_IN,
    EXACT_OUT,
    PERMIT2_TRANSFER, //giving tokens for aggregator to trade with
    PERMIT2_BATCH, //for transferring multiple input tokens at once, to be implemented later
    PAY_FEE, // pay us a part of the output in order to pay for gas + gasless service fee
    WRAP_ETH, //turn users GLMR to WGLMR
    UNWRAP_ETH, //reverse
    SWEEP //say user had negative slippage, send the remaining funds back
}

struct SwapArguments {
    uint256 inputAmount;
    uint256 outputAmount;
    uint256 desiredInput;
    uint256 desiredOutput;
}

struct Command {
    AMM amm_type;
    InstructionType instruction;
    bool isInAggregator; //are the tokens in aggregator or do they need to be transferred via permit2?
}

struct Witness {
    // Address of the user that signer is giving the tokens to
    address user;
}

contract Aggregator {
    //Aggregator is a contract that takes commands, data, and a signature from the user
    //to transfer their tokens to operate on them. It then creates a multicall-friendly
    //batch transaction array and sends to multicall to execute. returns result to user.
    ISignatureTransfer permit2;
    ISwapRouter V3Router;
    Multicall2 multicall;
    IUniswapV2Router02 v2router;

    string constant WITNESS_TYPE_STRING =
        "Witness witness)TokenPermissions(address token,uint256 amount)Witness(address user)";

    bytes32 private constant WITNESS_TYPEHASH =
        keccak256("Witness(address user)");

    constructor(
        ISwapRouter _v3router,
        IUniswapV2Router02 _v2router,
        ISignatureTransfer _permit2
    ) {
        //creating a permit2 just for testing purposes

        permit2 = _permit2;

        V3Router = _v3router;
        multicall = new Multicall2();
        v2router = _v2router;
    }

    function execute(
        Command[] calldata commands,
        bytes[] calldata inputs // with abi.encode it gives InvalidSignatureLength(), so we pass here
    ) public {
        require(commands.length < 10, "Too many commands for executor.");
        require(
            commands.length == inputs.length,
            "Amount of commands must match inputs."
        );

        for (uint i = 0; i < commands.length; ++i) {
            if (commands[i].instruction == InstructionType.EXACT_IN) {
                //check if V2, V3 or stable, call functions accordingly
                console.log("exact_in called");

                (
                    address recipient,
                    uint256 amountIn,
                    uint256 amountOutMin,
                    bool isPayerUser
                ) = abi.decode(inputs[i], (address, uint256, uint256, bool));
                if (commands[i].amm_type == AMM.V3) {
                    //v3 stuff
                }
                if (commands[i].amm_type == AMM.V2) {
                    //v3 stuff
                }
                if (commands[i].amm_type == AMM.STABLE) {
                    //v3 stuff
                }
            }
            if (commands[i].instruction == InstructionType.EXACT_OUT) {
                //check if V2, V3 or stable, call functions accordingly
                (
                    address recipient,
                    uint256 amountOut,
                    uint256 amountInMax,
                    bool payerIsUser
                ) = abi.decode(inputs[i], (address, uint256, uint256, bool));

                console.log("exact_out called");
            }

            if (commands[i].instruction == InstructionType.PERMIT2_TRANSFER) {
                //transfer tokens to Multicall to be executed later
                console.log("permit2_transfer called");
                //use a hashed version of the Witness struct as an extra layer of security
                (
                    uint256 _amount,
                    ,
                    address _user,
                    address _token,
                    uint256 _nonce,
                    uint256 _deadline,
                    bytes memory _signature
                ) = abi.decode(
                        inputs[i],
                        (
                            uint256,
                            address,
                            address,
                            address,
                            uint256,
                            uint256,
                            bytes
                        )
                    );
                address permit2addr = address(permit2);
                ISignatureTransfer.TokenPermissions
                    memory permitted = ISignatureTransfer.TokenPermissions({
                        amount: _amount,
                        token: _token
                    });

                ISignatureTransfer(permit2addr).permitWitnessTransferFrom(
                    ISignatureTransfer.PermitTransferFrom({
                        permitted: permitted,
                        nonce: _nonce,
                        deadline: _deadline
                    }),
                    ISignatureTransfer.SignatureTransferDetails({
                        to: address(this),
                        requestedAmount: _amount
                    }),
                    msg.sender,
                    // witness
                    keccak256(abi.encode(WITNESS_TYPEHASH, Witness(_user))),
                    // witnessTypeString,
                    WITNESS_TYPE_STRING,
                    _signature
                );
            }

            if (commands[i].instruction == InstructionType.PAY_FEE) {
                //take a cut out of the output, liquify a part to GLMR to feed gasless, and a part to us
                //as StellaSwap gasless service fee.
            }

            if (commands[i].instruction == InstructionType.WRAP_ETH) {
                //wgmlr.deposit (with users permit signature)
            }

            if (commands[i].instruction == InstructionType.UNWRAP_ETH) {
                //wglmr.withdraw (with users permit signature)
            }
        }
    }
}
