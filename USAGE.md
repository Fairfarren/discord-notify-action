# Discord Notify Action 使用指南

## 快速开始

### 1. 添加 Discord Webhook Secret

在项目仓库设置中添加 Secret：
1. 进入仓库 Settings > Secrets and variables > Actions
2. 点击 "New repository secret"
3. Name: `DISCORD_WEBHOOK`
4. Value: 你的 Discord Webhook URL

### 2. 在 Workflow 中使用

#### 基础通知

```yaml
- name: Notify Success
  if: success()
  uses: fairfarren/discord-notify@v1
  with:
    webhook-url: ${{ secrets.DISCORD_WEBHOOK }}
    title: "构建成功"
    status: success
```

#### 完整配置

```yaml
- name: Notify Failure
  if: failure()
  uses: fairfarren/discord-notify@v1
  with:
    webhook-url: ${{ secrets.DISCORD_WEBHOOK }}
    title: "❌ 构建失败"
    status: failure
    job: ${{ github.job }}
    repository: ${{ github.repository }}
    branch: ${{ github.ref_name }}
    run-id: ${{ github.run_id }}
    run-url: ${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}
    pr-url: ${{ steps.pr_info.outputs.pr_url }}
    commit-message: ${{ github.event.head_commit.message }}
```

#### 带错误摘要

```yaml
- name: Run Tests
  id: tests
  run: pnpm test 2>&1 | tee test.log

- name: Notify on Failure
  if: failure()
  uses: fairfarren/discord-notify/extract-error-summary@v1
  with:
    log-file: test.log
    job-name: ${{ github.job }}
    failure-title: "测试失败"
    webhook-url: ${{ secrets.DISCORD_WEBHOOK }}
```

## 参数说明

| 参数 | 必填 | 默认值 | 说明 |
|------|------|--------|------|
| webhook-url | 是 | - | Discord Webhook URL |
| title | 是 | - | 通知标题 |
| status | 否 | info | success/failure/warning/info |
| color | 否 | 自动 | 嵌入颜色（十进制） |
| job | 否 | - | Job 名称 |
| repository | 否 | - | GitHub 仓库 |
| branch | 否 | - | 分支名称 |
| run-id | 否 | - | Run ID |
| run-url | 否 | - | Run URL |
| error-summary | 否 | - | 错误摘要 |
| preview-url | 否 | - | 预览地址 |
| screenshot | 否 | - | 截图文件路径 |
| pr-url | 否 | - | PR URL |
| commit-message | 否 | - | 提交信息 |

## 常用模板

### CI/CD 通知

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Build
        run: npm run build

      - name: Notify Success
        if: success()
        uses: fairfarren/discord-notify@v1
        with:
          webhook-url: ${{ secrets.DISCORD_WEBHOOK }}
          title: "✅ 构建成功"
          status: success

      - name: Notify Failure
        if: failure()
        uses: fairfarren/discord-notify@v1
        with:
          webhook-url: ${{ secrets.DISCORD_WEBHOOK }}
          title: "❌ 构建失败"
          status: failure
```

### 部署通知

```yaml
- name: Deploy
  id: deploy
  run: |
    npm run deploy
    echo "preview_url=https://preview.example.com" >> $GITHUB_OUTPUT

- name: Notify
  uses: fairfarren/discord-notify@v1
  with:
    webhook-url: ${{ secrets.DISCORD_WEBHOOK }}
    title: "🚀 部署完成"
    status: success
    preview-url: ${{ steps.deploy.outputs.preview_url }}
```
