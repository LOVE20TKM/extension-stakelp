#!/bin/bash

if [[ "$network" != thinkium70001* ]]; then
  echo "Network is not thinkium70001 related, skipping verification"
  return 0
fi

# Ensure environment is initialized
if [ -z "$RPC_URL" ]; then
    source 00_init.sh $network
fi

# Ensure extension factory stakelp address is loaded
if [ -z "$extensionFactoryStakeLpAddress" ]; then
    source $network_dir/address.extension.factory.stakelp.params
fi

if [ -z "$extensionCenterAddress" ]; then
    source $network_dir/address.extension.center.params
fi

verify_contract(){
  local contract_address=$1
  local contract_name=$2
  local contract_path=$3
  local constructor_args=$4

  echo "Verifying contract: $contract_name at $contract_address"

  forge verify-contract \
    --chain-id $CHAIN_ID \
    --verifier $VERIFIER \
    --verifier-url $VERIFIER_URL \
    --constructor-args "$constructor_args" \
    $contract_address \
    $contract_path:$contract_name

  if [ $? -eq 0 ]; then
    echo -e "\033[32m✓\033[0m Contract $contract_name verified successfully"
    return 0
  else
    echo -e "\033[31m✗\033[0m Failed to verify contract $contract_name"
    return 1
  fi
}
echo "verify_contract() loaded"

# Verify LOVE20ExtensionFactoryStakeLp
constructor_args=$(cast abi-encode "constructor(address)" $extensionCenterAddress)
verify_contract $extensionFactoryStakeLpAddress "LOVE20ExtensionFactoryStakeLp" "src/LOVE20ExtensionFactoryStakeLp.sol" "$constructor_args"

