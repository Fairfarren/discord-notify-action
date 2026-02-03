# Discord Notify Action 使用指南

本文档提供了 Discord Notify Action 的详细使用指南和最佳实践。

## 目录

- [常用场景](#常用场景)
- [最佳实践](#最佳实践)
- [参数详解](#参数详解)
- [常见问题](#常见问题)
- [完整示例](#完整示例)

## 常用场景

### 1. CI/CD 构建通知

同时通知成功和失败状态：

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install & Build
        run: |
          npm ci
          npm run build

      - name: Notify Success
        if: success()
        uses: fairfarren/discord-notify-action@v1
        with:
          webhook-url: ${{ secrets.DISCORD_WEBHOOK }}
          title: "✅ 构建成功"
          status: success
          repository: ${{ github.repository }}
          branch: ${{ github.ref_name }}

      - name: Notify Failure
        if: failure()
        uses: fairfarren/discord-notify-action@v1
        with:
          webhook-url: ${{ secrets.DISCORD_WEBHOOK }}
          title: "❌ 构建失败"
          status: failure
          repository: ${{ github.repository }}
          branch: ${{ github.ref_name }}
          run-url: ${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}
```

### 2. 部署预览通知

部署完成后通知预览链接：

```yaml
jobs:
  deploy-preview:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Deploy to Preview
        id: deploy
        run: |
          # 执行部署并获取预览 URL
          PREVIEW_URL=$(npx wrangler pages deploy ./dist --preview)
          echo "url=$PREVIEW_URL" >> $GITHUB_OUTPUT

      - name: Notify Preview
        uses: fairfarren/discord-notify-action@v1
        with:
          webhook-url: ${{ secrets.DISCORD_WEBHOOK }}
          title: "🔍 预览环境已部署"
          status: success
          preview-url: ${{ steps.deploy.outputs.url }}
          branch: ${{ github.ref_name }}
          commit-message: ${{ github.event.head_commit.message }}
```

### 3. E2E 测试失败通知（带截图）

```yaml
jobs:
  e2e:
    runs-on: ubuntu-latest
    container:
      image: mcr.microsoft.com/playwright:v1.56.1-jammy
    steps:
      - uses: actions/checkout@v4

      - name: Install & Run E2E
        run: |
          npm ci
          npx playwright test || true

      - name: Find Latest Screenshot
        if: failure()
        id: screenshot
        run: |
          # 查找最新的截图文件
          IMG_PATH=$(find . -type f -name "*.png" -path "*/test-results/*" -printf "%T@ %p\n" | sort -n | tail -n 1 | cut -d' ' -f2-)

          if [ -n "$IMG_PATH" ] && [ -f "$IMG_PATH" ]; then
            mkdir -p ./e2e-artifacts
            cp "$IMG_PATH" ./e2e-artifacts/failure-screenshot.png
            echo "path=e2e-artifacts/failure-screenshot.png" >> $GITHUB_OUTPUT
          fi

      - name: Notify Failure
        if: failure()
        uses: fairfarren/discord-notify-action@v1
        with:
          webhook-url: ${{ secrets.DISCORD_WEBHOOK }}
          title: "❌ E2E 测试失败"
          status: failure
          job: e2e-test
          repository: ${{ github.repository }}
          branch: ${{ github.ref_name }}
          run-id: ${{ github.run_id }}
          run-url: ${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}
          screenshot: ${{ steps.screenshot.outputs.path }}
```

### 4. 定时任务通知

定时任务完成后发送通知：

```yaml
name: Nightly Build

on:
  schedule:
    - cron: '0 2 * * *'  # 每天凌晨 2 点
  workflow_dispatch:

jobs:
  nightly:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Run Nightly Build
        run: npm run build:nightly

      - name: Notify
        uses: fairfarren/discord-notify-action@v1
        with:
          webhook-url: ${{ secrets.DISCORD_WEBHOOK }}
          title: "🌙 夜间构建完成"
          status: ${{ job.status }}
          repository: ${{ github.repository }}
```

### 5. 多环境部署通知

根据分支通知不同的环境：

```yaml
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Deploy
        run: npm run deploy

      - name: Set Environment Name
        id: env
        run: |
          if [[ "${{ github.ref_name }}" == "main" ]]; then
            echo "name=Production" >> $GITHUB_OUTPUT
            echo "emoji=🚀" >> $GITHUB_OUTPUT
          elif [[ "${{ github.ref_name }}" == "develop" ]]; then
            echo "name=Staging" >> $GITHUB_OUTPUT
            echo "emoji=🔧" >> $GITHUB_OUTPUT
          else
            echo "name=Preview" >> $GITHUB_OUTPUT
            echo "emoji=🔍" >> $GITHUB_OUTPUT
          fi

      - name: Notify
        uses: fairfarren/discord-notify-action@v1
        with:
          webhook-url: ${{ secrets.DISCORD_WEBHOOK }}
          title: "${{ steps.env.outputs.emoji }} ${{ steps.env.outputs.name }} 部署完成"
          status: success
```

## 最佳实践

### 1. 使用 Job Outputs 复用数据

```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    outputs:
      result: ${{ steps.test.outputs.result }}
      summary: ${{ steps.summary.outputs.text }}
    steps:
      - uses: actions/checkout@v4

      - name: Run Tests
        id: test
        run: |
          npm test | tee test.log
          echo "result=$?" >> $GITHUB_OUTPUT

      - name: Extract Summary
        if: failure()
        id: summary
        run: |
          SUMMARY=$(tail -n 20 test.log)
          echo "text=$SUMMARY" >> $GITHUB_OUTPUT

  notify:
    needs: test
    runs-on: ubuntu-latest
    if: always()
    steps:
      - name: Notify
        uses: fairfarren/discord-notify-action@v1
        with:
          webhook-url: ${{ secrets.DISCORD_WEBHOOK }}
          title: "测试 ${{ needs.test.outputs.result == '0' && '通过' || '失败' }}"
          status: ${{ needs.test.outputs.result == '0' && 'success' || 'failure' }}
          error-summary: ${{ needs.test.outputs.summary }}
```

### 2. 条件通知

只在特定分支或 PR 时通知：

```yaml
- name: Notify
  if: github.event_name == 'pull_request' || github.ref == 'refs/heads/main'
  uses: fairfarren/discord-notify-action@v1
  with:
    webhook-url: ${{ secrets.DISCORD_WEBHOOK }}
    title: "构建完成"
    status: success
```

### 3. 使用 Matrix 时的通知

```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        node-version: [18, 20, 22]
    steps:
      - uses: actions/checkout@v4

      - name: Test
        uses: actions/setup-node@v4
        with:
          node-version: ${{ matrix.node-version }}

      - run: npm test

      - name: Notify on Failure
        if: failure()
        uses: fairfarren/discord-notify-action@v1
        with:
          webhook-url: ${{ secrets.DISCORD_WEBHOOK }}
          title: "❌ Node ${{ matrix.node-version }} 测试失败"
          status: failure
```

### 4. 链接到 PR

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Get PR URL
        id: pr
        run: |
          if [ "${{ github.event_name }}" = "pull_request" ]; then
            PR_URL="${{ github.event.pull_request.html_url }}"
          else
            PR_URL=$(gh pr list --head "${{ github.ref_name }}" --json url --jq '.[0].url')
          fi
          echo "url=${PR_URL}" >> $GITHUB_OUTPUT
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}

      - name: Notify
        uses: fairfarren/discord-notify-action@v1
        with:
          webhook-url: ${{ secrets.DISCORD_WEBHOOK }}
          title: "构建完成"
          pr-url: ${{ steps.pr.outputs.url }}
```

## 参数详解

### 必填参数

| 参数 | 说明 | 示例 |
|------|------|------|
| `webhook-url` | Discord Webhook URL | `${{ secrets.DISCORD_WEBHOOK }}` |
| `title` | 通知标题 | `"构建成功"` |

### 可选参数

| 参数 | 说明 | 示例 |
|------|------|------|
| `status` | 状态标识 | `success`, `failure`, `warning`, `info` |
| `color` | 自定义颜色（十进制） | `16711680` (红色) |
| `job` | Job 名称 | `build`, `test`, `deploy` |
| `repository` | GitHub 仓库 | `owner/repo` |
| `branch` | 分支名称 | `main`, `develop` |
| `run-id` | Run ID | `1234567890` |
| `run-url` | Run URL | 完整的 Actions URL |
| `error-summary` | 错误摘要 | 日志摘要文本 |
| `preview-url` | 预览链接 | 部署预览 URL |
| `screenshot` | 截图路径 | `screenshots/failure.png` |
| `pr-url` | PR 链接 | PR 的完整 URL |
| `commit-message` | 提交信息 | Git commit message |

### Discord 颜色值参考

| 颜色 | 十进制 | 十六进制 | 使用场景 |
|------|--------|----------|----------|
| 红色 | 16711680 | FF0000 | 失败、错误 |
| 绿色 | 3447003 | 55FF55 | 成功、通过 |
| 蓝色 | 3447003 | 5555FF | 信息、提示 |
| 黄色 | 16776960 | FFFF00 | 警告 |
| 橙色 | 15844367 | FF5500 | 警告 |
| 灰色 | 8421504 | 808080 | 默认 |

## 常见问题

### Q: 如何创建 Discord Webhook？

1. 打开 Discord 服务器设置
2. 选择"集成" → "Webhooks"
3. 点击"新建 Webhook"
4. 设置名称和目标频道
5. 复制 Webhook URL

### Q: 通知没有发送，怎么办？

检查以下几点：
1. Webhook URL 是否正确
2. Secret 是否已正确配置
3. 查看GitHub Actions 日志中的错误信息
4. 确认 Webhook 所在频道是否有权限发送消息

### Q: 如何在多个频道发送通知？

创建多个 Webhook，使用多个通知步骤：

```yaml
- name: Notify Dev Channel
  uses: fairfarren/discord-notify-action@v1
  with:
    webhook-url: ${{ secrets.DISCORD_WEBHOOK_DEV }}
    title: "开发环境构建完成"

- name: Notify Prod Channel
  if: github.ref == 'refs/heads/main'
  uses: fairfarren/discord-notify-action@v1
  with:
    webhook-url: ${{ secrets.DISCORD_WEBHOOK_PROD }}
    title: "生产环境部署完成"
```

### Q: 截图没有发送成功？

确保：
1. 截图文件路径相对于 workspace 根目录
2. 文件确实存在（在容器环境中需复制到 workspace）
3. 文件格式是 PNG/JPG 等支持的格式

### Q: 如何调试通知内容？

在本地测试脚本：

```bash
export DISCORD_WEBHOOK="your-webhook-url"
export DISCORD_TITLE="测试"
export DISCORD_STATUS="info"
export DISCORD_REPOSITORY="test/repo"
export DISCORD_BRANCH="main"

bash discord-notify.sh
```

## 完整示例

### 完整的 CI/CD 工作流

```yaml
name: CI/CD

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

env:
  DISCORD_WEBHOOK: ${{ secrets.DISCORD_WEBHOOK }}

jobs:
  lint-and-test:
    name: Lint & Test
    runs-on: ubuntu-latest
    outputs:
      pr_url: ${{ steps.pr_info.outputs.pr_url }}
      commit_message: ${{ steps.commit_info.outputs.message }}
    steps:
      - uses: actions/checkout@v4

      - name: Get PR Info
        id: pr_info
        run: |
          if [ "${{ github.event_name }}" = "pull_request" ]; then
            echo "pr_url=${{ github.event.pull_request.html_url }}" >> $GITHUB_OUTPUT
          fi

      - name: Get Commit Message
        id: commit_info
        run: |
          MESSAGE=$(echo "${{ github.event.head_commit.message }}" | head -n 1)
          echo "message=$MESSAGE" >> $GITHUB_OUTPUT

      - name: Install & Lint
        run: |
          npm ci
          npm run lint

      - name: Test
        run: npm test 2>&1 | tee test.log

      - name: Notify Failure
        if: failure()
        uses: fairfarren/discord-notify-action/extract-error-summary@v1
        with:
          webhook-url: ${{ env.DISCORD_WEBHOOK }}
          log-file: test.log
          job-name: lint-and-test
          failure-title: "❌ 代码检查或测试失败"
          run-url: ${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}
          pr-url: ${{ steps.pr_info.outputs.pr_url }}
          commit-message: ${{ steps.commit_info.outputs.message }}

  e2e:
    name: E2E Tests
    needs: [lint-and-test]
    runs-on: ubuntu-latest
    container:
      image: mcr.microsoft.com/playwright:v1.56.1-jammy
    steps:
      - uses: actions/checkout@v4

      - name: Install & Run E2E
        run: |
          npm ci
          npx playwright test 2>&1 | tee e2e.log

      - name: Find Screenshot
        if: failure()
        id: screenshot
        run: |
          IMG_PATH=$(find . -type f -name "*.png" -path "*/test-results/*" -printf "%T@ %p\n" | sort -n | tail -n 1 | cut -d' ' -f2-)
          if [ -n "$IMG_PATH" ] && [ -f "$IMG_PATH" ]; then
            mkdir -p ./e2e-artifacts
            cp "$IMG_PATH" ./e2e-artifacts/failure-screenshot.png
            echo "path=e2e-artifacts/failure-screenshot.png" >> $GITHUB_OUTPUT
          fi

      - name: Notify Success
        if: success()
        uses: fairfarren/discord-notify-action@v1
        with:
          webhook-url: ${{ env.DISCORD_WEBHOOK }}
          title: "✅ CI/CD 全部通过"
          status: success
          repository: ${{ github.repository }}
          branch: ${{ github.ref_name }}

      - name: Notify Failure
        if: failure()
        uses: fairfarren/discord-notify-action@v1
        with:
          webhook-url: ${{ env.DISCORD_WEBHOOK }}
          title: "❌ E2E 测试失败"
          status: failure
          repository: ${{ github.repository }}
          branch: ${{ github.ref_name }}
          run-id: ${{ github.run_id }}
          run-url: ${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}
          screenshot: ${{ steps.screenshot.outputs.path }}
          pr-url: ${{ needs.lint-and-test.outputs.pr_url }}
          commit-message: ${{ needs.lint-and-test.outputs.commit_message }}
```

### 完整的部署工作流

```yaml
name: Deploy

on:
  push:
    branches: [main]

env:
  DISCORD_WEBHOOK: ${{ secrets.DISCORD_WEBHOOK }}

jobs:
  deploy:
    name: Deploy Production
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Node
        uses: actions/setup-node@v4
        with:
          node-version: 20

      - name: Install & Build
        run: |
          npm ci
          npm run build

      - name: Deploy
        id: deploy
        run: |
          npm run deploy
          echo "url=https://example.com" >> $GITHUB_OUTPUT

      - name: Notify Success
        if: success()
        uses: fairfarren/discord-notify-action@v1
        with:
          webhook-url: ${{ env.DISCORD_WEBHOOK }}
          title: "🚀 生产环境部署成功"
          status: success
          preview-url: ${{ steps.deploy.outputs.url }}
          repository: ${{ github.repository }}
          branch: ${{ github.ref_name }}
          commit-message: ${{ github.event.head_commit.message }}

      - name: Notify Failure
        if: failure()
        uses: fairfarren/discord-notify-action@v1
        with:
          webhook-url: ${{ env.DISCORD_WEBHOOK }}
          title: "❌ 部署失败"
          status: failure
          repository: ${{ github.repository }}
          branch: ${{ github.ref_name }}
          run-url: ${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}
```
