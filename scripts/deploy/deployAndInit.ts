'use strict';
require('dotenv').config();
import { deployChildContracts } from "./child_deployment";
import { initialiseChildContracts } from "./child_initialisation";
import { deployRootContracts } from "./root_deployment";
import { initialiseRootContracts } from "./root_initialisation";

async function run() {
    await deployChildContracts();
    await deployRootContracts();
    await initialiseChildContracts();
    await initialiseRootContracts();
}
run();