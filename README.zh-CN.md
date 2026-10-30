# claude-agent-bridge

让 [Claude Code](https://claude.com/claude-code) 当主脑，把活派给**同一台 Windows 电脑上别家的编程 agent**：DeepSeek Harness（DSH）和腾讯 CodeBuddy Code（WorkBuddy 的引擎）。它们并行干活，主脑负责核验、合并结果。

[English](README.md)

Claude Code 自己的子代理只能是 Claude。这里的 4 个 Bash 小脚本就是桥：每个脚本包一个 agent 的无界面命令行，主脑一条命令就能派活，可以后台并行，结果以纯文本读回。

## 内容

| 文件 | 作用 |
|---|---|
| `bin/ds.sh` | 跑一个 DSH 无界面任务：`ds.sh [-C 目录] [-m provider/model] "任务"` |
| `bin/cb.sh` | 跑一个 CodeBuddy 任务：`cb.sh [-C 目录] [-m 模型] "任务"` |
| `bin/dispatch.sh` | 在派活目录里执行 `<job>.task.md`，写出 `<job>.out.md` 和 `<job>.log`（耗时、退出码、报错） |
| `bin/_args.sh` | 共用参数解析（用法错误返回码 2） |
| `config/headless.patch.example.yml` | 让 DSH 无界面模式改走你自己的 OpenAI 兼容接口 |
| `examples/*.task.md` | 只读代码审查、维基体检的任务模板 |

## 环境

- Windows + Git Bash。下面列的 Windows 坑脚本都已处理。
- **DeepSeek Harness** 桌面版。实测版本 0.2.1-rc.2。
- **CodeBuddy Code**：`npm i -g @tencent-ai/codebuddy-code`，然后运行一次 `codebuddy`，输入 `/login` 登录。实测版本 2.178.1。
- Claude Code，或任何能执行命令的主控 agent。

## 安装

```bash
git clone https://github.com/JelloWang/claude-agent-bridge.git
cd claude-agent-bridge
# 只有 DSH 不在 %LOCALAPPDATA%\Programs\DeepSeek Harness 时才需要：
echo "DSH_APP='D:\你的路径\DeepSeek Harness'" > local.env
# 可选：DSH 改走自己的模型接口
cp config/headless.patch.example.yml config/headless.patch.yml   # 再按需修改
bin/ds.sh "只回复两个字：在线"
bin/cb.sh "只回复两个字：在线"
```

## 派活目录

每次派活用一个独立目录。外部 agent 的工作目录就是它，只能看到**快照**，碰不到原件：

```
runs/20261030-代码审查/
  snapshot/        只复制需要的文件；先脱敏；私人目录不放进来
  bugs.task.md     派出去的指令
  bugs.out.md      代理交回的结果
  bugs.log         代理、起止时间、耗时、退出码、报错
  summary.md       主脑核验后的合并版，人只需要看这一个
```

实战中守住的规矩：

1. **给快照，不给原件路径。** 两个 agent 都会把读到的内容发给各自的模型服务商。凭据文件、`.env`、私人资料一律不放。
2. **派活前扫快照里的密钥并脱敏。** 第一次实战就扫出一份被 git 跟踪的 `start.bat` 里有明文 API key。
3. **默认只读。** 必须写文件的任务只写到暂存目录，主脑审过再落地。
4. **两个 agent 不许写同一个文件。**
5. **每条结论都要对照原件核验。** agent 说错的时候语气一样笃定。
6. **审线上服务前，先比对本地和线上的文件。** 第一次实战中，两个 agent 的头号结论都是线上早已修好的问题，原因是本地仓库落后于线上。

## 第一次实战（2026-10-30）

4 个任务并行：维基体检切成两半，再加上一个线上 RAG 客服机器人，从两个角度做代码审查。

| 任务 | CodeBuddy | DSH（glm-5.3-flash） |
|---|---|---|
| 代码审查 | 171 秒 | 329 秒 |
| 维基体检 | 232 秒 | 1080 秒 |

- 全部退出码 0，快照没被改动。
- 抽查维基结论 9 条，8 条属实。错的那条读错了一个词，但它指出的冲突是真的。
- 两个 agent 互补：CodeBuddy 抓到内容合规问题（机器人问答库里有真实兑换码）；DSH 抓到逻辑缺陷（检索零命中仍调用模型；"思考检测"会截掉正常的销售回复）。

## 已处理的 Windows 坑

1. **`.cmd` 启动器会拆坏带空格的参数**：`dsh.cmd` 和 npm 生成的 `codebuddy.cmd` 都经过 `cmd.exe`。→ 直接调 exe / `node`。
2. **DSH 无界面模式不读凭据库**：自带的 headless profile 关掉了 `dsh-credentials-local`，会报 `MISSING_CREDENTIAL`。→ `ds.sh` 从 `~/.dsh/.credentials.yaml` 读出 `*_API_KEY`，只传给子进程。
3. **DSH 无界面默认走 `deepseek-official`**。→ 用 `--patch` 覆盖（见示例配置）；每个任务可用 `DS_PROVIDER` / `DS_MODEL` 选模型。
4. **CodeBuddy 的 `--allowedTools` 是可变长参数**，会把任务描述吞掉，结果零输出、退出码 0。→ 写成 `--allowedTools=Read,Edit,...`，后面加 `--`。
5. **Git Bash 会改写像路径的参数**（`/d/foo` → `D:\foo`），任务描述被悄悄改掉。→ 设 `MSYS2_ARG_CONV_EXCL='*'`；因此传给原生程序的路径一律先 `cygpath -w`。
6. **WorkBuddy 自带 node，升级会换版本目录**。→ `cb.sh` 自动找装了 CodeBuddy 的那个版本。
7. **GLM 系模型会把思考过程混进最终答案**。合并时要过滤。

## 其他入口（本项目未使用）

- DSH：`dsh --profile acp`，ACP 协议（JSON-RPC stdio），支持持久多会话、续接、取消，适合做常驻调度。
- CodeBuddy：`--acp`、`--serve`（HTTP + REST）、`--output-format json|stream-json`。

## 客户端能不能看到

DSH 无界面会话存在 `~/.dsh/sessions/<工作目录>/`，但不会登记进桌面版侧边栏。CodeBuddy 命令行会话存在 `~/.codebuddy/projects/`，和 WorkBuddy 自己的历史分开。以派活目录为准。

## 许可

MIT
