# VLESS Reality & Trojan Reality 一键脚本 V4.0

一键安装并配置基于 [Xray-core](https://github.com/XTLS/Xray-core) 的 VLESS Reality 和 Trojan Reality 节点，同时支持 Shadowsocks (SS) 和 Socks5 代理，轻松实现多协议代理服务。  

## 主要功能

- 自动检测并安装 Xray-core  
- 一键部署 VLESS Reality 节点  
- 一键部署 Trojan Reality 节点  
- 生成并显示节点连接链接  
- 生成 Shadowsocks (SS) 和 Socks5 代理配置（可选）  
- 查询当前 Xray 已部署协议及对应连接信息  
- 流媒体解锁检测（Netflix、Disney+、YouTube Premium、ChatGPT 等）  
- IP 纯净度检测（检测常用域名连通性）  
- BBR TCP加速开启  
- Ookla Speedtest 网络测速  
- 一键卸载 Xray  

## 支持系统

- Debian / Ubuntu  
- CentOS（自动更换为阿里云源）  
- Alpine Linux（基础依赖安装支持）  

## 使用说明
   ```bash
   bash <(curl -Ls https://raw.githubusercontent.com/sdd-tes/autoxraybash/main/xray.sh)

根据菜单提示选择需要的功能，如安装节点、测速、生成链接等。



示例链接格式

VLESS Reality：

vless://UUID@IP:PORT?type=tcp&security=reality&sni=www.cloudflare.com&fp=chrome&pbk=PUBKEY&sid=SHORTID#Remark

Trojan Reality：

trojan://PASSWORD@IP:PORT#Remark

Shadowsocks (SS)：

ss://BASE64(method:password)@IP:PORT#Remark

Socks5：

直接使用 IP、端口，配合用户名密码认证（如启用）。


依赖和第三方项目

Xray-core — 核心代理软件

jq — JSON 解析工具

openssl — 生成随机密码

Ookla Speedtest CLI — 网络测速工具

本脚本部分代码参考自 Xray 官方安装脚本和社区优秀脚本，感谢所有开源贡献者。


备注

本脚本适合具备基本 Linux 使用经验的用户操作。

请确保服务器已开启对应端口，避免防火墙阻挡。

部署后建议测试节点连接是否正常，确认无误后方可使用。

流媒体解锁检测依赖网络环境，结果仅供参考。


许可证

本脚本遵循 MIT 许可证，欢迎 Fork 和贡献。


---

如果你有任何问题或建议，欢迎提交 Issue 或联系我。


---
