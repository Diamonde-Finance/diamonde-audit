// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

interface IERC20 {
    function mint(address to, uint256 value) external;

    function transfer(address to, uint256 value) external returns (bool);

    function approve(address spender, uint256 value) external returns (bool);

    function burn(address from, uint256 value) external;

    function allowance(address owner, address spender) external view returns (uint256);

    function decimals() external view returns (uint8);
}

interface IRootDispatch {
    function getSubContractAddress(string memory _name) external view returns (address);
}

interface ISwapRouter {
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 liquidity);
}

interface ArbSys {
    function arbBlockNumber() external view returns (uint256);
}

contract Treasury {
    ArbSys constant arbsys = ArbSys(address(100));
    address public manager;
    address public managerContract;
    address public diaContract;
    address public amdContract;
    address public routerContract;
    address public factoryContract;
    address public mintContract;
    address public stakingContract;
    address public amdReleaseContract;
    address public diaExerciseContract;
    address public usdtContract;
    address public referralContract;
    // init tag
    // uint256 public initTag;

    struct UserMint {
        uint256 totalAmount;
        uint256 withdrewAmount;
        uint256 createHeight;
        uint8 mintType;
    }

    mapping(address => mapping(uint256 => UserMint)) public userMints;
    mapping(address => uint256) public userMintCount;

    mapping(uint256 => uint256) public rateOfBlock;
    uint256 public latestRebaseBlock;
    uint256[] public rateBlocks;

    struct UserStaking {
        uint256 stakingAmount;
        uint256 currentDDIAAmount;
        uint256 totalDDIAAmount;
        uint256 createHeight;
        uint256 recordHeight;
        uint256 usdtValue;
        address[] referrers;
        uint256[] referrerAMDIndexes;
    }

    mapping(address => mapping(uint256 => UserStaking)) public userStakings;
    mapping(address => uint256) public userStakingCount;
    mapping(address => uint256) public totalUserStaking;
    mapping(address => uint256) public userBranchCount;

    struct UserDIAExercise {
        uint256 dAmount;
        uint256 withdrewAmount;
        uint256 createHeight;
        uint256 accelerateTime;
    }

    mapping(address => mapping(uint256 => UserDIAExercise)) public userDIAExercises;
    mapping(address => uint256) public userDIAExerciseCount;

    constructor(address _manager) {
        manager = msg.sender;
        managerContract = _manager;
        diaContract = IRootDispatch(managerContract).getSubContractAddress("DIA_TOKEN");
        amdContract = IRootDispatch(managerContract).getSubContractAddress("AMD_TOKEN");
        routerContract = IRootDispatch(managerContract).getSubContractAddress("SWAP_ROUTER");
        factoryContract = IRootDispatch(managerContract).getSubContractAddress("SWAP_FACTORY");
        mintContract = IRootDispatch(managerContract).getSubContractAddress("MINT");
        stakingContract = IRootDispatch(managerContract).getSubContractAddress("STAKING");
        amdReleaseContract = IRootDispatch(managerContract).getSubContractAddress("AMD_RELEASE");
        diaExerciseContract = IRootDispatch(managerContract).getSubContractAddress("DIA_EXERCISE");
        referralContract = IRootDispatch(managerContract).getSubContractAddress("REFERRAL");
        usdtContract = address(0x22D70Fbd6cbae9D217a5453b7488704F4D35f72C);
        IERC20(usdtContract).approve(routerContract, type(uint256).max);
        IERC20(diaContract).approve(routerContract, type(uint256).max);
        IERC20(amdContract).approve(routerContract, type(uint256).max);
        // initTag = 0;
    }

    receive() external payable {}

    fallback() external payable {}

    // modifier onlyInit() {
    //     require(initTag == 0, "Pool already init before");
    //     _;
    // }

    modifier onlyContract(address allowedContracts) {
        require(msg.sender == allowedContracts, "Caller is not an allowed contract");
        _;
    }

    modifier allInternalContract() {
        require(
            msg.sender == manager || msg.sender == managerContract || msg.sender == mintContract
            || msg.sender == stakingContract || msg.sender == amdReleaseContract || msg.sender == diaExerciseContract,
            "Caller must be Internal Contract"
        );
        _;
    }

    function changeManager(address _to) external onlyContract(manager) {
        manager = _to;
    }

    function refreshContract() external allInternalContract {
        diaContract = IRootDispatch(managerContract).getSubContractAddress("DIA_TOKEN");
        amdContract = IRootDispatch(managerContract).getSubContractAddress("AMD_TOKEN");
        routerContract = IRootDispatch(managerContract).getSubContractAddress("SWAP_ROUTER");
        factoryContract = IRootDispatch(managerContract).getSubContractAddress("SWAP_FACTORY");
        mintContract = IRootDispatch(managerContract).getSubContractAddress("MINT");
        stakingContract = IRootDispatch(managerContract).getSubContractAddress("STAKING");
        amdReleaseContract = IRootDispatch(managerContract).getSubContractAddress("AMD_RELEASE");
        diaExerciseContract = IRootDispatch(managerContract).getSubContractAddress("DIA_EXERCISE");
        referralContract = IRootDispatch(managerContract).getSubContractAddress("REFERRAL");
        IERC20(usdtContract).approve(routerContract, type(uint256).max);
        IERC20(diaContract).approve(routerContract, type(uint256).max);
        IERC20(amdContract).approve(routerContract, type(uint256).max);
    }

    function mintDIA(uint256 _amount) external allInternalContract {
        IERC20(diaContract).mint(address(this), _amount);
    }

    function mintAMD(uint256 _amount) external allInternalContract {
        IERC20(amdContract).mint(address(this), _amount);
    }

    function swapToken(uint256 _amountIn, uint256 _amountOutMin, address[] calldata _path)
    external
    allInternalContract
    returns (uint256[] memory amounts)
    {
        return ISwapRouter(routerContract).swapExactTokensForTokens(
            _amountIn, _amountOutMin, _path, address(this), block.timestamp + 5 minutes
        );
    }

    function addLiquidity(
        address _tokenA,
        address _tokenB,
        uint256 _amountADesired,
        uint256 _amountBDesired,
        uint256 _amountAMin,
        uint256 _amountBMin,
        address _to
    ) external allInternalContract returns (uint256 liquidity) {
        return ISwapRouter(routerContract).addLiquidity(
            _tokenA,
            _tokenB,
            _amountADesired,
            _amountBDesired,
            _amountAMin,
            _amountBMin,
            _to,
            block.timestamp + 5 minutes
        );
    }

    function addUserMint(address _user, uint256 _amount, uint8 _mintType) external onlyContract(mintContract) {
        uint256 index = userMintCount[_user];
        userMints[_user][index] = UserMint({
            totalAmount: _amount,
            withdrewAmount: 0,
            createHeight: arbsys.arbBlockNumber(),
            mintType: _mintType
        });
        userMintCount[_user]++;
    }

    function getUserMint(address _user, uint256 _index)
    external
    view
    returns (uint256 totalAmount, uint256 withdrewAmount, uint256 createHeight, uint8 mintType)
    {
        UserMint memory record = userMints[_user][_index];
        return (record.totalAmount, record.withdrewAmount, record.createHeight, record.mintType);
    }

    function updateUserMint(address _user, uint256 _index, uint256 _withdrewAmount) external allInternalContract {
        UserMint storage record = userMints[_user][_index];
        record.withdrewAmount = _withdrewAmount;
    }

    function transferDIA(address _user, uint256 _amount) external allInternalContract {
        require(IERC20(diaContract).transfer(_user, _amount), "DIA transfer failed");
    }

    function transferAMD(address _user, uint256 _amount) external allInternalContract {
        require(IERC20(amdContract).transfer(_user, _amount), "AMD transfer failed");
    }

    function transferUSDT(address _user, uint256 _amount) external onlyContract(manager) {
        require(IERC20(usdtContract).transfer(_user, _amount), "USDT transfer failed");
    }

    function burnAMD(uint256 _amount) external allInternalContract {
        IERC20(amdContract).burn(address(this), _amount);
    }

    function addUserStaking(
        address _user,
        uint256 _amount,
        uint256 _usdtValue,
        address[] memory _referrers,
        uint256[] memory _indexes
    ) external onlyContract(stakingContract) {
        uint256 stakingId = userStakingCount[_user];

        userStakings[_user][stakingId] = UserStaking({
            stakingAmount: _amount,
            currentDDIAAmount: 0,
            totalDDIAAmount: 0,
            createHeight: arbsys.arbBlockNumber(),
            recordHeight: arbsys.arbBlockNumber(),
            usdtValue: _usdtValue,
            referrers: _referrers,
            referrerAMDIndexes: _indexes
        });

        userStakingCount[_user]++;
        totalUserStaking[_user] += _usdtValue;
    }

    function updateUserBranchCount(address _user, uint256 _count) external onlyContract(stakingContract) {
        userBranchCount[_user] = _count;
    }

    function getUserStaking(address _user, uint256 _index)
    external
    view
    returns (
        uint256 stakingAmount,
        uint256 currentDDIAAmount,
        uint256 totalDDIAAmount,
        uint256 recordHeight,
        uint256 usdtValue,
        address[] memory referrers,
        uint256[] memory referrerAMDIndexes
    )
    {
        UserStaking memory record = userStakings[_user][_index];
        return (
            record.stakingAmount,
            record.currentDDIAAmount,
            record.totalDDIAAmount,
            record.recordHeight,
            record.usdtValue,
            record.referrers,
            record.referrerAMDIndexes
        );
    }

    function updateUserStaking(
        address _user,
        uint256 _index,
        uint256 _stakingAmount,
        uint256 _currentDDIAAmount,
        uint256 _totalDDIAAmount
    ) external allInternalContract {
        UserStaking storage record = userStakings[_user][_index];
        record.stakingAmount = _stakingAmount;
        record.currentDDIAAmount = _currentDDIAAmount;
        record.totalDDIAAmount = _totalDDIAAmount;
        record.recordHeight = arbsys.arbBlockNumber();
        if (_stakingAmount == 0) {
            totalUserStaking[_user] -= record.usdtValue;
            record.usdtValue = 0;
        }
    }

    function addUserDIAExercise(address _user, uint256 _amount, uint256 _accelerateTime)
    external
    onlyContract(diaExerciseContract)
    {
        uint256 userDIAExerciseId = userDIAExerciseCount[_user];
        userDIAExercises[_user][userDIAExerciseId] = UserDIAExercise({
            dAmount: _amount,
            withdrewAmount: 0,
            createHeight: arbsys.arbBlockNumber(),
            accelerateTime: _accelerateTime
        });
        userDIAExerciseCount[_user]++;
    }

    function getUserDIAExercise(address _user, uint256 _index)
    external
    view
    returns (uint256 dAmount, uint256 withdrewAmount, uint256 createHeight, uint256 accelerateTime)
    {
        UserDIAExercise storage record = userDIAExercises[_user][_index];
        return (record.dAmount, record.withdrewAmount, record.createHeight, record.accelerateTime);
    }

    function updateUserDIAExercise(address _user, uint256 _index, uint256 _withdrewAmount, uint256 _accelerateTime)
    external
    onlyContract(diaExerciseContract)
    {
        UserDIAExercise storage record = userDIAExercises[_user][_index];
        record.withdrewAmount = _withdrewAmount;
        record.accelerateTime = _accelerateTime;
    }

    function getRateBlocks() external view returns (uint256[] memory) {
        return rateBlocks;
    }

    function rebaseRate(uint256 _rate) external onlyContract(manager) {
        if (latestRebaseBlock >= arbsys.arbBlockNumber()) {
            return;
        }

        if (rateBlocks.length > 0) {
            uint256 lastBlock = rateBlocks[rateBlocks.length - 1];
            if (rateOfBlock[lastBlock] == _rate) {
                latestRebaseBlock = arbsys.arbBlockNumber();
                return;
            }
        }
        rateOfBlock[arbsys.arbBlockNumber()] = _rate;
        rateBlocks.push(arbsys.arbBlockNumber());
        latestRebaseBlock = arbsys.arbBlockNumber();
    }
}
