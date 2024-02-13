// Deploy root contracts
import { deployRootContracts } from "../deploy/root_deployment";

async function run() {
    console.log("=======Start Root Deployment=======");

    await deployRootContracts();

    console.log("=======End Root Deployment=======");
}
run();