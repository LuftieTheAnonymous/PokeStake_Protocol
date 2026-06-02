deploy-contracts-sepolia:
	forge script script/DeployContracts.s.sol \
		--account laptop_acc \
		--broadcast \
		--rpc-url $(RPC_URL_SEPOLIA) \
		--verify \
		--etherscan-api-key $(ETHER_SCAN_API_KEY) \
		-vvvvv
