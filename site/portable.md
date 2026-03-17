---
title: 便携版
description: ClawStart 便携版，无需安装，即开即用，数据随身携带，支持U盘/移动硬盘运行。
keywords: ClawStart,OpenClaw,便携版,U盘运行,免安装,多机切换
---

# 便携版
{.title}

> 📱 数据随身带，插上就能用

ClawStart 便携版让你可以将整个 OpenClaw 运行环境放在 U 盘、移动硬盘或云盘里，插到任何电脑上就能直接运行，不需要安装，所有数据和配置都跟着你走。

## 版本说明

我们提供两个级别的便携版，按需选择：

| 版本 | 特点 | 适合场景 |
|------|------|----------|
| **Level 1 伪便携版**（当前推荐） | 程序和配置都在U盘，运行时会产生少量临时文件 | 绝大多数用户 |
| **Level 2 真便携版**（开发中） | 完全不写入系统，所有路径重定向到U盘 | 极致隐私需求用户 |

## 核心优势

✅ **零安装**：不需要安装任何软件，下载解压就能用  
✅ **数据随身**：聊天记录、配置、工作区都在U盘里  
✅ **即插即用**：插到任何电脑上双击启动，1分钟就绪  
✅ **不污染系统**：不写注册表，不残留垃圾文件  
✅ **隐私安全**：数据存在你的U盘里，离开即带走  

## 适合场景

<div class="use-case-grid">
  <div class="use-case-card">
    <div class="use-case-icon">🎤</div>
    <h3>客户演示</h3>
    <p>给客户演示AI产品，不用在客户电脑上装任何东西，插上U盘就能用，专业又省心。</p>
  </div>
  <div class="use-case-card">
    <div class="use-case-icon">💼</div>
    <h3>多机切换</h3>
    <p>公司、家里、出差多台电脑切换，工作环境随身带，不用每台都重新配置。</p>
  </div>
  <div class="use-case-card">
    <div class="use-case-icon">📚</div>
    <h3>培训教学</h3>
    <p>培训课统一环境，所有学员用一样的配置，避免安装问题耽误上课时间。</p>
  </div>
  <div class="use-case-card">
    <div class="use-case-icon">🏢</div>
    <h3>企业部署</h3>
    <p>批量给员工配置AI助手，不用每台电脑单独安装，插U盘就能用，统一管理。</p>
  </div>
  <div class="use-case-card">
    <div class="use-case-icon">🛡️</div>
    <h3>隐私保护</h3>
    <p>敏感数据存在加密U盘里，用完拔走，不会在电脑上留下任何痕迹。</p>
  </div>
  <div class="use-case-card">
    <div class="use-case-icon">🌐</div>
    <h3>离线使用</h3>
    <p>搭配本地模型，即使没有网络也能使用，适合保密场景。</p>
  </div>
</div>

## 使用方法

### Windows
1. 下载便携版压缩包
2. 解压到 U 盘根目录（建议USB 3.0以上）
3. 插入任意 Windows 电脑
4. 打开 U 盘，双击 `launch.bat`
5. 等待1分钟左右，自动打开浏览器即可使用

### macOS
1. 下载便携版压缩包
2. 解压到 U 盘根目录（建议格式化为APFS）
3. 插入任意 Mac
4. 右键点击 `launch.command` → 选择"打开"（首次需要绕过安全限制）
5. 等待启动完成，自动打开浏览器

## 注意事项

💡 **U盘建议**：使用 USB 3.0 以上的 U 盘，速度更快，体验更好  
💡 **格式建议**：Windows 用 NTFS，macOS 用 APFS，如果需要跨平台用 exFAT  
💡 **安全退出**：不要在运行时直接拔出 U 盘，先关闭程序窗口再拔  
💡 **定期备份**：建议定期备份 U 盘里的 `workspace/` 和 `config/` 目录  
💡 **不要修改**：不要改动 `runtime/` 和 `openclaw/` 目录下的文件，避免程序无法运行

## 下载

| 平台 | 下载地址 | 大小 |
|------|----------|------|
| Windows 便携版 | [GitHub Releases](https://github.com/nicekate/openlola/releases/latest) | ~50MB |
| macOS 便携版 | [GitHub Releases](https://github.com/nicekate/openlola/releases/latest) | ~45MB |

## 常见问题

### 问：便携版和普通一键包有什么区别？
答：普通一键包解压后只能在当前电脑用，换电脑需要重新配置。便携版所有数据都在U盘里，换电脑直接用，不需要重新配置。

### 问：速度怎么样？
答：USB 3.0 U 盘的速度和本地硬盘差不多，完全感受不到差别。USB 2.0 会慢一些，不推荐。

### 问：支持在系统里同时安装普通版和便携版吗？
答：支持，两者互不影响。

### 问：Level 2 真便携版什么时候出？
答：正在开发中，预计 2026 Q2 发布，可以关注 GitHub Releases 获得更新通知。

## 升级方法
下载新版本的便携版压缩包，解压后替换旧版本的 `runtime/` 和 `openclaw/` 目录即可，`config/` 和 `workspace/` 目录不要替换，保留你的配置和数据。

[← 返回下载页](./download.md)
