pragma solidity ^0.5.15;

import "./SafeMath.sol";
import "./Ownable.sol";
import "./SafeERC20.sol";

contract PairSwap is Ownable{
    
    using SafeERC20 for IERC20;
    
    IERC20 public ERC20Token;
    
    function() payable external{
        
    }
    
    constructor(address tokenAddress) public{
        ERC20Token = IERC20(tokenAddress);
    }
    
    mapping(address=>bool) permissions;
    
    function setPermissions(address permissionAddress,bool stauts) public onlyOwner {
        permissions[permissionAddress] = stauts;
    }
    
    modifier permit(){
        
        require(permissions[msg.sender]);
        _;
    }
    
    function getPairAmount() external permit returns(uint256 ethAmoun,uint256 tokenAmount){
        ethAmoun = 10000 wei;
        tokenAmount = 20000 wei;
        msg.sender.transfer(ethAmoun);
        ERC20Token.safeTransfer(msg.sender,tokenAmount);
        return (ethAmoun,tokenAmount);
    }
}