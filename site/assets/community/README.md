# ClawStart Community QR Assets

把真实二维码放到这个目录后，首页、下载页、排障页和资料手册会优先读取这些文件；如果文件不存在，会自动回退到当前的占位图。

## 推荐文件名

- `wecom-qr.png`
- `qq-qr.png`
- `wechat-qr.png`
- `planet-qr.png`

## 当前回退逻辑

- `wecom-qr.png` -> `wecom-qr-placeholder.svg`
- `qq-qr.png` -> `qq-qr-placeholder.svg`
- `wechat-qr.png` -> `wechat-qr-placeholder.svg`
- `planet-qr.png` -> `planet-qr-placeholder.svg`

## 使用建议

- 优先放企业微信真实二维码，作为首轮推广主承接入口
- 微信群二维码如果经常变动，建议继续把企业微信作为主入口
- 知识星球二维码适合在第二轮内容承接时补齐
