<div align="center">

[🇺🇸 English](../../README.md) &nbsp;/&nbsp; [🇮🇷 فارسی](README_fa.md) &nbsp;/&nbsp; **🇨🇳 简体中文** &nbsp;/&nbsp; [🇷🇺 Русский](README_ru.md)

</div>
<br>

<p align="center"><img src="../images/logo.png" width="128" alt="Vista VPN"></p>

<h1 align="center">Vista VPN</h1>

<h2 align="center">⚠️ 非官方项目</h2>

<h3 align="center">Vista VPN 是一个独立项目，并非由 Mozilla 开发、拥有、赞助或认可，与 Mozilla 没有任何关联。参见<a href="#免责声明">免责声明</a>。</h3>

<div align="center">

[![Downloads](https://img.shields.io/github/downloads/thisisvista/vista-vpn/total?style=flat&logo=github&label=Downloads)](https://github.com/thisisvista/vista-vpn/releases)
[![Last Version](https://img.shields.io/github/v/release/thisisvista/vista-vpn?style=flat&label=Version)](https://github.com/thisisvista/vista-vpn/releases/latest)
[![License](https://img.shields.io/github/license/thisisvista/vista-vpn?style=flat&label=License)](../../LICENSE)

</div>

## Vista VPN 是什么？

**Vista VPN** 是一款面向 Firefox 账户的独立开源 VPN 客户端。它通过 Fastly 基础设施上的 Mozilla VPN 服务器，使用 **HTTP/1.1、HTTP/2 和 HTTP/3** 隧道传输网络流量。

支持 **Android、Windows、macOS 和 Linux**；完全免费，没有广告。

<p align="center"><a href="https://raw.githubusercontent.com/thisisvista/vista-vpn/main/docs/screenshots/main.webp" target="_blank"><img src="../screenshots/main.webp" width="720" alt="Vista VPN"></a></p>

## 功能

- **多平台支持：** Android、Windows、macOS 和 Linux。
- **Android TV：** 可使用遥控器进行操作。
- **简洁界面：** 将常用连接控制集中在清晰的界面中。
- **免费流量：** 每个 Firefox 账户每月 50 GB。
- **服务器选择：** 测试延迟后手动选择地区，也可以交由 Vista 自动选择。
- **连接协议：** 支持 HTTP/1.1、HTTP/2 和 HTTP/3。
- **兼容 Firefox 的 TLS：** 通过 uTLS，使连接 Mozilla 服务器时使用类似 Firefox 的 TLS 指纹。
- **分流模式：** 指定绕过 VPN 的网站和应用（Split Tunneling）。
- **受限网络选项：** TLS 分片、上游 SOCKS5 代理，以及可选的[中继服务器](../relay/README.md)。
- **备份与恢复：** 导出账户和设置，以便在其他设备或服务器上使用。
- **网络设置：** IPv4、IPv6、双栈模式和自定义 MTU。
- **加密 DNS：** 支持 DNS over HTTPS。
- **多语言：** 提供 15 种语言，包括中文、英语、波斯语和俄语。
- **界面主题：** 浅色和深色模式。
- **开源项目：** 项目代码开放，便于查看和参与改进。
- **自动更新：** 支持自动更新。

## 截图

<p align="center">
<img src="../screenshots/phone_01.webp" width="240" alt="Home">&nbsp;&nbsp;
<img src="../screenshots/phone_02.webp" width="240" alt="Servers">&nbsp;&nbsp;
<img src="../screenshots/phone_03.webp" width="240" alt="Settings">
</p>

## 下载

<table>
<thead>
<tr><th>系统</th><th>下载</th></tr>
</thead>
<tbody>
<tr><td>Android</td><td><a href="https://github.com/thisisvista/vista-vpn/releases/latest/download/Vista-VPN-Android-universal.apk"><img src="https://img.shields.io/badge/APK-Universal-1a7f37?logo=android&logoColor=white" alt="APK Universal"></a><br><a href="https://github.com/thisisvista/vista-vpn/releases/latest/download/Vista-VPN-Android-arm64-v8a.apk"><img src="https://img.shields.io/badge/APK-ARMv8-2da44e?logo=android&logoColor=white" alt="APK ARMv8"></a><br><a href="https://github.com/thisisvista/vista-vpn/releases/latest/download/Vista-VPN-Android-armeabi-v7a.apk"><img src="https://img.shields.io/badge/APK-ARMv7-4ac26b?logo=android&logoColor=white" alt="APK ARMv7"></a><br><a href="https://github.com/thisisvista/vista-vpn/releases/latest/download/Vista-VPN-Android-x86_64.apk"><img src="https://img.shields.io/badge/APK-x64-6fdd8b?logo=android&logoColor=white" alt="APK x64"></a></td></tr>
<tr><td>Android TV</td><td><a href="https://github.com/thisisvista/vista-vpn/releases/latest/download/Vista-VPN-Android-universal.apk"><img src="https://img.shields.io/badge/APK-Universal-1a7f37?logo=android&logoColor=white" alt="APK Universal"></a></td></tr>
<tr><td>Windows</td><td><a href="https://github.com/thisisvista/vista-vpn/releases/latest/download/Vista-VPN-Windows-Setup-x64.exe"><img src="https://img.shields.io/badge/Setup-x64-0550ae?logo=windows&logoColor=white" alt="Setup x64"></a><br><a href="https://github.com/thisisvista/vista-vpn/releases/latest/download/Vista-VPN-Windows-x64.zip"><img src="https://img.shields.io/badge/Portable-x64-0969da" alt="Portable x64"></a></td></tr>
<tr><td>macOS</td><td><a href="https://github.com/thisisvista/vista-vpn/releases/latest/download/Vista-VPN-macOS.dmg"><img src="https://img.shields.io/badge/DMG-Universal-24292f?logo=apple&logoColor=white" alt="DMG Universal"></a></td></tr>
<tr><td rowspan="2">Linux</td><td><a href="https://github.com/thisisvista/vista-vpn/releases/latest/download/Vista-VPN-Linux-amd64.tar.gz"><img src="https://img.shields.io/badge/App-amd64-e36209?logo=linux&logoColor=white" alt="App amd64"></a><br><a href="https://github.com/thisisvista/vista-vpn/releases/latest/download/Vista-VPN-Linux-arm64.tar.gz"><img src="https://img.shields.io/badge/App-ARM64-e36209?logo=linux&logoColor=white" alt="App ARM64"></a></td></tr>
<tr><td><a href="https://github.com/thisisvista/vista-vpn/releases/latest/download/vista-vpn-core-linux-amd64.tar.gz"><img src="https://img.shields.io/badge/Core-amd64-f0883e?logo=linux&logoColor=white" alt="Core amd64"></a><br><a href="https://github.com/thisisvista/vista-vpn/releases/latest/download/vista-vpn-core-linux-arm64.tar.gz"><img src="https://img.shields.io/badge/Core-ARM64-f6a35e?logo=linux&logoColor=white" alt="Core ARM64"></a></td></tr>
</tbody>
</table>

**该下载哪个文件？**

- **Android：** 不确定的话，选 **Universal**，所有手机都能安装。**ARMv8** 适用于大多数现代手机，体积更小。
- **Windows：** **Setup** 是普通安装程序；**Portable** 无需安装，可在任意文件夹运行。
- **Linux：** **App** 用于 Linux 桌面（有图形界面）；**Core** 用于服务器（无图形界面，带网页面板）。

## Linux 和 macOS 安装

> Windows 和 Android 用户无需阅读本节：直接从上方“下载”表格获取安装文件。

```bash
curl -fsSL https://raw.githubusercontent.com/thisisvista/vista-vpn/main/install.sh | bash
```

### 网页面板

在 Linux 服务器上，Vista VPN 提供一个**网页面板**，可在任何浏览器中打开，拥有应用的全部功能：管理账户和流量、选择服务器并测试延迟、连接测试、实时日志以及所有设置。

<p align="center"><img src="../screenshots/web.webp" width="720" alt="Web panel"></p>

- **面板地址：** `http://SERVER-IP:10820/app/`，需要用户名和密码。安装结束时会显示确切地址。
- **代理：** 端口 `10810` 上的 SOCKS5 和 HTTP，使用单独的用户名和密码。

### 终端管理

在服务器上运行 `sudo vista-vpn`，即可打开管理菜单：

```text
$ sudo vista-vpn

  Vista VPN
  ────────────────────────────────────────────────────────────────────────────
    Service     ● running
    Autostart   on
  ────────────────────────────────────────────────────────────────────────────
   0) Exit
  ────────────────────────────────────────────────────────────────────────────
   1) Update                                   vista-vpn update
   2) Uninstall                                vista-vpn uninstall
  ────────────────────────────────────────────────────────────────────────────
   3) Set panel login                          vista-vpn panel
   4) View panel info                          vista-vpn panel-info
  ────────────────────────────────────────────────────────────────────────────
   5) Status                                   vista-vpn status
   6) Start                                    vista-vpn start
   7) Stop                                     vista-vpn stop
   8) Restart                                  vista-vpn restart
   9) Show the log                             vista-vpn logs
  ────────────────────────────────────────────────────────────────────────────
  10) Enable autostart                         vista-vpn enable
  11) Disable autostart                        vista-vpn disable
  ────────────────────────────────────────────────────────────────────────────
  12) Add a Firefox Account                    vista-vpn add-account
  13) List the accounts                        vista-vpn list-accounts
  ────────────────────────────────────────────────────────────────────────────
  Enter a number [0-13]:
```

## OpenWrt 路由器

如需在 OpenWrt 路由器上安装，请参阅 [OpenWrt 指南](../OPENWRT.md)。

## 免责声明

本应用是一个独立的非官方客户端，由其开发者自行开发和维护。它不是 Mozilla 的产品：Mozilla 没有开发它，不拥有、不赞助、也不认可它，也不参与它的开发或支持。有关本应用的问题请在本仓库提出，而不是向 Mozilla 反映。

你使用自己的 Mozilla 账户登录。账户的条款、流量限额和可用性由 Mozilla 决定。你的密码和登录令牌只保存在你的设备上。
