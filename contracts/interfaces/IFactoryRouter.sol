pragma solidity >=0.5.7;


interface IFactoryRouter {
           function deployPool(
        address controller, 
        address datatokenAddress, 
        address basetokenAddress, 
        address publisherAddress, 
        uint256 burnInEndBlock,
        uint256[] calldata ssParams,
        address basetokenSender
    ) external returns (address);
}