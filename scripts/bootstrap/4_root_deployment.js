// Deploy root contracts
'use strict';
require('dotenv').config();
const deploy = require("../deploy/root_deployment.js");

async function run() {
    await deploy.deployRootContracts();
}
run();