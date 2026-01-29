
---

# HPRC - HomeProxy 规则集管理工具

**一个简单的 OpenWrt 脚本，让 HomeProxy 的规则更新变得安全、省心。**

---

## 🤖 关于本项目 (Project Story)

**特别说明：这是一个由 AI 协助完成的项目。**

我本人并不懂代码，**HPRC** 的诞生源于我对路由维护痛点的思考。我负责提出构思、设计逻辑架构和测试反馈，而所有的代码实现、Debug 和脚本编写，均由 AI (Google Gemini) 协助完成。

这是一个验证想法的产物，希望它也能帮到有同样需求的你。

---

## ✨ 它是做什么的？

简单来说，它解决三个问题：

1. **怕更新断网**：它会先检查，如果新规则有问题导致服务起不来，它会自动回滚到旧规则，保证家里不断网。
2. **怕无效更新**：它会比对文件指纹 (MD5)，只有规则真的变了才会替换，不瞎折腾。
3. **懒得动手**：配合定时任务，每天自动检查，有更新才通知你，没更新就静默退出。

---

## 🚀 怎么用？

### 1. 安装前的准备 (重要)

本脚本需要完整版的 `wget` 来确保下载稳定性（支持断点续传和重试）。OpenWrt 自带的精简版可能会报错。
请先在 SSH 执行：

```bash
opkg update && opkg install wget-ssl

```

### 2. 一键安装

环境准备好后，复制这行命令回车即可：

```bash
sh -c "$(wget -qO- https://raw.githubusercontent.com/Vonzhen/hprc/master/install.sh)"

```

### 3. 使用

安装完成后，随时输入命令调出菜单：

```bash
hprc

```

*你可以用它检测更新、强制更新、或者修改配置（比如换个 TG 通知机器人）。*

### 4. 自动更新 (可选)

想每天早上 7:20 自动跑一次？在 `crontab -e` 里加一行：

```cron
20 7 * * * /usr/bin/hprc auto > /dev/null 2>&1

```

---

## ❤️ 致谢 (Credits)

本项目站在巨人的肩膀上，感谢以下开源项目：

* **[HomeProxy](https://github.com/immortalwrt/homeproxy)**: 优秀的 OpenWrt 插件界面。
* **[sing-box](https://github.com/SagerNet/sing-box)**: 强大的核心代理引擎。
* **[meta-rules-dat](https://github.com/MetaCubeX/meta-rules-dat/tree/sing)**: 优质的规则数据来源。

---

## ⚠️ 免责声明

* 本项目仅为个人维护工具，不提供任何节点或代理服务。
* 由于我本人不懂代码，脚本按“现状”提供。虽然加入了备份和回滚机制，但对于因使用本脚本可能导致的数据丢失或系统问题，我不承担责任。
* 请在合规的前提下使用。
