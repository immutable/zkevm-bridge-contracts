// Deploy child contracts
'use strict';
require('dotenv').config();
const deploy = require("../deploy/child_deployment.js");

async function run() {
    console.log("=======Start Child Deployment=======");

    await deploy.deployChildContracts();
    
    console.log("=======End Child Deployment=======");
}
run();