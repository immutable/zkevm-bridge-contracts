// Deploy root contracts
'use strict';
require('dotenv').config();
const deploy = require("../deploy/root_deployment.js");

async function run() {
    console.log("=======Start Root Deployment=======");

    await deploy.deployRootContracts();

    console.log("=======Start Root Deployment=======");
}
run();