# Axelar cross-chain gateway protocol Aptos implementation

## Getting started
#### Installing rust and move-cli (optional, macOS)
```shell
brew install rustup
rustup-init
cargo install --git https://github.com/move-language/move move-cli --branch main
```


### Installing Aptos CLI
Follow the instructions [here](https://aptos.dev/cli-tools/aptos-cli-tool/install-aptos-cli/#download-precompiled-binary)

### Initializing project
```shell
aptos init
aptos account fund-with-faucet --account default
```

## Local development
### Compile
```shell
aptos move compile --named-addresses axelar=default
```

### Test
```shell
aptos move test --named-addresses axelar=default
```
