# ClawStart 免安装一键包

## 产品定义

ClawStart 一键包是面向中文用户的 OpenClaw 免安装发行版。用户下载 → 解压 → 双击即可使用，零配置门槛。

## 包含内容

| 组件 | 说明 |
|------|------|
| OpenClaw 本体 | 核心 AI Agent 框架 |
| Node.js 运行时 | 内嵌便携版，不污染系统环境 |
| 预配置工作区 | 开箱即用的项目模板 |
| 国内模型配置 | 火山引擎 / 硅基流动 / DeepSeek 预置 |
| 启动器 | 一键启动 + 首次运行引导 + 诊断工具 |

## 目录结构

```
ClawStart-v{版本号}-win64/
├── launch.bat              # 双击启动（主入口，默认打开 http://127.0.0.1:18789/ ）
├── first-run.bat           # 首次运行引导（自动调用）
├── diagnose.bat            # 诊断工具（遇到问题时使用）
├── runtime/
│   └── node/               # 内嵌 Node.js
├── openclaw/               # OpenClaw 本体
├── workspace/              # 预配置工作区
└── config/                 # 用户配置（首次运行时生成）

ClawStart-v{版本号}-macos/
├── launch.command          # 双击启动（主入口）
├── first-run.sh            # 首次运行引导（自动调用）
├── runtime/
│   └── node/               # 内嵌 Node.js
├── openclaw/               # OpenClaw 本体
├── workspace/              # 预配置工作区
└── config/                 # 用户配置

ClawStart Linux Beta
├── installer/linux/install.sh   # 实验性 Linux 安装脚本
├── ~/.clawstart-linux-beta/     # 默认安装目录
│   ├── launch.sh                # 本地启动入口
│   ├── runtime/npm-global/      # 本地 CLI 安装目录
│   ├── workspace/               # 工作区
│   └── config/                  # 用户配置
```

## 打包流程

### Windows 包（建议在 Windows Runner 或 Windows 真机构建）

```bash
cd installer/windows
./build.sh --version 0.1.0
```

构建步骤：
1. 下载 Node.js Windows 便携版（x64）
2. 通过 npm 安装 `openclaw` 到包内前缀目录（不是直接从本地源码仓库复制）
3. 复制启动器脚本和配置模板
4. 生成预配置工作区
5. 校验关键产物路径和文件名
6. 打包为 zip（保留目录结构）
7. 计算 SHA256 校验和

说明：
- 当前默认来源是 npm registry 上的 `openclaw` 包
- `openclaw` 包对应源码仓库：`https://github.com/openclaw/openclaw.git`
- 如需固定版本或切换镜像，应优先通过 npm 源和版本号控制，不要假设打包脚本会直接读取本地 OpenClaw 仓库

### macOS 包

```bash
cd installer/macos
./build.sh --version 0.1.0
```

构建步骤与 Windows 类似，使用 macOS 版 Node.js 运行时。

补充说明：
- macOS 包当前也通过 npm 安装 `openclaw` 到包内目录
- 默认网关地址按当前 OpenClaw 本地服务约定对齐到 `http://127.0.0.1:18789/`

## 版本管理策略

### 版本号规则

采用语义化版本 `MAJOR.MINOR.PATCH`：
- MAJOR：OpenClaw 大版本升级或不兼容变更
- MINOR：新功能、新模型支持
- PATCH：Bug 修复、配置更新

### 发布流程

1. 更新 `installer/VERSION` 文件
2. 运行打包脚本生成产物
3. 校验产物完整性（SHA256）
4. 上传至 GitHub Releases + 国内镜像
5. 更新官网下载页链接

## 诊断脚本回归验证

当 `diagnose.bat` 或 `diagnose.sh` 的规则发生变化时，先运行这条最小回归：

```bash
bash installer/verify-diagnose-fixtures.sh
```

当前脚本会：

- 验证 macOS 诊断脚本的 3 个核心场景：
  - 缺少内嵌 Node
  - 缺少 `provider.json`
  - Git SSH 权限错误
- 静态检查 Windows 诊断脚本是否仍保留标准输出字段和核心规则

说明：

- 如果当前机器没有 `cmd` 环境，Windows 运行级验证会跳过
- 真正的 Windows 执行验证仍建议在 Windows Runner 或真机上补一次
- Linux Beta 安装脚本当前由 `installer/linux/verify-install-fixtures.sh` 做 fixture 回归，并在 `.github/workflows/installer-validation.yml` 中执行

### 兼容性矩阵

| 一键包版本 | OpenClaw 版本 | Node.js 版本 | 最低系统要求 |
|-----------|--------------|-------------|-------------|
| 0.1.x | latest | 20.x LTS | Win10+ / macOS 12+ |
