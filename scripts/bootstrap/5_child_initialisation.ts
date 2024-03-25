// Initialise child contracts
import { initialiseChildContracts } from "../deploy/child_initialisation";

async function run() {
    console.log("=======Start Child Initialisation=======");

    await initialiseChildContracts();

    console.log("=======End Child Initialisation=======");
}
run();