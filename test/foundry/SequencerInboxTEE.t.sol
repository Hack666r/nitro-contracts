// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "forge-std/Test.sol";
import "./util/TestUtil.sol";
import "../../src/bridge/Bridge.sol";
import "../../src/bridge/SequencerInbox.sol";
import {ERC20Bridge} from "../../src/bridge/ERC20Bridge.sol";
import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";
import {EspressoTEEVerifier} from "../../src/bridge/EspressoTEEVerifier.sol";
import {
    TransparentUpgradeableProxy
} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {
    V3QuoteVerifier
} from "@automata-network/dcap-attestation/contracts/verifiers/V3QuoteVerifier.sol";

contract RollupMock {
    address public immutable owner;

    constructor(address _owner) {
        owner = _owner;
    }
}

contract SequencerInboxTest is Test {
    event TEEAttestationQuoteVerified(uint256 indexed seqMessageIndex);
    error InvalidReportDataHash();

    address rollupOwner = address(137);
    uint256 maxDataSize = 10000;
    ISequencerInbox.MaxTimeVariation maxTimeVariation =
        ISequencerInbox.MaxTimeVariation({
            delayBlocks: 10,
            futureBlocks: 10,
            delaySeconds: 100,
            futureSeconds: 100
        });
    address dummyInbox = address(139);
    address proxyAdmin = address(140);
    bytes32 mrEnclave = bytes32(0x32ed2f272a3bb58e07dc8af2e66879a57c648549707cbeb396ffc234ba1b65d9);
    bytes32 mrSigner = bytes32(0x0458a0e62674775ca9a048016f817f39b0bd40153000aceb44a5128ded30555e);
    IReader4844 dummyReader4844 = IReader4844(address(137));

    uint256 public constant MAX_DATA_SIZE = 117964;
    address adminTEE = address(141);
    address fakeAddress = address(145);

    EspressoTEEVerifier espressoTEEVerifier;
    V3QuoteVerifier quoteVerifier;
    bytes sampleQuote;
    SequencerInbox seqInboxImpl;
    SequencerInbox seqInbox;
    Bridge bridgeImpl;
    Bridge bridge;
    RollupMock rollupMock;
    //  Address of the automata V3QuoteVerifier deployed on sepolia
    address v3QuoteVerifier = address(0x6E64769A13617f528a2135692484B681Ee1a7169);
    // address of the Reader4844 contract deployed on sepolia
    address reader4844 = address(0xf6134C5849Fe8177163747288d41283B271B1624);

    // This was generated by running the batch poster in the TEE
    // and coping the l2MessageData that it was trying to post in a batch
    bytes l2TEEData =
        hex"001ba63251c4180700b07ea0882a5101f879601b331f3c180d5d7ea1bf30d808701425f6ed6175ca56a48c90647678dae6df016225209cfb32dde6e21bb5afdfe15c3530b89bb2780fb316cd0560ff3d62d188ab7695e93afe9cfea76a39ff744e95a99d252e484ea10c21b5048622668e0d9ed74d731d3e0092d23a7d8092f65a8fabcee32a37b5ab58a5f5ffd63445e3386c9a496651efad4b9ccd024dcba7ae9c83e7bd55e1ff971480258d5d40696ca708873bd0e184c73d01f688105b50c48d780fcfb2d634b5bc693c2ac1220c298180a217e0ff7b9de585ffb2acdd001f5089459b19ef115445264523bdb75ff4bd8e259be5e4b4d6b21675e875c0b03ef20518ab9b54807600a0042ec31d1054295394579429ebd82662743b63b2b64955e38d010fbf0ca713b64ef4d5282184de57dee9cf98f9c6dc7ef71b38017371e7744cf07e4ce2848377d3c6f4bc682c658ffc8805b59bbd7fd8b8a1efba0d6ea72c32d40c69befdbafd01d19c5ade5fd287a7766f49c3087d907654cb774f59da32349e5c54312b9e3c57667f258f087b6679d643785826b32f173b06546ce930f6ce6ae7f7479edccdb7318f3336de0a7cfdb079545fb2dd80c4af0387b3027ce734243271027f353668eebd50b793d322673d4e5db0b6a8dd8bf85b11352e8527c64666faa59f585aa3bbb7d8b8f0e7bcf2694b5a5cb7add02c8f4b1064d49579273396bd1d7d1f3a7af59d22ffe8bba331e1c1d5018f23255e2f8eb66ff06f2b7ca55e3ad9b9fb46ef3e2cdf651c2ebb4246c8ddcf90419cf822064ff4a0e95dc45be0a0419a3a01629bf21840ab21711431103bcd25035ac5408f5fb8fab30e60a6f50f98f60a04ddfd44106be483e7bda7cdf03084ce94ec371d0982384585ca3f7dee87dac8ab5f7318669c4bd7850cb4e79055ffd247cdaf5352521d1df7b24f9287b9197b48307770d643a25d75fd8f80ae6eaedad7898e36bb0baf227777cbe1f5101e3a187814b1c7b29d6ef87b62e6a554bc3c7da7cf630e92ebf6fdc2676ef0c62376b227d29a2fff7068effd9fe507a53b4e94749d8e1fc4d9eac3e4d2bf638d9948642b7b201a7d0a4b40c5b35410d3a68797799881a3f7d381581627a0b97988dc55e9f379ccd6f295741a241d487c348536c51897993deda93882fa2254a04eab92587d1b3d6df453c624d2cbe89f06327658d557dc182c007fb82bce816647512601b5757a0103b13daf8e4b5fa22760ca1c18dd7ad03f01b5039d2ec1bc5cd6190e989277da2563d960f7023ecc23f5fd54812558c83a062c661740277735477ff5a2a356b0de7dd4ae93da1a6aa5998a80119d26352e1245b1eb082a2cb850aa3d8622e9c91619b14b58a979602339e97e0a591358fee185d5946027c1ff7d570d51b139f0115c9f6b5b83f7ceb5c2095ba70bb03b8082ff53209a440244dbd5c8bb589cf8b6bcb1af28a2b37fe17f320da6e716b20e50c63cf1c4c93bdffebb6463b79b6f3c2770ebd26fb79fbdefbbecfdb3cba9fbfaffad03b2f63c71127dfd150e57806267190a42b8dd7353e2d058704daed556c80e67034061c1ff49abf37c98d00ee354151a647b88f6963caf0194462c8b7befdf82c3841c5e14c683af7cde098e30a5eb6aceb85bf6fd255c43c82c100bf81b4aab18f27314f233085353bb9a2c67bad1b3bf7d840362f77e511e5da2f0ce0d48855d4204da94e9c251f8314be2933ed656c8f7b680da25e47f214b4a506ae49d63b24a5ed20d120a8042f20f00426b21423bbd07ae794c6a6c059326a96a4cb25a257fd6cbfce42f8d702a0ebb8a13dde2289c4e7b29062747f180bcacd4b9158aed887b13836b901b3459f23a6701fc2301e1b89451ef45a22c6ec6edf46034fdc44564f130e7764bb3abfcb470aede6ce6718650569c00c9dd2c67599ef8151c10661e7c0415d55399fc0a599f3ff6b77e442507e3aa4efb1a95b25c99bf40323ad0651f1a059279332c5169b6daa26273d2a69177b238416593b5de178d95d57a15084d3823d9d5eadf7e574933310909fe2768e4572162c83abeae554ebce489c03a3d2f9d5ebef28a47ee820304206a381f0835b40169d5c034b6aa71acb30536362e0161bb2941e2082a015a3f43b5702ce5a50c7944e7c2c11595000163ee9d5640993610575d2118a074f7a961e5244706b2752073647e96c3b91b1d442573ed45e3d83699d44eac26d899eea5f8a03e5104336189aad8228bc1d8ef41d35f9a91609d564ac4ba80cbd6b50d0af171524b3ecdb338c992ec262e291b2a6ef4ecd84efacb1d20380322a9edcefe3535d36dba56a1e1d0f907812e2d03da8302a66f69aaf4d256972ca67a981c3f3d58bdadf1916ab3d8f8ea3b807874cf9d7301102c29f326dbc0f871a3e092e2214035dc45223a2459dd22c83f4341518d8e54e87bcc4456a795b7288d2150fa9bd4012cb53862fcf9243c0d7a8f27754a5a94e98a22758c8996e16b1d6cf3f1715f44c5f1750fb1bac8c39c91c0f090fbcd2c93ab2609ba27e2b5bd325ab210fe462cedcd2b3c1e4ac18bfd4331703a41fe199b081d043d625855eab321289923baf6138f6f3eb306fd0206e7103d4be391d7e41184dad9e751053d58b998d01f2d132c08ba198e087a2ca006afa0ef4f9c03cf94a3056b16a585ad86af476ae44ffd95c2fcf2df8084fe36933ae85bf99b532cfd6ba04cb7608c6c944e36767e3ab012208bc5d5c0885a7528c680bd48a5dfad8883a0a79a027c5a23f08854dcf76d806c622bb24a90450b3d95087aae2375b8d7fe2db593d2302b8dd1d150ea761fb6502ad549d36f8e918ebaa92380f34811d16962d41cbc386d455662f0b5115b904582b476ceab9705181ca944c2f5b2fe12e8e546813435a96be4863432caf8a76e108a2cb8a34bc5ecace3c910eb77ee400c903bbb8e8a1689186fc18ffc07b954f1e1a25e49013097aaa0a8205b2dabd8c242d31a71a13d71c3e9b0aab1eeb3521609db929507cfbdd587cc614736e684bf40628dca7d6870b2830639e179325c5b9fb45cfa75e85c7f43c6945f33d94d3de32e972fedf1d43963081920b9f0cacb02bd3e3362ca6ffa6019808fdd060e1227c1fdbb9020ad21dfe408f36bcc6bc9e15d091fbdfd8e4fd9cf6e29cbae4c6ceae1abb0271cf8d61160666e91f78427bb98a3f39644073e582a8cfec2aefff752c0bad50f8d53fcdf7251a27ab52e7e932ba07affdc310d581a82de9b298033ef844d8bfb9d9c772d78f26236c66999ae9daa2d508eb7b6f9d7b6fb388a35a9d3ca2d00470cd16dd5718c1fa1ea07761568ce6cd5721c8b6b71e8fd8a3147026d1c1b7d66eb3e868c3f7df23e13399fa25d7d32646398f4e949254b093d9551eb76abc8f90c1e4d5a1a9ff5619f8f2171e1a92c6149aaded5516491cf0650e6982c1b7fa4ac23b40609d79616afb20e26b09f9cc72cd7e99ef4265698ed9f2b8db3edaca67036d0ea4a5737d56ea57dcef6ee7409eede85b570a2d6f354d538abb03dda94319896d7e9616e14717d7cc1e7a647fba10dc907baa0b68c5c0dbb6a19e3eca4658bbcc76a13af489260e667a7fdb109cd561ab3d95d3d6a064dcf2f6d275bcb79261f37a348d40e928c5b699bad52b61d32bbea1b3b7c7863cb1f7d3fe96ca30101d655db55640cf61c807ae55d1b278d0f97e488b444ad30d78a66be16c5d75ce235dc0252615a77a975acff34f7df175b1bb7d0ec4bae36cc7ab931f9d257b97ef972ab2e75ab646aac2d2623e5956fa87e061f5382eb1058876b8f49a5c3e45bab158a085ba37ab1b1f684992ed3b5d60045854c8ee493551b5d9ed712c98e2551f7af16eb90c58edce910ae4ad133cd8c7a2c6c9486696e9d5a1cb184bec715eafd73d42140a2a8b1ae01aaf491e6468e649e1c9ddddc40ed14d693b4573b55560328a60719edbc4e475a5c440cd7bc1c334a9f2a34893c670687d12555692913784b7be64ac2f52b7c9d46b6e92190a07eddd496328bad25a6821b693fc5d37a38f4d8982a1c7ca9081ba5fdb82017850c66091b02bc99ab0aa86cad2f40290cab3d5bab3121378ea26964381940e262a5a38941a65f7d07322beb6c4601755fe301635440a8df73acdbf62d6123dfceaa288f148f7568b823acebf7b9ccfbc345d2d6583a2bef4ed114e7cfb0b62b6692312012784fc1d5cc1395a49ccee79fa139d5001e32539ee2028d2be43db627fbd17e2e598ea83f2235d594777241e3a925eed08c4f4e9dbd7bc57b7608fafd1e3922a587114d7feb2ac496ce87403a909e419b4ac06e27484d5a02cab964499b2fb914474818ecf356e8c57011232bb7479a14e4752812a62a5ca9d12ccc41e21a9b99651ed00ceb6aa021682676b50a465019ecd124fe6e50a821324a6f8272cd853091393c34a83f4fbea07916b98a3d9e07aa98c6d540da4eab91741df7875522611d00fa3cb02db9693591a0599537ac1c94986c8b99e151c302f9d2d169ebbff25a8007792011f4e3f251656615798998cab1a52bd1224bc9a86132bcc2885cf91eb2d1b856d8bc1102234569de87658d717f8eab3860e6303967993a4cb06899d0a227343f547333cd264c85a8ff7062ef9d7eb2226a3d3cdd9ed61eb4484668ddb9469da24355613480e069bd212d81d66d4348fda18dd1f8d98e79b06ca47ae38768a10f3840ec3537d86ab52cb4f6ab61180761fc802d8d78403ea8b8449c90631c5b2a41b3ad5b564201f9581de8ee187b498357f28d476b888f3ce1b36fa76f91104f465655298528e1827de5f3bd2f58f197bb44181fa276b959d40bebee04c4db94b1a91d249e827529b30b1033762ddfea348017b9d782564241a295cc5a99f7187acf5d3d7d2f96c4d300d2261277c29d055cf88539b3f4e241f012c9272af8b9a88224019846b86d8e009eec1b802db2df4d13fa5e5b885eec65d09f8bcb2ab3542be00371eac98e3f74b156c4278949de2a9225486a317381d4a6457f45aaccb5e7bbda5560b5b0f5d53cee7c50570f9a61a3ac4a15921394e2b9bdb6e5d1290f4622a275d85941b2526077d52542a4a162a4e76cc33defe514c23251b365c1ddfa0619ed362019d2908540dae7959f6a66752dd0ca3681001c017613a4b63a65c83ba60d271c9da2b312b052f6bad858b954922ce904b9acf061b5b891c126d78ae796bc3ad794fb59ca45cda5c4dfe43a2949c298db3f0e4cb582cac1a696982672768b7357606d4ba79fd23a019c64fd23aec447353513eede11baf872ad5ebee7cd4fff740709c6ac3a52ed312f7ba6feadc4627bdf8ffbe1fa4f7ce2e3a7d6c79ccffd3096f81df43de499f4ff9893ee45fc3898f2eec38d1ff22f878937f3906247a421b9564e61bef8e9817b8ebb86349b340be7b78b3df53a99d444aa14b0ac52834f965571a4c1f216397f8f1ca62e16e74f5a1a9c4bebea4e8d63f9aca216703257c9ec1a06446130da510306472d002ba4fe984aca626c9cc79c47a5f993a43648bb601a5d62ca7b8041477ba1dcfcc85221837be644d8908ffab661b852cff43a893181c2c61f6ccfd1bb687c7ae0e074a94d457867c73fb538658b4d3f2c945673e9fd0c4f0fcadc61c07096762c4fa872408eea3a3f571e58c33fa40dd9d4002b4007bd607482e2ea4d0065a7ec866ca4b55f89fb6afd553cc4fcfeb0f208e634efbafac1d0f5c5a2d8017747243fb742d9054aa784b2a5406ec46d50361706d7411957a58278d133471f303c1556d9c647d36833edb78997660b9fe51a464ed985bd1d626b92dd1d9b04650598e16749abe964000fe5ca4df3720fd159cf6c7ba414f4c30a658e080733091fd080254fe42c864873083da542b3630d2cc953520b4b80f0a9efb4842dfff78878f2cf669f48f5c400d7944eefceb596cf2c88f3fa3264f0afc39b2a23979e79bce397d73767567e594ee5a8b000f9ee50b9e7c9410d53c7ce5cd3f1be23b7e1dab5e2dc6c31aebec72c5cbaf2d7e9855995a545997db06a10f6fc57b4237964f73d07f69517be5970726a6ceb7ccdcc99926fe33589074e2d6817a16e6edde19818e936e9f844e3ea812bde36a6161c3aedba6da174f073b6b4dde48fe8c2719e7897706fab222fdcee8def2e1cda3a499801684d8785239af82cb745292b66249cd652e1ffb32343dd43d74523c5e941817dcf855e5cf6c9281d64981bd6747be393adc1a58559d443443741979f888118b2c9ad913ac328a30ff5b15172dd5ac8c866ca87874cd56e41474aa9d4b1e5cae0151efebdb133db22c67af899631b969fd179f82963e78483c523791114c764ce5ff55ffba1be90228ffdd4faa42e0dfbc1667ede717f7da43d010dc298bb6247b15fa2ea8d11320a4b04590191d5d54fea65fea87f70c708c60475ebaf02720091a6ab0735c863ab90dc8e4ed2fea80ba24c888c9d4e90f6e168f1529dddb4026722e503507c40bcc86f0a1fca74778935e8a0dcc73034ee828cc746a8d6c4983445cbee0a08fd8dffcb3b097a45874894c119adf79d1c854aee7de0f6b899f47b8ee0ef3a275cf07d8b18dc05af5b59e52304dfc69f847eb8529a05c8c26d7380109a48b7a32d80ec6706f49b9f982aacfceb8f9f85da7e89ae6d1df5cbdbc3b83f5bfbf7f1cf7090309b042532fb7ecc8516135be51061e0e75eddbe0231bbd31c554c2ed9d9650c19697deea9ca76387170e5f83f8d2cd52ec10620738ee02ed9ec4ac578bc65709b38adeeedb64c2fe6e95416108f6634e8a1059413fb8919be08da6c223a7ec2680b6d6be66d7172f63853dcd2cb039141b68ed0d871524638619edbebe9d1d929b36e5f0c07892a93a0d6669c6b7b31abc3e02e7992f5a3303c277ee62e1dd8add86117f94e2232b091be9149312d28bf208cb9979629927e32905ba16a47608f49fda447750f9fda023f7c5644d07b32dffa52516ed5092aaf7e740b9776073e53968ddc7caac8ffd3425df83805bf451d0f50f553bc7047387e4e35d2c4af8bd355f8cbe2059952e0d06b22ff062b62da6ef51bacc2c6ca3eaf823397ccd00472690ec2ab345746095912c4709a9ce5ab603fd17a919351e5e6e9ba77783115ad4dc9f6e8ec180327561d9f6c29bc3ada58299d39fff2fc1bfd7a26cddc32edbdcf73447ee04bae44933725f3324691f141d7766cc9d9b8c7aa852732d888b29dd6b70544951f7d90ce4275091ace05fa65155218c89033e4bbff6c7b5611f693fda520cbe3bba45f3ad430d7f94cf86ccac159ef3624873ef215ae12adaa6b303dffaddfbc417047c2a903bd474fc80debf8eae8f72ba6a7e1f1e93b4286edaaea18d8c8e67bf4945f76648d70f33e52b3399cd7b9fb26f1c159d92d6d77470da5e9d915db0c13770d324cdae5b564c37bcdf3e6edeed66dca73ead503a4019a51ebb1c9bd74129fd66324d8ea31ee49eaac5c32832300188e1fa0c7b890daaf4e2003da2c406e4db5f7331af14e31052753219b1762b2acff7c99b89506a1263c403424cea96cb7ca597d86f926a35bc065da69b3baca8c5babed0cde75b65a8d65361064f29f974d11e931b68e327477b337a63436b517e69eec3c287257c3e954f9c4b3ff24ae96379d568e49eab637e32848a447d0cc84cf5f7e9b16cdb6d8013640566431ec9d7e2343fe2ea275c1fdddcdf25edfb5ed87ed2d6c5b3d75304c977c3b6a74648a8976d22a112d427a8c2da3747a8c7e0d19bdb50cdb6223f2069375b1951b0277fd5881977448cddcfee29dffe4eb2b2526cf31906f33cccc1a36a577b4e4e05f03eddbbe7cadbe12fbfa57e76c45ef0d5ce4b12549a7a6cc329b3536463587318babd5e2d966238bab1b39911ea34d94522c415a1574cd468c1e13942bd067446615d27aeaadc96557a29fbacf1a97dbe1daf6fbd555a3b203600e44dfa599f593e83186a85a358830a90dff9d41475e543a2972e5d396dfa11fd638c46c55b6c68cab73dca4f33274d274709aa84df5aaf4189b1ab619c959588b31e30b52482c6ea6149e5620f05a564351c39e5a85154fcd91c5716512fd10628e46da00589563644be23725c5045dc95592880dcd597faa80c1ab50a94856e4f969296a4a3e541171cf2d7860f09d3b8b43e68dba371978ad15895abb8eac13c4041dcd916562914fc79b1f6bea36eed849d4e39c2b2e229f7583a24fdc63f56e8c6609a239964917060d949f4c8b8722e212f0acb23a1fb166df5bdbd17b3af659dfac56bb5e16267c0bb2ce923b6e3fab51f064042315b15ea77d6e4011f15d19ed9dc42f7bb804b28e29006a58c28985fa40bb9762d736a3da611e29e7534a2094d69b9055e8864a73bd08d90b4f04962be8bb0ee1b3c5f46f5ac091220163f76ef864e6482e96516258a51ff7d2d3afde59694cbefc87fee01d0e890f856c857fa59df8a06a3247ee9e7d0192fdae23d93f9598400ed1d2b2a97231cb417f2292d502242847b24740b6801f23b58fc1a0e8523a0b28502aee4a6ef833705537aa3fc83755fe65820984f1d4c582de9875e20c9738ca691b13517f7158625154d1bb36a45948c7219df82a848f47f2a05f927a356c0de5267a391119143f3b4d740b4ba64816822227f379099d3c55fd8748d6718ee822bde469227dc8decb30adcfb2f8e28c61b7cb7a6d2953873ca831654b4e1ec06f8aaa73730e56b104d1f7f5670831eb17c7b152e6b0b167d2e8587ced593ddf429e9cc085fb25fbf252f02ff34b590933be28583a5504f98994027dd629502ba9b5bdb3bffc5f505bb60a34b83b2e6545e9e429ff928ebb2e437e89fc071a83559ca575a8b5b229e95f1e023930024ac7804f043042385dcb50abffa6a59984bce63009f94fd3f987fc8da4e1a453e77a798be13f85fad0b10a96b02abb30978f294e8c98d50ae8e44dae7e0ec08c9329ad1f2814cca17450c0504a25a983029b050a1aa0cb28074fd9eca9ca7e990043c114dbb95594265b0f4da68b924a887d2d0e62991b700a10c116d0670ca471653a663a413153f7419716bb6d5db48431e38b9b4c5e128b731de2e38ca62764e59c636232a15011f73701b0f48a8cffc00faa54c2a2cf84c231c9844255b2a04b0b5afd22e8f2912cb54e0685650978233f6c06c8e92eceaad0ac320ec1063ad6e44723db997245ae53c30ab692f99b845a754606677195d98c83beb8dac6e036934d098536f28fdb5794735a94c7995549f8d12f7a7a8fcb5774e5d5c7081ada648256cf4fbd9903450bcb1f83e1bbff4c9c5eb6d990bc7c25ed1fa83e6c9e32833c97be71eca09edde71f59b4e7c534df0d33ae7c6afaf53e656978d69144715cdf2b49b35e73d8765900f6c639488ec03f55ff7e8c99372176a8bdf69f8ba7db4fe256159eded298d4dc2629e00ff971dd31e66683ea40e330f4001bbcf2a4efe9d7765da6a8edc9cd756627d004bd7ee9caf2f19d3b3f77a0bad98bffb8221e33dfee1b5ab3e6e3f1d61d6d8b17ffea53fdf5f37c43c02a7a67df55ef478ddce6cb517f4361bcdc34c5dc83b8a36c5d45f41ebfdb5bd7df253b9c7f1caa6f11283fc466d5bfac9aa01d6b73f9d8e2187de78d73d4ebab07beecfdafdbe0f137625e3435cff390059d169dfe5ca379a9dabc73eeb9dada4c705a43ebecbbfd2ba397b5dd5d2e2a48a378fc9b7ae4e5d9533b857bfef04edba50c8df4f5611774d598378c146f135f8c6f9919e708fd5e7fc29bf50fdaa04b785678c97cf35e979f01210f872c3e19fd34998929f737f2595e9c51c0f2623f316336bcafe4ddaa37ae4d5911f9e286b4276b2f667cfd78aca8efe68d803b366eed792ff98d4f04dce23de4b6cf4cd513c2f59a4eeac23d9b32a135b4eeeb6f87a27c69e7bf177fabef32d5fdef4311dfcc2f2775ba6081af0b99f6ea995bd7950c02";

    function setUp() public {
        vm.createSelectFork("https://rpc.ankr.com/eth_sepolia");
        espressoTEEVerifier = new EspressoTEEVerifier(mrEnclave, mrSigner, v3QuoteVerifier);

        string memory quotePath = "/test/foundry/configs/sequencer_inbox_attestation.bin";
        string memory inputFile = string.concat(vm.projectRoot(), quotePath);
        sampleQuote = vm.readFileBinary(inputFile);
        seqInboxImpl = new SequencerInbox(maxDataSize, IReader4844(reader4844), false);
        rollupMock = new RollupMock(rollupOwner);
        bridgeImpl = new Bridge();
        bridge = Bridge(
            address(new TransparentUpgradeableProxy(address(bridgeImpl), proxyAdmin, ""))
        );

        bridge.initialize(IOwnable(address(rollupMock)));
        vm.prank(rollupOwner);
        bridge.setDelayedInbox(dummyInbox, true);

        seqInboxImpl = new SequencerInbox(maxDataSize, IReader4844(reader4844), false);
        seqInbox = SequencerInbox(
            address(new TransparentUpgradeableProxy(address(seqInboxImpl), proxyAdmin, ""))
        );
        seqInbox.initialize(bridge, maxTimeVariation, address(espressoTEEVerifier));

        vm.prank(rollupOwner);
        seqInbox.setIsBatchPoster(tx.origin, true);

        vm.prank(rollupOwner);
        bridge.setSequencerInbox(address(seqInbox));
    }

    function testAddSequencerL2BatchFromOrigin() public {
        uint256 subMessageCount = 1;
        uint256 nextSubMessageCount = 18;
        uint256 sequenceNumber = 1;
        uint256 delayedMessagesRead = 10;
        bytes32 reportDataHash = keccak256(
            abi.encode(
                sequenceNumber,
                delayedMessagesRead,
                l2TEEData,
                address(0),
                subMessageCount,
                nextSubMessageCount
            )
        );

        vm.prank(tx.origin);
        vm.expectRevert();

        //  We expect the TEE attestation quote to be validated
        vm.expectEmit();
        emit TEEAttestationQuoteVerified(sequenceNumber);
        seqInbox.addSequencerL2BatchFromOrigin(
            sequenceNumber,
            l2TEEData,
            delayedMessagesRead,
            IGasRefunder(0x0000000000000000000000000000000000000000),
            subMessageCount,
            nextSubMessageCount,
            sampleQuote
        );
    }

    function testAddSequencerL2BatchFromOriginWithIncorrectParams() public {
        bytes memory invalidData = hex"012346";
        uint256 subMessageCount = 1;
        uint256 nextSubMessageCount = 18;
        uint256 sequenceNumber = 1;
        uint256 delayedMessagesRead = 10;

        vm.prank(tx.origin);
        vm.expectRevert(abi.encodeWithSelector(InvalidReportDataHash.selector));
        seqInbox.addSequencerL2Batch(
            sequenceNumber,
            invalidData,
            delayedMessagesRead,
            IGasRefunder(0x0000000000000000000000000000000000000000),
            subMessageCount,
            nextSubMessageCount,
            sampleQuote
        );
    }

    function testAddSequencerL2Batch() public {
        uint256 subMessageCount = 1;
        uint256 nextSubMessageCount = 18;
        uint256 sequenceNumber = 1;
        uint256 delayedMessagesRead = 10;
        bytes32 reportDataHash = keccak256(
            abi.encode(
                sequenceNumber,
                delayedMessagesRead,
                l2TEEData,
                address(0),
                subMessageCount,
                nextSubMessageCount
            )
        );

        vm.prank(tx.origin);
        vm.expectRevert();

        //  We expect the TEE attestation quote to be validated
        vm.expectEmit();
        emit TEEAttestationQuoteVerified(sequenceNumber);
        seqInbox.addSequencerL2Batch(
            sequenceNumber,
            l2TEEData,
            delayedMessagesRead,
            IGasRefunder(0x0000000000000000000000000000000000000000),
            subMessageCount,
            nextSubMessageCount,
            sampleQuote
        );
    }

    function testAddSequencerL2BatchWithIncorrectParams() public {
        bytes memory invalidData = hex"012346";
        uint256 subMessageCount = 1;
        uint256 nextSubMessageCount = 18;
        uint256 sequenceNumber = 1;
        uint256 delayedMessagesRead = 10;

        vm.prank(tx.origin);
        vm.expectRevert(abi.encodeWithSelector(InvalidReportDataHash.selector));
        seqInbox.addSequencerL2Batch(
            sequenceNumber,
            invalidData,
            delayedMessagesRead,
            IGasRefunder(0x0000000000000000000000000000000000000000),
            subMessageCount,
            nextSubMessageCount,
            sampleQuote
        );
    }
}
