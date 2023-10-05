# Clashmgr

自用 Shell 脚本，用来管理 Clash 服务，已稳定使用多年。

支持 Linux (Bash) 和 Windows (PowerShell) 平台。

我喜欢简单轻量的工具，需求也轻量，Clash for Windows 体积 300M+ ，太重，我也用不到那些高级功能。
Clash 的核心程序才不到 4M 大小，因此决定自己写脚本管理 Clash 服务。

脚本实现功能：

1. 启动/关闭服务

2. 切换配置文件

3. 更新机场订阅

4. 更新运行时文件 (包括 Clash 核心程序、GEOIP 数据库、clash-dashboard 管理面板)

脚本实现原理：

启动/关闭服务：就是简单的进程管理，启动时拼接参数指定了 clash-dashboard 目录。

切换配置文件：因为 Clash 服务启动后开放了 http 接口用来管理服务，
所以脚本实际做的工作就是拼接 http 请求参数然后用 cURL 向 Clash 服务发送请求并解析返回值。

更新订阅和更新运行时就是用 cURL 下载新版本并替换旧文件。

使用方法在英文 README。
