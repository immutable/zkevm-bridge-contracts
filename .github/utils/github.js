const { getOctokit, context } = require("@actions/github");
const { EOL } = require('os');
const githubToken = process.env.GITHUB_TOKEN;
const octokit = githubToken && getOctokit(githubToken);

const OWNER = 'immutable';
const REPO = 'zkevm-bridge-contracts';
const REPORT_TITLE = `# 📃CI Report${EOL}`;
const pr = context.payload.number;

const getExistingReportComment = async () => getExistingComment(REPORT_TITLE);

const getExistingComment = async (head) => {
    const { data: comments } = await octokit.rest.issues.listComments({
        owner: OWNER,
        repo: REPO,
        issue_number: pr,
    });
    return comments.find(comment => comment.body.includes(head));
}

const createComment = (report) => {
    return octokit.rest.issues.createComment({
        owner: OWNER,
        repo: REPO,
        issue_number: pr,
        body: report
    });
}

const updateComment = (id, report) => {
    return octokit.rest.issues.updateComment({
        owner: OWNER,
        repo: REPO,
        comment_id: id,
        body: report
    });
}

exports.updateComment = async (target, report) => {
    const comment = await getExistingReportComment();
    if (comment) {
        await updateComment(comment.id, REPORT_TITLE + report);
    } else {
        await createComment(REPORT_TITLE + report);
    }
}