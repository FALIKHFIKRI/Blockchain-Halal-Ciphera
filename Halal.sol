// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title HalalSupplyChain
 * @dev Smart contract for tracking halal products through the supply chain
 */
contract HalalSupplyChain {
    
    // ========== State Variables ==========
    address public admin;
    
    // Role mappings
    mapping(address => bool) public producers;
    mapping(address => bool) public halalAuthorities;
    mapping(address => bool) public distributors;
    mapping(address => bool) public retailers;
    
    // ========== Structs ==========
    struct Batch {
        string productName;
        string batchId;
        address producer;
        address currentOwner;
        string status; // "Produced", "Certified Halal", "In Transit", "At Retailer", "Sold"
        string halalCertHash; // IPFS CID or hash
        uint256 createdAt;
        bool exists;
    }
    
    struct StatusHistory {
        string status;
        uint256 timestamp;
        address updatedBy;
    }
    
    // ========== Mappings ==========
    mapping(string => Batch) public batches;
    mapping(string => StatusHistory[]) public batchHistory;
    string[] public batchIds;
    
    // ========== Events ==========
    event RoleAssigned(address indexed account, string role);
    event RoleRevoked(address indexed account, string role);
    event BatchCreated(string indexed batchId, string productName, address indexed producer, uint256 timestamp);
    event HalalCertified(string indexed batchId, string certHash, address indexed authority, uint256 timestamp);
    event StatusUpdated(string indexed batchId, string newStatus, address indexed updatedBy, uint256 timestamp);
    event BatchTransferred(string indexed batchId, address indexed from, address indexed to, uint256 timestamp);
    
    // ========== Modifiers ==========
    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can perform this action");
        _;
    }
    
    modifier onlyProducer() {
        require(producers[msg.sender], "Only producer can perform this action");
        _;
    }
    
    modifier onlyHalalAuthority() {
        require(halalAuthorities[msg.sender], "Only halal authority can perform this action");
        _;
    }
    
    modifier onlyDistributor() {
        require(distributors[msg.sender], "Only distributor can perform this action");
        _;
    }
    
    modifier onlyRetailer() {
        require(retailers[msg.sender], "Only retailer can perform this action");
        _;
    }
    
    modifier batchExists(string memory _batchId) {
        require(batches[_batchId].exists, "Batch does not exist");
        _;
    }
    
    modifier onlyCurrentOwner(string memory _batchId) {
        require(batches[_batchId].currentOwner == msg.sender, "Only current owner can perform this action");
        _;
    }
    
    // ========== Constructor ==========
    constructor() {
        admin = msg.sender;
    }
    
    // ========== Role Management Functions ==========
    
    function assignProducer(address _account) public onlyAdmin {
        producers[_account] = true;
        emit RoleAssigned(_account, "Producer");
    }
    
    function assignHalalAuthority(address _account) public onlyAdmin {
        halalAuthorities[_account] = true;
        emit RoleAssigned(_account, "HalalAuthority");
    }
    
    function assignDistributor(address _account) public onlyAdmin {
        distributors[_account] = true;
        emit RoleAssigned(_account, "Distributor");
    }
    
    function assignRetailer(address _account) public onlyAdmin {
        retailers[_account] = true;
        emit RoleAssigned(_account, "Retailer");
    }
    
    function revokeProducer(address _account) public onlyAdmin {
        producers[_account] = false;
        emit RoleRevoked(_account, "Producer");
    }
    
    function revokeHalalAuthority(address _account) public onlyAdmin {
        halalAuthorities[_account] = false;
        emit RoleRevoked(_account, "HalalAuthority");
    }
    
    function revokeDistributor(address _account) public onlyAdmin {
        distributors[_account] = false;
        emit RoleRevoked(_account, "Distributor");
    }
    
    function revokeRetailer(address _account) public onlyAdmin {
        retailers[_account] = false;
        emit RoleRevoked(_account, "Retailer");
    }
    
    // ========== Core Supply Chain Functions ==========
    
    /**
     * @dev Create a new batch (only producer)
     */
    function createBatch(string memory _batchId, string memory _productName) public onlyProducer {
        require(!batches[_batchId].exists, "Batch ID already exists");
        require(bytes(_batchId).length > 0, "Batch ID cannot be empty");
        require(bytes(_productName).length > 0, "Product name cannot be empty");
        
        Batch memory newBatch = Batch({
            productName: _productName,
            batchId: _batchId,
            producer: msg.sender,
            currentOwner: msg.sender,
            status: "Produced",
            halalCertHash: "",
            createdAt: block.timestamp,
            exists: true
        });
        
        batches[_batchId] = newBatch;
        batchIds.push(_batchId);
        
        // Add to history
        batchHistory[_batchId].push(StatusHistory({
            status: "Produced",
            timestamp: block.timestamp,
            updatedBy: msg.sender
        }));
        
        emit BatchCreated(_batchId, _productName, msg.sender, block.timestamp);
    }
    
    /**
     * @dev Set halal certificate (only halal authority)
     */
    function setHalalCertificate(string memory _batchId, string memory _certHash) 
        public 
        onlyHalalAuthority 
        batchExists(_batchId) 
    {
        require(bytes(_certHash).length > 0, "Certificate hash cannot be empty");
        
        batches[_batchId].halalCertHash = _certHash;
        batches[_batchId].status = "Certified Halal";
        
        // Add to history
        batchHistory[_batchId].push(StatusHistory({
            status: "Certified Halal",
            timestamp: block.timestamp,
            updatedBy: msg.sender
        }));
        
        emit HalalCertified(_batchId, _certHash, msg.sender, block.timestamp);
    }
    
    /**
     * @dev Update batch status (only current owner or authorized roles)
     */
    function updateStatus(string memory _batchId, string memory _newStatus) 
        public 
        batchExists(_batchId) 
    {
        require(
            batches[_batchId].currentOwner == msg.sender || 
            halalAuthorities[msg.sender],
            "Not authorized to update status"
        );
        require(bytes(_newStatus).length > 0, "Status cannot be empty");
        
        batches[_batchId].status = _newStatus;
        
        // Add to history
        batchHistory[_batchId].push(StatusHistory({
            status: _newStatus,
            timestamp: block.timestamp,
            updatedBy: msg.sender
        }));
        
        emit StatusUpdated(_batchId, _newStatus, msg.sender, block.timestamp);
    }
    
    /**
     * @dev Transfer batch to next party in supply chain
     */
    function transferBatch(string memory _batchId, address _to) 
        public 
        batchExists(_batchId) 
        onlyCurrentOwner(_batchId) 
    {
        require(_to != address(0), "Invalid recipient address");
        require(_to != msg.sender, "Cannot transfer to yourself");
        require(
            producers[_to] || distributors[_to] || retailers[_to],
            "Recipient must have a valid role"
        );
        
        address previousOwner = batches[_batchId].currentOwner;
        batches[_batchId].currentOwner = _to;
        
        // Update status based on recipient role
        if (distributors[_to]) {
            batches[_batchId].status = "In Transit";
            batchHistory[_batchId].push(StatusHistory({
                status: "In Transit",
                timestamp: block.timestamp,
                updatedBy: msg.sender
            }));
        } else if (retailers[_to]) {
            batches[_batchId].status = "At Retailer";
            batchHistory[_batchId].push(StatusHistory({
                status: "At Retailer",
                timestamp: block.timestamp,
                updatedBy: msg.sender
            }));
        }
        
        emit BatchTransferred(_batchId, previousOwner, _to, block.timestamp);
    }
    
    // ========== Query Functions ==========
    
    /**
     * @dev Get batch details
     */
    function getBatch(string memory _batchId) 
        public 
        view 
        batchExists(_batchId) 
        returns (
            string memory productName,
            string memory batchId,
            address producer,
            address currentOwner,
            string memory status,
            string memory halalCertHash,
            uint256 createdAt
        ) 
    {
        Batch memory batch = batches[_batchId];
        return (
            batch.productName,
            batch.batchId,
            batch.producer,
            batch.currentOwner,
            batch.status,
            batch.halalCertHash,
            batch.createdAt
        );
    }
    
    /**
     * @dev Get batch history
     */
    function getBatchHistory(string memory _batchId) 
        public 
        view 
        batchExists(_batchId) 
        returns (StatusHistory[] memory) 
    {
        return batchHistory[_batchId];
    }
    
    /**
     * @dev Get all batch IDs
     */
    function getAllBatchIds() public view returns (string[] memory) {
        return batchIds;
    }
    
    /**
     * @dev Get total number of batches
     */
    function getTotalBatches() public view returns (uint256) {
        return batchIds.length;
    }
    
    /**
     * @dev Check if an address has a specific role
     */
    function hasRole(address _account, string memory _role) public view returns (bool) {
        bytes32 roleHash = keccak256(abi.encodePacked(_role));
        
        if (roleHash == keccak256(abi.encodePacked("Producer"))) {
            return producers[_account];
        } else if (roleHash == keccak256(abi.encodePacked("HalalAuthority"))) {
            return halalAuthorities[_account];
        } else if (roleHash == keccak256(abi.encodePacked("Distributor"))) {
            return distributors[_account];
        } else if (roleHash == keccak256(abi.encodePacked("Retailer"))) {
            return retailers[_account];
        } else if (roleHash == keccak256(abi.encodePacked("Admin"))) {
            return _account == admin;
        }
        
        return false;
    }
}