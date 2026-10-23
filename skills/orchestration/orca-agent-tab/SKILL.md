---
name: orca-agent-tab
description: >-
  Route work to another Orca TUI, in a new tab or a user-selected existing tab.
  Auto-apply when the user names another TUI product (Codex, Claude Code,
  Cursor CLI, Qoder CLI, Gemini CLI, Grok Build CLI, Antigravity, Trae,
  DeepSeek Harness) or
  explicitly selects another agent tab. Do not apply for same-TUI model switches.
  For work that must return a result, use supervised orchestration, wait for
  completion, settle resource ownership, then report here.
---
# Orca Agent Tab

加载 ≠ 开标签。宿主是**当前这条会话的 TUI**。

换模型 ≠ 换产品。点名另一个 TUI 才跨产品；明确指定已有标签时复用该标签。没点名产品或另一标签（包括裸「开终端」「审计一下」）→ 本会话。

| 产品 | Orca agent id |
|---|---|
| Codex | `codex` |
| Claude Code | `claude` |
| Cursor CLI | `cursor` |
| Qoder CLI | `qoder` |
| Gemini CLI | `gemini` |
| Grok Build / Grok CLI | `grok` |
| Antigravity / agy | `antigravity` |
| Trae CLI | `trae` |
| DeepSeek Harness / dsh-tui | `dsh` |

`agy` 是启动命令，不是 agent id；Antigravity 不等于 Gemini CLI。Grok 模型不等于 Grok Build CLI，也不等于 Grok Bot。裸「Grok」按上下文判定；产品与模型仍有歧义时只澄清这一点。

DeepSeek 模型不等于 DeepSeek Harness；在 Trae、OpenCode 等产品中选 DeepSeek 仍是原产品。官方 `dsh` 核心与社区 `dsh-tui` 界面分别核对，按用户选择和宿主实际配置启动；`dsh web`、ACP 或 headless 不能冒充用户指定的终端 TUI。菜单启用不证明已安装或可派发；首次引导或缺少 Key 时停在配置界面，由用户完成凭据配置后再检查输入就绪，不把 Key 写进任务、命令参数或交接材料。

命令细节需要时再 `orca skills get orchestration` 或 `orca skills get orca-cli`。

## 走哪条


| 用户怎么说                      | 走         |
| -------------------------- | --------- |
| 用 Opus/Grok 模型审计；换个模型；本窗口接着做 | 本会话       |
| 让另一个 TUI 审计，或执行后回传结果       | [监督任务](#监督任务) |
| 用已有的某个标签审计并回传 | [复用已有标签](#复用已有标签) |
| 交给另一个 TUI 接着改，不要结果         | [移交](#移交) |
| 就在这里 / 没点名另一产品             | 本会话       |


## 定位

先 `orca status --json`，使用同一可执行文件读取当前版本指南。优先从当前会话或 `worktree show/list`、`terminal list/show` 取得完整 workspace id 与精确 handle；folder 工作区有效，不要求 Git。

示例中的 `<workspace-selector>` 是经 `worktree show` 验证的 `id:<完整workspace-id>`。不要截短返回值，也不要假定环境中的裸 `folder:…` 能用于所有命令。只有调用方绑定明确时才使用官方支持的 `current`；无法定位就澄清，不依赖可见窗口猜测。

跨主机时核对执行主机、材料可读性和该主机的启动入口；本地回环地址不能替远端提供代理。Orca 重启后重新列举 handle，不复用旧 handle。

## 任务合同

每次交给另一个 TUI，只写清角色、目标、材料与范围、允许/禁止动作、输出和停止条件；不要复制目标 Skill 全文。

- 审计：角色是独立审计者，默认只读；验收点证据足够即结论，发现具体矛盾才扩大搜索。
- 执行：角色是受限执行者，只做用户明确授权的写入；回传变更、验证和剩余问题。

## 监督任务

需要回传结果的审计或执行都走监督任务。短任务可用自包含 `--spec`；较长材料放在对方执行主机可读的路径。需要临时交接文件时使用 `.orca/handoffs/` 并记录清理责任；只读任务不为交接而擅自创建报告或方案。

```text
orca orchestration run-create --objective "<谁审计或执行什么>" --json
orca orchestration worker-start --spec "<自包含任务+材料路径>" --task-title "<短标题>" --worktree <workspace-selector> --agent <对方id> --json
```

未被自动识别的协调者显式传 `--from <coordinator-handle>`、`--run <run-id>`；消费消息用 `check --terminal <coordinator-handle> --run <run-id>`。任务依赖或重试才另用 `task-create` + `worker-start --task`。

`--agent` 使用 Orca 当前配置的启动入口、参数和环境，不自行换成裸 CLI 或 alias。保留每产品已有的代理或直连策略；不把协调者的代理变量注入所有 worker，也不在 Skill 固定本机端口、账号、版本或标签 handle。

菜单可启动、模型参数、输入观测、transcript 和完成回传是不同能力，以当前指南和回执分别核对。未指定模型时继承用户设置；`--model/--effort` 只用于当前版本支持的新 agent 启动，不能与 `--terminal` 组合。CLI 自身的参数不等于 Orca 支持范围。

用户明确指定的模型与 effort 必须保留。某启动接口不支持时，先核对是否存在同产品、同模型的官方可用路径；确实无法满足才说明缺口并等用户决定，不自行省略或替换参数，也不切换产品绕过限制。

### 复用已有标签

用户明确选择的标签不另开副本。先用 `terminal list/show/read` 核对产品、执行主机、该标签自己的 workspace 和当前状态，再 `terminal wait --for tui-idle`；空闲且没有其他活动 Dispatch 才 attach。不打断已有任务，不改变模型、登录或网络设置。

```text
orca orchestration worker-start --spec "<自包含任务>" --task-title "<短标题>" --worktree <该标签的workspace-selector> --terminal <精确handle> --json
```

回传后按用户要求记录 `worker-retain`；已有用户标签不执行 `terminal close`。下一轮沿用同一 handle，但创建新 Dispatch，不复用已结算的生命周期 ID。任意窗口数量都按此规则；协调者是当前会话，不固定为某产品。

### Cursor 只读审计兼容分支

以下保留已有的 Cursor Grok high/fast 审计方式，仅用于本次新建的审计标签；复用用户已有 Cursor 标签时不进入 picker、不改全局模型。只从当前 Orca profile 解析 `<cursor-cmd>`，不沿用 `agentDefaultArgs.cursor` 的 `--auto-review`。模型选择会更新 `~/.cursor/cli-config.json`，所以启动前用权限为 `0700` 的临时目录保存模型相关字段：`model`、`selectedModel`、`hasChangedDefaultModel`、`modelParameters`、`modelSelectionHistory`；不得复制凭证或整份配置。

用 Cursor `--list-models` 取得模型列表，同时识别 `grok-<版本>-high-fast` 和 `cursor-grok-<版本>-high-fast`，按数字版本选择最高项（不写死版本）。当前 CLI 可能列出该 id 却拒绝用它启动；因此去掉可选的 `cursor-` 前缀和 `-high-fast` 后缀得到 `<grok-base-id>`。先进入 TUI picker，再用该基础 id 筛选并显式设置参数：

```text
orca terminal create --worktree <workspace-selector> --title "<短标题>" --command '<cursor-cmd> --plan --yolo --trust' --json
orca terminal wait --terminal <handle> --for tui-idle --timeout-ms 60000 --json
orca terminal send --terminal <handle> --text "/model" --enter --json
orca terminal wait --terminal <handle> --for tui-idle --timeout-ms 60000 --json
orca terminal read --terminal <handle> --limit 80 --json
<把 <grok-base-id> 拆成单个字符，按顺序逐次执行 terminal send --text "<字符>"，不带 --enter>
orca terminal wait --terminal <handle> --for tui-idle --timeout-ms 60000 --json
orca terminal read --terminal <handle> --limit 80 --json
orca terminal send --terminal <handle> --text $'\t' --json
orca terminal wait --terminal <handle> --for tui-idle --timeout-ms 60000 --json
orca terminal read --terminal <handle> --limit 80 --json
<按当前界面用 ↑/↓ 与 Enter 或 Space，将 effort 设为 high、fast 设为 true；连续移动高亮时不 wait，每个参数修改后读取确认>
orca terminal send --terminal <handle> --text $'\e' --json
orca terminal wait --terminal <handle> --for tui-idle --timeout-ms 60000 --json
orca terminal read --terminal <handle> --limit 80 --json
orca terminal send --terminal <handle> --text $'\r' --json
orca terminal wait --terminal <handle> --for tui-idle --timeout-ms 60000 --json
<记录本次模型字段作为审计指纹>
orca terminal read --terminal <handle> --limit 80 --json
orca orchestration worker-start --spec "<自包含审计任务+材料路径>" --worktree <workspace-selector> --terminal <handle> --json
```

`--plan` 保持只读；`--yolo` 仅在此审计分支启用以避免命令审批；`--trust` 跳过 workspace trust 提示。picker 只处理单字符输入事件，所以筛选词必须逐字符发送。三个状态门必须逐一成立：`/model` 后看到模型列表；输入 `<grok-base-id>` 后只剩目标版本；Tab 后进入 `Edit Parameters`。参数设定后先退回模型列表，再按 Enter 确认。最后覆盖记录审计指纹并读取状态栏；只有配置字段与状态栏都显示动态版本、`high` 和 `fast` 才能 `worker-start`。任一状态不符即失败收口，不盲发按键、不降级或硬编码模型。任务仍须明确不修改文件、不外传材料。其他审计方继续使用上面的 `--agent` 路径。

`ready` 后告诉用户新建或复用了哪个标签。`input_accepted` 只证明输入接收；若 turn 观测不支持，用后续输出和有效 `worker_done` 验证，不重复投递。`worker-start` 非零退出时先读失败阶段和残留资源，按当前官方 recovery 指南处理，不盲目重开。

```text
orca orchestration check --wait --types worker_done,escalation,question --timeout-ms 45000 --json
```

超时不是失败。连续三次空等后按官方指南 `worker-list --run <run-id>` 核对 liveness 与 nextAction，再等待或取证；没有退出证明不取消或重试。用户插话先回应，worker 继续，随后恢复等待。

### Cursor 运行中追加

只在同一 Cursor 审计尚未 `worker_done` 且确需纠偏或收口时追加；普通超时仍继续 wait。先 `terminal read` 确认 Cursor 正在工作，再向精确 `<handle>` 发送一次：

```text
orca terminal send --terminal <handle> --text "<追加指令>" --enter --json
orca terminal read --terminal <handle> --limit 80 --json
```

这一次 Enter 默认把指令排到当前思考之后，不打断。`accepted: true` 只证明 PTY 收到输入；读取当前界面确认追加项已进入 follow-up 队列后，才能报告“已排队”，不要依赖固定版本或固定界面文案。只有用户要求立即处理，或证据已经足够但审计仍明显失控扩展时，才从已确认的队列状态开始逐步推进；每轮只单独发送一次 Enter，并立即读取：

```text
orca terminal send --terminal <handle> --enter --json
orca terminal read --terminal <handle> --limit 80 --json
```

排队后的第一次额外 Enter 请求 steer；读取确认追加项进入 steering 状态后仍不能称“已消费”。仅当当前界面继续明确提供 interrupt/send 动作且确实需要立刻打断时，才再执行上面同一组命令一次；读取到该追加内容成为新的用户输入并触发新一轮处理，才能报告“已消费”。不要用 `--interrupt` 代替，不要一次发送多个 Enter，也不要无状态门连发。同一指令不要再用 `orchestration send` 重复投递；那是结构化 inbox mail，不是 prompt injection。

### 收口门

收到 `worker_done` 后核对预期 Task/Dispatch、发送方与明确 outcome，缓存结果并处理整个消息批次。每个已结算 worker 立即选择下一轮新 Dispatch 复用、用户要求的 `worker-retain`，或 `worker-release`；完成所有权决定及本次临时材料清理后才 ack、报告和继续副作用操作。release pending/unknown 时按回执恢复，不直接关闭。

只有本次为审计自定义创建、未被用户接管或要求保留的 Cursor 临时终端需要手动关闭；release 返回 `external_terminal` 后执行 `orca terminal close --terminal <handle> --json`，并用 `terminal list` 确认精确 handle 已消失。

本次 Cursor 临时终端确认关闭后重读模型字段：仅当它们仍与本次审计指纹一致时，把启动前快照的五个字段合并回当前完整 JSON；用同目录临时文件保留原权限并原子替换，禁止用快照覆盖整份配置。若不同，说明期间有人主动换过模型，禁止恢复并告知用户。恢复后删除本次精确临时目录。

若 handoff 标为临时，恢复后删除本次精确文件。资源确认、Cursor 模型恢复和临时材料清理全部完成后再 `--ack`；随后才在本会话报告结果、处理审计意见或继续后续任务。审计结果用认可/不认可表述，不认可写清原因，不贴 TUI 原文。

快照与指纹都只用 `jq '{model,selectedModel,hasChangedDefaultModel,modelParameters,modelSelectionHistory}'` 提取。恢复用 `jq --slurpfile before <before.json>` 将 `$before[0]` 的这五个字段逐一赋回当前完整配置，输出到 `~/.cursor/` 下的临时文件；保留原权限后再原子替换 `cli-config.json`，不得写回 `authInfo` 等其他字段。

模型选择失败或状态不符时，清理本次尚未挂 worker 的 Cursor 临时终端；已挂 worker 或 `worker-start` 返回失败/未知时按官方 recovery 回执处理，不因超时强制 release 或 close。只有本次模型字段仍匹配审计指纹才合并恢复，并清理本次临时目录；不得关闭用户原有标签。

## 移交

移交也遵守任务合同，但任务交出后由对方拥有；本会话不等待、不 release。

```text
orca terminal create --worktree <workspace-selector> --title "<短标题>" --command '<cmd> <args>' --json
orca terminal wait --terminal <handle> --for tui-idle --timeout-ms 60000 --json
orca terminal send --terminal <handle> --text "<任务>" --enter --json
orca terminal switch --terminal <handle> --json
```

`cmd`/`args`/环境从实际活动的 Orca profile 核对 `agentCmdOverrides`、`agentDefaultArgs`、`agentDefaultEnv`；通过当前版本提供的只读接口或设置界面确认，不把旧 JSON glob 当作活动配置，不直接写运行中的持久化数据库。保留该产品已有网络策略。命令须为可执行路径或 PATH 名，不能是 alias。纯移交不建 Run/Task，不 `check --wait`。

## 例子

- 「用 opus 审计当前方案」→ 本会话
- 「当前实现让 Codex 审计」→ 监督任务
- Codex 里「让 Cursor 审计」→ 监督任务
- 「让 Cursor 改完把结果带回来」→ 监督任务
- 「用已有的 Antigravity 和 Grok CLI 标签独立审计并保留」→ 精确 attach、等回传、retain 后 ack
- 「用 Grok 模型审计」→ 本会话；「让 Grok Build CLI 审计」→ 监督任务
- 「用 DeepSeek 模型审计」→ 本会话；「让 DeepSeek Harness 审计并回传」→ 监督任务，使用 `--agent dsh`
- 「开终端」没点名产品 → 本会话

## 禁止

- 只换当前 TUI 的模型就开标签
- 用本会话的 headless 调用冒充用户要求的另一个 TUI 审计；安装诊断的 `--version/--help` 等不属于外部审计替代
- 同 checkout 却 `worktree create`
- 监督任务不回传、不处理资源所有权，或 `worker_done` 后未收口就继续副作用操作
- 关闭已有用户标签、接管忙碌标签，或把一种产品的代理、模型、权限策略套到其他产品
