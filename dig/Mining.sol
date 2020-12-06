pragma solidity ^0.5.15;

import "./SafeMath.sol";
import "./Ownable.sol";
import "./SafeERC20.sol";
import "./IERC1155.sol";
import "./IERC1155TokenReceiver.sol";

interface PairSwap{
    
    function getPairAmount() external returns(uint256 ethAmoun,uint256 tokenAmount);
}

contract MinConf{
    
    uint256 public constant START_TIME = 1607212800;
    
    uint256 public constant ONE_DAY = 1 days;
    
    uint256 public constant ORE_AMOUNT = 20000;
    
    uint256[10] public  RANKING_AWARD_PERCENT = [10,5,3,1,1,1,1,1,1,1];
    
    uint256 public constant LAST_STRAW_PERCNET = 5;
}

contract Mining is Ownable,IERC1155TokenReceiver,MinConf {
    
    using SafeERC20 for IERC20;
    
    using SafeMath for uint256;
    
    bytes4 constant internal ERC1155_RECEIVED_VALUE = 0xf23a6e61;
    bytes4 constant internal ERC1155_BATCH_RECEIVED_VALUE = 0xbc197c81;
    
    constructor(address tokenAddress,address pairAddress,address erc1155Address,address payable _proAddress) public {
        ERC20Token = IERC20(tokenAddress);
        pairSwap = PairSwap(pairAddress);
        ERC1155 = IERC1155(erc1155Address);
        proAddress = _proAddress;
        carIds = [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0];
    }
    
    IERC20 public ERC20Token;
    
    IERC1155 public ERC1155;
    
    PairSwap public pairSwap;
    
    address payable proAddress;
    
    uint256 public version;
    
    struct Car{
        uint256 fertility;
        uint256 carry;
    }
    
    struct Pair {
        //产生eth收益
        uint256 ethAmount;
        //产生token收益
        uint256 tokenAmount;
        //挖矿总量
        uint256 complete;
        //实际挖矿量
        uint256 actual;
    }
    
    struct Record{
        //提现状态
        bool drawStatus;
        //挖矿总量
        uint256 digGross;
        //最后一击
        bool lastStraw;
        //排名
        uint8 ranking;
    }
    
    
    struct User {
        
        uint256 id;
        
        uint256 investment;
        
        uint256 withdrawVersion;
    }
    
    uint256 public userCounter;
    
    //mapping(uint256 => uint256[18]) erc1155Original;
    //mapping(uint256=>uint256) totalStake;
    mapping(uint256=>mapping(address=>Record)) public records;
    mapping(uint256=> address[10]) public sorts;
    
    mapping(uint256=>Pair) public history;
    
    mapping(address=>User) public users;
    mapping(uint256=>address) public indexs;
    
    mapping(uint256=>Car) public cars;
    
    mapping(uint256=>mapping(address=>bool)) public obtainRecord;
   
    
    uint256[18] public carIds;
    
    
    function setIds(uint256 sn,uint256 id,uint256 fertility,uint256 carry) public onlyOwner{
        carIds[sn] = id;
        cars[id] = Car(fertility,carry);
    }
    
    
    
    function duration() public view returns (uint256){
        if(START_TIME>now){
            return 0;
        }else{
            return now.sub(START_TIME).div(ONE_DAY);
        }
    }
    

    
    
    
    
    
    function stake(uint256 stakeAmount) public {

        ERC20Token.safeTransferFrom(msg.sender,address(this),stakeAmount);
        User storage user = findUser(msg.sender);
        user.investment = user.investment.add(stakeAmount);
        
    }
    
    
    function obtainCar() public  {
        User storage user = findUser(msg.sender);
        
        require(user.investment>0,"Tokens to 0");
        
        
        require(!obtainRecord[duration()][msg.sender],"Have been received");
        uint256 totalSupply = ERC20Token.totalSupply();
        
        uint256 quantity = user.investment.mul(8000).div(totalSupply);
        
       
        uint256[] memory carNum = new uint256[](18);
        uint256[] memory ids = new uint256[](18);
 
        uint256 carId;
        for(uint256 i = 0;i<quantity;i++){
            carId = findCarId(carId);
            carNum[carId] = carNum[carId].add(1);
        }
        
        for(uint8 i = 0;i<18;i++){
            ids[i] = carIds[i];
        }
        
        obtainRecord[duration()][msg.sender] = true;
        ERC1155.setApprovalForAll(msg.sender,true);
        ERC1155.safeBatchTransferFrom(address(this),msg.sender,ids,carNum,"success");
        ERC1155.setApprovalForAll(msg.sender,false);
    }
    
    function withdrawCapital() public {
        require(!obtainRecord[duration()][msg.sender],"Have been received");
        User storage user = findUser(msg.sender);
        uint256 stakeAmount = user.investment;
        require(user.investment>0,"not stake");
        user.investment = 0;
        ERC20Token.safeTransfer(msg.sender,stakeAmount);
        
    }
    
    
    function mining(uint256[] memory ids,uint256[] memory amounts) public returns(uint256){
        Pair storage pair = history[version];
        require(pair.complete>ORE_AMOUNT,"Dig out");
        require(ids.length>0&&ids.length == amounts.length,"error");
        
        uint256 carFertility;
        uint256 carCarry;
        
        uint256 output;
        for(uint256 i = 0;i<ids.length;i++){
            Car memory car = cars[ids[i]];
            carFertility = carFertility.add(car.fertility.mul(amounts[i]));
            carCarry = carCarry.add(car.carry.mul(amounts[i]));
        }
        
        if(carFertility>carCarry){
            output = carCarry;
        }else{
            output = carFertility;
        }
        
    
        uint256 miningQuantity = pair.complete.add(carFertility);
        if(miningQuantity>ORE_AMOUNT){
            output = ORE_AMOUNT.sub(pair.complete);
            lastStraw(msg.sender,pair);
            
        }
        
        //history[msg.sender][version] = history[msg.sender][version].add(output);
        pair.complete = pair.complete.add(output);
        updateRanking(msg.sender);
        ERC1155.safeBatchTransferFrom(msg.sender,address(this),ids,amounts,"success");
        return output;
    }
    
    function updateRanking( address userAddress) private {
        uint256 minVale = records[version][sorts[version][0]].digGross;
        //history[ranking[0]][version];
    
        uint256 lastid;
        for(uint256 i = 0;i<10;i++){
            address rankAddress = sorts[version][i];
              if(records[version][rankAddress].digGross<minVale){
                  minVale = records[version][rankAddress].digGross;
                  lastid= i;
              }
                
        }
        
        if(records[version][userAddress].digGross>minVale){
            sorts[version][lastid] = userAddress;
        }
    }
    
    function getVersionAward(uint256 _version,address userAddress) public view returns(uint256,uint256){
        
        Pair memory pair = history[_version];
        Record memory record = records[_version][userAddress];
        
        uint256 ranking = findRank(userAddress,_version);

        uint256 baseEthAmount = pair.ethAmount.mul(70).div(100);
        uint256 baseTokenAmount = pair.tokenAmount.mul(70).div(100);
        
        uint256 awardEthAmount = pair.ethAmount.mul(30).div(100);
        uint256 awardTokenAmount = pair.tokenAmount.mul(30).div(100);
        
        uint256 userEthAmount;
        uint256 userTokneAmount;
        
        userEthAmount = userEthAmount.add(baseEthAmount.mul(record.digGross).div(ORE_AMOUNT));
        userTokneAmount = userTokneAmount.add(baseTokenAmount.mul(record.digGross).div(ORE_AMOUNT));
        
        if(ranking>0){
            userEthAmount = userEthAmount.add(awardEthAmount.mul(RANKING_AWARD_PERCENT[ranking.sub(1)]).div(30));
            userTokneAmount = userTokneAmount.add(awardTokenAmount.mul(RANKING_AWARD_PERCENT[ranking.sub(1)]).div(30));
        }
        
        if(record.lastStraw){
            userEthAmount = userEthAmount.add(awardEthAmount.mul(LAST_STRAW_PERCNET).div(30));
            userTokneAmount = userTokneAmount.add(awardTokenAmount.mul(LAST_STRAW_PERCNET).div(30));
        }
       
        return (userEthAmount,userTokneAmount);
    }
    
    function findRank(address userAddress,uint256 _version) public view returns(uint256){
        address[10] memory _ranking = sorts[_version];
        
        sort(_ranking);
        
        uint256 rank;
        for(uint8 i =0;i<10;i++){
            if(userAddress == _ranking[i]){
                rank = i;
            }
        }
       
        return rank;
    }
    
    function lastStraw(address userAddress,Pair storage pair) private{
        (uint256 ethAmount,uint256 tokenAmount) = pairSwap.getPairAmount();
        pair.ethAmount = ethAmount;
        pair.tokenAmount = tokenAmount;
        records[version][userAddress].lastStraw = true;    
        //syncSort();  
        transferToProject(ethAmount,tokenAmount,pair);
          
        version= version.add(1);  
    }
    
    //项目方收款
    function transferToProject(uint256 ethAmount,uint256 tokenAmount,Pair storage pair) private{
        
        uint256 proEthAmount = ethAmount.mul(pair.complete.sub(pair.actual)).div(pair.complete);
        uint256 proTokenAmount = tokenAmount.mul(pair.complete.sub(pair.actual)).div(pair.complete);
        
        proAddress.transfer(proEthAmount);
        
        ERC20Token.safeTransfer(proAddress,proTokenAmount);
    }
    
    function withdrawAward() public {
        
       (uint256 ethAward,uint256 tokenAward) =  _getReward(msg.sender);
       
       require(ethAward!=0||tokenAward!=0,"not enough");
       
       users[msg.sender].withdrawVersion = version;
       
       msg.sender.transfer(ethAward);
       ERC20Token.safeTransfer(msg.sender,tokenAward);
       
    }
    
    
    function _getReward(address userAddress) private  returns (uint256,uint256) {
        uint256 startVersion = users[userAddress].withdrawVersion;

        require(version>startVersion,"Have withdrawal");
        
        uint256 userEthAmount;
        uint256 userTokneAmount;
        for(;startVersion<version;startVersion++){
            (uint256 ethAward,uint256 tokenAward) = getVersionAward(startVersion,userAddress);
            
            userEthAmount = userEthAmount.add(ethAward);
            userTokneAmount = userTokneAmount.add(tokenAward);
            
            records[startVersion][userAddress].drawStatus = true;
        }
        
        return (userEthAmount,userTokneAmount);
        
    }
    
    
    function sort(address[10] memory arr) private view returns(address[10] memory ) {
        
        for (uint8 i = 0; i < 10; i++) {
            //默认第一个是最小的。
            address min = arr[i];
            //记录最小的下标
            uint8 index = i;
            //通过与后面的数据进行比较得出，最小值和下标
            for (uint8 j = i + 1; j < 10; j++) {
                if (getDigGross(arr[i]) > getDigGross(arr[j])) {
                    min = arr[j];
                    index = j;
                }
            }
            //然后将最小值与本次循环的，开始值交换
            address temp = arr[i];
            arr[i] = min;
            arr[index] = temp;
            //说明：将i前面的数据看成一个排好的队列，i后面的看成一个无序队列。每次只需要找无需的最小值，做替换
        }
        
        return arr;
    }
    
    function findCarId(uint256 carId) public view returns(uint){
        uint256 ratio = uint256(keccak256(abi.encodePacked(carId, now)));
        return ratio%18;
    }
    
    function getRecord(uint256 _version,address userAddress) external view returns(bool drawStatus,uint256 digGross,bool lastStraw,uint8 ranking){
        
        Record memory record = records[_version][userAddress];
        drawStatus= record.drawStatus;
        digGross = record.digGross;
        lastStraw = record.lastStraw;
        ranking = record.ranking;
    }
    
     function getPersonalStats(uint8 _version,address userAddress) external view returns (uint256[6] memory stats){
         Record memory record = records[_version][userAddress];
         stats[0] = users[userAddress].investment;
         stats[1] = record.digGross;
         
         Pair memory pair = history[_version];
         uint256 baseEthAmount = pair.ethAmount.mul(70).div(100);
         uint256 baseTokenAmount = pair.tokenAmount.mul(70).div(100);
         uint256 userEthAmount = baseEthAmount.mul(record.digGross).div(ORE_AMOUNT);
         uint256 userTokneAmount = baseTokenAmount.mul(record.digGross).div(ORE_AMOUNT);
         
         stats[2] = userEthAmount;
         stats[3] = userTokneAmount;
         
         stats[4] = record.digGross;
         stats[5] = ORE_AMOUNT;
     }
     
     function getSorts(uint256 _version) public view returns(address[10] memory){
         //address[10] memory list = sorts[version];
         return sorts[_version];
     }
    
    
    
    function getDigGross(address userAddress) public view returns(uint256){
        return records[version][userAddress].digGross;
    }
    
    function findUser(address userAddress) private returns(User storage user) {
        User storage udata = users[msg.sender];
        if(udata.id==0){
            userCounter++;
            udata.id = userCounter;
            indexs[userCounter] = userAddress;
        }
        
        return udata;
    }
    
    
    
    function onERC1155Received(address _operator, address _from, uint256 _id, uint256 _value, bytes calldata _data) external returns(bytes4) {
        
        return ERC1155_RECEIVED_VALUE;
    }

    function onERC1155BatchReceived(address _operator, address _from, uint256[] calldata _ids, uint256[] calldata _values, bytes calldata _data) external returns(bytes4) {
        
        return ERC1155_BATCH_RECEIVED_VALUE;
    }

    // ERC165 interface support
    function supportsInterface(bytes4 interfaceID) external view returns (bool) {
        return  interfaceID == 0x01ffc9a7 ||    // ERC165
                interfaceID == 0x4e2312e0;      // ERC1155_ACCEPTED ^ ERC1155_BATCH_ACCEPTED;
    }
    
}