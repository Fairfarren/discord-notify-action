# Discord Notify Action

发送格式化的通知到 Discord 的 GitHub Action，支持富文本嵌入、截图附件等功能。

## 特性

- 📨 **格式化通知** - 支持 Discord Embed 格式的富文本通知
- 📸 **截图附件** - 支持发送截图作为附件，适用于 E2E 测试失败等场景
- 🎨 **状态颜色** - 根据 status 自动设置颜色，或自定义颜色
- 🔗 **丰富信息** - 支持仓库、分支、PR URL、预览链接等丰富上下文
- 🐳 **容器支持** - 兼容 Docker 容器环境，自动处理路径问题

## 快速开始

### 1. 创建 Discord Webhook

1. 打开 Discord 服务器设置
2. 进入"集成" → "Webhooks"
3. 点击"新建 Webhook"
4. 复制 Webhook URL

### 2. 配置 GitHub Secret

在仓库中添加 Secret：
1. 进入仓库 **Settings** > **Secrets and variables** > **Actions**
2. 点击 **New repository secret**
3. Name: `DISCORD_WEBHOOK`
4. Value: 粘贴你的 Discord Webhook URL

### 3. 在 Workflow 中使用

```yaml
name: CI

on: [push, pull_request]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Build
        run: npm run build

      - name: Notify Success
        if: success()
        uses: fairfarren/discord-notify-action@v1
        with:
          webhook-url: ${{ secrets.DISCORD_WEBHOOK }}
          title: "✅ 构建成功"
          status: success

      - name: Notify Failure
        if: failure()
        uses: fairfarren/discord-notify-action@v1
        with:
          webhook-url: ${{ secrets.DISCORD_WEBHOOK }}
          title: "❌ 构建失败"
          status: failure
```

## 参数说明

| 参数 | 必填 | 默认值 | 说明 |
|------|------|--------|------|
| `webhook-url` | ✅ | - | Discord Webhook URL |
| `title` | ✅ | - | 通知标题 |
| `status` | ❌ | `info` | 状态标识：`success` / `failure` / `warning` / `info` |
| `color` | ❌ | 自动 | 嵌入颜色（十进制），不设置则根据 status 自动选择 |
| `job` | ❌ | - | Job 名称，显示在 footer 中 |
| `repository` | ❌ | - | GitHub 仓库，格式：`owner/repo` |
| `branch` | ❌ | - | 分支名称 |
| `run-id` | ❌ | - | GitHub Actions Run ID |
| `run-url` | ❌ | - | GitHub Actions Run URL |
| `error-summary` | ❌ | - | 错误摘要信息 |
| `preview-url` | ❌ | - | 预览地址（如部署预览链接） |
| `screenshot` | ❌ | - | 截图文件路径（相对于 workspace） |
| `pr-url` | ❌ | - | Pull Request URL |
| `commit-message` | ❌ | - | Git 提交信息 |

## 状态颜色

| Status | 颜色 | 十进制值 |
|--------|------|----------|
| `success` | 绿色 | 3447003 |
| `failure` | 红色 | 16711680 |
| `warning` | 橙色 | 15844367 |
| `info` | 蓝色 | 3447003 |
| 其他 | 灰色 | 8421504 |

## 使用示例

### 带上下文的完整通知

```yaml
- name: Notify
  uses: fairfarren/discord-notify-action@v1
  with:
    webhook-url: ${{ secrets.DISCORD_WEBHOOK }}
    title: "🚀 部署成功"
    status: success
    job: ${{ github.job }}
    repository: ${{ github.repository }}
    branch: ${{ github.ref_name }}
    run-id: ${{ github.run_id }}
    run-url: ${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}
    pr-url: ${{ steps.pr_info.outputs.pr_url }}
    commit-message: ${{ github.event.head_commit.message }}
```

### E2E 测试失败时发送截图

```yaml
- name: Run E2E Tests
  id: e2e
  run: |
    pnpm test:e2e 2>&1 | tee e2e.log

- name: Find Failure Screenshot
  if: failure()
  id: screenshot
  run: |
    # 将测试失败时的截图复制到 workspace 根目录
    find . -name "*.png" -path "*/test-results/*" -exec cp {} ./failure-screenshot.png \;
    echo "path=failure-screenshot.png" >> $GITHUB_OUTPUT

- name: Notify Failure
  if: failure()
  uses: fairfarren/discord-notify-action@v1
  with:
    webhook-url: ${{ secrets.DISCORD_WEBHOOK }}
    title: "❌ E2E 测试失败"
    status: failure
    error-summary: "测试运行失败，请查看日志"
    screenshot: ${{ steps.screenshot.outputs.path }}
    run-url: ${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}
```

### 带预览链接的通知

```yaml
- name: Deploy Preview
  id: deploy
  run: |
    URL=$(pnpm deploy-preview)
    echo "url=$URL" >> $GITHUB_OUTPUT

- name: Notify
  uses: fairfarren/discord-notify-action@v1
  with:
    webhook-url: ${{ secrets.DISCORD_WEBHOOK }}
    title: "🔍 预览已部署"
    status: success
    preview-url: ${{ steps.deploy.outputs.url }}
```

## 容器环境注意事项

如果你的 Job 运行在 Docker 容器中（例如 Playwright E2E 测试），需要注意：

1. **截图路径**：使用相对于 workspace 的路径，不要使用 `/tmp` 等容器内临时目录
2. **Action 会自动处理**：本 Action 会尝试在多个路径中查找截图文件

```yaml
jobs:
  e2e:
    runs-on: ubuntu-latest
    container:
      image: mcr.microsoft.com/playwright:v1.56.1
    steps:
      - uses: actions/checkout@v4

      - name: Run Tests
        run: pnpm test:e2e

      - name: Copy Screenshot
        if: failure()
        run: |
          # 复制到 workspace 根目录
          cp test-results/*/failure.png ./screenshot.png

      - name: Notify
        if: failure()
        uses: fairfarren/discord-notify-action@v1
        with:
          webhook-url: ${{ secrets.DISCORD_WEBHOOK }}
          title: "E2E 失败"
          status: failure
          screenshot: screenshot.png  # 相对路径
```

## 高级用法

### 使用 extract-error-summary 子 Action

自动从日志文件中提取错误摘要：

```yaml
- name: Run Tests
  run: pnpm test 2>&1 | tee test.log

- name: Notify on Failure
  if: failure()
  uses: fairfarren/discord-notify-action/extract-error-summary@v1
  with:
    webhook-url: ${{ secrets.DISCORD_WEBHOOK }}
    log-file: test.log
    job-name: ${{ github.job }}
    failure-title: "测试失败"
    run-url: ${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}
```

### 自定义颜色

```yaml
- name: Notify
  uses: fairfarren/discord-notify-action@v1
  with:
    webhook-url: ${{ secrets.DISCORD_WEBHOOK }}
    title: "自定义颜色通知"
    color: "16776960"  # 黄色
```

## 开发

### 项目结构

```
discord-notify-action/
├── action.yml              # Action 定义
├── discord-notify.sh       # 核心脚本
├── extract-error-summary/  # 错误摘要子 Action
├── README.md               # 项目说明
└── USAGE.md                # 详细使用指南
```

### 本地测试

修改脚本后，可以使用以下方式测试：

```bash
# 设置测试环境变量
export DISCORD_WEBHOOK="your-webhook-url"
export DISCORD_TITLE="测试通知"
export DISCORD_STATUS="info"
export DISCORD_REPOSITORY="owner/repo"
export DISCORD_BRANCH="main"

# 运行脚本
bash discord-notify.sh
```

## License

MIT
