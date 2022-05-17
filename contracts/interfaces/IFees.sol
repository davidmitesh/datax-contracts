// SPDX-License-Identifier: BSU-1.1
pragma solidity >=0.8.0 <0.9.0;
interface IFees {
   

    function calcDataXFees(uint256 baseTokenAmount, string calldata feeType)
        external
        view
        returns (uint256);

    function calcRefFees(uint256 baseTokenAmount, uint256 refFees)
        external
        pure
        returns (uint256);
}
