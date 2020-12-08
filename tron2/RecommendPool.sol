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

contract RecommendPool is Ownable{
    
    using SafeMath for uint256;
    
    mapping(address=>uint256) public allowances;
    
    mapping(address=>bool) public permissions;
    
    mapping(uint256=>bool) settleStatus;
    
    address payable contractAllow;
    
    uint256 public credit;
    
    uint256[5] public rankPercent = [5,4,3,2,1];
    
    modifier permission(){
        require(permissions[_msgSender()],"not allowed");
        _;
    }
    
    modifier onlyContractAllow(){
        require(_msgSender() == contractAllow,"not allowed");
        _;
    }
    
    function() external payable {
        deposit();
    }
    
    function setContract(address payable contractAddress) public onlyOwner{
        contractAllow = contractAddress;
    }
    
    function setPermissions(address userAddress,bool status) public onlyOwner{
        permissions[userAddress] = status;
    }
    
    function deposit() public payable permission {
        require(msg.value>0,"It's not allowed to be zero");
        credit = credit.add(msg.value);
    }
    
    function allotBonus(address[5] calldata ranking,uint256 timePointer) external onlyContractAllow permission returns (uint256) {
        
        //结算前一天
        require(!settleStatus[timePointer],"Has been settled");
        uint256 bonus;
        
        for(uint8 i= 0;i<5;i++){
            uint256 refBonus = credit.mul(rankPercent[i]).div(100);
            
            allowances[ranking[i]] = allowances[ranking[i]].add(refBonus);
            bonus = bonus.add(refBonus);
        }
        credit = credit.sub(bonus);
        
        settleStatus[timePointer] = true;
        return bonus;
    }
    
    function withdraw(address payable ref,uint256 amount) public permission{
       require(allowances[ref]>=amount,"Lines of 0");
       allowances[ref] = allowances[ref].sub(amount);
       ref.transfer(amount);
    }
    
    function getCredit() public view returns(uint256){
        return credit;
    }
  
}