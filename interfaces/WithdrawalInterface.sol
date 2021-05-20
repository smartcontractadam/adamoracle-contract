// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

interface WithdrawalInterface {
  /**
   * @notice transfer ADAM held by the contract belonging to msg.sender to
   * another address
   * @param recipient is the address to send the ADAM to
   * @param amount is the amount of ADAM to send
   */
  function withdraw(address recipient, uint256 amount) external;

  /**
   * @notice query the available amount of ADAM to withdraw by msg.sender
   */
  function withdrawable() external view returns (uint256);
}
