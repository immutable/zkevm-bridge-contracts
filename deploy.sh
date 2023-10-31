#!/bin/bash
source .env

###
# ARGS:
#  1. deployments JSON object
#  2. contract name
###
function get_deployed_contract() {
    deployments_json_filename=$1
    contract_name=$2
    jq -r --arg cn "$contract_name" '.transactions[] | select(.contractName == $cn) | select(.transactionType == "CREATE") | .contractAddress' "$deployments_json_filename"
}

function main() {

    forge script script/DeployRootContracts.s.sol:DeployRootContracts --broadcast
    forge script script/DeployChildContracts.s.sol:DeployChildContracts --broadcast

    echo "sleepy boy"
    sleep 5

    root_filename="broadcast/DeployRootContracts.s.sol/$ROOT_CHAIN_ID/run-latest.json"
    child_filename="broadcast/DeployChildContracts.s.sol/$CHILD_CHAIN_ID/run-latest.json"
    
    # Extract smart contract addresses from deployments JSON
    root_erc20_bridge=$( get_deployed_contract "$root_filename" "RootERC20Bridge" )
    root_bridge_adaptor=$( get_deployed_contract "$root_filename" "RootAxelarBridgeAdaptor" )
    root_chain_child_token_template=$( get_deployed_contract "$root_filename" "ChildERC20" )
    
    if [ "$ENVIRONMENT" = "local" ]; then
        root_weth_contract=$( get_deployed_contract "$root_filename" "WETH" )
        export ROOT_WETH_ADDRESS=$root_weth_contract
    fi

    child_erc20_bridge_implementation=$( get_deployed_contract "$child_filename" "ChildERC20Bridge" )
    proxies=$( get_deployed_contract "$child_filename" "TransparentUpgradeableProxy" )
    child_bridge_adaptor_implementation=$( get_deployed_contract "$child_filename" "ChildAxelarBridgeAdaptor" )
    child_chain_child_token_template=$( get_deployed_contract "$child_filename" "ChildERC20" )

    echo "Proxies: $proxies"

    implementation_storage_slot="0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc"

    while IFS= read -r proxy_address; do
        echo "... $proxy_address ..."
        implementation_slot_value=$(cast storage --rpc-url "$CHILD_RPC_URL" "$proxy_address" "$implementation_storage_slot")
        implementation_address=$(cast parse-bytes32-address "$implementation_slot_value")
        echo "logic: $implementation_address"
        if [ "$implementation_address" = "$child_erc20_bridge_implementation" ]; then
            child_erc20_bridge_proxy=$proxy_address
        elif [ "$implementation_address" = "$child_bridge_adaptor_implementation" ]; then
            child_bridge_adaptor_proxy=$proxy_address
        fi
    done <<< "$proxies"

    export ROOT_ERC20_BRIDGE=$root_erc20_bridge
    export ROOT_BRIDGE_ADAPTOR=$root_bridge_adaptor
    export ROOTCHAIN_CHILD_TOKEN_TEMPLATE=$root_chain_child_token_template

    export CHILD_BRIDGE_ADAPTOR=$child_bridge_adaptor_proxy
    export CHILD_ERC20_BRIDGE=$child_erc20_bridge_proxy
    export CHILDCHAIN_CHILD_TOKEN_TEMPLATE=$child_chain_child_token_template

    forge script script/InitializeRootContracts.s.sol:InitializeRootContracts --broadcast --ffi
    forge script script/InitializeChildContracts.s.sol:InitializeChildContracts --broadcast --ffi

    # Write JSON file with contract addresses
    echo "{
        \"root_chain_id\": \"$ROOT_CHAIN_ID\",
        \"root_bridge\": \"$root_erc20_bridge\",
        \"root_bridge_adaptor\": \"$root_bridge_adaptor\",
        \"root_chain_child_token_template\": \"$root_chain_child_token_template\",
        \"child_chain_id\": \"$CHILD_CHAIN_ID\",
        \"child_bridge_address\": \"$child_erc20_bridge_proxy\",
        \"child_bridge_adaptor\": \"$child_bridge_adaptor_proxy\",
        \"child_chain_child_token_template\": \"$child_chain_child_token_template\"
    }" | jq . > addresses.json

    return
}


main
