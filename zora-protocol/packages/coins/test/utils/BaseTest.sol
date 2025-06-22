// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {ERC1967Utils} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IZoraFactory} from "../../src/interfaces/IZoraFactory.sol";
import {ZoraFactoryImpl} from "../../src/ZoraFactoryImpl.sol";
import {ZoraFactory} from "../../src/proxy/ZoraFactory.sol";
import {Coin} from "../../src/Coin.sol";
import {CoinV4} from "../../src/CoinV4.sol";
import {MultiOwnable} from "../../src/utils/MultiOwnable.sol";
import {ICoin} from "../../src/interfaces/ICoin.sol";
import {IERC7572} from "../../src/interfaces/IERC7572.sol";
import {IWETH} from "../../src/interfaces/IWETH.sol";
import {IAirlock} from "../../src/interfaces/IAirlock.sol";
import {INonfungiblePositionManager} from "../../src/interfaces/INonfungiblePositionManager.sol";
import {ISwapRouter} from "../../src/interfaces/ISwapRouter.sol";
import {IUniswapV3Factory} from "../../src/interfaces/IUniswapV3Factory.sol";
import {IUniswapV3Pool} from "../../src/interfaces/IUniswapV3Pool.sol";
import {IProtocolRewards} from "../../src/interfaces/IProtocolRewards.sol";
import {ProtocolRewards} from "../utils/ProtocolRewards.sol";
import {MarketConstants} from "../../src/libs/MarketConstants.sol";
import {CoinConfigurationVersions} from "../../src/libs/CoinConfigurationVersions.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {ZoraV4CoinHook} from "../../src/hooks/ZoraV4CoinHook.sol";
import {HooksDeployment} from "../../src/libs/HooksDeployment.sol";
import {CoinConstants} from "../../src/libs/CoinConstants.sol";
import {ProxyShim} from "./ProxyShim.sol";
import {ICoinV4} from "../../src/interfaces/ICoinV4.sol";
import {UniV4SwapHelper} from "../../src/libs/UniV4SwapHelper.sol";
import {IPermit2} from "permit2/src/interfaces/IPermit2.sol";
import {IUniversalRouter} from "@uniswap/universal-router/contracts/interfaces/IUniversalRouter.sol";
import {Commands} from "@uniswap/universal-router/contracts/libraries/Commands.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Actions} from "@uniswap/v4-periphery/src/libraries/Actions.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract BaseTest is Test {
    using stdStorage for StdStorage;

    address internal constant WETH_ADDRESS = 0x4200000000000000000000000000000000000006;
    address internal constant V3_FACTORY = 0x33128a8fC17869897dcE68Ed026d694621f6FDfD;
    address internal constant NONFUNGIBLE_POSITION_MANAGER = 0x03a520b32C04BF3bEEf7BEb72E919cf822Ed34f1;
    address internal constant SWAP_ROUTER = 0x2626664c2603336E57B271c5C0b26F421741e481;
    address internal constant DOPPLER_AIRLOCK = 0x660eAaEdEBc968f8f3694354FA8EC0b4c5Ba8D12;
    address internal constant USDC_ADDRESS = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address internal constant V4_POOL_MANAGER = 0x498581fF718922c3f8e6A244956aF099B2652b2b;
    address internal constant V4_POSITION_MANAGER = 0x7C5f5A4bBd8fD63184577525326123B519429bDc;
    address internal constant V4_PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
    address internal constant V4_QUOTER = 0x0d5e0F971ED27FBfF6c2837bf31316121532048D;
    address internal constant UNIVERSAL_ROUTER = 0x6fF5693b99212Da76ad316178A184AB56D299b43;
    int24 internal constant USDC_TICK_LOWER = 57200;

    struct Users {
        address factoryOwner;
        address feeRecipient;
        address creator;
        address platformReferrer;
        address buyer;
        address seller;
        address coinRecipient;
        address tradeReferrer;
    }

    uint256 internal forkId;
    IERC20Metadata internal usdc;
    IWETH internal weth;
    ProtocolRewards internal protocolRewards;
    IUniswapV3Factory internal v3Factory;
    INonfungiblePositionManager internal nonfungiblePositionManager;
    IPermit2 internal permit2;
    IUniversalRouter internal router;

    ISwapRouter internal swapRouter;
    IAirlock internal airlock;
    Users internal users;

    Coin internal coinV3Impl;
    CoinV4 internal coinV4Impl;
    ZoraFactoryImpl internal factoryImpl;
    IZoraFactory internal factory;
    ZoraV4CoinHook internal zoraV4CoinHook;
    Coin internal coin;

    IUniswapV3Pool internal pool;
    int24 internal constant DEFAULT_DISCOVERY_TICK_LOWER = CoinConstants.DEFAULT_DISCOVERY_TICK_LOWER;
    int24 internal constant DEFAULT_DISCOVERY_TICK_UPPER = CoinConstants.DEFAULT_DISCOVERY_TICK_UPPER;
    uint16 internal constant DEFAULT_NUM_DISCOVERY_POSITIONS = CoinConstants.DEFAULT_NUM_DISCOVERY_POSITIONS;
    uint256 internal constant DEFAULT_DISCOVERY_SUPPLY_SHARE = CoinConstants.DEFAULT_DISCOVERY_SUPPLY_SHARE;

    function _deployCoin() internal {
        bytes memory poolConfig_ = _generatePoolConfig(
            CoinConfigurationVersions.DOPPLER_UNI_V3_POOL_VERSION,
            address(weth),
            DEFAULT_DISCOVERY_TICK_LOWER,
            DEFAULT_DISCOVERY_TICK_UPPER,
            DEFAULT_NUM_DISCOVERY_POSITIONS,
            DEFAULT_DISCOVERY_SUPPLY_SHARE
        );
        vm.prank(users.creator);
        (address coinAddress, ) = factory.deploy(
            users.creator,
            _getDefaultOwners(),
            "https://test.com",
            "Testcoin",
            "TEST",
            poolConfig_,
            users.platformReferrer,
            0
        );

        coin = Coin(payable(coinAddress));
        pool = IUniswapV3Pool(coin.poolAddress());

        vm.label(address(coin), "COIN");
        vm.label(address(pool), "POOL");
    }

    function _deployCoinUSDCPair() internal {
        bytes memory poolConfig_ = _generatePoolConfig(
            CoinConfigurationVersions.DOPPLER_UNI_V3_POOL_VERSION,
            USDC_ADDRESS,
            DEFAULT_DISCOVERY_TICK_LOWER,
            DEFAULT_DISCOVERY_TICK_UPPER,
            DEFAULT_NUM_DISCOVERY_POSITIONS,
            DEFAULT_DISCOVERY_SUPPLY_SHARE
        );
        vm.prank(users.creator);
        (address coinAddress, ) = factory.deploy(
            users.creator,
            _getDefaultOwners(),
            "https://test.com",
            "Testcoin",
            "TEST",
            poolConfig_,
            users.platformReferrer,
            0
        );

        coin = Coin(payable(coinAddress));
        pool = IUniswapV3Pool(coin.poolAddress());

        vm.label(address(coin), "COIN");
        vm.label(address(pool), "POOL");
    }

    function _swapSomeCurrencyForCoin(ICoinV4 _coin, address currency, uint128 amountIn, address trader) internal {
        uint128 minAmountOut = uint128(0);

        (bytes memory commands, bytes[] memory inputs) = UniV4SwapHelper.buildExactInputSingleSwapCommand(
            currency,
            amountIn,
            address(_coin),
            minAmountOut,
            _coin.getPoolKey(),
            bytes("")
        );

        vm.startPrank(trader);
        UniV4SwapHelper.approveTokenWithPermit2(permit2, address(router), currency, amountIn, uint48(block.timestamp + 1 days));

        // Execute the swap
        uint256 deadline = block.timestamp + 20;
        router.execute(commands, inputs, deadline);

        vm.stopPrank();
    }

    function _swapSomeCoinForCurrency(ICoinV4 _coin, address currency, uint128 amountIn, address trader) internal {
        uint128 minAmountOut = uint128(0);

        (bytes memory commands, bytes[] memory inputs) = UniV4SwapHelper.buildExactInputSingleSwapCommand(
            address(_coin),
            amountIn,
            currency,
            minAmountOut,
            _coin.getPoolKey(),
            bytes("")
        );

        vm.startPrank(trader);
        UniV4SwapHelper.approveTokenWithPermit2(permit2, address(router), address(_coin), amountIn, uint48(block.timestamp + 1 days));

        // Execute the swap
        uint256 deadline = block.timestamp + 20;
        router.execute(commands, inputs, deadline);

        vm.stopPrank();
    }

    function setUp() public virtual {
        setUpWithBlockNumber(28415528);
    }

    function setUpWithBlockNumber(uint256 forkBlockNumber) public {
        forkId = vm.createSelectFork("base", forkBlockNumber);

        weth = IWETH(WETH_ADDRESS);
        usdc = IERC20Metadata(USDC_ADDRESS);
        v3Factory = IUniswapV3Factory(V3_FACTORY);
        nonfungiblePositionManager = INonfungiblePositionManager(NONFUNGIBLE_POSITION_MANAGER);
        swapRouter = ISwapRouter(SWAP_ROUTER);
        airlock = IAirlock(DOPPLER_AIRLOCK);
        protocolRewards = new ProtocolRewards();
        permit2 = IPermit2(V4_PERMIT2);
        router = IUniversalRouter(UNIVERSAL_ROUTER);
        users = Users({
            factoryOwner: makeAddr("factoryOwner"),
            feeRecipient: makeAddr("feeRecipient"),
            creator: makeAddr("creator"),
            platformReferrer: makeAddr("platformReferrer"),
            buyer: makeAddr("buyer"),
            seller: makeAddr("seller"),
            coinRecipient: makeAddr("coinRecipient"),
            tradeReferrer: makeAddr("tradeReferrer")
        });

        address[] memory trustedMessageSenders = new address[](2);
        trustedMessageSenders[0] = UNIVERSAL_ROUTER;
        trustedMessageSenders[1] = V4_POSITION_MANAGER;

        ProxyShim mockUpgradeableImpl = new ProxyShim();
        factory = IZoraFactory(address(new ZoraFactory(address(mockUpgradeableImpl))));
        zoraV4CoinHook = ZoraV4CoinHook(address(HooksDeployment.deployZoraV4CoinHookFromContract(V4_POOL_MANAGER, address(factory), trustedMessageSenders)));
        coinV3Impl = new Coin(users.feeRecipient, address(protocolRewards), WETH_ADDRESS, V3_FACTORY, SWAP_ROUTER, DOPPLER_AIRLOCK);
        coinV4Impl = new CoinV4(users.feeRecipient, address(protocolRewards), IPoolManager(V4_POOL_MANAGER), DOPPLER_AIRLOCK, zoraV4CoinHook);
        factoryImpl = new ZoraFactoryImpl(address(coinV3Impl), address(coinV4Impl));
        UUPSUpgradeable(address(factory)).upgradeToAndCall(address(factoryImpl), "");
        factory = IZoraFactory(address(factory));
        // factory = ZoraFactoryImpl(address(new ZoraFactory(address(factoryImpl))));

        ZoraFactoryImpl(address(factory)).initialize(users.factoryOwner);

        vm.label(address(factory), "ZORA_FACTORY");
        vm.label(address(protocolRewards), "PROTOCOL_REWARDS");
        vm.label(address(nonfungiblePositionManager), "NONFUNGIBLE_POSITION_MANAGER");
        vm.label(address(v3Factory), "V3_FACTORY");
        vm.label(address(swapRouter), "SWAP_ROUTER");
        vm.label(address(weth), "WETH");
        vm.label(address(usdc), "USDC");
        vm.label(address(airlock), "AIRLOCK");
    }

    struct TradeRewards {
        uint256 creator;
        uint256 platformReferrer;
        uint256 tradeReferrer;
        uint256 protocol;
    }

    struct MarketRewards {
        uint256 creator;
        uint256 platformReferrer;
        uint256 doppler;
        uint256 protocol;
    }

    function _calculateTradeRewards(uint256 ethAmount) internal pure returns (TradeRewards memory) {
        return
            TradeRewards({
                creator: (ethAmount * 5000) / 10_000,
                platformReferrer: (ethAmount * 1500) / 10_000,
                tradeReferrer: (ethAmount * 1500) / 10_000,
                protocol: (ethAmount * 2000) / 10_000
            });
    }

    function _calculateExpectedFee(uint256 ethAmount) internal pure returns (uint256) {
        uint256 feeBps = 100; // 1%
        return (ethAmount * feeBps) / 10_000;
    }

    function _calculateMarketRewards(uint256 ethAmount) internal pure returns (MarketRewards memory) {
        uint256 creator = (ethAmount * 5000) / 10_000;
        uint256 platformReferrer = (ethAmount * 2500) / 10_000;
        uint256 doppler = (ethAmount * 500) / 10_000;
        uint256 protocol = ethAmount - creator - platformReferrer - doppler;

        return MarketRewards({creator: creator, platformReferrer: platformReferrer, doppler: doppler, protocol: protocol});
    }

    function dealUSDC(address to, uint256 numUSDC) internal returns (uint256) {
        uint256 amount = numUSDC * 1e6;
        deal(address(usdc), to, amount);
        return amount;
    }

    function _getDefaultOwners() internal view returns (address[] memory owners) {
        owners = new address[](1);
        owners[0] = users.creator;
    }

    function dopplerFeeRecipient() internal view returns (address) {
        return airlock.owner();
    }

    function _generatePoolConfig(address currency_) internal pure returns (bytes memory) {
        return
            _generatePoolConfig(
                CoinConfigurationVersions.DOPPLER_UNI_V3_POOL_VERSION,
                currency_,
                DEFAULT_DISCOVERY_TICK_LOWER,
                DEFAULT_DISCOVERY_TICK_UPPER,
                DEFAULT_NUM_DISCOVERY_POSITIONS,
                DEFAULT_DISCOVERY_SUPPLY_SHARE
            );
    }

    function _generatePoolConfig(
        uint8 version_,
        address currency_,
        int24 tickLower_,
        int24 tickUpper_,
        uint16 numDiscoveryPositions_,
        uint256 maxDiscoverySupplyShare_
    ) internal pure returns (bytes memory) {
        return abi.encode(version_, currency_, tickLower_, tickUpper_, numDiscoveryPositions_, maxDiscoverySupplyShare_);
    }
}
