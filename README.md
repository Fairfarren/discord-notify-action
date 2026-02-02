# Discord Notify Action

发送格式化的通知到 Discord 的 GitHub Action。

## 使用方法

```yaml
- name: Notify Discord
  uses: fairfarren/discord-notify@v1
  with:
    webhook-url: ${{ secrets.DISCORD_WEBHOOK }}
    title: "通知标题"
    status: "success"
```

## 参数

| 参数 | 必填 | 说明 |
|------|------|------|
| webhook-url | 是 | Discord Webhook URL |
| title | 是 | 通知标题 |
| status | 否 | 状态标识 (success/failure/warning/info) |
| color | 否 | 嵌入颜色（默认根据 status 自动设置） |
| job | 否 | Job 名称 |
| repository | 否 | GitHub 仓库 |
| branch | 否 | 分支名称 |
| run-id | 否 | GitHub Actions Run ID |
| run-url | 否 | GitHub Actions Run URL |
| error-summary | 否 | 错误摘要 |
| preview-url | 否 | 预览地址 |
| screenshot | 否 | 截图文件路径 |
| pr-url | 否 | Pull Request URL |
| commit-message | 否 | 提交信息 |

## License

MIT
