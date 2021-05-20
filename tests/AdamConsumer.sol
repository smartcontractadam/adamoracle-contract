// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "../AdamoracleClient.sol";

contract AdmaConsumer is AdamoracleClient {
  bytes32 private specId;
  bytes32 public currentPrice;

  AdamTokenInterface private adam;

  uint256 public volume;

  event RequestFulfilled(
    bytes32 indexed requestId, // User-defined ID
    uint256 indexed price
  );

  constructor() public {
    setAdamoracleOracle(0x3080FD5de9af4665C6175aa5C29eb4CD72c14f3f);
    setPublicAdamoracleToken();
    // specId = _specId;
    specId = "190a9b1d5cc6405cafe063442fc78e37";
}


  function requestEthereumPrice(uint256 _payment)
  public
  returns (bytes32 _requestId)
  {
    Adamoracle.Request memory request = buildAdamoracleRequest(specId, address(this), this.fulfill.selector);
    request.add("get", "https://min-api.cryptocompare.com/data/price?fsym=ETH&tsyms=USD");
    request.add("path", "USD");

    // request.add("get", "https://min-api.cryptocompare.com/data/pricemultifull?fsyms=ETH&tsyms=USD");
    // request.add("path", "RAW.ETH.USD.VOLUME24HOUR");

    // request.add("get","https://www.okex.com/api/v5/market/ticker?instId=ETH-USD-SWAP");
    // request.add("path","data[0].last");

    int _times = 10 ** 18;
    request.addInt("times", _times);
    return sendAdamoracleRequest(request, _payment);
}

  /**
  * Receive the response in the form of uint256
  */
  function fulfill(bytes32 _requestId, uint256 _volume) public recordAdamoracleFulfillment(_requestId)
  {
    emit RequestFulfilled(_requestId, _volume);
    volume = _volume;
  }

  /**
  * Withdraw ADAM from this contract
  *
  * NOTE: DO NOT USE THIS IN PRODUCTION AS IT CAN BE CALLED BY ANY ADDRESS.
  * THIS IS PURELY FOR EXAMPLE PURPOSES ONLY.
  */
  function withdrawAdam() external {
    AdamTokenInterface AdamToken = AdamTokenInterface(adamoracleTokenAddress());
    require(AdamToken.transfer(msg.sender, AdamToken.balanceOf(address(this))), "Unable to transfer");
  }
}
