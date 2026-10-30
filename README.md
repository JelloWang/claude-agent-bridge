# claude-agent-bridge

Let [Claude Code](https://claude.com/claude-code) act as the lead agent and hand work to
**other vendors' coding agents running on the same Windows machine** — DeepSeek Harness (DSH)
and Tencent CodeBuddy Code (the engine behind WorkBuddy) — in parallel, then verify and merge
their answers.

[中文说明](README.zh-CN.md)

Claude Code's own sub-agents can only be Claude. These four small Bash scripts are the bridge:
each wraps one agent's headless CLI so the lead can dispatch a job with one command, run several
in the background, and read back plain text.

```
              ┌──────────── Claude Code (lead: split, verify, decide) ────────────┐
              │                                                                    │
   dispatch.sh run/ ds job-a                                 dispatch.sh run/ cb job-b
              │                                                                    │
     ds.sh → DeepSeek Harness                                     cb.sh → CodeBuddy Code
     `dsh --profile headless`                                     `codebuddy -p`
              │                                                                    │
         job-a.out.md ──────────────►  Claude reads both, checks against  ◄──── job-b.out.md
                                       the originals, writes 汇总/summary
```

## What's in here

| File | Does |
|---|---|
| `bin/ds.sh` | Run one DSH headless job: `ds.sh [-C dir] [-m provider/model] "prompt"` |
| `bin/cb.sh` | Run one CodeBuddy job: `cb.sh [-C dir] [-m model] "prompt"` |
| `bin/dispatch.sh` | Run `<job>.task.md` inside a run directory; write `<job>.out.md` and `<job>.log` (timing, exit code, stderr) |
| `bin/_args.sh` | Shared argument parsing (bad usage → exit 2) |
| `config/headless.patch.example.yml` | Route DSH headless through your own OpenAI-compatible provider |
| `examples/*.task.md` | Task templates for a read-only code review and a wiki lint |

## Requirements

- Windows + Git Bash (the scripts handle the Windows-specific traps listed below).
- **DeepSeek Harness** desktop app installed. Tested with 0.2.1-rc.2.
- **CodeBuddy Code**: `npm i -g @tencent-ai/codebuddy-code`, then run `codebuddy` once and `/login`. Tested with 2.178.1.
- Claude Code (or any orchestrator that can run shell commands).

## Setup

```bash
git clone https://github.com/JelloWang/claude-agent-bridge.git
cd claude-agent-bridge
# Only if DSH is not in %LOCALAPPDATA%\Programs\DeepSeek Harness:
echo "DSH_APP='D:\path\to\DeepSeek Harness'" > local.env
# Optional: use your own provider for DSH instead of deepseek-official
cp config/headless.patch.example.yml config/headless.patch.yml   # then edit
bin/ds.sh "Reply with one word: online"
bin/cb.sh "Reply with one word: online"
```

## The run-directory pattern

Give each dispatch its own folder. The external agent's working directory is that folder, and it
only ever sees a **snapshot**, never your originals:

```
runs/20261030-code-review/
  snapshot/            copy of only the files needed; secrets scrubbed; private folders left out
  bugs.task.md         instructions sent out
  bugs.out.md          what the agent returned
  bugs.log             agent, start/end time, elapsed, exit code, stderr
  summary.md           the lead's verified merge — the only file a human needs to read
```

```bash
R=runs/20261030-code-review
bin/dispatch.sh $R ds bugs &      # DSH: correctness
bin/dispatch.sh $R cb security &  # CodeBuddy: security & compliance
wait
```

Rules that kept this safe in practice:

1. **Snapshot, don't point.** Copy only what the job needs. Both agents send what they read to
   their model provider — leave out credential files, `.env`, and anything personal.
2. **Scan the snapshot for secrets before dispatching** (`sk-…`, tokens, passwords) and redact.
   The first real run found a live API key in a tracked `start.bat`.
3. **Read-only by default.** Jobs that must write go to a staging folder; the lead reviews before
   anything lands.
4. **Never let two agents write the same file.**
5. **Verify every finding against the original.** Agents report confidently either way.
6. **If the target is a live service, diff local vs production first.** In the first run both
   agents ranked an already-fixed bug as their #1 finding because the local repo lagged production.

## First real run (2026-10-30)

Four jobs in parallel — two wiki-lint slices and two code-review angles on a production RAG
customer-service bot.

| Job | CodeBuddy | DSH (glm-5.3-flash) |
|---|---|---|
| Code review | 171 s | 329 s |
| Wiki lint | 232 s | 1080 s |

- All four exited 0; snapshots untouched.
- Spot check: 8 of 9 wiki findings were correct (the miss misread a word but the conflict it flagged was real).
- The two agents complemented each other: CodeBuddy caught content-compliance problems (live
  redemption codes in the bot's Q&A data); DSH caught logic flaws (empty retrieval still calls the
  model; a "thinking detector" that truncates normal sales replies).

## Windows traps these scripts already handle

1. **`.cmd` shims break quoted arguments.** `dsh.cmd` and npm's `codebuddy.cmd` go through
   `cmd.exe`; a prompt with spaces splits the executable path. → Call the exe / `node` directly.
2. **DSH headless ignores the credential store.** The bundled headless profile disables
   `dsh-credentials-local` and reports `MISSING_CREDENTIAL`. → `ds.sh` reads `*_API_KEY` entries
   from `~/.dsh/.credentials.yaml` and passes them only to the child process.
3. **DSH headless defaults to `deepseek-official`.** → Override with `--patch` (see the example
   config); `DS_PROVIDER` / `DS_MODEL` env vars pick the model per job.
4. **CodeBuddy's `--allowedTools` is variadic** and swallows the prompt: no output, exit code 0.
   → Use `--allowedTools=Read,Edit,...` followed by `--`.
5. **Git Bash rewrites POSIX-looking arguments** (`/d/foo` → `D:\foo`) when calling native
   programs, silently changing prompts. → `MSYS2_ARG_CONV_EXCL='*'`, and therefore every path handed
   to a native program goes through `cygpath -w` first.
6. **WorkBuddy bundles its own node**, and its version folder changes on upgrade. → `cb.sh`
   searches for the version that has CodeBuddy installed.
7. **GLM-family models may leak their reasoning into the final answer.** Filter when merging.

## Other entry points (not used here)

- DSH: `dsh --profile acp` — Agent Client Protocol over JSON-RPC stdio, with persistent
  multi-session, resume and cancel. Good for a long-running dispatcher.
- CodeBuddy: `--acp`, `--serve` (HTTP + REST), `--output-format json|stream-json`.

## Visibility

DSH headless sessions are saved under `~/.dsh/sessions/<workdir>/` but are not registered in the
desktop sidebar. CodeBuddy CLI sessions live in `~/.codebuddy/projects/`, separate from WorkBuddy's
own history. The run directory is the record of truth.

## License

MIT
