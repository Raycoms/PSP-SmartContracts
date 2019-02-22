pragma solidity >=0.4.22 < 0.6.0;

import "./institution_list_test.sol";

contract Vacancy {
    
    enum Phase { Applicant, Reviewer, Result }
    enum ReviewPhase { None, WrittenExam, TitlesAndPub, PracticalExam, OralPresentation, Finish }
     
    Phase public state;
    ReviewPhase public reviewPhase;
    InstitutionList institutionList;
    uint registrationTime;
    uint reviewTime;
    uint price;
    uint reviewerAmount;
    address institution;
    uint[] weights;
    mapping(address => Structs.Applicant) public applicants;
    mapping(address => Structs.Reviewer) reviewers;
    address[] applicantsIndices;
    address[] public reviewersIndices;
    
    
    event ReviewAcceptedEvent(address reviewer);
    event ReviewReceivedEvent(address reviewer, address applicant, uint grade);
    event HashReceivedEvent(address applicant, uint reviewPhase, string hash);
    event ReviewRejectedEvent(address reviewer);
    event ApplicantRegisterEvent(address applicant);
    event ApplicantUnregisterEvent(address applicant);
    event ReviewerRegisterEvent(address reviewer);
    event PhaseChangeEvent(Phase phase);
    
    constructor(address _list, 
                uint _price, 
                uint _reviewerAmount, 
                uint _regDeadline, 
                uint _reviewDeadline,
                uint[] memory _weights) public {
        institutionList = InstitutionList(_list);
        institution = msg.sender;
        institutionList.check(institution);
        price = _price;
        registrationTime = now + _regDeadline;
        reviewTime = registrationTime + _reviewDeadline;
        reviewerAmount = _reviewerAmount;
        weights = _weights;
    }
    
    
    modifier applicantNotRegistered(address appl) {
        require(
            !applicants[appl].registered,
            "Applicant already registered.");
        _;
    }
    
    modifier applicantRegistered(address appl) {
        require(
            applicants[appl].registered,
            "Applicant need to be registered.");
        _;
    }
    
    modifier priceMatch(uint amount) {
        require(
            price == amount,
            "You have to pay the exact value.");
        _;
    }
    
    modifier admin() {
        require(
            msg.sender == institution,
            "You have to be the admin of this application.");
       
        _;
    }
    
    modifier reviewer(address appl) {
        require(
            reviewers[appl].registered,
            "You have to be a reviewer of this application.");
       
        _;
    }
    
    modifier inPhase(Phase _state) {
        require(
            state == _state,
            "Invalid phase."
        );
        _;
    }
    
    function registerApplicant() public 
                        applicantNotRegistered(msg.sender)
                        priceMatch(msg.value)
                        inPhase(Phase.Applicant)
                        payable {
        applicants[msg.sender].registered = true;
        applicantsIndices.push(msg.sender);
        emit ApplicantRegisterEvent(msg.sender);
    }
    
    
    function unregisterApplicant() public 
                        applicantRegistered(msg.sender)
                        inPhase(Phase.Applicant) {
        applicants[msg.sender].registered = false;
        msg.sender.transfer(price);
        uint indexToBeDeleted;
        uint arrayLength = applicantsIndices.length;
        for (uint i=0; i<arrayLength; i++) {
            if (applicantsIndices[i] == msg.sender) {
                indexToBeDeleted = i;
                break;
            }
        }
        // if index to be deleted is not the last index, swap position.
        if (indexToBeDeleted < arrayLength-1) {
          applicantsIndices[indexToBeDeleted] = applicantsIndices[arrayLength-1];
        }
        // we can now reduce the array length by 1
        applicantsIndices.length--;
        emit ApplicantUnregisterEvent(msg.sender);
    }
    
    // Qualquer um pode chamar pois há mecanismos
    // que só aceita se o tempo estiver correto
    function closeRegistering() public 
                        inPhase(Phase.Applicant) {
        require(now > registrationTime, "The registration period ins't over yet.");
        state = Phase.Reviewer;
        reviewPhase = ReviewPhase.WrittenExam;
        address[] memory reviewerList = institutionList.findReviewers(reviewerAmount);
        for(uint i = 0; i < reviewerList.length; i++) {
            address rev = reviewerList[i];
            reviewersIndices.push(rev);
            reviewers[rev].registered = true;
            emit ReviewerRegisterEvent(rev);
        }
        emit PhaseChangeEvent(state);
    }
    
    
    function sendReview(address applicant,
                        uint _grade, uint reviewPhase_) public 
                        inPhase(Phase.Reviewer)
                        reviewer(msg.sender) {
        require(_grade <= 100, 
                    "Grade greater than allowed. Use 0 - 100");
        // Utilizamos essa checkagem para realmente ter certeza que o reviewer sabe qual phase está
        require(uint(reviewPhase) == reviewPhase_, 
            "ReviewPhase insn't equal to actual ReviewPhase");
        require(reviewPhase != ReviewPhase.Finish, "There isn't any more review phase");
        Structs.Applicant storage appl = applicants[applicant];
        require(!appl.disqualified, "The applicant is disqualified.");
        require(appl.reviewPhase == uint(reviewPhase), "The applicant didn't send the hash yet.");
        Structs.Grade storage reviewGrade = appl.grades[msg.sender];
        // caso o reviewer queira alterar a nota
        if (reviewGrade.phase != uint(reviewPhase)) {
            appl.reviewers++;
            reviewGrade.phase = uint(reviewPhase);
        } else {
            if (reviewGrade.grade > 0)
                appl.sum -= reviewGrade.grade;
        }
        appl.sum += _grade;
        reviewGrade.grade = _grade;
        emit ReviewReceivedEvent(msg.sender, applicant, _grade);
    }
 
 
    function sendHash(string memory hash_, uint reviewPhase_) public 
                        inPhase(Phase.Reviewer)
                        applicantRegistered(msg.sender) {

        require(uint(reviewPhase) == reviewPhase_, "ReviewPhase insn't equal to actual ReviewPhase");
        require(reviewPhase != ReviewPhase.Finish, "There isn't any more review phase");
        Structs.Applicant storage appl = applicants[msg.sender];
        require(!appl.disqualified, "You were disqualified.");
        if(appl.reviewPhase != uint(reviewPhase)) {
            appl.sum = 0;
            appl.reviewers = 0;
            appl.reviewPhase = uint(reviewPhase);
        }
        appl.hash = hash_;
        emit HashReceivedEvent(msg.sender, reviewPhase_, hash_);
    }
    
    
    function nextReviewPhase() public 
                                inPhase(Phase.Reviewer) 
                                admin {
        require(reviewPhase != ReviewPhase.Finish, "There isn't any more review phase");
        uint weight = 1; // Os pesos são por padrão peso 1, caso não tenha sido enviado os pesos
        if((uint(reviewPhase) - 2) < weights.length)
            weight = weights[uint(reviewPhase) - 2];
		for (uint i = 0; i < applicantsIndices.length; i++) {
            Structs.Applicant storage applicant = applicants[applicantsIndices[i]];
            if(applicant.disqualified)
                continue;
            uint rev = 1;
            if(applicant.reviewers > 0)
                rev = applicant.reviewers;
            uint result = applicant.sum / rev;
            // Aqui começa a formar a nota do applicant
            applicant.finalGrade += weight * result;
            if(result == 0 || (reviewPhase == ReviewPhase.WrittenExam && result < 70))
                applicant.disqualified = true;
            for (uint j = 0; j < reviewerAmount; j++) {
                address c = reviewersIndices[j];
                // Se a diferença entre média e nota for maior que 30, o reviewer é desonesto
                // Se o reviewer não mandou o review, não influencia no resultado
                // E o reviewer é punido
                if(abs(applicant.grades[c].grade - result) > 30 || applicant.grades[c].phase != uint(reviewPhase)) {
                    // Punish them
                    emit ReviewRejectedEvent(c);
                } else {
                    // TODO  Reward them
                    emit ReviewAcceptedEvent(c);
                }
            }
        }
        reviewPhase = ReviewPhase(uint(reviewPhase) + 1);
    }
    
    // Qualquer um pode chamar pois há mecanismos
    // que só aceita se o tempo estiver correto
    function closeVacancy() public 
                        inPhase(Phase.Reviewer) {
        require(now > reviewTime, "The review period ins't over yet."); //TODO alterar deadline de review
        require(reviewPhase == ReviewPhase.Finish, "There are some review phases yet.");
        state = Phase.Result;
        uint sumWeight = 0;
        for(uint k = 0; k < (uint(ReviewPhase.Finish) - 1); k++) {
            if(k < weights.length)
                sumWeight += weights[k];
            else
                sumWeight += 1;// Os pesos são por padrão peso 1, caso não tenha sido enviado os pesos
        }
        for (uint i = 0; i < applicantsIndices.length; i++) {
            Structs.Applicant storage applicant = applicants[applicantsIndices[i]];
            applicant.finalGrade /= sumWeight;
        }
        emit PhaseChangeEvent(state);
    }
    
    function getResult() public view
                        applicantRegistered(msg.sender)
                        inPhase(Phase.Result) 
                        returns(uint) {
        return applicants[msg.sender].finalGrade;
    }

    function getHash(address applicant) public view
                        applicantRegistered(applicant)
                        returns(string memory) {
        return applicants[applicant].hash;
    }

    function abs(uint i) internal pure returns(uint) {
        if (i > 0)
            return i;
        else
            return -i;
    }
    
}