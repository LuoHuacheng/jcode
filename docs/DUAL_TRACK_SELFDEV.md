# 官方与本地 Selfdev 单仓分支工作流

只使用当前 `jcode` checkout。不创建额外仓库或 `git worktree`。

## 分支

| 分支 | 用途 |
| --- | --- |
| `main` / `local/main` | 本地定制，推送到 `origin/main` |
| `official/master` | 官方镜像，只指向 `upstream/master` |
| `integration/master` | 合并 local 与 official 后的日常构建线 |

首次初始化已有分支时：

```bash
git fetch upstream master
git branch -f official/master upstream/master
git branch -f local/main main
git branch integration/master local/main
```

## 同步官方代码

在干净的 `main` 执行：

```bash
scripts/sync_upstream.sh --dry-run
scripts/sync_upstream.sh
```

脚本 fetch `upstream/master`，更新 `local/main` 和 `official/master`，切到
`integration/master` 合并两者，最后自动切回 `main`。未提交文件不会参与。

冲突留在 `integration/master`：解决、提交、再 `git switch main`。官方分支不写本地
定制。

## 隔离构建和运行

```bash
scripts/build_channel.sh official build
scripts/build_channel.sh integration build
scripts/build_channel.sh integration run '<prompt>'
```

构建临时切换目标分支，完成后恢复原分支。每个 channel 独立使用
`JCODE_HOME`、`JCODE_RUNTIME_DIR`、`CARGO_TARGET_DIR`、binary、socket，目录为
`~/.jcode/channels/<channel>/`。官方和 integration 可同时启动，不共享 daemon lock。

```bash
scripts/build_channel.sh integration path
```

可用 `JCODE_CHANNEL_ROOT=/other/path` 改 artifact 根目录。全局 launcher 和
`jcode self-dev --build` 不会被脚本修改。

## 日常规则

1. 本地功能在 `main` 开发并提交。
2. 运行同步脚本把最新本地提交和官方更新合入 `integration/master`。
3. 用 integration channel 构建和运行。官方 channel 用于对比与回归。
4. 切换或同步前保持工作区干净。
