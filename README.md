# proxy_config

OpenClash (Clash Meta / mihomo) 代理配置仓库，用于 iStoreOS 环境。

## 目录结构

```
proxy_config/
├── config/                              # OpenClash 配置文件
│   └── config_in_config.yaml            # 种子配置（proxies + proxy-groups）
│
├── rule_provider/                       # 规则集
│   ├── custom/                          # 自定义规则集
│   │   ├── Docker.yaml                  # Docker/容器注册表域名
│   │   └── AI.yaml                      # AI 平台域名（补充 AI Suite）
│   └── upstream/                        # 上游规则集（自动同步自 dler-io/Rules）
│       ├── AdBlock.yaml
│       ├── Netflix.yaml
│       ├── Telegram.yaml
│       └── ...                          # 共 62 个规则集
│
├── docs/                                # 文档
│   └── config_running_annotated.yaml    # 带完整注释的运行配置参考
│
├── scripts/                             # 辅助脚本
│   └── download_upstream.ps1            # 本地下载上游规则集（PowerShell）
│
└── .github/workflows/
    └── sync-rules.yml                   # GitHub Actions：每周自动同步上游规则集
```

## 使用方法

### 规则集 URL 格式

通过 jsDelivr CDN 引用：

```
# 自定义规则集
https://fastly.jsdelivr.net/gh/zhuxu222/proxy_config@main/rule_provider/custom/Docker.yaml
https://fastly.jsdelivr.net/gh/zhuxu222/proxy_config@main/rule_provider/custom/AI.yaml

# 上游规则集（例）
https://fastly.jsdelivr.net/gh/zhuxu222/proxy_config@main/rule_provider/upstream/Netflix.yaml
https://fastly.jsdelivr.net/gh/zhuxu222/proxy_config@main/rule_provider/upstream/Telegram.yaml
```

### OpenClash 配置示例

```yaml
rule-providers:
  Docker:
    type: http
    behavior: classical
    url: https://fastly.jsdelivr.net/gh/zhuxu222/proxy_config@main/rule_provider/custom/Docker.yaml
    path: "./rule_provider/Docker"
    interval: 86400

rules:
  - RULE-SET,Docker,Docker
```

### 刷新 CDN 缓存

push 后如需立即生效：

```
https://purge.jsdelivr.net/gh/zhuxu222/proxy_config@main/rule_provider/custom/Docker.yaml
```

## 同步机制

- **GitHub Actions** 每周一自动从 [dler-io/Rules](https://github.com/dler-io/Rules) 同步上游规则集
- 也可在 GitHub Actions 页面手动触发同步
- 本地可运行 `scripts/download_upstream.ps1` 手动更新

## 协议栈

- **代理协议**: VLESS + REALITY
- **内核**: Clash Meta (mihomo)
- **管理面板**: OpenClash on iStoreOS
- **Web UI**: MetaCubeXD