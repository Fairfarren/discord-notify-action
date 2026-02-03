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
# 检查截图文件是否存在（优先使用 workspace 路径，因为 composite action 在 action_path 运行）
SCREENSHOT_FILE=""

if [ -n "${SCREENSHOT}" ]; then
  # 优先尝试在工作区目录中查找（composite action 的 working-directory 是 action_path）
  if [ -n "${GITHUB_WORKSPACE}" ] && [ -f "${GITHUB_WORKSPACE}/${SCREENSHOT}" ]; then
    SCREENSHOT_FILE="${GITHUB_WORKSPACE}/${SCREENSHOT}"
    echo "✅ 找到截图文件（workspace 路径）: ${SCREENSHOT_FILE}"
  # 尝试直接使用路径（绝对路径）
  elif [ -f "${SCREENSHOT}" ]; then
    SCREENSHOT_FILE="${SCREENSHOT}"
    echo "✅ 找到截图文件（直接路径）: ${SCREENSHOT}"
  # 尝试在当前目录中查找
  elif [ -f "$(pwd)/${SCREENSHOT}" ]; then
    SCREENSHOT_FILE="$(pwd)/${SCREENSHOT}"
    echo "✅ 找到截图文件（当前目录）: ${SCREENSHOT_FILE}"
  else
    echo "⚠️ 截图文件不存在: ${SCREENSHOT}" >&2
    echo "   GITHUB_WORKSPACE: ${GITHUB_WORKSPACE:-未设置}" >&2
    echo "   当前目录: $(pwd)" >&2
    echo "   尝试在 workspace 中查找 png 文件..." >&2
    if [ -n "${GITHUB_WORKSPACE}" ]; then
      find "${GITHUB_WORKSPACE}" -name "failure-screenshot.png" 2>/dev/null | head -n 5 || true >&2
    fi
  fi
fi

if [ -n "${SCREENSHOT_FILE}" ] && [ -f "${SCREENSHOT_FILE}" ]; then
  echo "📸 发送带截图的通知: ${SCREENSHOT_FILE}"
  curl -X POST "${WEBHOOK_URL}" \
    -F "payload_json=${PAYLOAD}" \
    -F "files[0]=@${SCREENSHOT_FILE}" \
    --silent --show-error
else
  echo "📢 发送 Embed 通知"
  curl -X POST "${WEBHOOK_URL}" \
    -H "Content-Type: application/json" \
    -d "${PAYLOAD}" \
    --silent --show-error
fi
