## Dynamic 1155 NFT - Course Certificate Generator

Situation: each User can buy a Course NFT token, which will enable him to become a Learning Student. 
An exam will take place in real life by one Evaluator in a specific date.
After that specific date, each Course NFT token can either
1. become a Certificate and it can be transfered to the Student's account only if he's been given a mark greater than 6 out of 10
2. it will be burned if the Student has not passed the exam


![Timelapse](/img/timelapse.png)

## Foundry

ERC1155
Opensea

### libs

### Deploy interactions to testnet

Steps:

1.  ALICE Creates 2 courses with 5 and 1 places.
2.  ALICE sets up BOB as evaluator
3.  CARL will buy a course
4.  ALICE sends him a NFT
5.  BOB will evaluate CARL with 7/10
6.  ALICE will make a certificate for CARL and burn all the (4) other courses NFTs
