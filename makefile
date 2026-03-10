.PHONY: deploy-contracts-sepolia

deploy-contracts-sepolia:
	forge script script/DeployContracts.s.sol \
		--account laptop_acc \
		--broadcast \
		--rpc-url https://sepolia.drpc.org
