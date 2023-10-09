// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.21;

// @notice WIMX is a wrapped IMX contract that allows users to wrap their native IMX.
// @dev This contract is adapted from the official Wrapped ETH contract.
contract WIMX {
    string public name     = "Wrapped IMX";
    string public symbol   = "WIMX";
    uint8  public decimals = 18;

    event  Approval(address indexed src, address indexed guy, uint wad);
    event  Transfer(address indexed src, address indexed dst, uint wad);
    event  Deposit(address indexed dst, uint wad);
    event  Withdrawal(address indexed src, uint wad);

    mapping (address => uint)                       public  balanceOf;
    mapping (address => mapping (address => uint))  public  allowance;

    // @notice Fallback function on recieving native IMX.
    receive() external payable {
        deposit();
    }
    
    // @notice Deposit native IMX in the function call and mint the equal amount of wrapped IMX to msg.sender.
    function deposit() public payable {
        balanceOf[msg.sender] += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    // @notice Withdraw given amount of native IMX to msg.sender and burn the equal amount of wrapped IMX.
    // @params wad The amount to withdraw.
    function withdraw(uint wad) public {
        require(balanceOf[msg.sender] >= wad, "Wrapped IMX: Insufficient balance");
        balanceOf[msg.sender] -= wad;
        
        payable(msg.sender).transfer(wad);
        emit Withdrawal(msg.sender, wad);
    }

    // @notice Obtain the current total supply of wrapped IMX.
    // @return uint The amount of supplied wrapped IMX.
    function totalSupply() public view returns (uint) {
        return address(this).balance;
    }

    // @notice Approve given spender the ability to spend a given amount of msg.sender's tokens.
    // @params guy Approved spender.
    // @params wad Amount of allowance.
    // @return bool Returns true if function call is successful.
    function approve(address guy, uint wad) public returns (bool) {
        allowance[msg.sender][guy] = wad;
        emit Approval(msg.sender, guy, wad);
        return true;
    }

    // @notice Transfer given amount of tokens from msg.sender to given destination.
    // @params dst Destination of this transfer.
    // @params wad Amount of this transfer.
    // @return bool Returns true if function call is successful.
    function transfer(address dst, uint wad) public returns (bool) {
        return transferFrom(msg.sender, dst, wad);
    }

    // @notice Transfer given amount of tokens from given source to given destination.
    // @params src Source of this transfer.
    // @params dst Destination of this transfer.
    // @params wad Amount of this transfer.
    // @return bool Returns true if function call is successful.
    function transferFrom(address src, address dst, uint wad)
        public
        returns (bool)
    {
        require(balanceOf[src] >= wad, "Wrapped IMX: Insufficient balance");

        if (src != msg.sender && allowance[src][msg.sender] != type(uint256).max) {
            require(allowance[src][msg.sender] >= wad, "Wrapped IMX: Insufficient allowance");
            allowance[src][msg.sender] -= wad;
        }

        balanceOf[src] -= wad;
        balanceOf[dst] += wad;

        emit Transfer(src, dst, wad);

        return true;
    }
}