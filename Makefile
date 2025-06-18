-include .env

.PHONY: all test clean deploy fund help install snapshot format anvil zktest

DEFAULT_ANVIL_KEY := 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

all: clean remove install update build

# Clean the repo
clean  :; forge clean

# Remove modules
remove :; rm -rf .gitmodules && rm -rf .git/modules/* && rm -rf lib && touch .gitmodules && git add . && git commit -m "modules"

install :; forge install eth-infinitism/account-abstraction@v0.8.0 --no-commit && forge install vectorized/solady --no-commit && forge install OpenZeppelin/openzeppelin-contracts --no-commit

# Update Dependencies
update:; forge update

build:; forge build

test :; forge test

snapshot :; forge snapshot

format :; forge fmt

anvil :; anvil -m 'test test test test test test test test test test test junk' --steps-tracing --block-time 1

deploy:
	@forge script script/DeployJustaNameAccount.s.sol:DeployJustaNameAccount $(NETWORK_ARGS)

NETWORK_ARGS := --rpc-url http://localhost:8545 --account $(LOCAL_ACCOUNT) --broadcast

ifeq ($(findstring --network sepolia,$(ARGS)),--network sepolia)
	NETWORK_ARGS := --rpc-url $(SEPOLIA_RPC_URL) --account $(SEPOLIA_ACCOUNT) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vvvv
endif

ifeq ($(findstring --network base-sepolia,$(ARGS)),--network base-sepolia)
	NETWORK_ARGS := --rpc-url $(BASE_SEPOLIA_RPC_URL) --account $(SEPOLIA_ACCOUNT) --broadcast --verify --verifier-url $(SEPOLIA_BASESCAN_API) --etherscan-api-key $(BASESCAN_API_KEY) -vvvv
endif

ifeq ($(findstring --network op-sepolia,$(ARGS)),--network op-sepolia)
	NETWORK_ARGS := --rpc-url $(OP_SEPOLIA_RPC_URL) --account $(SEPOLIA_ACCOUNT) --broadcast --verify --verifier-url $(SEPOLIA_OPSCAN_API) --etherscan-api-key $(OPSCAN_API_KEY) -vvvv
endif

deploy-sepolia:
	@forge script script/DeployJustaNameAccount.s.sol:DeployJustaNameAccount $(NETWORK_ARGS)

deploy-base-sepolia:
	@forge script script/DeployJustaNameAccount.s.sol:DeployJustaNameAccount $(NETWORK_ARGS)

deploy-op-sepolia:
	@forge script script/DeployJustaNameAccount.s.sol:DeployJustaNameAccount $(NETWORK_ARGS)

