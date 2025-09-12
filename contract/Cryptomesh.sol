// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Cryptomesh - Project.sol
 * @dev A decentralized mesh network coordination smart contract
 * @notice This contract manages node registration, staking, and rewards for the Cryptomesh network
 * @author Cryptomesh Team
 */
contract Project {
    // State variables
    address public owner;
    uint256 public totalNodes;
    uint256 public totalStaked;
    uint256 public constant MINIMUM_STAKE = 1 ether;
    uint256 public constant REWARD_RATE = 100; // 1% per period
    
    // Node structure
    struct Node {
        address nodeAddress;
        uint256 stakedAmount;
        uint256 registrationTime;
        uint256 lastRewardTime;
        uint256 reputation;
        bool isActive;
        string ipAddress;
        uint256 uptime;
    }
    
    // Mappings
    mapping(address => Node) public nodes;
    mapping(address => bool) public isRegistered;
    address[] public nodeAddresses;
    
    // Events
    event NodeRegistered(address indexed nodeAddress, string ipAddress, uint256 stakedAmount);
    event NodeStakeIncreased(address indexed nodeAddress, uint256 additionalStake);
    event RewardsDistributed(address indexed nodeAddress, uint256 rewardAmount);
    event NodeDeregistered(address indexed nodeAddress, uint256 refundedStake);
    
    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    modifier onlyRegisteredNode() {
        require(isRegistered[msg.sender], "Node is not registered");
        _;
    }
    
    modifier validStakeAmount() {
        require(msg.value >= MINIMUM_STAKE, "Insufficient stake amount");
        _;
    }
    
    // Constructor
    constructor() {
        owner = msg.sender;
        totalNodes = 0;
        totalStaked = 0;
    }
    
    /**
     * @dev Core Function 1: Register a new node in the mesh network
     * @param _ipAddress The IP address of the node joining the network
     */
    function registerNode(string memory _ipAddress) external payable validStakeAmount {
        require(!isRegistered[msg.sender], "Node already registered");
        require(bytes(_ipAddress).length > 0, "IP address cannot be empty");
        
        // Create new node
        nodes[msg.sender] = Node({
            nodeAddress: msg.sender,
            stakedAmount: msg.value,
            registrationTime: block.timestamp,
            lastRewardTime: block.timestamp,
            reputation: 100, // Starting reputation
            isActive: true,
            ipAddress: _ipAddress,
            uptime: 0
        });
        
        // Update global state
        isRegistered[msg.sender] = true;
        nodeAddresses.push(msg.sender);
        totalNodes++;
        totalStaked += msg.value;
        
        emit NodeRegistered(msg.sender, _ipAddress, msg.value);
    }
    
    /**
     * @dev Core Function 2: Distribute rewards to active nodes based on their stake and reputation
     * @param _nodeAddress Address of the node to reward
     */
    function distributeRewards(address _nodeAddress) external onlyOwner {
        require(isRegistered[_nodeAddress], "Node is not registered");
        require(nodes[_nodeAddress].isActive, "Node is not active");
        
        Node storage node = nodes[_nodeAddress];
        
        // Calculate time elapsed since last reward
        uint256 timeElapsed = block.timestamp - node.lastRewardTime;
        require(timeElapsed >= 1 hours, "Rewards can only be distributed once per hour");
        
        // Calculate reward based on stake, time, and reputation
        uint256 baseReward = (node.stakedAmount * REWARD_RATE * timeElapsed) / (10000 * 1 hours);
        uint256 reputationMultiplier = node.reputation > 100 ? node.reputation : 100;
        uint256 totalReward = (baseReward * reputationMultiplier) / 100;
        
        // Ensure contract has enough balance
        require(address(this).balance >= totalReward, "Insufficient contract balance for rewards");
        
        // Update node data
        node.lastRewardTime = block.timestamp;
        node.uptime += timeElapsed;
        
        // Transfer reward
        payable(_nodeAddress).transfer(totalReward);
        
        emit RewardsDistributed(_nodeAddress, totalReward);
    }
    
    /**
     * @dev Core Function 3: Update node reputation and manage network quality
     * @param _nodeAddress Address of the node to update
     * @param _reputationChange Positive or negative change in reputation
     * @param _isReliable Whether the node has been reliable in recent operations
     */
    function updateNodeReputation(address _nodeAddress, int256 _reputationChange, bool _isReliable) external onlyOwner {
        require(isRegistered[_nodeAddress], "Node is not registered");
        
        Node storage node = nodes[_nodeAddress];
        
        // Update reputation (with bounds)
        if (_reputationChange > 0) {
            node.reputation += uint256(_reputationChange);
            if (node.reputation > 200) {
                node.reputation = 200; // Max reputation cap
            }
        } else if (_reputationChange < 0) {
            uint256 decrease = uint256(-_reputationChange);
            if (node.reputation > decrease) {
                node.reputation -= decrease;
            } else {
                node.reputation = 0; // Min reputation floor
            }
        }
        
        // Handle unreliable nodes
        if (!_isReliable && node.reputation < 50) {
            node.isActive = false;
            // Could implement slashing logic here
        }
        
        // Reactivate node if reputation improves
        if (_isReliable && !node.isActive && node.reputation >= 75) {
            node.isActive = true;
        }
    }
    
    // Additional utility functions
    
    /**
     * @dev Allow nodes to increase their stake
     */
    function increaseStake() external payable onlyRegisteredNode {
        require(msg.value > 0, "Stake amount must be greater than 0");
        
        nodes[msg.sender].stakedAmount += msg.value;
        totalStaked += msg.value;
        
        emit NodeStakeIncreased(msg.sender, msg.value);
    }
    
    /**
     * @dev Allow nodes to deregister and withdraw their stake
     */
    function deregisterNode() external onlyRegisteredNode {
        Node storage node = nodes[msg.sender];
        uint256 refundAmount = node.stakedAmount;
        
        // Remove node from arrays and mappings
        isRegistered[msg.sender] = false;
        totalNodes--;
        totalStaked -= refundAmount;
        
        // Remove from node addresses array
        for (uint256 i = 0; i < nodeAddresses.length; i++) {
            if (nodeAddresses[i] == msg.sender) {
                nodeAddresses[i] = nodeAddresses[nodeAddresses.length - 1];
                nodeAddresses.pop();
                break;
            }
        }
        
        // Clear node data
        delete nodes[msg.sender];
        
        // Refund stake
        payable(msg.sender).transfer(refundAmount);
        
        emit NodeDeregistered(msg.sender, refundAmount);
    }
    
    /**
     * @dev Get node information
     */
    function getNodeInfo(address _nodeAddress) external view returns (
        uint256 stakedAmount,
        uint256 registrationTime,
        uint256 reputation,
        bool isActive,
        string memory ipAddress,
        uint256 uptime
    ) {
        require(isRegistered[_nodeAddress], "Node is not registered");
        Node memory node = nodes[_nodeAddress];
        
        return (
            node.stakedAmount,
            node.registrationTime,
            node.reputation,
            node.isActive,
            node.ipAddress,
            node.uptime
        );
    }
    
    /**
     * @dev Get all active nodes
     */
    function getActiveNodes() external view returns (address[] memory) {
        address[] memory activeNodes = new address[](totalNodes);
        uint256 activeCount = 0;
        
        for (uint256 i = 0; i < nodeAddresses.length; i++) {
            if (nodes[nodeAddresses[i]].isActive) {
                activeNodes[activeCount] = nodeAddresses[i];
                activeCount++;
            }
        }
        
        // Resize array to actual active count
        assembly {
            mstore(activeNodes, activeCount)
        }
        
        return activeNodes;
    }
    
    /**
     * @dev Emergency function to fund the contract for rewards
     */
    function fundContract() external payable onlyOwner {
        // Contract receives Ether for reward distribution
    }
    
    /**
     * @dev Get contract balance
     */
    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }
    
    /**
     * @dev Emergency withdrawal (only owner)
     */
    function emergencyWithdraw() external onlyOwner {
        payable(owner).transfer(address(this).balance);
    }
}
