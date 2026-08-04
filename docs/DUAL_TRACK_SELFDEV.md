# 官方与本地 Selfdev 双分支工作流

只使用当前 `jcode` checkout。不创建额外 clone 或 `git worktree`。

| 分支 | 用途 |
| --- | --- |
| `official/master` | 官方 `upstream/master` 镜像。禁止本地开发。 |
| `main` | 本地开发、合并官方代码、日常构建。跟踪 `origin/main`。 |

## 首次初始化

```bash
git remote -v
git fetch upstream master
git branch -f official/master upstream/master
git switch main
```

`origin` 应为你的 fork，`upstream` 应为官方仓库。

## 本地开发

始终在 `main` 开发并提交：

```bash
git switch main
# 编辑、测试
git add <files>
git commit -m "<commit message>"
```

## 同步官方并合并

先保证 `main` 干净：

```bash
git switch main
git status --short
scripts/sync_upstream.sh --dry-run
```

dry-run 只显示待合并官方提交，不 fetch、不修改分支。确认后执行：

```bash
scripts/sync_upstream.sh
```

脚本执行：

1. fetch `upstream/master`。
2. 快进 `official/master`。
3. merge `official/master` 到 `main`。

冲突保留在 `main`：

```bash
git status
# 编辑冲突文件
git add <resolved-files>
git commit
```

放弃本次合并：

```bash
git merge --abort
```

## 构建和运行

`local` 使用 `main`。`official` 使用 `official/master`，仅用于官方行为对比。
构建时脚本临时切目标分支，完成自动恢复原分支。构建前工作区必须干净。

```bash
scripts/build_channel.sh local build
scripts/build_channel.sh local run '<prompt>'

scripts/build_channel.sh official build
scripts/build_channel.sh official run '<prompt>'
```

查看实际路径：

```bash
scripts/build_channel.sh local path
scripts/build_channel.sh official path
```

每个 channel 独立使用 `JCODE_HOME`、`JCODE_RUNTIME_DIR`、`CARGO_TARGET_DIR`、binary、socket，位于 `~/.jcode/channels/<channel>/`。两个 channel 可同时运行，不共享 daemon lock。

可用 `JCODE_CHANNEL_ROOT=/other/path` 改 channel artifact 根目录。全局 launcher 和 `jcode self-dev --build` 不受该脚本影响。

## 推送本地 fork

```bash
git switch main
git push origin main
```

推送修改远端仓库。先确认 remote 与分支。
