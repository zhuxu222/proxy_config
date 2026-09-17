# proxy_config

OpenClash / mihomo 公开规则仓库。仅发布自定义规则、上游规则及内网单点 IP 清单，不保存节点、订阅、完整配置、认证信息或环境部署脚本。

完整配置及运维文件已迁入独立私有仓库 `zhuxu222/openclash_private`。本仓库的规则路径保持不变，OpenClash 可以继续匿名下载，不需要私有仓库访问令牌。

## 目录结构

```text
rule_provider/custom/                    自定义规则
rule_provider/upstream/                  上游规则
openclash/custom/lenovo_intranet_ips.list 静态内网单点 IP 例外
scripts/                                公开规则下载与校验
.github/workflows/                      校验与上游同步
```

## 使用方法

### 规则集 URL 格式

通过 jsDelivr CDN 引用：

```
# 自定义规则集
https://fastly.jsdelivr.net/gh/zhuxu222/proxy_config@main/rule_provider/custom/Docker.yaml
https://fastly.jsdelivr.net/gh/zhuxu222/proxy_config@main/rule_provider/custom/HuggingFace.yaml
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

  HuggingFace:
    type: http
    behavior: classical
    url: https://fastly.jsdelivr.net/gh/zhuxu222/proxy_config@main/rule_provider/custom/HuggingFace.yaml
    path: "./rule_provider/HuggingFace"
    interval: 86400

rules:
  - RULE-SET,Docker,Docker
  - RULE-SET,HuggingFace,HuggingFace
```

### 刷新 CDN 缓存

push 后如需立即生效：

```
https://purge.jsdelivr.net/gh/zhuxu222/proxy_config@main/rule_provider/custom/Docker.yaml
```

## Lenovo/Moto 内网例外

企业域名与静态 IP 规则位于 `rule_provider/custom/Lenovo.yaml`，裸 IP 兜底清单位于 `openclash/custom/lenovo_intranet_ips.list`。两者的 IPv4 单点集合必须一致，不自动扩大为宽网段。内网 IP 按维护者决定公开，认证信息和节点配置不属于公开规则。

域名检查工具和路由器部署脚本已移入私有仓库，并默认引用本仓库中的规则文件。规则是唯一维护源，私有快照只用于历史恢复。

## 提交检查

```sh
python3 -m pip install -r requirements-validation.txt
python3 -m unittest discover -s scripts -p 'test_validate_public.py'
python3 scripts/validate_public.py
git config core.hooksPath .githooks
```

钩子检查暂存区的文件白名单、规则 YAML 结构、内网清单一致性和常见配置/凭据模式。可通过 `PYTHON` 环境变量选择安装了 PyYAML 的解释器。Git 钩子不会自动随 clone 启用，新工作目录需要执行上面的配置命令。

CI 再次执行同样检查。CI 是提交后的检测，不能撤回已泄漏的凭据；发布前必须检查暂存路径与差异，禁止强制加入本地配置。此检查不能替代凭据扫描、人工审查和 GitHub 分支保护。

## 同步机制

- **GitHub Actions** 每周一自动从 [dler-io/Rules](https://github.com/dler-io/Rules) 同步上游规则集
- 也可在 GitHub Actions 页面手动触发同步
- 下载错误或校验失败时停止提交，不发布错误页面或部分失败的更新
- 同步任务只拥有本公开仓库的写权限，不读取私有配置或持有其凭据
- 本地可运行 `scripts/download_upstream.ps1` 手动下载，提交前仍需完整校验
- `@main` CDN 缓存可能延迟；需要可复现部署时使用已验证的提交 SHA，并记录版本
