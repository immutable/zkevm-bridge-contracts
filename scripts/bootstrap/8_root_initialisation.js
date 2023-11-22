// Initialise root contracts
'use strict';
require('dotenv').config();
const init = require("../deploy/root_initialisation.js");

async function run() {
    console.log("=======Start Root Initialisation=======");

    await init.initialiseRootContracts();

    console.log("=======End Root Initialisation=======");
}
run();