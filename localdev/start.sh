# Stop previous deployment.
./stop.sh

# Start root & child chain.
npx hardhat node --config ./rootchain.config.js --port 8500 &
npx hardhat node --config ./childchain.config.js --port 8501 &
sleep 3

# Setup root & child chain.
npx hardhat run ./rootchain_setup.js --config ./rootchain.config.js --network localhost
if [ $? -ne 0 ]; then
    ./stop.sh
    echo "Fail to setup rootchain..."
else
    npx hardhat run ./childchain_setup.js --config ./childchain.config.js --network localhost
    if [ $? -ne 0 ]; then
        ./stop.sh
        echo "Fail to setup childchain..."
    else
        echo "Successfully setup root chain and child chain..."
    fi
fi