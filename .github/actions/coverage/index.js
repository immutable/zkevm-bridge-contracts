const core = require('@actions/core');
const fs = require('fs');

const inputs = {
    coverage: core.getInput('coverage'),
    target: core.getInput('target'),
};


(async () => {
    const { updateComment } = require("../../utils/github");

    const data = fs.readFileSync(inputs.coverage, { encoding: 'utf8', flag: 'r' });
    await updateComment(inputs.target, data);
})();

