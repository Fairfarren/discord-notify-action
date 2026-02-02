#!/bin/bash

# Discord 通知脚本
# 用途: 发送格式化通知到 Discord

set -e

# 参数从环境变量读取
WEBHOOK_URL="${DISCORD_WEBHOOK}"
TITLE="${DISCORD_TITLE}"
COLOR="${DISCORD_COLOR}"
STATUS="${DISCORD_STATUS}"
JOB="${DISCORD_JOB}"
BRANCH="${DISCORD_BRANCH}"
RUN_ID="${DISCORD_RUN_ID}"
RUN_URL="${DISCORD_RUN_URL}"
ERROR_SUMMARY="${DISCORD_ERROR_SUMMARY}"
PREVIEW_URL="${DISCORD_PREVIEW_URL}"
COMMIT_MESSAGE="${DISCORD_COMMIT_MESSAGE}"
REPOSITORY="${DISCORD_REPOSITORY}"
SCREENSHOT="${DISCORD_SCREENSHOT}"
PR_URL="${DISCORD_PR_URL}"

# 默认颜色设置
if [ -z "${COLOR}" ]; then
  case "${STATUS}" in
    success) COLOR="3447003" ;;    # 绿色
    failure) COLOR="16711680" ;;   # 红色
    warning) COLOR="15844367" ;;   # 橙色
    info)    COLOR="3447003" ;;    # 蓝色
    *)       COLOR="8421504" ;;    # 灰色
  esac
fi

# 初始 Fields（基础 + 可选）
FIELDS='{"name":"仓库","value":"'"${REPOSITORY}"'","inline":true},{"name":"分支","value":"'"${BRANCH}"'","inline":true},{"name":"运行","value":"[查看日志]('"${RUN_URL}"')","inline":true}'

# 添加可选字段（处理特殊字符）
if [ -n "${ERROR_SUMMARY}" ]; then
  ERROR_SUMMARY_CLEAN=$(echo "${ERROR_SUMMARY}" | tr '\n' ' ' | sed 's/"/\\"/g')
  FIELDS="${FIELDS},{\"name\":\"错误摘要\",\"value\":\"${ERROR_SUMMARY_CLEAN}\",\"inline\":false}"
fi

if [ -n "${PREVIEW_URL}" ]; then
  FIELDS="${FIELDS},{\"name\":\"预览地址\",\"value\":\"[点击访问]('${PREVIEW_URL}')\",\"inline\":false}"
fi

if [ -n "${PR_URL}" ]; then
  FIELDS="${FIELDS},{\"name\":\"Pull Request\",\"value\":\"[查看 PR]('${PR_URL}')\",\"inline\":false}"
fi

if [ -n "${COMMIT_MESSAGE}" ]; then
  COMMIT_MESSAGE_CLEAN=$(echo "${COMMIT_MESSAGE}" | tr '\n' ' ' | sed 's/"/\\"/g')
  FIELDS="${FIELDS},{\"name\":\"提交\",\"value\":\"${COMMIT_MESSAGE_CLEAN}\",\"inline\":false}"
fi

# 构建 Footer
FOOTER="{\"text\":\"status: ${STATUS} | job: ${JOB} | run: ${RUN_ID}\"}"

# 构建 Embed JSON
EMBED="{\"title\":\"${TITLE}\",\"color\":${COLOR},\"fields\":[${FIELDS}],\"url\":\"${RUN_URL}\",\"footer\":${FOOTER}}"

# 构建 Payload
PAYLOAD="{\"embeds\":[${EMBED}]}"

# 发送到 Discord Webhook
if [ -n "${SCREENSHOT}" ] && [ -f "${SCREENSHOT}" ]; then
  echo "发送带截图的通知: ${SCREENSHOT}"
  curl -X POST "${WEBHOOK_URL}" \
    -F "payload_json=${PAYLOAD}" \
    -F "files[0]=@${SCREENSHOT}" \
    --silent --show-error
else
  echo "发送 Embed 通知"
  curl -X POST "${WEBHOOK_URL}" \
    -H "Content-Type: application/json" \
    -d "${PAYLOAD}" \
    --silent --show-error
fi
