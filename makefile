include .env

.PHONY: all test clean deploy fund help install snapshot format anvil #do no generate any files

#target that has to be executed regardless of its timestamp (PHONY)
all: clean remove install update build

clean  :; forge clean

remove :; rm -rf .gitmodules && rm -rf .git/modules/* && rm -rf lib && touch .gitmodules && git add . && git commit -m "modules"

install :; forge install Cyfrin/foundry-devops@0.1.0 --no-commit && forge install foundry-rs/forge-std@v1.5.3 --no-commit && forge install openzeppelin/openzeppelin-contracts@v4.8.3 --no-commit

update:; forge update

build:; forge build

SEPOLIA_ARGS := --rpc-url $(SEPOLIA_RPC_URL) --private-key $(PRIVATE_KEY) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vvvv

#@ prevents to print the command 
deploy:
	@forge script script/PinkSpace.s.sol:PinkSpaceScript $(SEPOLIA_ARGS) 

mint:
	@forge script script/Interaction.s.sol:MintBasicNFT $(SEPOLIA_ARGS)