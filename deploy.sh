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

    root_filename="broadcast/DeployRootContracts.s.sol/$ROOT_CHAIN_ID/run-latest.json"
    child_filename="broadcast/DeployChildContracts.s.sol/$CHILD_CHAIN_ID/run-latest.json"
    
    # Extract smart contract addresses from deployments JSON
    root_proxies=$( get_deployed_contract "$root_filename" "TransparentUpgradeableProxy" )
    root_erc20_bridge_implementation=$( get_deployed_contract "$root_filename" "RootERC20Bridge" )
    root_bridge_adaptor_implementation=$( get_deployed_contract "$root_filename" "RootAxelarBridgeAdaptor" )
    root_chain_child_token_template=$( get_deployed_contract "$root_filename" "ChildERC20" )
    root_proxy_admin=$( get_deployed_contract "$root_filename" "ProxyAdmin" )
    
    if [ "$ENVIRONMENT" = "local" ]; then
        root_weth_contract=$( get_deployed_contract "$root_filename" "WETH" )
        export ROOT_WETH_ADDRESS=$root_weth_contract
    fi

    child_proxies=$( get_deployed_contract "$child_filename" "TransparentUpgradeableProxy" )
    child_erc20_bridge_implementation=$( get_deployed_contract "$child_filename" "ChildERC20Bridge" )
    child_bridge_adaptor_implementation=$( get_deployed_contract "$child_filename" "ChildAxelarBridgeAdaptor" )
    child_chain_child_token_template=$( get_deployed_contract "$child_filename" "ChildERC20" )
    child_proxy_admin=$( get_deployed_contract "$child_filename" "ProxyAdmin" )

    # In the TransparentUpgradeableProxy contract, you have to query the storage slot directly.
    implementation_storage_slot="0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc"

    while IFS= read -r proxy_address; do
        implementation_slot_value=$(cast storage --rpc-url "$CHILD_RPC_URL" "$proxy_address" "$implementation_storage_slot")
        implementation_address=$(cast parse-bytes32-address "$implementation_slot_value")
        if [ "$implementation_address" = "$child_erc20_bridge_implementation" ]; then
            child_erc20_bridge_proxy=$proxy_address
        elif [ "$implementation_address" = "$child_bridge_adaptor_implementation" ]; then
            child_bridge_adaptor_proxy=$proxy_address
        fi
    done <<< "$child_proxies"

    while IFS= read -r proxy_address; do
        implementation_slot_value=$(cast storage --rpc-url "$ROOT_RPC_URL" "$proxy_address" "$implementation_storage_slot")
        implementation_address=$(cast parse-bytes32-address "$implementation_slot_value")
        if [ "$implementation_address" = "$root_erc20_bridge_implementation" ]; then
            root_erc20_bridge_proxy=$proxy_address
        elif [ "$implementation_address" = "$root_bridge_adaptor_implementation" ]; then
            root_bridge_adaptor_proxy=$proxy_address
        fi
    done <<< "$root_proxies"

    export ROOT_ERC20_BRIDGE=$root_erc20_bridge_proxy
    export ROOT_BRIDGE_ADAPTOR=$root_bridge_adaptor_proxy
    export ROOTCHAIN_CHILD_TOKEN_TEMPLATE=$root_chain_child_token_template

    export CHILD_BRIDGE_ADAPTOR=$child_bridge_adaptor_proxy
    export CHILD_ERC20_BRIDGE=$child_erc20_bridge_proxy
    export CHILDCHAIN_CHILD_TOKEN_TEMPLATE=$child_chain_child_token_template

    forge script script/InitializeRootContracts.s.sol:InitializeRootContracts --broadcast --ffi
    forge script script/InitializeChildContracts.s.sol:InitializeChildContracts --broadcast --ffi

    # Write JSON file with contract addresses
    echo "{
        \"root_chain_id\": \"$ROOT_CHAIN_ID\",
        \"root_proxy_admin_address\": \"$root_proxy_admin\",
        \"root_bridge_proxy_address\": \"$root_erc20_bridge_proxy\",
        \"root_bridge_implementation_address\": \"$root_erc20_bridge_implementation\",
        \"root_bridge_adaptor_proxy_address\": \"$root_bridge_adaptor_proxy\",
        \"root_bridge_adaptor_implementation_address\": \"$root_bridge_adaptor_implementation\",
        \"root_chain_child_token_template\": \"$root_chain_child_token_template\",
        \"child_chain_id\": \"$CHILD_CHAIN_ID\",
        \"child_proxy_admin_address\": \"$child_proxy_admin\",
        \"child_bridge_proxy_address\": \"$child_erc20_bridge_proxy\",
        \"child_bridge_implementation_address\": \"$child_erc20_bridge_implementation\",
        \"child_bridge_proxy_adaptor\": \"$child_bridge_adaptor_proxy\",
        \"child_bridge_adaptor_implementation_address\": \"$child_bridge_adaptor_implementation\",
        \"child_chain_child_token_template\": \"$child_chain_child_token_template\"
    }" | jq . > addresses.json

    return
}


main
