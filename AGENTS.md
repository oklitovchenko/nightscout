# Repository maintenance agreements

Read the shared workspace instructions and memory when available. Then
read [the repository map](docs/repository-layout.md) and the documentation
for the affected subsystem. Inspect Git status and the active branch before
editing; preserve unrelated changes and coordinate shared checkouts.

## Responsibilities and delivery

- This repository owns the Nightscout application, image publishing,
  deployment, runtime settings, and application roles/client access.
  `nightscout-infra` owns AWS resources and IAM; `aws-ops` owns account
  OIDC bootstrap and general delegation.
- Apply all persistent operational changes through the owning repository
  and its reviewed delivery mechanism. Do not edit production settings,
  roles, subjects, or records through ad hoc API, database, console, or
  shell commands. Permission approval does not waive the delivery rule.
  Read-only diagnosis and verification remain allowed.
- The only manual bootstrap exception is initial access for `aws-ops`.
  Administrator execution of reviewed repository-generated plans/change
  sets remains an agreed delivery mechanism.
- Keep runtime secrets in GitHub environment secrets and nonsecret settings
  in environment variables. Commit schemas, validation, reconciliation,
  and tests, not personal production settings or credentials.
- Manage application access through `NIGHTSCOUT_ACCESS_OPTIONS_JSON` in
  `production`. Preserve existing subject identities, tokens, API_SECRET,
  unrelated role bindings, and clinical records. Reconcile only declared
  roles and clients; do not introduce automatic deletion or rotation.
- A push tests and publishes an image; production deployment is a separate
  manual workflow action. Do not infer deployment authorization from a
  request to reorganize files, commits, or documentation.

## Code and file placement

- Follow existing application conventions. Keep changes focused and use
  SOLID principles where they clarify ownership, without extra layers.
- Keep changed code, documentation, and commit bodies within 80 columns.
  Do not reformat unrelated upstream code merely to satisfy this limit.
- Write delivery shell scripts in POSIX shell. Do not hide Python or
  JavaScript implementations in shell heredocs. Application code and
  MongoDB/Mocha tests retain their native language where required.
- Keep production delivery code in `deploy/ec2/`, tests in `tests/`, and
  deployment/image/access/sensor-adapter tests in `tests/deployment/`.
  Document test entry points in that directory.
- Keep workflows in `.github/workflows/` and procedural CI orchestration
  in `.github/scripts/`. CI scripts invoke tests rather than contain their
  implementations. Update callers when moving files; preserve behavior.
- Keep account IDs, regions, ARNs, and deployment settings in configuration
  or derive them from infrastructure outputs. Reviewed action SHA pins
  are integrity controls and remain pinned.
- Keep README files concise and current. Document resulting behavior,
  responsibilities, configuration, validation, and material limitations.
  Remove verified obsolete files rather than retaining experimental paths.

## Commit boundaries and messages

- Keep the upstream baseline clean and personal releases on `my-main`.
  Isolate upstream bug fixes so they can be reviewed and transferred alone.
- Keep the current pending upstream API fix and its regression tests as
  the final, separate patch commits in this cleaned release history.
  After upstream acceptance, verify the equivalent change is actually in
  `main` before removing or reverting the local patch and merging the
  updated baseline. Never infer equivalence from PR status alone or undo
  unrelated personal changes. Do not perform this migration automatically.
- Group changes by one completed purpose, not by editing session or tool.
  Split unrelated fixes and independent capabilities into separate commits.
- Separate production code, tests, CI/build orchestration, user-facing
  documentation, and agent instructions into focused commits. Within each
  category, keep one coherent feature or fix together. Do not create one
  commit per file or split tightly coupled implementation changes.
- Order dependencies: implementation before its tests, tests before their
  CI callers, and documentation after the behavior it describes. Tests may
  be written first locally and staged later. Each commit must avoid broken
  references to files or functions introduced only by a later commit.
- Use `type(Scope): Completed action` in concise English. Use `fix` for
  corrected behavior, `feat` for capabilities, `test` for tests, `ci` for
  automation, `docs` for documentation, and `refactor` for behavior-preserving
  restructuring. Choose a technical scope such as `API`, `Build`,
  `Deployment`, `Access`, `Release`, or `Maintenance`; avoid chat-specific
  scopes and mixed topics.
- Write the subject and optional body in completed-action form. Explain
  the final result and why it matters. Do not recount intermediate moves,
  conversations, or experimental attempts, or list changed filenames.
  PR titles and descriptions follow the same rule.
- Before publication, review staged code, comments, documentation, commit
  messages, and PR text for signs of AI-generated filler or assistant work:
  chat/prompt references, canned explanations, tool transcripts, unintended
  authorship trailers, and claims about checks that were not performed.
  Remove such residue; preserve accurate technical explanations, required
  licenses, upstream attribution, and existing legitimate provenance.
- After the explicitly authorized initial history cleanup, use ordinary
  forward commits. Do not rewrite published history, squash accepted work,
  or force-push without a new explicit instruction. Do not leave temporary
  fixup commits or unnecessary branches in the final published result.

## Verification and reporting

- Run checks appropriate to the affected behavior. Mock tests verify local
  delivery decisions; disposable-server tests verify actual API behavior.
  Never run test fixtures against production or erase real data for tests.
- Inspect the final diff and check shell syntax, changed line lengths,
  stale paths, secrets, and unintended files. Preserve behavior during
  structural changes; compare trees when rewriting history.
- Inspect the remote before publishing. For an authorized history rewrite,
  keep a local recovery reference and use an explicit `--force-with-lease`
  tied to the remote commit you reviewed. Never overwrite concurrent work.
- Distinguish local changes, committed changes, published code, successful
  CI, deployment, and live verification. Report skipped checks and material
  limitations honestly. A direct API change is not a CI/CD deployment.
