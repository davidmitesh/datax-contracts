pragma solidity  >=0.8.0 <0.9.0;
// SPDX-License-Identifier: BSU-1.1

/** @notice : interface to stake any erc20 token in datapools
 */
interface IStakeRouter  {

/********* ETH ************/

 struct TradeInfo {
        address[5] meta; //[source, dtAddress, to, refAddress, adapterAddress]
        uint256[3] uints; //[dtAmountOut/minDTAmountOut/tokenAmountOut/minTokenAmountOut, refFees, dtAmountIn/maxDTAmountIn/tokenAmountIn/maxTokenAmountIn]
        address[] path;
        bool isFRE;
        bytes32 exchangeId;
    }

    /** @dev stakes ETH (native token) into datapool
     */
    function stakeETHInPool(TradeInfo calldata info) external payable  returns (uint256 poolAmountOut);

    /** @dev unstakes staked pool tokens into ETH from datapool
     */
    function unstakeToETHFromPool(TradeInfo calldata info) external returns (uint256 amountOut);

    /********* ERC20 ************/

   /** @dev stakes given Erc20 token into datapool
     */
    function stakeTokenInPool(TradeInfo calldata info) external payable  returns (uint256 poolAmountOut);

    /** @dev unstakes staked pool tokens into given Erc20 from datapool
     */
    function unstakeToTokenFromPool(TradeInfo calldata info) external returns (uint256 amountOut);


    /********* DT ************/ 

    /** @dev stakes given DT into given datapool
     */
    function stakeDTInPool(TradeInfo calldata info) external payable  returns (uint256 poolAmountOut);

    /** @dev unstakes staked pool tokens into given DT from given datapool
     */
    function unstakeDTFromPool(TradeInfo calldata info) external returns (uint256 amountOut);



}
