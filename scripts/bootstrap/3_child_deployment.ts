// Deploy child contracts
import { deployChildContracts } from "../deploy/child_deployment";

async function run() {
    console.log("=======Start Child Deployment=======");

    await deployChildContracts();
    
    console.log("=======End Child Deployment=======");
}
run();