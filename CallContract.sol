// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { AxelarExecutable } from '@axelar-network/axelar-gmp-sdk-solidity/contracts/executable/AxelarExecutable.sol';
import { IAxelarGasService } from '@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IAxelarGasService.sol';
import { IERC20 } from '@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IERC20.sol';

/**
 * @title CallContract
 * @notice Send a message from chain A to chain B and store it on the destination.
 */
contract CallContract is AxelarExecutable {
    string public message;
    string public sourceChain;
    string public sourceAddress;
    IAxelarGasService public immutable gasService;

    event Executed(bytes32 commandId, string from, string message);

    /**
     * @param _gateway      Address of Axelar Gateway on this chain.
     * @param _gasReceiver  Address of Axelar Gas Service on this chain.
     */
    constructor(address _gateway, address _gasReceiver) AxelarExecutable(_gateway) {
        gasService = IAxelarGasService(_gasReceiver);
    }

    /**
     * @notice Send message from chain A to chain B using native gas payment.
     *
     * @param destinationChain     Name of the destination chain (ex. "Moonbeam").
     * @param destinationAddress   Contract address on the destination chain.
     * @param _message             Any string payload you want to send.
     */
    function setRemoteValue(
        string calldata destinationChain,
        string calldata destinationAddress,
        string calldata _message
    ) external payable {
        require(msg.value > 0, 'Gas payment is required');

        bytes memory payload = abi.encode(_message);

        // Pay with native gas
        gasService.payNativeGasForContractCall{ value: msg.value }(
            address(this),
            destinationChain,
            destinationAddress,
            payload,
            msg.sender
        );

        // Execute the cross-chain call
        gateway().callContract(destinationChain, destinationAddress, payload);
    }

    /**
     * @notice Send message from chain A to chain B, paying gas in an ERC20 token (e.g. aUSDC).
     *
     * @dev You must first have transferred `gasFeeAmount` of token into this contract,
     *      or call this function after the user has given allowance so we can pull
     *      tokens in from their address. See below for the transfer/approve logic.
     *
     * @param destinationChain     Name of the destination chain (ex. "Base-Sepolia").
     * @param destinationAddress   Contract address on the destination chain.
     * @param _message             String payload to send.
     * @param gasToken             The ERC20 token address you will use to pay for gas (e.g. aUSDC).
     * @param gasFeeAmount         How many tokens to pay as the Axelar gas fee.
     * @param gasTokenSymbol       The symbol of that token recognized by Axelar (e.g. "aUSDC").
     */
    function setRemoteValuePayToken(
        string calldata destinationChain,
        string calldata destinationAddress,
        string calldata _message,
        address gasToken,
        uint256 gasFeeAmount,
        string calldata gasTokenSymbol
    ) external {
        bytes memory payload = abi.encode(_message);

        // 1. Pull the ERC20 from the msg.sender into this contract.
        //    Alternatively, the user might have already transferred tokens here
        //    or you can do transferFrom(...) if the user provided allowance.
        IERC20(gasToken).transferFrom(msg.sender, address(this), gasFeeAmount);

        // 2. Approve AxelarGasService to spend those tokens from this contract.
        IERC20(gasToken).approve(address(gasService), gasFeeAmount);

        // 3. Pay for the contract call in the specified ERC20.
        //    We are NOT sending tokens to the destination. We’re just paying the fee.
        gasService.payGasForContractCallWithToken(
            address(this),
            destinationChain,
            destinationAddress,
            payload,
            gasTokenSymbol,
            0,              // `amount` = 0 if you aren't actually delivering tokens to the destination.
            gasToken,
            gasFeeAmount,
            msg.sender
        );

        // 4. Make the cross-chain call carrying your payload
        //    Since we are NOT sending tokens, call `callContract()`.
        gateway().callContract(destinationChain, destinationAddress, payload);
    }

    /**
     * @notice Logic to be executed on the destination chain.
     * @dev This is triggered automatically by Axelar’s relayer.
     * @param commandId        Unique ID for Axelar cross-chain command.
     * @param _sourceChain     Blockchain where the call originates.
     * @param _sourceAddress   Address on the source chain that made the call.
     * @param _payload         Encoded GMP message payload sent from source chain.
     */
    function _execute(
        bytes32 commandId,
        string calldata _sourceChain,
        string calldata _sourceAddress,
        bytes calldata _payload
    ) internal override {
        message = abi.decode(_payload, (string));
        sourceChain = _sourceChain;
        sourceAddress = _sourceAddress;

        emit Executed(commandId, _sourceAddress, message);
    }
}
