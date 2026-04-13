# 架构文档：PVE 环境下企业 VPN 绕过与透明代理方案

## 1. 核心痛点与挑战

在 Proxmox VE (PVE) 虚拟化环境中，需要让内网的其他虚拟机共享 `vm-in` (Windows) 的企业 VPN 连接（Lenovo 内网），但面临以下严峻挑战：

- **全局路由劫持 (Kill Switch)**：企业 VPN 拨号后会接管并阻断所有非隧道内的 IPv4 流量，导致传统的添加第二张虚拟网卡桥接方案失效。
- **严苛的企业安全查杀 (Symantec AV)**：目标机部署了严格的杀毒软件，执行常规的内网穿透二进制程序（如 `gost.exe`）会被 AdvML 启发式引擎和 PUA 规则直接隔离并删除。
- **DNS 泄露与解析失败**：客户端默认的本地 DNS 无法解析企业内网域名，导致 `NXDOMAIN` 错误。

## 2. 最终架构设计

采用 **"IPv6 侧信道 + 进程防杀伪装 + 代理远端解析"** 的混合架构：

- **底层链路**：利用 VPN 客户端往往忽略 IPv6 路由劫持的盲区，使用 PVE 虚拟网桥的局域网 IPv6 地址（如 `fd3e:7070:d4dc::364`）建立底层通信暗道。
- **核心中继**：放弃易被查杀的独立 exe 程序，利用受杀软信任的 Python 环境运行 `proxy.py`，实现静默端口监听。
- **上层分流**：终端通过标准 URI 格式挂载代理，或由 iStoreOS (OpenClash) 进行透明劫持与域名分流。

## 3. 标准配置手册 (SOP)

### 节点 A：中继服务器 (vm-in Windows 虚拟机)

- **角色**：VPN 拨号机 & 代理服务端
- **IPv6 地址**：`fd3e:7070:d4dc::364`

1. 正常连接企业 VPN。
2. 确保系统已安装 Python 环境。
3. 打开 PowerShell (管理员)，安装并启动轻量级代理：

```powershell
# 安装 proxy.py
pip install proxy.py

# 放行防火墙 8080 端口 (仅首次需要)
New-NetFirewallRule -DisplayName "Allow IPv6 Proxy Port 8080" -Direction Inbound -LocalPort 8080 -Protocol TCP -Action Allow

# 启动代理服务，监听所有 IPv6 地址
python -m proxy --hostname "::" --port 8080
```

*(保持该 PowerShell 窗口运行。如需极致隐蔽或避免被关，可考虑将此命令注册为 Windows 后台服务或放入 WSL2 Docker 容器中运行。)*

### 节点 B：独立 Windows 客户端虚拟机

- **角色**：共享上网的开发机

#### 1. 浏览器/系统级访问配置：

- 进入 Windows 设置 -> 网络和 Internet -> 代理。
- **严格规范**：地址栏必须带有 HTTP 协议头及方括号，填写为 `http://[fd3e:7070:d4dc::364]`，端口填写 `8080`。

*(推荐方案：关闭系统代理，使用浏览器扩展 SwitchyOmega，新建 HTTP 代理指向 `[fd3e:7070:d4dc::364]:8080`)*

#### 2. Git 代码拉取配置 (PowerShell/Bash)：

针对 HTTPS 方式拉取内部代码库（如 GitLab/Gitea）：

```bash
# 设置全局代理 (交给远端 VPN 隧道解析 DNS)
git config --global http.proxy http://[fd3e:7070:d4dc::364]:8080
git config --global https.proxy http://[fd3e:7070:d4dc::364]:8080

# (可选) 应对企业网关证书中间人劫持
git config --global http.sslVerify false
```

### 节点 C：全屋透明代理 (iStoreOS + OpenClash)

- **角色**：主路由无感分流网关
- **目的**：局域网内任意设备无需配置代理，访问 `*.lenovo.com` 时自动走 VPN 隧道，其余流量走本地或机场直连。

1. **添加自定义代理节点**：
   - 进入 OpenClash -> 服务器与策略组管理 -> 节点管理 -> 添加。
   - 类型选择 `HTTP`，地址填入 `fd3e:7070:d4dc::364`，端口 `8080`。命名为 `Office-Hub`。

2. **创建内网策略组**：
   - 新建策略组 `Lenovo-Rules`，将 `Office-Hub` 节点加入其中。

3. **编写自定义分流规则**：
   - 进入覆盖设置 -> 规则设置 -> 启用自定义规则。
   - 在规则头部添加：

```yaml
- DOMAIN-SUFFIX,lenovo.com,Lenovo-Rules
- DOMAIN-KEYWORD,lenovo,Lenovo-Rules
```

4. **环境检查与应用**：
   - 确保 OpenClash 的 IPv6 设置中开启了"允许 IPv6 类型 DNS 解析"。
   - 保存并应用配置。

> **维护建议**：未来如果由于 `vm-in` 重启导致其局域网 IPv6 地址发生变化，只需将上述步骤中的 `fd3e:7070:d4dc::364` 替换为新的 IPv6 地址即可。
