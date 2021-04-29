// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.6.0;

import "./BeaconOracle.sol";
import "../oracle/interfaces/RegistryInterface.sol";

/**
 * @title Simple implementation of the OracleInterface that is intended to be deployed on non-Mainnet networks and used
 * to communicate price request data cross-chain with a Source Oracle on Mainnet. An Admin can request prices from
 * this oracle, which might ultimately request a price from a Mainnet Source Oracle and eventually the DVM.
 * @dev Admins capable of making price requests to this contract should be OptimisticOracle contracts. This enables
 * optimistic price resolution on non-Mainnet networks while also providing ultimate security by the DVM on Mainnet.
 */
contract SinkOracle is BeaconOracle {
    constructor(address _finderAddress) public BeaconOracle(_finderAddress) {}

    modifier onlyRegisteredContract() {
        RegistryInterface registry = RegistryInterface(finder.getImplementationAddress(OracleInterfaces.Registry));
        require(registry.isContractRegistered(msg.sender), "Caller must be registered");
        _;
    }

    // This function will be called by the GenericHandler upon a deposit to ensure that the deposit is arising from a
    // real price request. This method will revert unless the price request has been requested by a registered contract.
    function validateDeposit(
        bytes32 identifier,
        uint256 time,
        bytes memory ancillaryData
    ) public view {
        bytes32 priceRequestId = _encodePriceRequest(identifier, time, ancillaryData);
        Price storage lookup = prices[priceRequestId];
        require(lookup.state == RequestState.Requested, "Price has not been requested");
    }

    // Should be callable only by registered contract.
    function requestPrice(
        bytes32 identifier,
        uint256 time,
        bytes memory ancillaryData
    ) public override onlyRegisteredContract() {
        _requestPrice(identifier, time, ancillaryData);

        // TODO: Call Bridge.deposit() to intiate cross-chain price request.
        // _getBridge().deposit(formattedMetadata);
    }

    // Should be callable only by the GenericHandler contract.
    function publishPrice(
        bytes32 identifier,
        uint256 time,
        bytes memory ancillaryData,
        int256 price
    ) public onlyGenericHandlerContract() {
        _publishPrice(identifier, time, ancillaryData, price);
    }
}
