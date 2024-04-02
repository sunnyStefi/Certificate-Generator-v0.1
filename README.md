## Course Certificate Generator - Dynamic NFT - ERC1155

Fullstack application that simulates a real world certificate-issuer institution.

**Process and Schemas**

An _User_ can buy a Place NFT token, which will enable him to become an _Enrolled Student_ for that particular Course. An examination will take place in real life and one listed Evaluator will register the mark in a specific date.
After that moment, the admin will either:

1. convert the Places to Certificates, which will remain inside the Promoted Student's accounts
2. burn unsold or failed Places

![Timelapse](/img/general.png)
![Timelapse](/img/part_1.png)
![Timelapse](/img/part_2.png)
![Timelapse](/img/part_3.png)


## Recommendations

Use multi-sig wallet such as [Safe](https://app.safe.global/)
Monitor with its own [Forta bot]()

## Security Threat Model

[Rekt-test](https://blog.trailofbits.com/2023/08/14/can-you-pass-the-rekt-test/) ✅

## Frameworks

Foundry
Openzeppelin ERC1155, AccessControl,
Opensea

### Prerequisites

- .env file with 5 metamask accounts private keys (see env. example)
- ADMIN account must have more than 0.5 eth, others more than 0.02 eth
- forge installed

### Deploy interactions to testnet

**make**

1. deploy
2. createCourses
3. setUpEvaluator
4. buyPlaces
5. transferNFT
6. evaluate
7. makeCertificates


## Invariants / Properties
Tested inside stateful fuzz testing

### 1 Course Creation
1. The total amount of courses must be less or equal than the amount of certificates
2. Not more than 100 places per course can be created
3. Only created courses can be removed

### 2 Evaluator
4. An evaluator can be set up only for existing course
5. Not more than 5 evaluators can be made
6. The evaluator can be removed from the course only if both exists

### 3 Purchase
7. An evaluator cannot purchase a place that belongs to a course that he was assigned to
8. Only existing courses can be purchased
9. NFT of a place type must be unique for each student
10. NFT cannot be sent if the student did not buy a course first

### 4 Evaluation
11.  A student cannot do an exam if he did not buy a course
12.  An evaluator cannot be a student and viceversa
13.  The courseId must exist
14.  The student can be evaluated only one time
15.  The mark must be between 1 and 10

### 5 Make certificates
16. The rest of the NFT places (failed student, not purchased) must be removed
17. Only passed student can have a NFT certificate
18. The NFT of a certificate is different from a place NFT certificate
19. No NFT are left that hold the old places NFT url
20. Cannot make a certificate twice

### 6 Funds management
19. Funds can always be withdrawn correctly

### Generic
20. Role assignment action: only users with specific actions can perform certain actions
21. Storage integrity: data is consistent thorughout the contract's execution
22. Getter view should never revert

Handler-based testing