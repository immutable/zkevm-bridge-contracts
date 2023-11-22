// Initialise child contracts
'use strict';
require('dotenv').config();
const init = require("../deploy/child_initialisation.js");

async function run() {
    await init.initialiseChildContracts();
}
run();