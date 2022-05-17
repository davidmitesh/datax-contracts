/* eslint-env mocha */
/* global artifacts, contract, web3, it, beforeEach */
const hre = require("hardhat");
const { assert, expect, should, be } = require("chai");
const {
  expectRevert,
  expectEvent,
  time,
} = require("@openzeppelin/test-helpers");
const { impersonate } = require("../helpers/impersonate");
const { getEventFromTx } = require("../helpers/utils")
const constants = require("../helpers/constants");
const { web3, BN } = require("@openzeppelin/test-helpers/src/setup");
const { keccak256 } = require("@ethersproject/keccak256");
const { MAX_UINT256, ZERO_ADDRESS } = require("@openzeppelin/test-helpers/src/constants");

const ethers = hre.ethers;

// TEST NEW FUNCTIONS, FOR UNIT TEST REFER TO V3 CONTRACTS BRANCH
describe("FixedRateExchange", () => {
  let alice, // DT Owner and exchange Owner
    exchangeOwner,
    bob, // baseToken Holder
    charlie,
    fixedRateExchange,
    rate,
    MockERC20,
    metadata,
    tokenERC721,
    tokenAddress,
    data,
    flags,
    factoryERC721,
    templateERC721,
    templateERC20,
    erc20Token,
    oceanContract,
    oceanOPFBalance,
    daiContract,
    storageContract,
    tradeRouterContract,
    usdcContract,
    sideStaking,
    router,
    signer,
    amountDT,
    marketFee = 1e15, // 0.1%
    oceanFee = 1e15; // 0.1%
  (dtIndex = null),
    (oceanIndex = null),
    (daiIndex = null),
    (cap = web3.utils.toWei("100000"));

  const oceanAddress = "0x967da4048cD07aB37855c090aAF366e4ce1b9F48";
  const daiAddress = "0x6B175474E89094C44Da98b954EedeAC495271d0F";
  const usdcAddress = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48";
  const noLimit = web3.utils.toWei('100000000000000000000');
  
  const noSellLimit = '1';
  before("init contracts for each test", async () => {
    MockERC20 = await ethers.getContractFactory("MockERC20Decimals");
    const FixedRateExchange = await ethers.getContractFactory(
      "FixedRateExchange"
    );

    const ERC721Template = await ethers.getContractFactory("ERC721Template");
    const ERC20Template = await ethers.getContractFactory("ERC20Template");
    const ERC721Factory = await ethers.getContractFactory("ERC721Factory");


    const Router = await ethers.getContractFactory("FactoryRouter");
    const SSContract = await ethers.getContractFactory("SideStaking");

    [
      owner, // nft owner, 721 deployer
      reciever,
      user2, // 721Contract manager
      user3, // alice, exchange owner
      user4,
      user5,
      user6,
      marketFeeCollector,
      newMarketFeeCollector,
      opcCollector,
      consumeMarket
    ] = await ethers.getSigners();

    alice = user3;
    exchangeOwner = user3;
    bob = user4;
    charlie = user5;

    rate = web3.utils.toWei("1");


    // GET SOME OCEAN TOKEN FROM OUR MAINNET FORK and send them to user3
    const userWithOcean = "0x53aB4a93B31F480d17D3440a6329bDa86869458A";
    await impersonate(userWithOcean);

    oceanContract = await ethers.getContractAt(
      "contracts/interfaces/IERC20.sol:IERC20",
      oceanAddress
    );
    signer = ethers.provider.getSigner(userWithOcean);

    await oceanContract
      .connect(signer)
      .transfer(bob.address, ethers.utils.parseEther("1000000"));



    // GET SOME DAI (A NEW TOKEN different from OCEAN)
    const userWithDAI = "0x16de59092dAE5CcF4A1E6439D611fd0653f0Bd01";

    await impersonate(userWithDAI);

    daiContract = await ethers.getContractAt(
      "contracts/interfaces/IERC20.sol:IERC20",
      daiAddress
    );
    signer = ethers.provider.getSigner(userWithDAI);

    await daiContract
      .connect(signer)
      .transfer(bob.address, ethers.utils.parseEther("1000000"));



    // GET SOME USDC (token with !18 decimals (6 in this case))
    const userWithUSDC = "0xF977814e90dA44bFA03b6295A0616a897441aceC";

    await impersonate(userWithUSDC);

    usdcContract = await ethers.getContractAt(
      "contracts/interfaces/IERC20.sol:IERC20",
      usdcAddress
    );

    signer = ethers.provider.getSigner(userWithUSDC);

    const amount = 1e11; // 100000 USDC

    await usdcContract.connect(signer).transfer(bob.address, amount);

    data = web3.utils.asciiToHex("SomeData");
    flags = web3.utils.asciiToHex(constants.blob[0]);

    // DEPLOY ROUTER, SETTING OWNER
    router = await Router.deploy(
      owner.address,
      oceanAddress,
      oceanAddress, // pooltemplate field, unused in this test
      opcCollector.address,
      []
    );

    sideStaking = await SSContract.deploy(router.address);


    fixedRateExchange = await FixedRateExchange.deploy(
      router.address,
      opcCollector.address
    );

    templateERC20 = await ERC20Template.deploy();



    // SETUP ERC721 Factory with template
    templateERC721 = await ERC721Template.deploy();
    factoryERC721 = await ERC721Factory.deploy(
      templateERC721.address,
      templateERC20.address,
      opcCollector.address,
      router.address
    );

    // SET REQUIRED ADDRESS


    await router.addFactory(factoryERC721.address);

    await router.addFixedRateContract(fixedRateExchange.address);

    await router.addSSContract(sideStaking.address)

  });
  it("#1 - owner deploys a new ERC721 Contract", async () => {
    // by default connect() in ethers goes with the first address (owner in this case)
    const tx = await factoryERC721.deployERC721Contract(
      "NFT",
      "NFTSYMBOL",
      1,
      "0x0000000000000000000000000000000000000000",
      "0x0000000000000000000000000000000000000000",
      "https://oceanprotocol.com/nft/",
      true,
      owner.address
    );
    const txReceipt = await tx.wait();

    const event = getEventFromTx(txReceipt, 'NFTCreated')
    assert(event, "Cannot find NFTCreated event")
    tokenAddress = event.args[0];

    tokenERC721 = await ethers.getContractAt("ERC721Template", tokenAddress);

    assert((await tokenERC721.balanceOf(owner.address)) == 1);
  });

  it("#2 - owner adds user2 as manager, which then adds user3 as store updater, metadata updater and erc20 deployer", async () => {
    await tokenERC721.addManager(user2.address);
    await tokenERC721.connect(user2).addTo725StoreList(user3.address);
    await tokenERC721.connect(user2).addToCreateERC20List(user3.address);
    await tokenERC721.connect(user2).addToMetadataList(user3.address);

    assert((await tokenERC721.getPermissions(user3.address)).store == true);
    assert(
      (await tokenERC721.getPermissions(user3.address)).deployERC20 == true
    );
    assert(
      (await tokenERC721.getPermissions(user3.address)).updateMetadata == true
    );
  });

  describe("#1 - Exchange with baseToken(OCEAN) 18 Decimals and datatoken 18 Decimals, RATE = 1", async () => {
    let amountDTtoSell = web3.utils.toWei("10000"); // exact amount so that we can check if balances works
    marketFee = 1e15;
    it("#1 - user3 (alice) create a new erc20DT, assigning herself as minter", async () => {
      const trxERC20 = await tokenERC721.connect(user3).createERC20(1,
        ["ERC20DT1", "ERC20DT1Symbol"],
        [user3.address, user6.address, user3.address, '0x0000000000000000000000000000000000000000'],
        [cap, 0],
        []
      );
      const trxReceiptERC20 = await trxERC20.wait();
      const event = getEventFromTx(trxReceiptERC20, 'TokenCreated')
      assert(event, "Cannot find TokenCreated event")
      erc20Address = event.args[0];


      erc20Token = await ethers.getContractAt("ERC20Template", erc20Address);
      assert((await erc20Token.permissions(user3.address)).minter == true);

      await erc20Token.connect(alice).mint(alice.address, cap);
      expect(await erc20Token.balanceOf(alice.address)).to.equal(cap);

      mockDT18 = erc20Token;
    });

    it("#2 - create exchange", async () => {
      marketFee = 1e15;
      console.log(marketFee)


      receipt = await (
        await mockDT18
          .connect(alice)
          .createFixedRate(
            fixedRateExchange.address,
            [oceanContract.address, alice.address, marketFeeCollector.address, ZERO_ADDRESS],
            [18, 18, rate, marketFee, 0]
            // 18,
            // rate,
            // alice.address,
            // marketFee,
            // marketFeeCollector.address
          )
      ).wait(); // from exchangeOwner (alice)

      eventsExchange = receipt.events.filter((e) => e.event === "NewFixedRate");

      // commented out for now
      // expect(eventsExchange[0].args.baseToken).to.equal(oceanContract.address);
      // expect(eventsExchange[0].args.owner).to.equal(alice.address);
      expect(eventsExchange[0].args.owner).to.equal(web3.utils.toChecksumAddress(alice.address));
      expect(eventsExchange[0].args.baseToken).to.equal(web3.utils.toChecksumAddress(oceanContract.address));

      const fixedrates = await erc20Token.getFixedRates()
      assert(fixedrates[0].contractAddress ===web3.utils.toChecksumAddress(fixedRateExchange.address),
           "Fixed Rate exchange not found in erc20Token.getFixedRates()")
      assert(fixedrates[0].id === eventsExchange[0].args.exchangeId,
           "Fixed Rate exchange not found in erc20Token.getFixedRates()")
    });

    it("#getId - should return templateId", async () => {
      const templateId = 1;
      assert((await fixedRateExchange.getId()) == templateId);
    });
    it("#3 - exchange is active", async () => {
      const isActive = await fixedRateExchange.isActive(
        eventsExchange[0].args.exchangeId
      );
      assert(isActive === true, "Exchange was not activated correctly!");
    });

    it("#4 - should check that the exchange has no supply yet", async () => {
      const exchangeDetails = await fixedRateExchange.getExchange(
        eventsExchange[0].args.exchangeId
      );
      expect(exchangeDetails.dtSupply).to.equal(0);
      expect(exchangeDetails.btSupply).to.equal(0);
    });

    it("#5 - alice and bob approve contracts to spend tokens", async () => {
      // alice approves how many DT tokens wants to sell
      // alice only approves an exact amount so we can check supply etc later in the test
      await mockDT18
        .connect(alice)
        .approve(fixedRateExchange.address, amountDTtoSell);

      // bob approves a big amount so that we don't need to re-approve during test
      await oceanContract
        .connect(bob)
        .approve(fixedRateExchange.address, web3.utils.toWei("1000000"));
    });

    it("#6 - should check that the exchange has supply and fees setup ", async () => {
      // NOW dtSupply has increased (because alice(exchangeOwner) approved DT). Bob approval has no effect on this
      const exchangeDetails = await fixedRateExchange.getExchange(
        eventsExchange[0].args.exchangeId
      );
      expect(exchangeDetails.dtSupply).to.equal(amountDTtoSell);
      expect(exchangeDetails.btSupply).to.equal(0);
      const feeInfo = await fixedRateExchange.getFeesInfo(
        eventsExchange[0].args.exchangeId
      );
      expect(feeInfo.marketFee).to.equal(marketFee);
      expect(feeInfo.marketFeeCollector).to.equal(marketFeeCollector.address);
      expect(feeInfo.opcFee).gt(0);
      expect(feeInfo.marketFeeAvailable).gte(0);
      expect(feeInfo.oceanFeeAvailable).gte(0);
    });

    it("#7 - should get the exchange rate", async () => {
      assert(
        web3.utils.toWei(
          web3.utils.fromWei(
            (
              await fixedRateExchange.getRate(eventsExchange[0].args.exchangeId)
            ).toString()
          )
        ) === rate
      );
    });
    it("#8 - Bob should fail to buy if price is too high", async () => {
      // this will fails because we are willing to spend only 1 wei of base tokens
      await expectRevert(fixedRateExchange.connect(bob)
      .buyDT(eventsExchange[0].args.exchangeId, amountDTtoSell, '1',ZERO_ADDRESS, 0)
      ,"FixedRateExchange: Too many base tokens" )
    });
    it("#9 - Bob should fail to sell if price is too low", async () => {
      // this will fails because we want to receive a high no of base tokens
      await expectRevert(fixedRateExchange.connect(bob)
      .sellDT(eventsExchange[0].args.exchangeId, amountDTtoSell, noLimit,ZERO_ADDRESS, 0)
      ,"FixedRateExchange: Too few base tokens" )
    });
      
    it("#10 - Bob should buy ALL Dataokens available(amount exchangeOwner approved) using the fixed rate exchange contract", async () => {
      const dtBobBalanceBeforeSwap = await mockDT18.balanceOf(bob.address);
      const btAliceBeforeSwap = await oceanContract.balanceOf(alice.address);
      expect(dtBobBalanceBeforeSwap).to.equal(0); // BOB HAS NO DT
      expect(btAliceBeforeSwap).to.equal(0); // Alice(owner) has no BT

      // BOB is going to buy all DT availables
      amountDT = amountDTtoSell;
      const receipt = await (
        await fixedRateExchange
          .connect(bob)
          .buyDT(eventsExchange[0].args.exchangeId, amountDT, noLimit,ZERO_ADDRESS, 0)
      ).wait();

      const SwappedEvent = receipt.events.filter((e) => e.event === "Swapped");

      const args = SwappedEvent[0].args;

      // we check that proper amount is being swapped (rate=1)
      expect(
        args.baseTokenSwappedAmount
          .sub(args.oceanFeeAmount)
          .sub(args.marketFeeAmount)
      ).to.equal(args.datatokenSwappedAmount);

      // BOB's DTbalance has increased
      const dtBobBalanceAfterSwap = await mockDT18.balanceOf(bob.address);
      expect(dtBobBalanceAfterSwap).to.equal(
        SwappedEvent[0].args.datatokenSwappedAmount.add(dtBobBalanceBeforeSwap)
      );

      // ALICE's BT balance hasn't increasead.
      expect(await oceanContract.balanceOf(alice.address)).to.equal(
        btAliceBeforeSwap
      );

      // BT are into the FixedRate contract.
      const exchangeDetails = await fixedRateExchange.getExchange(
        eventsExchange[0].args.exchangeId
      );

      expect(exchangeDetails.btSupply).to.equal(
        args.baseTokenSwappedAmount.sub(
          args.oceanFeeAmount.add(args.marketFeeAmount)
        )
      );

      // Bob bought all DT on sale so now dtSupply is ZERO
      expect(exchangeDetails.dtSupply).to.equal(0);

      // we also check DT and BT balances were accounted properly
      expect(exchangeDetails.btBalance).to.equal(
        args.baseTokenSwappedAmount.sub(
          args.oceanFeeAmount.add(args.marketFeeAmount)
        )
      );
      expect(exchangeDetails.dtBalance).to.equal(0);
    });

});


  
});