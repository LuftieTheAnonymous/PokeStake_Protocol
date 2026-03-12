.PHONY: deploy-contracts-sepolia

deploy-contracts-sepolia:
	forge script script/DeployContracts.s.sol \
		--account laptop_acc \
		--broadcast \
		--rpc-url https://sepolia.drpc.org \
		--verify \
		--etherscan-api-key $(ETHER_SCAN_API_KEY) \
		-vvvvv
