import * as core from "@actions/core";
import * as github from "@actions/github";
import { readFileSync } from "node:fs";
import { EOL } from "node:os";

const REPORT_TITLE = `# 📃CI Report${EOL}`;
const REPORT_SUFFIX = `${EOL}For a full HTML report run: \`forge coverage --report lcov && genhtml --ignore-errors category --branch-coverage --output-dir coverage lcov.info\``;

export async function run(): Promise<void> {
  const githubToken = core.getInput("github-token", { required: true });
  // eslint-disable-next-line security/detect-non-literal-fs-filename -- path from trusted action input
  const report = readFileSync(
    core.getInput("coverage", { required: true }),
    "utf8",
  );

  const octokit = github.getOctokit(githubToken);
  const { owner, repo } = github.context.repo;
  const pr = github.context.payload.number as number | undefined;

  if (!pr) {
    core.warning("No pull request number found — skipping coverage comment");
    return;
  }

  const { data: comments } = await octokit.rest.issues.listComments({
    owner,
    repo,
    issue_number: pr,
  });

  const existing = comments.find((c) => c.body?.includes(REPORT_TITLE));
  const body = REPORT_TITLE + report + REPORT_SUFFIX;

  if (existing) {
    await octokit.rest.issues.updateComment({
      owner,
      repo,
      comment_id: existing.id,
      body,
    });
  } else {
    await octokit.rest.issues.createComment({
      owner,
      repo,
      issue_number: pr,
      body,
    });
  }
}

run().catch((err: unknown) => {
  core.setFailed(err instanceof Error ? err.message : String(err));
});
