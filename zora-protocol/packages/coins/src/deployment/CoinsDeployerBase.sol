// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Script.sol";

import {ProxyDeployerScript, DeterministicContractConfig, DeterministicDeployerAndCaller} from "@zoralabs/shared-contracts/deployment/ProxyDeployerScript.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ZoraFactoryImpl} from "../ZoraFactoryImpl.sol";
import {Coin} from "../Coin.sol";
import {IVersionedContract} from "@zoralabs/shared-contracts/interfaces/IVersionedContract.sol";
import {BuySupplyWithSwapRouterHook} from "../hooks/deployment/BuySupplyWithSwapRouterHook.sol";
import {IZoraFactory} from "../interfaces/IZoraFactory.sol";
import {CoinV4} from "../CoinV4.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {ZoraV4CoinHook} from "../hooks/ZoraV4CoinHook.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {ZoraFactory} from "../proxy/ZoraFactory.sol";
import {HooksDeployment} from "../libs/HooksDeployment.sol";
import {ProxyShim} from "../../test/utils/ProxyShim.sol";

contract CoinsDeployerBase is ProxyDeployerScript {
    address internal constant PROTOCOL_REWARDS = 0x7777777F279eba3d3Ad8F4E708545291A6fDBA8B;
    address internal constant ZORA = 0x1111111111166b7FE7bd91427724B487980aFc69;

    using stdJson for string;

    struct CoinsDeployment {
        // Factory
        address zoraFactory;
        address zoraFactoryImpl;
        // Implementation
        address coinV3Impl;
        address coinV4Impl;
        string coinVersion;
        // hooks
        address buySupplyWithSwapRouterHook;
        address zoraV4CoinHook;
        // Hook deployment salt (for deterministic deployment)
        bytes32 zoraV4CoinHookSalt;
        bool isDev;
    }

    function addressesFile() internal view returns (string memory) {
        return addressesFile(false);
    }

    function addressesFile(bool dev) internal view returns (string memory) {
        if (dev) {
            return string.concat("./addresses/dev/", vm.toString(block.chainid), ".json");
        }
        return string.concat("./addresses/", vm.toString(block.chainid), ".json");
    }

    function saveDeployment(CoinsDeployment memory deployment) internal {
        string memory objectKey = "config";

        vm.serializeAddress(objectKey, "ZORA_FACTORY", deployment.zoraFactory);
        vm.serializeAddress(objectKey, "ZORA_FACTORY_IMPL", deployment.zoraFactoryImpl);
        vm.serializeString(objectKey, "COIN_VERSION", deployment.coinVersion);
        vm.serializeAddress(objectKey, "BUY_SUPPLY_WITH_SWAP_ROUTER_HOOK", deployment.buySupplyWithSwapRouterHook);
        vm.serializeAddress(objectKey, "COIN_V3_IMPL", deployment.coinV3Impl);
        vm.serializeAddress(objectKey, "ZORA_V4_COIN_HOOK", deployment.zoraV4CoinHook);
        vm.serializeBytes32(objectKey, "ZORA_V4_COIN_HOOK_SALT", deployment.zoraV4CoinHookSalt);
        string memory result = vm.serializeAddress(objectKey, "COIN_V4_IMPL", deployment.coinV4Impl);

        vm.writeJson(result, addressesFile(deployment.isDev));
    }

    function readDeployment() internal returns (CoinsDeployment memory deployment) {
        return readDeployment(false);
    }

    function readDeployment(bool dev) internal returns (CoinsDeployment memory deployment) {
        string memory file = addressesFile(dev);
        deployment.isDev = dev;
        if (!vm.exists(file)) {
            return deployment;
        }
        string memory json = vm.readFile(file);

        deployment.zoraFactory = readAddressOrDefaultToZero(json, "ZORA_FACTORY");
        deployment.zoraFactoryImpl = readAddressOrDefaultToZero(json, "ZORA_FACTORY_IMPL");
        deployment.coinV3Impl = readAddressOrDefaultToZero(json, "COIN_V3_IMPL");
        deployment.coinV4Impl = readAddressOrDefaultToZero(json, "COIN_V4_IMPL");
        deployment.coinVersion = readStringOrDefaultToEmpty(json, "COIN_VERSION");
        deployment.buySupplyWithSwapRouterHook = readAddressOrDefaultToZero(json, "BUY_SUPPLY_WITH_SWAP_ROUTER_HOOK");
        deployment.zoraV4CoinHook = readAddressOrDefaultToZero(json, "ZORA_V4_COIN_HOOK");
        deployment.zoraV4CoinHookSalt = readBytes32OrDefaultToZero(json, "ZORA_V4_COIN_HOOK_SALT");
    }

    function deployCoinV3Impl() internal returns (Coin) {
        return
            new Coin({
                protocolRewardRecipient_: getZoraRecipient(),
                protocolRewards_: PROTOCOL_REWARDS,
                weth_: getWeth(),
                v3Factory_: getUniswapV3Factory(),
                swapRouter_: getUniswapSwapRouter(),
                airlock_: getDopplerAirlock()
            });
    }

    function deployCoinV4Impl(address zoraV4CoinHook) internal returns (CoinV4) {
        return
            new CoinV4({
                protocolRewardRecipient_: getZoraRecipient(),
                protocolRewards_: PROTOCOL_REWARDS,
                poolManager_: IPoolManager(getUniswapV4PoolManager()),
                airlock_: getDopplerAirlock(),
                hooks_: IHooks(zoraV4CoinHook)
            });
    }

    function deployZoraFactoryImpl(address coinV3Impl, address coinV4Impl) internal returns (ZoraFactoryImpl) {
        return new ZoraFactoryImpl(coinV3Impl, coinV4Impl);
    }

    function deployBuySupplyWithSwapRouterHook(CoinsDeployment memory deployment) internal returns (BuySupplyWithSwapRouterHook) {
        return new BuySupplyWithSwapRouterHook(IZoraFactory(deployment.zoraFactory), getUniswapSwapRouter(), getUniswapV4PoolManager());
    }

    function deployZoraV4CoinHook(CoinsDeployment memory deployment) internal returns (IHooks, bytes32) {
        // Read existing deployment to get stored salt

        require(deployment.zoraFactory != address(0), "Zora factory is not set");

        return
            HooksDeployment.deployZoraV4CoinHookFromScript(
                getUniswapV4PoolManager(),
                deployment.zoraFactory,
                getDefaultTrustedMessageSenders(),
                deployment.zoraV4CoinHookSalt
            );
    }

    function getDefaultTrustedMessageSenders() internal view returns (address[] memory) {
        address[] memory trustedMessageSenders = new address[](2);
        trustedMessageSenders[0] = getUniswapUniversalRouter();
        trustedMessageSenders[1] = getUniswapV4PositionManager();
        return trustedMessageSenders;
    }

    function deployImpls(CoinsDeployment memory deployment) internal returns (CoinsDeployment memory) {
        // Deploy implementation contracts
        deployment.coinV3Impl = address(deployCoinV3Impl());

        // Deploy hook first, then use its address for coin v4 impl
        (IHooks zoraV4CoinHook, bytes32 usedSalt) = deployZoraV4CoinHook(deployment);
        deployment.zoraV4CoinHook = address(zoraV4CoinHook);
        deployment.zoraV4CoinHookSalt = usedSalt;

        deployment.coinV4Impl = address(deployCoinV4Impl(deployment.zoraV4CoinHook));
        deployment.zoraFactoryImpl = address(deployZoraFactoryImpl(deployment.coinV3Impl, deployment.coinV4Impl));
        deployment.coinVersion = IVersionedContract(deployment.coinV4Impl).contractVersion();
        deployment.buySupplyWithSwapRouterHook = address(deployBuySupplyWithSwapRouterHook(deployment));

        return deployment;
    }

    function deployZoraDeterministic(CoinsDeployment memory deployment, DeterministicDeployerAndCaller deployer) internal {
        // read previously saved deterministic config
        DeterministicContractConfig memory zoraConfig = readDeterministicContractConfig("zoraFactory");

        deployment = deployImpls(deployment);

        if (deployment.zoraFactoryImpl.code.length == 0) {
            revert("Factory Impl not yet deployed. Make sure to deploy it with DeployImpl.s.sol");
        }

        // build upgrade to and call for factory, with init call
        bytes memory upgradeToAndCall = abi.encodeWithSelector(
            UUPSUpgradeable.upgradeToAndCall.selector,
            deployment.zoraFactoryImpl,
            abi.encodeWithSelector(ZoraFactoryImpl.initialize.selector, getProxyAdmin())
        );

        // sign deployment with turnkey account
        bytes memory signature = signDeploymentWithTurnkey(zoraConfig, upgradeToAndCall, deployer);

        printVerificationCommand(zoraConfig);

        deployment.zoraFactory = deployer.permitSafeCreate2AndCall(
            signature,
            zoraConfig.salt,
            zoraConfig.creationCode,
            upgradeToAndCall,
            zoraConfig.deployedAddress
        );

        // validate that the zora factory owner is the proxy admin
        require(ZoraFactoryImpl(deployment.zoraFactory).owner() == getProxyAdmin(), "Zora factory owner is not the proxy admin");
    }

    function deployDevFactory(CoinsDeployment memory deployment) internal returns (ZoraFactory devFactory) {
        address owner = 0x63545B401283c993320A5b886ecF0fc6CB5668a9;

        ProxyShim shim = new ProxyShim();

        deployment.zoraFactory = address(new ZoraFactory(address(shim)));

        deployment = deployImpls(deployment);

        UUPSUpgradeable(deployment.zoraFactory).upgradeToAndCall(deployment.zoraFactoryImpl, "");

        ZoraFactoryImpl(deployment.zoraFactory).initialize(owner);

        saveDeployment(deployment);
    }

    function printUpgradeFactoryCommand(CoinsDeployment memory deployment) internal view {
        // build upgrade to and call for factory, with init call
        bytes memory call = abi.encodeWithSelector(UUPSUpgradeable.upgradeToAndCall.selector, deployment.zoraFactoryImpl, "");

        address proxyAdmin = getProxyAdmin();

        address target = address(deployment.zoraFactory);

        // print the details for upgrading:

        console.log("To upgrade the factory, this is the call information:");

        console.log("Multisig:", proxyAdmin);
        console.log("Target (the factory proxy):", target);
        console.log("Upgrade call:");
        console.logBytes(call);
        console.log("Function to call: upgradeToAndCall");
        // concat the args into a string, factoryImpl, ""
        console.log("Args: ", string.concat(vm.toString(deployment.zoraFactoryImpl), ",", '"'));
    }
}
