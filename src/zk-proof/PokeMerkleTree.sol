pragma solidity ^0.8.27;

contract PokemonMerkleTree {
    uint256 constant FIELD_SIZE = 21888242871839275222246405745257275088548364400416034343698204186575808495617;
    uint256 constant TREE_DEPTH = 20; // 2^20 = ~1M leaves
    
    // Public storage
    bytes32 public currentRoot;
    bytes32[] public roots; // Historical roots
    uint256 public nextLeafIndex = 0;
    
    // Optimization: store the "filled subtrees" for incremental updates
    bytes32[TREE_DEPTH] public filledSubtrees;
    bytes32[TREE_DEPTH] public zeros; // Zero hashes at each level
    
    mapping(bytes32 => bool) public commitments; // Prevent duplicate insertions
    mapping(bytes32 => bool) public nullifiers; // Prevent double-claiming
    
    event Deposit(bytes32 indexed commitment, uint256 leafIndex, uint256 timestamp);
    event Withdrawal(address indexed to, bytes32 nullifier);
    
    constructor() {
        // Initialize zero hashes (Poseidon of 0 at each level)
        zeros[0] = bytes32(0); // Or poseidon(0)
        for (uint256 i = 1; i < TREE_DEPTH; i++) {
            zeros[i] = poseidonHash(zeros[i - 1], zeros[i - 1]);
        }
        currentRoot = zeros[TREE_DEPTH - 1];
        roots.push(currentRoot);
    }
    
    // Add a commitment to the tree
    function addCommitment(bytes32 commitment) external {
        require(!commitments[commitment], "Duplicate commitment");
        require(nextLeafIndex < 2 ** TREE_DEPTH, "Tree is full");
        
        commitments[commitment] = true;
        
        // Update tree incrementally
        bytes32 node = commitment;
        uint256 leafIndex = nextLeafIndex;
        
        for (uint256 i = 0; i < TREE_DEPTH; i++) {
            if ((leafIndex & 1) == 0) {
                // This is a left child, store the sibling on the right
                filledSubtrees[i] = node;
                node = poseidonHash(node, zeros[i]);
            } else {
                // This is a right child, use stored sibling
                node = poseidonHash(filledSubtrees[i], node);
            }
            leafIndex >>= 1;
        }
        
        currentRoot = node;
        roots.push(currentRoot);
        nextLeafIndex++;
        
        emit Deposit(commitment, nextLeafIndex - 1, block.timestamp);
    }
    
    // Helper: check if a root is valid (recent enough)
    function isValidRoot(bytes32 root) public view returns (bool) {
        return root == currentRoot || isHistoricalRoot(root);
    }
    
    function isHistoricalRoot(bytes32 root) public view returns (bool) {
        // Check last 256 roots (or configurable window)
        for (uint256 i = 0; i < roots.length && i < 256; i++) {
            if (roots[roots.length - 1 - i] == root) {
                return true;
            }
        }
        return false;
    }
}
