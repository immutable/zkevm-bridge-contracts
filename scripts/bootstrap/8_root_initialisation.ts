// Initialise root contracts
import { initialiseRootContracts } from "../deploy/root_initialisation";

async function run() {
    console.log("=======Start Root Initialisation=======");

    await initialiseRootContracts();

    console.log("=======End Root Initialisation=======");
}
run();