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
# mint:
# 	@forge script script/Interaction.s.sol:MintBasicNFT $(SEPOLIA_ARGS)

push:
	git add .
	git commit -m "unit tests"
	git push origin main

deploy: 
	sudo rm -rf broadcast && sudo rm -rf cache
	@forge script script/Deployment.s.sol:Deployment $(SEPOLIA_ARGS)

courses:
	forge build --skip script --skip test --skip progress
	
createCourses:
	forge script script/Interaction.s.sol:createCourses $(SEPOLIA_ARGS) 

setUpEvaluator:
	forge script script/Interaction.s.sol:setUpEvaluator $(SEPOLIA_ARGS)

buyCourse:
	forge script script/Interaction.s.sol:buyCourse $(SEPOLIA_ARGS)

transferNFT:
	forge script script/Interaction.s.sol:transferNFT $(SEPOLIA_ARGS)

evaluate:
	forge script script/Interaction.s.sol:evaluate $(SEPOLIA_ARGS)

makeCertificate:
	forge script script/Interaction.s.sol:makeCertificate $(SEPOLIA_ARGS)