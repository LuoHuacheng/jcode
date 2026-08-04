# 官方与本地 Selfdev 双轨工作流

此仓库有两个远端：本地 fork `origin`，官方仓库 `upstream`。官方默认分支是
`master`，不是 `main`。双轨结构避免把官方代码、本地定制和运行时状态混在一起。

## 分支和工作树

首次在本仓库根目录执行：

```bash
scripts/setup_dual_track.sh --dry-run
scripts/setup_dual_track.sh
```

它创建同级目录和分支：

| 位置 | 分支 | 用途 |
| --- | --- | --- |
| 当前 `jcode` | `main`，别名 `local/main` | 本地定制开发，推送到 `origin/main` |
| `../jcode-official` | `official/master` | 官方只读线，只允许快进到 `upstream/master` |
| `../jcode-integration` | `integration/master` | 官方更新与本地定制的合并线 |

脚本拒绝覆盖已有分支或目录。首次设置前先检查 `git worktree list`。若已存在上述
结构，直接跳过 setup。

## 接收官方更新

```bash
scripts/sync_upstream.sh --dry-run
scripts/sync_upstream.sh
```

同步顺序：fetch `upstream master`，把已提交的当前 `main` 快进到 `local/main`，
快进 `official/master`，再依次 merge local 和官方代码到 `integration/master`。
未提交文件不会进入 integration。

若发生冲突，只有 `../jcode-integration` 进入冲突状态。到该目录解决、`git add`、
`git commit` 后再继续。不要在 `jcode-official` 写本地定制。

建议将 integration 作为备份推送到 fork：

```bash
git -C ../jcode-integration push -u origin integration/master
```

## 隔离构建和运行

```bash
scripts/build_channel.sh official build
scripts/build_channel.sh local build
scripts/build_channel.sh integration build

scripts/build_channel.sh official run '<prompt>'
scripts/build_channel.sh integration run '<prompt>'
```

每个 channel 使用独立 `JCODE_HOME`、`CARGO_TARGET_DIR`、binary 和 socket，默认在
`~/.jcode/channels/<channel>/`。因此官方版和 integration 版可同时运行，彼此不会
覆盖 `~/.jcode/builds/current` 或 shared daemon。

查看实际路径：

```bash
scripts/build_channel.sh integration path
```

可用 `JCODE_CHANNEL_ROOT=/other/path` 改 channel 根目录。默认 launcher 与
`jcode self-dev --build` 仍使用原有 shared `current` channel，未被本流程修改。

## 日常规则

1. 本地功能只在当前 `main` 开发并提交，再推送 `origin/main`。同步脚本会将已提交
   的 `main` 更新到 `local/main`。
2. 官方版本只在 `jcode-official` 构建、回归或对比。
3. 日常 selfdev 从 `integration` build/run。
4. 先执行同步 dry-run。合并前保证 official 与 integration 工作树干净。
5. 不提交 `.DS_Store` 或 channel 运行时文件。
