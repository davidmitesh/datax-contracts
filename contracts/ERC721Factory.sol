pragma solidity >=0.6.0;
pragma experimental ABIEncoderV2;
// Copyright BigchainDB GmbH and Ocean Protocol contributors
// SPDX-License-Identifier: (Apache-2.0 AND CC-BY-4.0)
// Code is Apache-2.0 and docs are CC-BY-4.0

import "./utils/Deployer.sol";
import "./interfaces/IERC721Template.sol";
import "./interfaces/IFactory.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IERC20Template.sol";
import "hardhat/console.sol";
/**
 * @title DTFactory contract
 * @author Ocean Protocol Team
 *
 * @dev Implementation of Ocean DataTokens Factory
 *
 *      DTFactory deploys DataToken proxy contracts.
 *      New DataToken proxy contracts are links to the template contract's bytecode.
 *      Proxy contract functionality is based on Ocean Protocol custom implementation of ERC1167 standard.
 */
contract ERC721Factory is Deployer, Ownable {
    address private communityFeeCollector;
    uint256 private currentNFTCount;
    address private erc20Factory;
    uint256 private nftTemplateCount;

    struct Template {
        address templateAddress;
        bool isActive;
    }

    mapping(uint256 => Template) public nftTemplateList;

    mapping(uint256 => Template) public templateList;

    mapping(address => address) public erc721List;

    mapping(address => bool) public erc20List;

    // MAPPING BECAUSE OF MULTIPLE TYPES OF StakingContracts (FRE,DUTCH)
    mapping(address => bool) private ssContracts;

    event NFTCreated(
        address indexed newTokenAddress,
        address indexed templateAddress,
        string indexed tokenName,
        address admin
    );

       uint256 private currentTokenCount = 0;
    uint256 public templateCount;
    address public router;

    event TokenCreated(
        address indexed newTokenAddress,
        address indexed templateAddress,
        string indexed tokenName
    );

    event TokenRegistered(
        address indexed tokenAddress,
        string tokenName,
        string tokenSymbol,
        uint256 tokenCap,
        address indexed registeredBy
    );

    

    /**
     * @dev constructor
     *      Called on contract deployment. Could not be called with zero address parameters.
     * @param _template refers to the address of a deployed DataToken contract.
     * @param _collector refers to the community fee collector address
     * @param _router router contract address
     */
    constructor(
        address _template721,
        address _template,
        address _collector,
        address _router
    ) {
        require(
            _template != address(0) &&
                _collector != address(0) &&
                _template721 != address(0),
            "ERC721DTFactory: Invalid template token/community fee collector address"
        );
        add721TokenTemplate(_template721);
        addTokenTemplate(_template);
        router = _router;
        communityFeeCollector = _collector;
    }


    /**
     * @dev deployERC721Contract
     *      
     * @param name NFT name
     * @param symbol NFT Symbol
     * @param _templateIndex template index we want to use
     */

    function deployERC721Contract(
        string memory name,
        string memory symbol,
        uint256 _templateIndex
    ) public returns (address token) {
        require(
            _templateIndex <= nftTemplateCount && _templateIndex != 0,
            "ERC721DTFactory: Template index doesnt exist"
        );
        Template memory tokenTemplate = nftTemplateList[_templateIndex];

        require(
            tokenTemplate.isActive == true,
            "ERC721DTFactory: ERC721Token Template disabled"
        );

        token = deploy(tokenTemplate.templateAddress);

        require(
            token != address(0),
            "ERC721DTFactory: Failed to perform minimal deploy of a new token"
        );
       
        erc721List[token] = token;

        IERC721Template tokenInstance = IERC721Template(token);
        require(
            tokenInstance.initialize(
                msg.sender,
                name,
                symbol,
                address(this)
            ),
            "ERC721DTFactory: Unable to initialize token instance"
        );

        emit NFTCreated(token, tokenTemplate.templateAddress, name, msg.sender);
        // emit TokenRegistered(
        //     token,
        //     name,
        //     symbol,
        //
        //     msg.sender,
        // );
        currentNFTCount += 1;
    }

    /**
     * @dev get the current token count.
     * @return the current token count
     */
    function getCurrentNFTCount() external view returns (uint256) {
        return currentNFTCount;
    }

    /**
     * @dev get the token template Object
     * @param _index template Index
     * @return the template struct
     */
    function getNFTTemplate(uint256 _index)
        external
        view
        returns (Template memory)
    {
        Template memory template = nftTemplateList[_index];
        return template;
    }

      /**
     * @dev add a new NFT Template.
      Only Factory Owner can call it
     * @param _templateAddress new template address
     * @return the actual template count
     */

    function add721TokenTemplate(address _templateAddress)
        public
        onlyOwner
        returns (uint256)
    {
        require(
            _templateAddress != address(0),
            "ERC721DTFactory: ERC721 template address(0) NOT ALLOWED"
        );
        require(isContract(_templateAddress), "ERC721Factory: NOT CONTRACT");
        nftTemplateCount += 1;
        Template memory template = Template(_templateAddress, true);
        nftTemplateList[nftTemplateCount] = template;
        return nftTemplateCount;
    }
      /**
     * @dev reactivate a disabled NFT Template.
            Only Factory Owner can call it
     * @param _index index we want to reactivate
     */
    
    // function to activate a disabled token.
    function reactivate721TokenTemplate(uint256 _index) external onlyOwner {
        require(
            _index <= nftTemplateCount && _index != 0,
            "ERC721DTFactory: Template index doesnt exist"
        );
        Template storage template = nftTemplateList[_index];
        template.isActive = true;
    }

      /**
     * @dev disable an NFT Template.
      Only Factory Owner can call it
     * @param _index index we want to disable
     */
    function disable721TokenTemplate(uint256 _index) external onlyOwner {
        require(
            _index <= nftTemplateCount && _index != 0,
            "ERC721DTFactory: Template index doesnt exist"
        );
        Template storage template = nftTemplateList[_index];
        template.isActive = false;
    }

    function getCurrentNFTTemplateCount() external view returns (uint256) {
        return nftTemplateCount;
    }

    /**
     * @dev Returns true if `account` is a contract.
     *
     * [IMPORTANT]
     * ====
     * It is unsafe to assume that an address for which this function returns
     * false is an externally-owned account (EOA) and not a contract.
     *
     * Among others, `isContract` will return false for the following
     * types of addresses:
     *
     *  - an externally-owned account
     *  - a contract in construction
     *  - an address where a contract will be created
     *  - an address where a contract lived, but was destroyed
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize, which returns 0 for contracts in
        // construction, since the code is only stored at the end of the
        // constructor execution.

        uint256 size;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }

 

    /**
     * @dev Deploys new DataToken proxy contract.
     *      This function is not called directly from here. It's called from the NFT contract.
            An NFT contract can deploy multiple ERC20 tokens.
     * @param _templateIndex ERC20Template index 
     * @param strings refers to an array of strings
     *                      [0] = name
     *                      [1] = symbol
     * @param addresses refers to an array of addresses
     *                     [0]  = minter account who can mint datatokens (can have multiple minters)
     *                     [1]  = feeManager initial feeManager for this DT
     *                     [2]  = publishing Market Address
     *                     [3]  = publishing Market Fee Token
     * @param uints  refers to an array of uints
     *                     [0] = cap_ the total ERC20 cap
     *                     [1] = publishing Market Fee Amount
     * @param bytess  refers to an array of bytes
     *                     Currently not used, usefull for future templates
     * @return token address of a new proxy DataToken contract
     */
    function createToken(
        uint256 _templateIndex,
        string[] memory strings,
        address[] memory addresses,
        uint256[] memory uints,
        bytes[] calldata bytess
    ) public returns (address token) {
        require(
            erc721List[msg.sender] == msg.sender,
            "ERC721Factory: ONLY ERC721 INSTANCE FROM ERC721FACTORY"
        );

        require(uints[0] != 0, "ERC20Factory: zero cap is not allowed");
        require(
            _templateIndex <= templateCount && _templateIndex != 0,
            "ERC20Factory: Template index doesnt exist"
        );
        Template memory tokenTemplate = templateList[_templateIndex];

        require(
            tokenTemplate.isActive == true,
            "ERC20Factory: ERC721Token Template disabled"
        );

        token = deploy(tokenTemplate.templateAddress);
        
        erc20List[token] = true;

        require(
            token != address(0),
            "ERC721Factory: Failed to perform minimal deploy of a new token"
        );

        IERC20Template tokenInstance = IERC20Template(token);
        address[] memory factoryAddresses = new address[](3);
        factoryAddresses[0] = msg.sender;
        
        factoryAddresses[1] = communityFeeCollector;
        
        factoryAddresses[2] = router;
        
        require(
            tokenInstance.initialize(
                strings,
                addresses,
                factoryAddresses,
                uints,
                bytess
            ),
            "ERC20Factory: Unable to initialize token instance"
        );
        emit TokenCreated(token, tokenTemplate.templateAddress, strings[0]);
        emit TokenRegistered(token, strings[0], strings[1], uints[0], msg.sender);

        currentTokenCount += 1;
    }

    /**
     * @dev get the current ERC20token deployed count.
     * @return the current token count
     */
    function getCurrentTokenCount() external view returns (uint256) {
        return currentTokenCount;
    }

    /**
     * @dev get the current ERC20token template.
      @param _index template Index
     * @return the token Template Object
     */

    function getTokenTemplate(uint256 _index)
        external
        view
        returns (Template memory)
    {
        Template memory template = templateList[_index];
        require(
            _index <= templateCount && _index != 0,
            "ERC20Factory: Template index doesnt exist"
        );
        return template;
    }

    /**
     * @dev add a new ERC20Template.
      Only Factory Owner can call it
     * @param _templateAddress new template address
     * @return the actual template count
     */


    function addTokenTemplate(address _templateAddress)
        public
        onlyOwner
        returns (uint256)
    {
        require(
            _templateAddress != address(0),
            "ERC20Factory: ERC721 template address(0) NOT ALLOWED"
        );
        require(isContract(_templateAddress), "ERC20Factory: NOT CONTRACT");
        templateCount += 1;
        Template memory template = Template(_templateAddress, true);
        templateList[templateCount] = template;
        return templateCount;
    }

     /**
     * @dev disable an ERC20Template.
      Only Factory Owner can call it
     * @param _index index we want to disable
     */

    function disableTokenTemplate(uint256 _index) external onlyOwner {
        Template storage template = templateList[_index];
        template.isActive = false;
    }


     /**
     * @dev reactivate a disabled ERC20Template.
      Only Factory Owner can call it
     * @param _index index we want to reactivate
     */

    // function to activate a disabled token.
    function reactivateTokenTemplate(uint256 _index) external onlyOwner {
        require(
            _index <= templateCount && _index != 0,
            "ERC20DTFactory: Template index doesnt exist"
        );
        Template storage template = templateList[_index];
        template.isActive = true;
    }

    // if templateCount is public we could remove it, or set templateCount to private
    function getCurrentTemplateCount() external view returns (uint256) {
        return templateCount;
    }

    struct tokenOrder {
        address tokenAddress;
        address consumer;
        uint256 amount;
        uint256 serviceId;
        address consumeFeeAddress;
        address consumeFeeToken; // address of the token marketplace wants to add fee on top
        uint256 consumeFeeAmount;
    }

    /**
     * @dev startMultipleTokenOrder
     *      Used as a proxy to order multiple services
     *      Users can have inifinite approvals for fees for factory instead of having one approval/ erc20 contract
     *      Requires previous approval of all :
     *          - consumeFeeTokens
     *          - publishMarketFeeTokens
     *          - erc20 datatokens
     * @param orders an array of struct tokenOrder
     */
    function startMultipleTokenOrder(
        tokenOrder[] memory orders
    ) external {
        uint256 ids = orders.length;
        // TO DO.  We can do better here , by groupping publishMarketFeeTokens and consumeFeeTokens and have a single 
        // transfer for each one, instead of doing it per dt..
        for (uint256 i = 0; i < ids; i++) {
            (address publishMarketFeeAddress, address publishMarketFeeToken, uint256 publishMarketFeeAmount) 
                = IERC20Template(orders[i].tokenAddress).getPublishingMarketFee();
            
            // check if we have publishFees, if so transfer them to us and approve dttemplate to take them
            if (publishMarketFeeAmount > 0 && publishMarketFeeToken!=address(0) 
            && publishMarketFeeAddress!=address(0)) {
                require(IERC20Template(publishMarketFeeToken).transferFrom(
                    msg.sender,
                    address(this),
                    publishMarketFeeAmount
                ),'Failed to transfer publishFee');
                IERC20Template(publishMarketFeeToken).approve(orders[i].tokenAddress, publishMarketFeeAmount);
            }
            // check if we have consumeFees, if so transfer them to us and approve dttemplate to take them
            if (orders[i].consumeFeeAmount > 0 && orders[i].consumeFeeToken!=address(0) 
            && orders[i].consumeFeeAddress!=address(0)) {
                require(IERC20Template(orders[i].consumeFeeToken).transferFrom(
                    msg.sender,
                    address(this),
                    orders[i].consumeFeeAmount
                ),'Failed to transfer consumeFee');
                IERC20Template(orders[i].consumeFeeToken).approve(orders[i].tokenAddress, orders[i].consumeFeeAmount);
            }
            // transfer erc20 datatoken from consumer to us
            require(IERC20Template(orders[i].tokenAddress).transferFrom(
                msg.sender,
                address(this),
                orders[i].amount
            ),'Failed to transfer datatoken');
        
            IERC20Template(orders[i].tokenAddress).startOrder(
                orders[i].consumer,
                orders[i].amount,
                orders[i].serviceId,
                orders[i].consumeFeeAddress,
                orders[i].consumeFeeToken,
                orders[i].consumeFeeAmount
            );
        }
    }
}
