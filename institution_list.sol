pragma solidity >=0.4.22 < 0.6.0;

library Structs {
    
    struct Institution {
        uint votesNeeded;
        uint votes;
        bool member;
        bool pending;
        address reviewer;
        mapping(address => bool) voting;
    }
    
    
    struct Reviewer {
        bool registered;
        address institution;
    }
    
    struct Applicant {
        bool registered;
        bool disqualified;
        Grade[] reviewGrade;
        
        uint finalGrade;
    }
    
    struct Grade {
        mapping(address => uint) grades;
        mapping(address => bool) reviewRegistered;
        string hash;
        uint reviewers;
        uint sum;
        uint result;
    }
}

contract InstitutionList {
    
    uint registeredInstitutions = 1;
    mapping(address => Structs.Institution) institutions;
    mapping(address => Structs.Reviewer) reviewers;
    address[] reviewerIndices;
    
    
    constructor() public {
        institutions[msg.sender].member = true;
    }
    
    
    modifier onlyMember(address inst) {
        require(
            institutions[inst].member,
            "Only members can call this.");
        _;
    }
    
    
    modifier onlyNotMember(address inst) {
        require(
            !institutions[inst].member,
            "Only non-members can call this.");
        _;
    }
    
    
    modifier onlyPending(address inst) {
        require(
            institutions[inst].pending,
            "Only pending can call this.");
        _;
    }
    
    
    modifier onlyNotPending(address inst) {
        require(
            !institutions[inst].pending,
            "Only non-pending can call this.");
        _;
    }
    
    
    function requestInstitutionRegister() 
                    public 
                    onlyNotMember(msg.sender) 
                    onlyNotPending(msg.sender) {
        institutions[msg.sender].votesNeeded = (registeredInstitutions / 2) + 1;
        institutions[msg.sender].pending = true;
    }
    
    
    function voteInstitution(
            address inst, 
            bool vote) 
            public 
            onlyMember(msg.sender)
            onlyPending(inst) {
                
        require(!institutions[inst].voting[msg.sender], "The institution already voted");
        institutions[inst].voting[msg.sender] = true;
        if (vote) {
            institutions[inst].votes++;
            if(institutions[inst].votes >= institutions[inst].votesNeeded) {
                institutions[inst].member = true;
                institutions[inst].pending = false;
                registeredInstitutions++;
            }
        }
    }
    
    
    function registerReviwer(address reviewer) public onlyMember(msg.sender) {
        require(institutions[msg.sender].reviewer == address(0), "Institution already have a reviewer");
        require(!reviewers[reviewer].registered, "Reviewer already registered.");
        reviewers[reviewer].registered = true;
        reviewers[reviewer].institution = msg.sender;
        reviewerIndices.push(reviewer);
        institutions[msg.sender].reviewer = reviewer;
    }
    
    
    function unregisterReviwer() public onlyMember(msg.sender)  {
        require(institutions[msg.sender].reviewer != address(0), "Institution doesn't have reviewer.");
        address reviewer = institutions[msg.sender].reviewer;
        reviewers[reviewer].registered = false;
        institutions[msg.sender].reviewer = address(0);
        uint indexToBeDeleted;
        uint arrayLength = reviewerIndices.length;
        for (uint i=0; i<arrayLength; i++) {
            if (reviewerIndices[i] == reviewer) {
                indexToBeDeleted = i;
                break;
            }
        }
        // if index to be deleted is not the last index, swap position.
        if (indexToBeDeleted < arrayLength-1) {
          reviewerIndices[indexToBeDeleted] = reviewerIndices[arrayLength-1];
        }
        // we can now reduce the array length by 1
        reviewerIndices.length--;
    }
    
    function findReviewers(uint q) external view returns(address[] memory){
        require(q <= reviewerIndices.length, "Not enough reviewers");
        address[] memory randomReviewers = new address[](q) ;
        if (q < (reviewerIndices.length/2)) {
            uint u;
            for(uint i = 0; i < q; i++) {
                bool trueRand = false;
                u++;
                while(!trueRand) {
                    uint rand = random(u, reviewerIndices.length);
                    address addr = reviewerIndices[rand];
                    if(contains(addr, randomReviewers)){
                        u++;
                        continue;
                    }
                    trueRand = true;
                    randomReviewers[i] = addr;
                }
            }
        } else if (q == reviewerIndices.length) {
            for(uint i = 0; i < q; i++) {
                randomReviewers[i] = reviewerIndices[i];
            }
        } else {
            uint toRemove = reviewerIndices.length - q;
            uint u;
            for(uint i = 0; i < reviewerIndices.length && u < q; i++) {
                if(toRemove > 0) {
                    uint rand = random(i, 2);
                    if(rand == 0) {
                        toRemove--;
                        continue;
                    }
                }
                randomReviewers[u] = reviewerIndices[i];
                u++;
            }
        }
        
        
        return randomReviewers;
    }

    function contains(address addr, address[] memory list) internal pure returns(bool cont) {
        for(uint i = 0; i < list.length; i++) {
            if(addr == list[i]) {
                cont = true;
                break;
            }
        }
    }
    
    function random(uint seed, uint max) internal view returns(uint256){
        return uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty, seed)))%max;
    }
    
    
    function check(address inst) external view onlyMember(inst) {
        
    }
    
    
}