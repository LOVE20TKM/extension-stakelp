#!/bin/bash

network=$1

echo "========================================="
echo "  One-Click Deploy Extension Factory StakeLp"
echo "  Network: $network"
echo "========================================="
echo ""

# Step 1: Initialize environment
echo "[Step 1/4] Initializing environment..."
source 00_init.sh $network || {
    echo -e "\033[31mError:\033[0m Failed to initialize environment"
    return 1
}
echo -e "\033[32m✓\033[0m Environment initialized"
echo ""

# Step 2: Deploy LOVE20ExtensionFactoryStakeLp
echo "[Step 2/4] Deploying LOVE20ExtensionFactoryStakeLp..."
forge_script_deploy_extension_factory_stakelp || {
    echo -e "\033[31mError:\033[0m Deployment failed"
    return 1
}
echo ""

# Step 3: Load deployed address
source $network_dir/address.extension.factory.stakelp.params
echo -e "\033[32m✓\033[0m Extension Factory StakeLp deployed at: $extensionFactoryStakeLpAddress"
echo ""

# Step 4: Verify contract (if applicable)
echo "[Step 3/4] Contract verification..."
if [[ "$network" == thinkium* ]]; then
    source 03_verify.sh || {
        echo -e "\033[33mWarning:\033[0m Contract verification failed, but deployment was successful"
    }
else
    echo "Skipping contract verification (not a thinkium network)"
fi
echo ""

# Step 5: Run deployment checks
echo "[Step 4/4] Running deployment checks..."
source 99_check.sh || {
    echo -e "\033[33mWarning:\033[0m Some checks failed"
}
echo ""

echo "========================================="
echo -e "\033[32m✓\033[0m Deployment completed successfully!"
echo "========================================="
echo "Extension Factory StakeLp Address: $extensionFactoryStakeLpAddress"
echo "Network: $network"
echo "========================================="

