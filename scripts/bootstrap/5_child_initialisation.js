// Initialise child contracts
'use strict';
require('dotenv').config();
const init = require("../deploy/child_initialisation.js");

async function run() {
    console.log("=======Start Child Initialisation=======");

    await init.initialiseChildContracts();

    console.log("=======End Child Initialisation=======");
}
run();