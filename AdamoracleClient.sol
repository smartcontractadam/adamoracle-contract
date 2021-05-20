// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "./Adamoracle.sol";
import "./interfaces/ENSInterface.sol";
import "./interfaces/AdamTokenInterface.sol";
import "./interfaces/AdamoracleRequestInterface.sol";
import "./interfaces/PointerInterface.sol";
import { ENSResolver as ENSResolver_Adamoracle} from "./vendor/ENSResolver.sol";

/**
 * @title The AdamoracleClient contract
 * @notice Contract writers can inherit this contract in order to create requests for the
 * Adamoracle network
 */
contract AdamoracleClient {
  using Adamoracle for Adamoracle.Request;

  uint256 constant internal ADAM = 10**8;
  uint256 constant private AMOUNT_OVERRIDE = 0;
  address constant private SENDER_OVERRIDE = address(0);
  uint256 constant private ARGS_VERSION = 1;
  bytes32 constant private ENS_TOKEN_SUBNAME = keccak256("adam");
  bytes32 constant private ENS_ORACLE_SUBNAME = keccak256("oracle");
  address constant private ADAM_TOKEN_POINTER = 0x3664cBA2553a48f09B3bf58B6d4A42d18F11Ee07;

   
  ENSInterface private ens;
  bytes32 private ensNode;
  AdamTokenInterface private adam;
  AdamoracleRequestInterface private oracle;
  uint256 private requestCount = 1;
  mapping(bytes32 => address) private pendingRequests;

  event AdamoracleRequested(bytes32 indexed id);
  event AdamoracleFulfilled(bytes32 indexed id);
  event AdamoracleCancelled(bytes32 indexed id);

  /**
   * @notice Creates a request that can hold additional parameters
   * @param _specId The Job Specification ID that the request will be created for
   * @param _callbackAddress The callback address that the response will be sent to
   * @param _callbackFunctionSignature The callback function signature to use for the callback address
   * @return A Adamoracle Request struct in memory
   */
  function buildAdamoracleRequest(
    bytes32 _specId,
    address _callbackAddress,
    bytes4 _callbackFunctionSignature
  ) internal pure returns (Adamoracle.Request memory) {
    Adamoracle.Request memory req;
    return req.initialize(_specId, _callbackAddress, _callbackFunctionSignature);
  }

  /**
   * @notice Creates a Adamoracle request to the stored oracle address
   * @dev Calls `AdamoracleRequestTo` with the stored oracle address
   * @param _req The initialized Adamoracle Request
   * @param _payment The amount of ADAM to send for the request
   * @return requestId The request ID
   */
  function sendAdamoracleRequest(Adamoracle.Request memory _req, uint256 _payment)
    internal
    returns (bytes32)
  {  //
    return sendAdamoracleRequestTo(address(oracle), _req, _payment);
  }

  /**
   * @notice Creates a Adamoracle request to the specified oracle address
   * @dev Generates and stores a request ID, increments the local nonce, and uses `transferAndCall` to
   * send ADAM which creates a request on the target oracle contract.
   * Emits AdamoracleRequested event.
   * @param _oracle The address of the oracle for the request
   * @param _req The initialized Adamoracle Request
   * @param _payment The amount of ADAM to send for the request
   * @return requestId The request ID
   */
  function sendAdamoracleRequestTo(address _oracle, Adamoracle.Request memory _req, uint256 _payment)
    internal
    returns (bytes32 requestId)
  {
    requestId = keccak256(abi.encodePacked(this, requestCount));
    _req.nonce = requestCount;
    pendingRequests[requestId] = _oracle;
    emit AdamoracleRequested(requestId);
    require(adam.transferAndCall(_oracle, _payment, encodeRequest(_req)), "unable to transferAndCall to oracle");

    requestCount += 1;

    return requestId;
  }

  /**
   * @notice Allows a request to be cancelled if it has not been fulfilled
   * @dev Requires keeping track of the expiration value emitted from the oracle contract.
   * Deletes the request from the `pendingRequests` mapping.
   * Emits AdamoracleCancelled event.
   * @param _requestId The request ID
   * @param _payment The amount of ADAM sent for the request
   * @param _callbackFunc The callback function specified for the request
   * @param _expiration The time of the expiration for the request
   */
  function cancelAdamoracleRequest(
    bytes32 _requestId,
    uint256 _payment,
    bytes4 _callbackFunc,
    uint256 _expiration
  )
    internal
  {
    AdamoracleRequestInterface requested = AdamoracleRequestInterface(pendingRequests[_requestId]);
    delete pendingRequests[_requestId];
    emit AdamoracleCancelled(_requestId);
    requested.cancelOracleRequest(_requestId, _payment, _callbackFunc, _expiration);
  }

  /**
   * @notice Sets the stored oracle address
   * @param _oracle The address of the oracle contract
   */
  function setAdamoracleOracle(address _oracle) internal {
    oracle = AdamoracleRequestInterface(_oracle);
  }

  /**
   * @notice Sets the ADAM token address
   * @param _adam The address of the ADAM token contract
   */
  function setAdamoracleToken(address _adam) internal {
    adam = AdamTokenInterface(_adam);
  }

  /**
   * @notice Sets the Adamoracle token address for the public
   * network as given by the Pointer contract
   */
  function setPublicAdamoracleToken() internal {
    // setAdamoracleToken(PointerInterface(ADAM_TOKEN_POINTER).getAddress());
    setAdamoracleToken(ADAM_TOKEN_POINTER);
  }

  /**
   * @notice Retrieves the stored address of the ADAM token
   * @return The address of the ADAM token
   */
  function adamoracleTokenAddress()
    internal
    view
    returns (address)
  {
    return address(adam);
  }

  /**
   * @notice Retrieves the stored address of the oracle contract
   * @return The address of the oracle contract
   */
  function adamoracleOracleAddress()
    internal
    view
    returns (address)
  {
    return address(oracle);
  }

  /**
   * @notice Allows for a request which was created on another contract to be fulfilled
   * on this contract
   * @param _oracle The address of the oracle contract that will fulfill the request
   * @param _requestId The request ID used for the response
   */
  function addAdamoracleExternalRequest(address _oracle, bytes32 _requestId)
    internal
    notPendingRequest(_requestId)
  {
    pendingRequests[_requestId] = _oracle;
  }

  /**
   * @notice Sets the stored oracle and ADAM token contracts with the addresses resolved by ENS
   * @dev Accounts for subnodes having different resolvers
   * @param _ens The address of the ENS contract
   * @param _node The ENS node hash
   */
  function useAdamoracleWithENS(address _ens, bytes32 _node)
    internal
  {
    ens = ENSInterface(_ens);
    ensNode = _node;
    bytes32 adamSubnode = keccak256(abi.encodePacked(ensNode, ENS_TOKEN_SUBNAME));
    ENSResolver_Adamoracle resolver = ENSResolver_Adamoracle(ens.resolver(adamSubnode));
    setAdamoracleToken(resolver.addr(adamSubnode));
    updateAdamoracleOracleWithENS();
  }

  /**
   * @notice Sets the stored oracle contract with the address resolved by ENS
   * @dev This may be called on its own as long as `useAdamoracleWithENS` has been called previously
   */
  function updateAdamoracleOracleWithENS()
    internal
  {
    bytes32 oracleSubnode = keccak256(abi.encodePacked(ensNode, ENS_ORACLE_SUBNAME));
    ENSResolver_Adamoracle resolver = ENSResolver_Adamoracle(ens.resolver(oracleSubnode));
    setAdamoracleOracle(resolver.addr(oracleSubnode));
  }

  /**
   * @notice Encodes the request to be sent to the oracle contract
   * @dev The Adamoracle node expects values to be in order for the request to be picked up. Order of types
   * will be validated in the oracle contract.
   * @param _req The initialized Adamoracle Request
   * @return The bytes payload for the `transferAndCall` method
   */
  function encodeRequest(Adamoracle.Request memory _req)
    private
    view
    returns (bytes memory)
  {
    return abi.encodeWithSelector(
      oracle.oracleRequest.selector,
      SENDER_OVERRIDE, // Sender value - overridden by onTokenTransfer by the requesting contract's address
      AMOUNT_OVERRIDE, // Amount value - overridden by onTokenTransfer by the actual amount of ADAM sent
      _req.id,
      _req.callbackAddress,
      _req.callbackFunctionId,
      _req.nonce,
      ARGS_VERSION,
      _req.buf.buf);
  }

  /**
   * @notice Ensures that the fulfillment is valid for this contract
   * @dev Use if the contract developer prefers methods instead of modifiers for validation
   * @param _requestId The request ID for fulfillment
   */
  function validateAdamoracleCallback(bytes32 _requestId)
    internal
    recordAdamoracleFulfillment(_requestId)
    // solhint-disable-next-line no-empty-blocks
  {}

  /**
   * @dev Reverts if the sender is not the oracle of the request.
   * Emits AdamoracleFulfilled event.
   * @param _requestId The request ID for fulfillment
   */
  modifier recordAdamoracleFulfillment(bytes32 _requestId) {
    require(msg.sender == pendingRequests[_requestId],
            "Source must be the oracle of the request");
    delete pendingRequests[_requestId];
    emit AdamoracleFulfilled(_requestId);
    _;
  }

  /**
   * @dev Reverts if the request is already pending
   * @param _requestId The request ID for fulfillment
   */
  modifier notPendingRequest(bytes32 _requestId) {
    require(pendingRequests[_requestId] == address(0), "Request is already pending");
    _;
  }
}
