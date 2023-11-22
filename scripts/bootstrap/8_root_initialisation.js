// Initialise root contracts
'use strict';
require('dotenv').config();
const init = require("../deploy/root_initialisation.js");

async function run() {
    await init.initialiseRootContracts();
}
run();