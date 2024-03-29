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
