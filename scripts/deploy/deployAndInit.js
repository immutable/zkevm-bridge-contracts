'use strict';
require('dotenv').config();
const deployChild = require("./child_deployment.js");
const initChild = require("./child_initialisation.js");
const deployRoot = require("./root_deployment.js");
const initRoot = require("./root_initialisation.js");

async function run() {
    await deployChild.deployChildContracts();
    await deployRoot.deployRootContracts();
    await initChild.initialiseChildContracts();
    await initRoot.initialiseRootContracts();
}
run();