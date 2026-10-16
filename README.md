# Chromium 基础库

基于 Chromium 151.0.7922.138 的独立构建树。
保留 base、Mojo、net、URL、SQL、prefs、Crashpad、sandbox 等原生库，以及
它们已有的依赖闭包和 GN/Ninja 构建配置。这不是完整 Chromium 浏览器源码。

整层自定义 `app/`、产品挂载机制、WebView2 SDK/样例、duilib、lunasvg、esbuild、
加密资源包、MSIX 和自解压打包设施均未迁入。`chrome/installer`、LZMA、zucchini
是快照自带的 Chromium 原生库，予以保留。源树中已有的移植修改仍然保留，
不声称与上游逐字一致；可用 `scripts/upstream_diff.ps1 -ChromiumSrc <path>`
与相同版本的完整 Chromium 源码对比。

源码按原始字节保存，`.gitattributes` 禁止自动转换换行；许可证见根目录
`LICENSE` 以及各第三方目录中的许可证。

## 工具链

需要 Windows、Git LFS、PowerShell、系统 `tar.exe`，以及本地 Visual Studio C++
工具和 Windows SDK。Visual Studio/Windows SDK 不随此仓库分发。

配套工具从同一源目录按组件归档到 `toolchain/*.zip`，通过 Git LFS 保存。
`toolchain/manifest.json` 记录每个归档的 SHA-256、压缩大小、文件数及恢复目录。
包含 LLVM、Rust、Dawn 的 Go SDK、depot_tools 的 CIPD/external 缓存与 bootstrap
Python，以及 GN、Ninja 和 Chromium 的 rc.exe。depot_tools 脚本本身作为普通源码
保存；恢复的二进制目录被忽略，不会重复进入 Git。

```powershell
git lfs install
git lfs pull
.\scripts\restore_toolchain.ps1
New-Item -ItemType Directory -Force out\Debug_x64 | Out-Null
Copy-Item args_example\Debug_x64.gn out\Debug_x64\args.gn
.\scripts\gn.ps1 gen out\Debug_x64
.\scripts\ninja.ps1 -C out\Debug_x64 default
```

Release 配置使用 `args_example/Release_x64.gn`，并使用独立输出目录。
测试目标可用 `ninja.ps1 -C out\Debug_x64 tests` 构建；运行对应测试程序时，
应从输出目录执行，以便找到依赖 DLL 和测试数据。非 Windows 配置未验证。

构建脚本优先使用本仓库 depot_tools 的 bootstrap Python，禁用 depot_tools
自动更新，并通过 `DEPOT_TOOLS_WIN_TOOLCHAIN=0` 使用本机 Visual Studio。
切换工具链版本后使用全新的输出目录，避免复用旧对象文件。

工具链更新时，从匹配版本的可信源重新生成相应 ZIP（条目路径相对仓库根目录），
更新 manifest 中的校验值和计数，再提交归档与 manifest。恢复脚本覆盖归档内的
文件；版本更新需要在干净工作副本恢复，以免残留旧版本文件。

当前仓库未配置远端，仅能验证本地 LFS 对象和恢复流程。推送前需确认目标服务
支持 Git LFS，且单对象大小及存储/流量配额足够。可用 `git lfs env` 查看端点，
推送时由 LFS pre-push hook 上传工具链对象；普通 Git 克隆仍需下载 LFS 内容。
