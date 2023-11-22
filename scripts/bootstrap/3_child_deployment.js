// Deploy child contracts
'use strict';
require('dotenv').config();
const deploy = require("../deploy/child_deployment.js");

async function run() {
    await deploy.deployChildContracts();
}
run();