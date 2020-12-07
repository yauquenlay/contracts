pragma solidity ^0.5.10;

library SafeMath {

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }


    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }


    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }


    function mul(uint256 a, uint256 b) internal pure returns (uint256) {



        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }


    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }


    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {

        require(b > 0, errorMessage);
        uint256 c = a / b;


        return c;
    }


    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "SafeMath: modulo by zero");
    }


    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}

contract Context {


    constructor () internal { }


    function _msgSender() internal view returns (address payable) {
        return msg.sender;
    }

    function _msgData() internal view returns (bytes memory) {
        this;
        return msg.data;
    }
}

contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);


    constructor () internal {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }


    function owner() public view returns (address) {
        return _owner;
    }


    modifier onlyOwner() {
        require(isOwner(), "Ownable: caller is not the owner");
        _;
    }


    function isOwner() public view returns (bool) {
        return _msgSender() == _owner;
    }


    function renounceOwnership() public onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }


    function transferOwnership(address newOwner) public onlyOwner {
        _transferOwnership(newOwner);
    }


    function _transferOwnership(address newOwner) internal {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

interface PrizePool {
    
    function allotPrize(address lucky, uint256 amount) external;
    
    function withdraw(address payable lucky,uint256 amount) external returns (uint256);
    
    function getCredit() external view returns(uint256);
    
    function permissions(address userAddress) external view returns (bool);
    
    function prizes(address) external view returns(uint256);
}

interface RecommendPool {
    
    function allotBonus(address[5] calldata ranking,uint256 timePointer) external;
    
    function withdraw(address payable ref,uint256 amount) external;
    
    function allowances(address) external view returns(uint256);
    
    function getCredit() external view returns(uint256);
}

contract Tron2Config{

    uint256 public constant CREATE_TIME = 1605225600;
    //Activity start time
    uint256 public constant START_TIME = 1605240000;
    //one day
    uint256 public constant ONE_DAY = 1 days;
    //Withdrawal cooldown time
    uint256 public constant WITHDRAW_DURATION = 8 hours;
    //Total number of transaction types
    uint8 public constant DEPOSITS_TYPES_COUNT = 3;
    //The total team bonus is 3.3
    uint8 public constant WITHDRAW_MUL = 33;
    //Minimum recharge amount
    uint256 public constant MINIMAL_DEPOSIT = 100 wei;
    //Maximum recharge amount
    uint256 public constant MAXIMAL_DEPOSIT = 100000 wei;
    
    uint256 public luckyPrizeLimit = 10000 wei;

    uint256[3] public overLimit = [100,50,100];
    
    uint256[3] public earn_percent = [1,1,25];
    
    uint256[3] public luckyPercentLimit = [0,50,100];
    
    uint256[15] public MODEL_REWARDS_PERCENTS = [20,10,15,5,5,5,5,5,5,5,6,6,6,6,6];


    uint256 public LEADER_PERCENT = 8;
    uint256 public TRON1_PERCENT = 5;
    uint256 public RECOMMEND_PERCENT = 4;
    uint256 public LUCKY_PERCENT =3;
    
    bool public RECOMMEND_AUTO = true;
    
    bool public FORCE_WITHDRAW = true;
    
    uint256 public freeze_cycle = 30 days;
}


contract Tron2 is Ownable,Tron2Config{
    using SafeMath for uint256;
    
    constructor(address payable _leaderPoolAddress,address payable _tron1PoolAddress,address payable _prizePoolAdress,address payable _recommendPoolAddress) public {
        
        leaderPoolAddress = _leaderPoolAddress;
        tron1PoolAddress = _tron1PoolAddress;
        prizePoolAdress = _prizePoolAdress;
        recommendPoolAddress = _recommendPoolAddress;
        
        prizePool = PrizePool(_prizePoolAdress);
        recommendPool = RecommendPool(_recommendPoolAddress);
    }

    struct Deposit {
        //contract NO
        uint256 id;
        //investment amount
        uint256 amount;
        //Contract Subdivision type0~5
        uint8 modelType;
        //
        uint256 freezeTime;
        //Withdrawal amount
        uint256 withdrawn;

    }

    struct Player{

        address payable referrer;

        bool linkEnable;

        uint256 referralReward;

        Deposit[] deposits;

        bool active;

        uint256 refsCount;

        uint256[3] accumulatives;

        uint256 teamCount;

        uint256 playerDepositAmount;

        uint256 playerWithdrawAmount;

        uint256 teamPerformance;

        uint256 withdrawTime;

    }




    PrizePool public prizePool;
    RecommendPool public recommendPool;
    
    address payable private leaderPoolAddress;
    address payable public tron1PoolAddress;
    address payable private prizePoolAdress;
    address payable private recommendPoolAddress;
    
    

    mapping(address => Player) public players;
    mapping(uint256 => mapping(address => uint256)) performances;
    mapping(uint256 => address[5]) performanceRank;

    //mapping(address => uint256) public luckyPrizes;
    mapping(address => uint256) public referRewards;
    //mapping(address => uint256) public performances;

    uint256 totalDepositAmount;
    uint256 totalWithdrawAmount;

    //Number of players
    uint256 public playersCount;
    //Recharge counter
    uint256 private depositsCounter;
    
    uint256 public timePointer;
    
    
    //销毁A合约
    modifier destroyContractA(address userAddress){
        _;
        
        if(extractable(userAddress)==0){
            players[userAddress].deposits[0] = createDeposit(0,0,0);
        }
    }
    

    function _checkOverLimit(uint8 modelType,uint256 amount,uint256[3] memory accumulatives) private {
        uint256 baseAmount = accumulatives[0];

        if(modelType!=0){
            require(accumulatives[modelType].add(amount)<=baseAmount.mul(overLimit[modelType]).div(100));
        }

    }

    //Team Performance statistics
    function _teamCount(address _ref,uint256 amount,bool active) private{
        address player = _ref;
        for (uint256 i = 0; i < 15; i++) {
            if (player == address(0)||!players[player].linkEnable) {
                break;
            }
            if(!active){
                players[player].teamCount++;
            }
            players[player].teamPerformance = players[player].teamPerformance.add(amount);
            player = players[player].referrer;
        }
    }

    function _genDepositId(uint8 modelType,uint256 amount) private  returns (uint256) {

        uint8 addType = modelType+1;
        uint256 lastStep = address(this).balance.div(5000 wei);
        uint256 nextStep = address(this).balance.add(amount).div(5000 wei);
        uint256 step = nextStep.sub(lastStep).mul(4);

        uint256 amountHash = uint256(keccak256(abi.encodePacked(amount)));
        uint256 lastNum = amountHash.mod(10);
        return depositsCounter = depositsCounter.add(addType).add(step).add(lastNum);
    }

    function _active(address payable ref,Player storage player) private {
        //Statistics of new registered users
        if (!player.active) {
            playersCount = playersCount.add(1);
            player.active = true;
            if(players[ref].linkEnable){
                player.referrer = ref;
                players[ref].refsCount = players[ref].refsCount.add(1);
            }

            players[ref].deposits.push(createDeposit(0,0,0));
        }
    }
    
    function _allotPool(uint256 amount) private {
        
        leaderPoolAddress.transfer(amount.mul(LEADER_PERCENT).div(100));
        tron1PoolAddress.transfer(amount.mul(TRON1_PERCENT).div(100));
        //prizePoolAdress.transfer(amount.mul(LUCKY_PERCENT).div(100));
       // recommendPoolAddress.transfer(amount.mul(RECOMMEND_PERCENT).div(100));
        
    }
    
    function luckyDeposit(uint256 amount,uint256 luckyId,Player storage player) private returns (uint256 luckyPrize,uint8 luckyType) {
        if(!player.linkEnable){
            player.linkEnable = true;
        }
        
        if(luckyId.mod(20) == 0){
            luckyType = 1;
            if(luckyId.mod(100) == 0){
                luckyType = 2;
            }
        }
        
        luckyPrize = amount.mul(luckyPercentLimit[luckyType]).div(100);
        
        if(prizePool.getCredit()>=luckyPrize){
            if(luckyPrize>0){
                prizePool.allotPrize(msg.sender,luckyPrize);
            }
        }

    }
    
    function createDeposit(uint256 depositId,uint8 modelType,uint256 amount) private returns(Deposit memory deopist){

        return Deposit({
            id: depositId,
            amount: amount,
            modelType: modelType,
            freezeTime: now,
            withdrawn: 0
        });
    }
    
    function shootOut(address[5] memory rankingList) public view returns (uint256 sn,uint256 minPerformance){
        
        minPerformance = performances[duration()][rankingList[0]];
        for(uint8 i =0;i<5;i++){
            if(performances[duration()][rankingList[i]]<minPerformance){
                minPerformance = performances[duration()][rankingList[i]];
                sn = i;
            }
        }
        
        return (sn,minPerformance);
    }
    
    function updateRanking(address userAddress) private {
        address[5] memory rankingList = performanceRank[duration()];
        
        (uint256 sn,uint256 minPerformance) = shootOut(rankingList);
        
        if(minPerformance<performances[duration()][userAddress]){
            rankingList[sn] = userAddress;
        }
        performanceRank[duration()] = rankingList;
    }
    
    
    
    function sortRanking(uint256 _duration) public view returns(address[5] memory ranking){
        ranking = performanceRank[_duration];
        
        address tmp;
        for(uint8 i = 1;i<5;i++){
            for(uint8 j = 0;j<5-i;j++){
                if(performances[_duration][ranking[j]]>performances[_duration][ranking[j+1]]){
                    tmp = ranking[j];
                    ranking[j] = ranking[j+1];
                    ranking[j+1] = tmp;
                }
            }
        }
        return ranking;
    }
    
    modifier settleBonus(){
        if(RECOMMEND_AUTO){
            settlePerformance();
        }
        _;
    }
    
    function settlePerformance() public {
        
        if(timePointer<duration()){
            address[5] memory rankingList = sortRanking(timePointer);
            recommendPool.allotBonus(rankingList,timePointer);
            timePointer = duration();
        }
    }
    
    function _statistics(address ref,uint256 amount) private{
        performances[duration()][ref] = performances[duration()][ref].add(amount);
    }

    function makeDeposit(address payable ref, uint8 modelType) public payable /*settleBonus*/ returns (bool) {

        require(now>=START_TIME,"Activity not started");

        require(msg.value.mod(100 wei)==0,"Only multiples of 100 are supported");
        //Verify that the contract type is correct
        require(modelType <= DEPOSITS_TYPES_COUNT, "Wrong deposit type");
        //Check recharge amount
        require(msg.value>= MINIMAL_DEPOSIT&&msg.value <=MAXIMAL_DEPOSIT,"Beyond the limit");

        Player storage player = players[msg.sender];
        require(player.active || ref != msg.sender, "Referal can't refer to itself");

        /*if(modelType == 0){
            require(player.deposits[0].id == 0,"There can only be one A contract");
        }*/

        _checkOverLimit(modelType,msg.value,player.accumulatives);

        bool isActive = player.active;

        _active(ref,player);
        
        _statistics(player.referrer,msg.value);

        _teamCount(player.referrer,msg.value,isActive);
        
        //_allotPool(msg.value);

        uint256 depositId = _genDepositId(modelType,msg.value);
        
        if(modelType==0){
            luckyDeposit(msg.value,depositId,player);
            player.deposits[0] = createDeposit(depositId,modelType,msg.value);
        }else{
            player.deposits.push(createDeposit(depositId,modelType,msg.value));
        }


        player.accumulatives[modelType] = player.accumulatives[modelType].add(msg.value);

        player.playerDepositAmount = player.playerDepositAmount.add(msg.value);
        
        updateRanking(msg.sender);

        totalDepositAmount = totalDepositAmount.add(msg.value);

    }
    
    
    function withdrawYield(uint256 id) public settleBonus returns (uint256){
        
        Player storage player = players[msg.sender];
        require(player.withdrawTime.add(WITHDRAW_DURATION)<now,"error");
        require(id < player.deposits.length, "Out of range");
        Deposit storage deposit = player.deposits[id];
        
        uint256 _income = income(msg.sender,id);
        
        require(_income>0,"Already withdrawn");
        
        (uint256 available,) = quota(msg.sender,_income);
        
        require(available>0,"The withdrawal limit is 0");
        
        deposit.withdrawn = deposit.withdrawn.add(available);
        
        player.playerWithdrawAmount = player.playerWithdrawAmount.add(available);
        totalWithdrawAmount = totalWithdrawAmount.add(available);
        player.withdrawTime = now;
        
        allocateTeamReward(available,msg.sender,deposit.modelType);
        
        return available;
    }
    
    
    function refund(uint256 id) public settleBonus {
        
        Player storage player = players[msg.sender];
        require(player.withdrawTime.add(WITHDRAW_DURATION)<now,"error");
        //Check the serial number of contract
        require(id < player.deposits.length, "Out of range");
        Deposit memory deposit = player.deposits[id];
        
        require(deposit.modelType!=0,"unsupport type");
        
        uint256 _income = income(msg.sender,id);
        (uint256 available,) = quota(msg.sender,_income);
        
        if(FORCE_WITHDRAW){
            require(available==0,"Please draw the proceeds first");
        }
        
        if(deposit.modelType==2){
            require(deposit.freezeTime.add(freeze_cycle) <= now,"Not allowed now");
        }
        
        require(address(this).balance >= deposit.amount, "TRX not enought");
        
        if (id < player.deposits.length.sub(1)) {
          player.deposits[id] = player.deposits[player.deposits.length.sub(1)];
        }
        player.deposits.pop();        
        player.withdrawTime = now;
        player.playerWithdrawAmount = player.playerWithdrawAmount.add(deposit.amount);
        totalWithdrawAmount = totalWithdrawAmount.add(deposit.amount);
        msg.sender.transfer(deposit.amount);
    }
    
    
    function withdrawReferReward() external settleBonus returns (uint256){
        uint256 refReward = referRewards[msg.sender];
        require(players[msg.sender].withdrawTime.add(WITHDRAW_DURATION)<now,"error");
        require(refReward>0,"error ");
        
        (uint256 available,) = quota(msg.sender,refReward);
        
        
        require(address(this).balance >= available,"error");
        
        players[msg.sender].playerWithdrawAmount = players[msg.sender].playerWithdrawAmount.add(available);
        totalWithdrawAmount = totalWithdrawAmount.add(available);
        referRewards[msg.sender] = referRewards[msg.sender].sub(available);
        players[msg.sender].withdrawTime = now;
        msg.sender.transfer(available);
        
        return available;
    }
    
    
    function withdrawLuckyPrize() external settleBonus returns(uint256){
        
        require(players[msg.sender].withdrawTime.add(WITHDRAW_DURATION)<now,"error");
        
        uint256 prize = prizePool.prizes(msg.sender);
        
        (uint256 available,) = quota(msg.sender,prize);
        
        players[msg.sender].playerWithdrawAmount = players[msg.sender].playerWithdrawAmount.add(available);
        totalWithdrawAmount = totalWithdrawAmount.add(available);
        players[msg.sender].withdrawTime = now;
        
        prizePool.withdraw(msg.sender,available);
        
        return available;
    }
    
    
    function withdrawRecommend() external settleBonus returns(uint256){
        
        require(players[msg.sender].withdrawTime.add(WITHDRAW_DURATION)<now,"error");
        
        uint256 recommend = recommendPool.allowances(msg.sender);
        
        (uint256 available,) = quota(msg.sender,recommend);
        
        players[msg.sender].playerWithdrawAmount = players[msg.sender].playerWithdrawAmount.add(available);
        totalWithdrawAmount = totalWithdrawAmount.add(available);
        players[msg.sender].withdrawTime = now;
        
        recommendPool.withdraw(msg.sender,available);
        
        return available;
    }
    
    
    function allocateTeamReward(uint256 _amount, address _player, uint8 modelType) private {
        address player = _player;
        address payable ref = players[_player].referrer;
        uint256 refReward;
        for (uint256 i = 0; i < MODEL_REWARDS_PERCENTS.length; i++) {            
            //Illegal referrer to skip
            if (ref == address(0x0)||!players[ref].linkEnable) {
                break;
            }
            //Invalid user
            if(players[ref].deposits[0].id==0){
                break;
            }
         
            if(players[ref].refsCount<i.add(1)){
                continue;
            }
            
            refReward = (_amount.mul(MODEL_REWARDS_PERCENTS[i]).div(100));
            
            (uint256 available,uint256 undeliverable) = quota(ref,refReward);
            
            //User recommendation reward
            players[ref].referralReward = players[ref].referralReward.add(refReward);            
            referRewards[ref] = referRewards[ref].add(available);
            player = ref;
            ref = players[ref].referrer;
        }
    }    
    

    function duration() public view returns(uint256){
        return duration(START_TIME);
    }

    function duration(uint256 startTime) public view returns(uint256){
        if(now<startTime){
            return 0;
        }else{
            return now.sub(startTime).div(ONE_DAY);
        }
    }

    //收益
    function income(address userAddress,uint256 depositId) public view returns(uint256) {

        Deposit memory deposit = players[userAddress].deposits[depositId];

        uint256 _duration = duration(deposit.freezeTime);
        if(deposit.modelType == 2){
            return deposit.amount.mul(earn_percent[2]).div(100).sub(deposit.withdrawn);
        }else{
            return deposit.amount.mul(earn_percent[2]).div(100).mul(_duration).sub(deposit.withdrawn);
        }
    }
    
    //提款上限
    function withdrawLimit(address userAddress) public view returns(uint256) {
        return players[userAddress].accumulatives[0].mul(WITHDRAW_MUL).div(10);
    }
    
    //可提取
    function extractable(address userAddress) public view returns (uint256) {
        if(players[userAddress].playerWithdrawAmount>=withdrawLimit(userAddress)){
            return 0;
        }else{
            return withdrawLimit(userAddress).sub((players[userAddress].playerWithdrawAmount));
        }
    }
    
    //输出可提取金额
    function quota(address userAddress,uint256 input) public view returns (uint256 available,uint256 undeliverable){
        
        uint256 extractableAmount = extractable(userAddress);
        
        if(input>extractableAmount){
            available = extractableAmount;
            undeliverable = input.sub(extractableAmount);
        }else{
            available = input;
            undeliverable = 0;
        }
        return (available,undeliverable);
    }
    
    
    
    	//The entire network information
    function getGlobalStats() external view returns (uint256[5] memory stats) {
        stats[0] = totalDepositAmount;
        stats[1] = address(this).balance;
        stats[2] = prizePool.getCredit();
        stats[3] = recommendPool.getCredit();
        stats[4] = playersCount;
    
    }
    
    function getPersonalStats(address _player) external view returns (uint256[14] memory stats){
        Player memory player = players[_player];        
        stats[0] = player.accumulatives[0];
        stats[1] = player.accumulatives[1];
        stats[2] = player.accumulatives[0].mul(overLimit[1]).div(100);
        stats[3] = player.accumulatives[2];
        stats[4] = player.accumulatives[0];
        stats[5] = withdrawLimit(_player);
        stats[6] = player.refsCount;
        stats[7] = player.teamCount;
        stats[8] = player.teamPerformance;
        stats[9] = player.playerDepositAmount;
        stats[10] = player.playerWithdrawAmount;
        stats[11] = extractable(_player);
    }
    
    //paging
    function getDeposits(address _player,uint256 page) public view returns (uint256[100] memory deposits) {
        Player memory player = players[_player];
        
        uint256 start = page.mul(10);
        uint256 init = start;
        uint256 _totalRow = player.deposits.length;
        if(start.add(10)<_totalRow){
            _totalRow = start.add(10);
        }
        for (start; start < _totalRow; start++) {
            uint256[10] memory deposit = depositStructToArray(start,player.deposits[start]);
            for (uint256 row = 0; row < 10; row++) {
                deposits[(start.sub(init)).mul(10).add(row)] = deposit[row];
            }
        }
        
        
    }
    
    function depositStructToArray(uint256 depositId,Deposit memory deposit) private view returns (uint256[10] memory depositArray) {
        depositArray[0] = depositId;
        depositArray[1] = deposit.amount;
        depositArray[2] = deposit.modelType;
        depositArray[3] = earn_percent[deposit.modelType];
        depositArray[4] = freeze_cycle;
        depositArray[5] = deposit.freezeTime;
        depositArray[6] = deposit.withdrawn;
        depositArray[7] = 0;
        depositArray[8] = deposit.id;
        depositArray[9] = 0;
    }

}