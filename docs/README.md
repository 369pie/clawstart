# ClawStart Site

这是 `site/` 目录当前的真实页面清单。

只把这里列为“核心页”的页面视为当前有效主路径。其余页面如果属于占位页、内部页或归档页，不应重新拉回公开导航、sitemap 或主 CTA 链路。

## 核心页

- `index.html`：首页，总入口
- `download.html`：下载页，当前主转化入口
- `windows.html`：Windows 安装说明
- `macos.html`：macOS 安装说明
- `linux.html`：Linux Beta 安装脚本路径与环境准备说明
- `start.html`：快速开始
- `tutorial.html`：装好后第一步教程
- `troubleshooting.html`：故障排查
- `resources.html`：资源页
- `about.html`：关于、品牌关系与 LolaClaw 承接

## 非主路径页

- `portable.html`：占位说明页，保留 URL，但不作为当前 MVP 主路径

## 内部页与基础设施

- `funnel.html`：本地复盘页，仅内部使用
- `analytics.js`：前端埋点脚本
- `robots.txt`：抓取规则
- `sitemap.xml`：当前公开页 sitemap
- `styles.css`：全站样式
- `favicon.svg`：站点图标
- `404.html`：404 页面

## 归档页

以下内容已移入 `site/_archive/`，仅作为历史页面保留：

- `advanced.html`
- `service.html`
- 旧版路径页、FAQ、support、solutions、updates 等历史稿

`site/_archive/` 下的页面不属于当前标准页面体系。

## 预览方式

```bash
cd site
python3 -m http.server 8080
```

然后打开：<http://localhost:8080>

## 当前维护原则

- 优先维护核心页，不扩张页面体系
- 占位页允许保留 URL，但默认 `noindex`
- 内部页不进入公开 SEO 路径
- 归档页不重新暴露到公开导航
- 页面标准以 [AGENT_GUIDE.md](/Users/caonanya/Documents/GitHub/openlola/AGENT_GUIDE.md) 和 [docs/CLAWSTART-DESIGN-GUIDE.md](/Users/caonanya/Documents/GitHub/openlola/docs/CLAWSTART-DESIGN-GUIDE.md) 为准
