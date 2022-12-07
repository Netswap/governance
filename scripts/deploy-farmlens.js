const hre = require('hardhat');
const fs = require('fs');
const path = require('path');

async function main() {
    const accounts = await ethers.getSigners();
    const signer = accounts[0];
    console.log('signer:', signer.address);

    const chainId = hre.network.config.chainId;

    if (!chainId || (chainId !== 599 && chainId !== 1088)) {
        throw new Error("Please input --network args and correct network");
    }

    const FarmLensFactory = await hre.ethers.getContractFactory('FarmLens');

    const config = {
        mainnet: {
            nett: '0x90fE084F877C65e1b577c7b2eA64B8D8dd1AB278',
            metis: '0xDeadDeAddeAddEAddeadDEaDDEAdDeaDDeAD0000',
            metisUsdt: '0x3d60afecf67e6ba950b499137a72478b2ca7c5a1',
            metisUsdc: '0x5ae3ee7fbb3cb28c17e7adc3a6ae605ae2465091',
            factory: '0x70f51d68D16e8f9e418441280342BD43AC9Dff9f',
            ntf: '0x9d1dbB49b2744A1555EDbF1708D64dC71B0CB052',
            bntf: '0x5E1f9Cd1B9635506af6Bc3B2414AC9C8b2840EFa'
        },
        testnet: {
            nett: '0xA49efFF1961C0aF60519887E390e9954952176f8',
            metis: '0xDeadDeAddeAddEAddeadDEaDDEAdDeaDDeAD0000',
            metisUsdt: '0x6db977e4a4a1a65F73440aE87a24456d506E6a6D',
            metisUsdc: '0xF6971Ec05557f680b0a8Cd8296C352A115a6e6bd',
            factory: '0x587e879E48AE1753d44D9F33603141c6AFb87F76',
            ntf: '0xA42f8cc09E32a8D1d302580A58e57AbB156f655c',
            bntf: '0xA82B195661AE803c18df4713E5Bf5CA18731724c'
        }
    }

    let parameters;

    if (chainId == 599) {
        parameters = config.testnet;
    } else {
        parameters = config.mainnet;
    }

    const FarmLens = await FarmLensFactory.connect(signer).deploy(
        parameters.nett,
        parameters.metis,
        parameters.metisUsdt,
        parameters.metisUsdc,
        parameters.factory,
        parameters.ntf,
        parameters.bntf,
    );
    await FarmLens.deployed();
    console.log('FarmLens is deployed to: ', FarmLens.address);

    const addresses = {
        FarmLens: FarmLens.address,
    };

    console.log(addresses);

    fs.writeFileSync(path.resolve(__dirname, `../deployments/${chainId === 599 ? 'testnet' : 'mainnet'}/FarmLens.json`), JSON.stringify(addresses, null, 4));
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });