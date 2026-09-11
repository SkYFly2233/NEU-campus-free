#!/usr/bin/env bash

# 当前脚本版本号
VERSION='v1.8.6-campus (2026.09.11)'

# Github 反代加速代理
GITHUB_PROXY=('https://hub.glowp.xyz/' 'https://proxy.vvvv.ee/')

# 各变量默认值
TEMP_DIR='/tmp/sing-box'
WORK_DIR='/etc/sing-box'
FIREWALL_STATE_DIR="${WORK_DIR}/firewall"
SERVICE_FIREWALL_STATE_FILE="${FIREWALL_STATE_DIR}/service_ports.list"
START_PORT_DEFAULT='8881'
MIN_PORT=100
MAX_PORT=65520
MIN_HOPPING_PORT=10000
MAX_HOPPING_PORT=65535
TLS_SERVER_DEFAULT=addons.mozilla.org
PROTOCOL_LIST=("XTLS + reality" "hysteria2" "tuic" "ShadowTLS" "shadowsocks" "trojan" "vmess + ws" "vless + ws + tls" "H2 + reality" "gRPC + reality" "AnyTLS" "naive")
NODE_TAG=("xtls-reality" "hysteria2" "tuic" "ShadowTLS" "shadowsocks" "trojan" "vmess-ws" "vless-ws-tls" "h2-reality" "grpc-reality" "anytls" "naive")
CONSECUTIVE_PORTS=${#PROTOCOL_LIST[@]}
CDN_DOMAIN=("skk.moe" "ip.sb" "time.is" "cfip.xxxxxxxx.tk" "bestcf.top" "cdn.2020111.xyz" "xn--b6gac.eu.org" "cf.090227.xyz")
SUBSCRIBE_TEMPLATE="https://raw.githubusercontent.com/fscarmen/client_template/main"
SCRIPT_UPDATE_URL="https://raw.githubusercontent.com/SkYFly2233/NEU-campus-free/main/sing-box.sh"
DEFAULT_NEWEST_VERSION='1.14.0-beta.13'
FINGER_PRINT='chrome'
STEP_NUM=0      # 当前步骤编号（安装流程中动态递增）
TOTAL_STEPS=''  # 总步骤数（协议确定后动态计算）
DETECTED_IPS=() # 检测到的本机所有静态 IPv4/IPv6 地址
SERVER_IPS=()   # 用户确认后的连接目标 IP 列表（多 IP）
CAMPUS_DIRECT_CIDR="202.118.0.0/19,202.199.0.0/20,210.30.192.0/20,219.216.64.0/18,58.154.160.0/19,58.154.192.0/18,118.202.0.0/19,118.202.32.0/20"   # 校园网内网直连网段（默认，可用 --CAMPUS_DIRECT_CIDR 覆盖）
CAMPUS_DIRECT_DOMAINS='' # 域名白名单：白名单及其子域名直连（逗号分隔，可用 --CAMPUS_DIRECT_DOMAINS 覆盖）
CAMPUS_DIRECT_DOMAINS_EXPLICIT=false
SUBSCRIBE_TOKEN='' # 订阅 URL 的独立随机凭据；不复用节点 UUID

export DEBIAN_FRONTEND=noninteractive

cleanup_temp() {
  rm -rf "$TEMP_DIR"
}

trap cleanup_temp EXIT
trap 'cleanup_temp; printf "\n"; exit 1' INT QUIT TERM

mkdir -p "$TEMP_DIR"

E[0]="Language:\n 1. English (default) \n 2. 简体中文"
C[0]="${E[0]}"
E[1]="1. Add Clash subscription usage progress headers and a configurable 4 TB monthly server quota; 2. provide an administrator web console and SQLite-backed Hysteria2/TUIC per-user accounting; 3. add a two-protocol-only quick installer; 4. safely back up and remove an old Sing-box installation before a clean reinstall"
C[1]="1. 新增 Clash 订阅已用/总量进度条和默认 4 TB 的可调服务器月流量; 2. 提供管理员网页与 SQLite Hysteria2/TUIC 多用户合并统计; 3. 新增仅安装这两种协议的极速安装; 4. 重装前自动备份并卸载旧 Sing-box"
E[2]="Downloading Sing-box. Please wait a seconds ..."
C[2]="下载 Sing-box 中，请稍等 ..."
E[3]="Input errors up to 5 times.The script is aborted."
C[3]="输入错误达5次,脚本退出"
E[4]="UUID should be 36 characters, please re-enter (\${UUID_ERROR_TIME} times remaining):"
C[4]="UUID 应为36位字符,请重新输入 (剩余\${UUID_ERROR_TIME}次):"
E[5]="The script supports Debian, Ubuntu, CentOS, Alpine, Armbian, Fedora or Arch systems only. Feedback: [https://github.com/fscarmen/sing-box/issues]"
C[5]="本脚本只支持 Debian、Ubuntu、CentOS、Alpine、Armbian、Fedora 或 Arch 系统,问题反馈:[https://github.com/fscarmen/sing-box/issues]"
E[6]="Curren operating system is \$SYS.\\\n The system lower than \$SYSTEM \${MAJOR[int]} is not supported. Feedback: [https://github.com/fscarmen/sing-box/issues]"
C[6]="当前操作是 \$SYS\\\n 不支持 \$SYSTEM \${MAJOR[int]} 以下系统,问题反馈:[https://github.com/fscarmen/sing-box/issues]"
E[7]="Install dependence-list:"
C[7]="安装依赖列表:"
E[8]="All dependencies already exist and do not need to be installed additionally."
C[8]="所有依赖已存在，不需要额外安装"
E[9]="Whether to upgrade [y/N] (default is N):"
C[9]="是否升级 [y/N] (默认为 N):"
E[10]="Please enter server address, IP or domain (Default: \${SERVER_IP_DEFAULT}):"
C[10]="请输入服务器地址（IP 或域名）(默认为: \${SERVER_IP_DEFAULT}):"
E[11]="Please enter the starting port number. Must be \${MIN_PORT} - \${MAX_PORT}, consecutive \${NUM} free ports are required (Default: \${START_PORT_DEFAULT}):"
C[11]="请输入开始的端口号，必须是 \${MIN_PORT} - \${MAX_PORT}，需要连续\${NUM}个空闲的端口 (默认为: \${START_PORT_DEFAULT}):"
E[12]="Please enter UUID (Default: \${UUID_DEFAULT}):"
C[12]="请输入 UUID (默认为: \${UUID_DEFAULT}):"
E[13]="Please enter the node name. (Default: \${NODE_NAME_DEFAULT}):"
C[13]="请输入节点名称 (默认为: \${NODE_NAME_DEFAULT}):"
E[14]="API check failed, using SagerNet URL as default. (Warning: rule_set may not exist)"
C[14]="API 校验失败，默认使用 SagerNet 地址。(警告: 规则集可能不存在)"
E[15]="Sing-box script has not been installed yet."
C[15]="Sing-box 脚本还没有安装"
E[16]="Sing-box is completely uninstalled."
C[16]="Sing-box 已彻底卸载"
E[17]="Version"
C[17]="脚本版本"
E[18]="New features"
C[18]="功能新增"
E[19]="System infomation"
C[19]="系统信息"
E[20]="Operating System"
C[20]="当前操作系统"
E[21]="Kernel"
C[21]="内核"
E[22]="Architecture"
C[22]="处理器架构"
E[23]="Virtualization"
C[23]="虚拟化"
E[24]="Choose:"
C[24]="请选择:"
E[25]="Curren architecture \$(uname -m) is not supported. Feedback: [https://github.com/fscarmen/sing-box/issues]"
C[25]="当前架构 \$(uname -m) 暂不支持,问题反馈:[https://github.com/fscarmen/sing-box/issues]"
E[26]="Not install"
C[26]="未安装"
E[27]="close"
C[27]="关闭"
E[28]="open"
C[28]="开启"
E[29]="View links (sb -n)"
C[29]="查看节点信息 (sb -n)"
E[30]="Listen ports  (current: \${VAL_ITEM})"
C[30]="监听端口  (当前: \${VAL_ITEM})"
E[31]="Sync Sing-box to the latest version (sb -v)"
C[31]="同步 Sing-box 至最新版本 (sb -v)"
E[32]="Upgrade kernel, turn on BBR, change Linux system (sb -b)"
C[32]="升级内核、安装BBR、DD脚本 (sb -b)"
E[33]="Uninstall (sb -u)"
C[33]="卸载 (sb -u)"
E[34]="Install Sing-box"
C[34]="安装 Sing-box"
E[35]="Exit"
C[35]="退出"
E[36]="Please enter the correct number"
C[36]="请输入正确数字"
E[37]="successful"
C[37]="成功"
E[38]="failed"
C[38]="失败"
E[39]="Sing-box is not installed and cannot change the Argo tunnel."
C[39]="Sing-box 未安装，不能更换 Argo 隧道"
E[40]="Sing-box local verion: \$LOCAL\\\t The newest verion: \$ONLINE"
C[40]="Sing-box 本地版本: \$LOCAL\\\t 最新版本: \$ONLINE"
E[41]="No upgrade required."
C[41]="不需要升级"
E[42]="Downloading the latest version Sing-box failed, script exits. Feedback:[https://github.com/fscarmen/sing-box/issues]"
C[42]="下载最新版本 Sing-box 失败，脚本退出，问题反馈:[https://github.com/fscarmen/sing-box/issues]"
E[43]="The script must be run as root, you can enter sudo -i and then download and run again. Feedback:[https://github.com/fscarmen/sing-box/issues]"
C[43]="必须以root方式运行脚本，可以输入 sudo -i 后重新下载运行，问题反馈:[https://github.com/fscarmen/sing-box/issues]"
E[44]="Ports are in used:  \${IN_USED[*]}"
C[44]="正在使用中的端口: \${IN_USED[*]}"
E[45]="Current custom route rules:"
C[45]="当前自定义路由规则:"
E[46]="Warp / warp-go was detected to be running. Please enter the correct server address (IP or domain):"
C[46]="检测到 warp / warp-go 正在运行，请输入确认的服务器地址（IP 或域名）:"
E[47]="No server ip, script exits. Feedback:[https://github.com/fscarmen/sing-box/issues]"
C[47]="没有 server ip，脚本退出，问题反馈:[https://github.com/fscarmen/sing-box/issues]"
E[48]="Client Fingerprint  (current: \${VAL_ITEM})"
C[48]="客户端指纹  (当前: \${VAL_ITEM})"
E[49]="Select more protocols to install (e.g. hgbd). The order of the port numbers of the protocols is related to the ordering of the multiple choices:\n a. all (default)"
C[49]="多选需要安装协议(比如 hgbd)，协议的端口号次序与多选的排序有关:\n a. all (默认)"
E[50]="Please enter the \$TYPE domain name:"
C[50]="请输入 \$TYPE 域名:"
E[51]="Please select or input client fingerprint:\n 1. chrome (default)\n 2. firefox\n Or input custom value:"
C[51]="请选择或输入客户端指纹:\n 1. chrome (默认)\n 2. firefox\n 或直接输入自定义值:"
E[52]="Please set the ip [\${WS_SERVER_IP_SHOW}] to domain [\${TYPE_HOST_DOMAIN}], and set the origin rule to [\${TYPE_PORT_WS}] in Cloudflare."
C[52]="请在 Cloudflare 绑定 [\${WS_SERVER_IP_SHOW}] 的域名为 [\${TYPE_HOST_DOMAIN}], 并设置 origin rule 为 [\${TYPE_PORT_WS}]"
E[53]="Please select or enter the preferred address (domain / IPv4 / [IPv6], optional :port), the default is \${CDN_DOMAIN[0]}:"
C[53]="请选择或者填入优选地址（域名 / IPv4 / [IPv6]，可选 :端口），默认为 \${CDN_DOMAIN[0]}:"
E[54]="Configuration check failed, new version \$ONLINE is incompatible with current config."
C[54]="配置文件检查失败，新版本 \$ONLINE 与当前配置不兼容"
E[55]="The script runs today: \$TODAY. Total: \$TOTAL"
C[55]="脚本当天运行次数: \$TODAY，累计运行次数: \$TOTAL"
E[56]="Invalid fingerprint format."
C[56]="无效的指纹格式"
E[57]="Selecting the ws return method:\n 1. Argo (default)\n 2. Origin rules"
C[57]="选择 ws 的回源方式:\n 1. Argo (默认)\n 2. Origin rules"
E[58]="Memory Usage"
C[58]="内存占用"
E[59]="Install ArgoX scripts (argo + xray) [https://github.com/fscarmen/argox]"
C[59]="安装 ArgoX 脚本 (argo + xray) [https://github.com/fscarmen/argox]"
E[60]="The order of the selected protocols and ports is as follows:"
C[60]="选择的协议及端口次序如下:"
E[61]="There are no replaceable Argo tunnels."
C[61]="没有可更换的Argo 隧道"
E[62]="Add / Remove protocols (sb -r)"
C[62]="增加 / 删除协议 (sb -r)"
E[63]="Close Realm"
C[63]="关闭 Realm"
E[64]="Please select the protocols to be removed (multiple selections possible. Press Enter to skip):"
C[64]="请选择需要删除的协议（可以多选，回车跳过）:"
E[65]="Open Realm"
C[65]="开启 Realm"
E[66]="Please select the protocols to be added (multiple choices possible. Press Enter to skip):"
C[66]="请选择需要增加的协议（可以多选，回车跳过）:"
E[67]="Bind network interface  (current: \${VAL_ITEM:-default})"
C[67]="指定网络出口  (当前: \${VAL_ITEM:-默认})"
E[68]="Press [n] if there is an error, other keys to continue:"
C[68]="如有错误请按 [n]，其他键继续:"
E[69]="Install sba scripts (argo + sing-box) [https://github.com/fscarmen/sba]"
C[69]="安装 sba 脚本 (argo + sing-box) [https://github.com/fscarmen/sba]"
E[70]="Please enter the reality private key (privateKey), skip to generate randomly:"
C[70]="请输入 reality 的密钥(privateKey)，跳过则随机生成:"
E[71]="Create shortcut [ sb ] successfully."
C[71]="创建快捷 [ sb ] 指令成功!"
E[72]="Path to each client configuration file: ${WORK_DIR}/subscribe/\n The full template can be found at:\n https://github.com/chika0801/sing-box-examples/tree/main/Tun"
C[72]="各客户端配置文件路径: ${WORK_DIR}/subscribe/\n 完整模板可参照:\n https://github.com/chika0801/sing-box-examples/tree/main/Tun"
E[73]=""
C[73]=""
E[74]="Keep protocols"
C[74]="保留协议"
E[75]="Add protocols"
C[75]="新增协议"
E[76]="Install TCP brutal"
C[76]="安装 TCP brutal"
E[77]="Please select network interface:"
C[77]="请选择网络接口:"
E[78]="1. Default (not specified)"
C[78]="1. 默认（不指定）"
E[79]="Please enter the port number of nginx. Must be \${MIN_PORT} - \${MAX_PORT} (Default: \${PORT_NGINX_DEFAULT}):"
C[79]="请输入 nginx 端口号，必须是 \${MIN_PORT} - \${MAX_PORT} (默认为: \${PORT_NGINX_DEFAULT}):"
E[80]="subscribe"
C[80]="订阅"
E[81]="Adaptive Clash / V2rayN / Throne / ShadowRocket / SFI / SFA / SFM Clients"
C[81]="自适应 Clash / V2rayN / Throne / ShadowRocket / SFI / SFA / SFM 客户端"
E[82]="template"
C[82]="模版"
E[83]="Whether to uninstall Nginx [y/N] (default is N):"
C[83]="是否卸载 Nginx [y/N] (默认为 N):"
E[84]="Bound interface updated to: "
C[84]="绑定接口已更新为: "
E[85]="Please enter Argo Token, Argo Json or Cloudflare API\n\n [*] Token: Visit https://dash.cloudflare.com/ , Zero Trust > Networks > Connectors > Create a tunnel > Select Cloudflared\n\n [*] Json: Users can easily obtain it through the following website: https://fscarmen.cloudflare.now.cc\n\n [*] Cloudflare API: Visit https://dash.cloudflare.com/profile/api-tokens > Create Token > Create Custom Token > Add the following permissions:\n - Account > Cloudflare One Connectors: cloudflared > Edit\n - Zone > DNS > Edit\n\n - Account Resources: Include > Required Account\n - Zone Resources: Include > Specific zone > Argo Root Domain"
C[85]="请输入 Argo Token, Argo Json 或者 Cloudflare API\n\n [*] Token: 访问 https://dash.cloudflare.com/ ，Zero Trust > 网络 > 连接器 > 创建隧道 > 选择 Cloudflared\n\n [*] Json: 用户通过以下网站轻松获取: https://fscarmen.cloudflare.now.cc\n\n [*] Cloudflare API: 访问 https://dash.cloudflare.com/profile/api-tokens > 创建令牌 > 创建自定义令牌 > 添加以下权限:\n - 帐户 > Cloudflare One连接器: Cloudflared > 编辑\n - 区域 > DNS > 编辑\n\n - 帐户资源: 包括 > 所需账户\n - 区域资源: 包括 > 特定区域 > 所需域名"
E[86]="Argo authentication message does not match the rules, neither Token nor Json, script exits. Feedback:[https://github.com/fscarmen/sba/issues]"
C[86]="Argo 认证信息不符合规则，既不是 Token，也是不是 Json，脚本退出，问题反馈:[https://github.com/fscarmen/sba/issues]"
E[87]="Please input the Argo domain (Default is temporary domain if left blank):"
C[87]="请输入 Argo 域名 (如果没有，可以跳过以使用 Argo 临时域名):"
E[88]="Please input the Argo domain (cannot be empty):"
C[88]="请输入 Argo 域名 (不能为空):"
E[89]="( Additional dependencies: nginx )"
C[89]="( 额外依赖: nginx )"
E[90]="Argo tunnel is: \$ARGO_TYPE\\\n The domain is: \$ARGO_DOMAIN"
C[90]="Argo 隧道类型为: \$ARGO_TYPE\\\n 域名是: \$ARGO_DOMAIN"
E[91]="Argo tunnel type:\n 1. Try\n 2. Token or Json. Including created through Cloudflare API"
C[91]="Argo 隧道类型:\n 1. Try\n 2. Token 或者 Json，包括通过 Cloudflare API 创建"
E[92]="Change the Argo tunnel (sb -t)"
C[92]="更换 Argo 隧道 (sb -t)"
E[93]="Can't get the temporary tunnel domain, script exits. Feedback:[https://github.com/fscarmen/sing-box/issues]"
C[93]="获取不到临时隧道的域名，脚本退出，问题反馈:[https://github.com/fscarmen/sing-box/issues]"
E[94]="Please bind [\${ARGO_DOMAIN}] tunnel TYPE to HTTP and URL to [localhost:\${PORT_NGINX}] in Cloudflare."
C[94]="请在 Cloudflare 绑定 [\${ARGO_DOMAIN}] 隧道 TYPE 为 HTTP，URL 为 [localhost:\${PORT_NGINX}]"
E[95]="Hot reload successful (PID unchanged: \$MAINPID)"
C[95]="热加载成功（PID 未变: \$MAINPID）"
E[96]="netfilter-persistent is not started, PortHopping forwarding rules cannot be persisted. Reboot the system, the rules will be invalidated, please manually execute [netfilter-persistent save], continue the script does not affect the subsequent configuration."
C[96]="netfilter-persistent未启动，PortHopping转发规则无法持久化，重启系统，规则将会失效，请手动执行 [netfilter-persistent save],继续运行脚本不影响后续配置"
E[97]="Port Hopping/Multiple: Users sometimes report that their ISPs block or throttle persistent UDP connections. However, these restrictions often only apply to the specific port being used. Port hopping can be used as a workaround for this situation. This function needs to occupy multiple ports, please make sure that these ports are not listening to other services. \n Tip1: The number of ports should not be too many, the recommended number is about 1000, the minimum value: $MIN_HOPPING_PORT, the maximum value: $MAX_HOPPING_PORT.\n Tip2: nat machines have a limited number of ports to listen on, usually 20-30. If setting ports out of the nat range will cause the node to not work, please use with caution!\n This function is not used by default."
C[97]="端口跳跃/多端口(Port Hopping)介绍: 用户有时报告运营商会阻断或限速 UDP 连接。不过，这些限制往往仅限单个端口。端口跳跃可用作此情况的解决方法。该功能需要占用多个端口，请保证这些端口没有监听其他服务\n Tip1: 端口选择数量不宜过多，推荐1000个左右，最小值:$MIN_HOPPING_PORT，最大值: $MAX_HOPPING_PORT\n Tip2: nat 鸡由于可用于监听的端口有限，一般为20-30个。如设置了不开放的端口会导致节点不通，请慎用！\n 默认不使用该功能"
E[98]="Enter the port range, e.g. 50000:51000. Leave blank to disable:"
C[98]="请输入端口范围，例如 50000:51000，如要禁用请留空:"
E[99]="The \${SING_BOX_SCRIPT} is detected to be installed. Script exits."
C[99]="检测到已安装 \${SING_BOX_SCRIPT}，脚本退出!"
E[100]="Can't get the official latest version. Script exits."
C[100]="获取不到官方的最新版本，脚本退出!"
E[101]="Failed to update configuration. Please check manually. Suggestion: reinstall script"
C[101]="更新配置后仍然无法检查成功，建议重装脚本"
E[102]="Backing up old version sing-box to ${WORK_DIR}/sing-box.bak"
C[102]="已备份旧版本 sing-box 到 ${WORK_DIR}/sing-box.bak"
E[103]="New version \$ONLINE is running successfully, backup file deleted"
C[103]="新版本 \$ONLINE 运行成功，已删除备份文件"
E[104]="New version failed to run \$ONLINE, restoring old version \$LOCAL ..."
C[104]="新版本 \$ONLINE 运行失败，正在恢复旧版本 \$LOCAL ..."
E[105]="Successfully restored old version \$LOCAL"
C[105]="已成功恢复旧版本 \$LOCAL"
E[106]="Failed to restore old version \$LOCAL, please check manually"
C[106]="恢复旧版本 \$LOCAL 失败，请手动检查"
E[107]="Sing-box is not installed and cannot change the CDN."
C[107]="Sing-box 未安装，不能更换 CDN"
E[108]="Enable subscription"
C[108]="开启订阅"
E[109]="Disable subscription"
C[109]="关闭订阅"
E[110]="Port hopping is enabled. Enabling Realm will disable port hopping. Continue? [y/N] (default N):"
C[110]="端口跳跃已开启，启用 Realm 将关闭端口跳跃。是否继续？[y/N]（默认 N）:"
E[111]="Update base configuration? (Node configs will remain unaffected; only log, outbounds, endpoints, route, experimental, dns, ntp, http_clients, etc., will be reset) [Y/n]:"
C[111]="是否更新基础配置？（不影响节点配置，仅重置 log、outbounds、endpoints、route、experimental、dns、ntp、http_clients）[Y/n]:"
E[112]="Change complete"
C[112]="修改完成"
E[113]="Failed to change CDN, using random privateKey"
C[113]="privateKey 格式失败次数过多，已使用随机私钥"
E[114]="Invalid privateKey format: expected a 43-character base64url-encoded string."
C[114]="privateKey 私钥格式错误，应该为 43位 base64url 编码"
E[115]="Quick install Hysteria2 + TUIC only (strict multi-user subscription) (bash sing-box.sh -k)"
C[115]="极速安装 Hysteria2 + TUIC（仅这两种协议 + 严格多用户订阅）(bash sing-box.sh -l)"
E[116]="Failed to generate publicKey from privateKey, using random privateKey"
C[116]="从 privateKey 生成 publicKey 失败，将使用随机公私钥"
E[117]="Continue with quick fast tunnel"
C[117]="使用临时隧道继续"
E[118]="Please enter [Token, Json, API] value:"
C[118]="请输入 [Token, Json, API] 的值:"
E[119]="Using Cloudflare API to create Tunnel and handle DNS config..."
C[119]="使用 Cloudflare API 创建 Tunnel 和处理 DNS 配置..."
E[120]="Found existing tunnel with the same name. Tunnel ID: \$EXISTING_TUNNEL_ID. Status: \$EXISTING_TUNNEL_STATUS. Overwrite? [Y/n] (default is Y):"
C[120]="发现同名隧道已创建，隧道 ID: \$EXISTING_TUNNEL_ID，状态: \$EXISTING_TUNNEL_STATUS。是否覆盖? [Y/n] (默认为 Y):"
E[121]="Change node configuration (sb -d)"
C[121]="修改节点配置 (sb -d)"
E[122]="Invalid access token. Please roll at https://dash.cloudflare.com/profile/api-tokens to re-generate."
C[122]="Token 访问令牌无效。请在 https://dash.cloudflare.com/profile/api-tokens 轮转，以重新获取"
E[123]="Token zone resource failed. The tunnel root domain and the authorized domain of the token are inconsistent. Please go to https://dash.cloudflare.com/profile/api-tokens to re-authorize."
C[123]="Token 区域资源获取失败，隧道的根域名和 Token 授权的域名不一致，请到 https://dash.cloudflare.com/profile/api-tokens 检查"
E[124]="API does not have enough permissions. Please check at https://dash.cloudflare.com/profile/api-tokens\n\n [*] Token: Visit https://dash.cloudflare.com/ , Zero Trust > Networks > Connectors > Create a tunnel > Select Cloudflared\n\n [*] Json: Users can easily obtain it through the following website: https://fscarmen.cloudflare.now.cc\n\n [*] Cloudflare API: Visit https://dash.cloudflare.com/profile/api-tokens > Create Token > Create Custom Token > Add the following permissions:\n - Account > Cloudflare One Connectors: cloudflared > Edit\n - Zone > DNS > Edit\n\n - Account Resources: Include > Required Account\n - Zone Resources: Include > Specific zone > Argo Root Domain"
C[124]="API 没有足够权限，请在 https://dash.cloudflare.com/profile/api-tokens 检查 Token 权限配置\n\n [*] Token: 访问 https://dash.cloudflare.com/ ，Zero Trust > 网络 > 连接器 > 创建隧道 > 选择 Cloudflared\n\n [*] Json: 用户通过以下网站轻松获取: https://fscarmen.cloudflare.now.cc\n\n [*] Cloudflare API: 访问 https://dash.cloudflare.com/profile/api-tokens > 创建令牌 > 创建自定义令牌 > 添加以下权限:\n - 帐户 > Cloudflare One连接器: Cloudflared > 编辑\n - 区域 > DNS > 编辑\n\n - 帐户资源: 包括 > 所需账户\n - 区域资源: 包括 > 特定区域 > 所需域名"
E[125]="API execution failed. Response: \$RESPONSE"
C[125]="执行 API 失败，返回: \$RESPONSE"
E[126]="Network request URL structure is wrong. Missing Zone ID"
C[126]="网络请求地址（URL）结构不对，缺少 Zone ID"
E[127]="Please select what to modify:"
C[127]="请选择修改项目:"
E[128]="Preferred CDN  (current: \${VAL_ITEM})"
C[128]="优选域名/IP  (当前: \${VAL_ITEM})"
E[129]="Reality SNI  (current: \${VAL_ITEM})"
C[129]="Reality SNI  (当前: \${VAL_ITEM})"
E[130]="Node name  (current: \${VAL_ITEM})"
C[130]="节点名称  (当前: \${VAL_ITEM})"
E[131]="UUID / Password  (current: \${VAL_ITEM})"
C[131]="UUID / 密码  (当前: \${VAL_ITEM})"
E[132]="Server address  (current: \${VAL_ITEM})"
C[132]="服务器地址  (当前: \${VAL_ITEM})"
E[133]="Invalid server address (IPv4 / IPv6 / domain)"
C[133]="服务器地址格式错误（IPv4 / IPv6 / 域名）"
E[134]="Please enter new value (press Enter to skip):"
C[134]="请输入新值 (回车跳过):"
E[135]="No change was made."
C[135]="未做任何修改"
E[136]="Installed protocols."
C[136]="已安装的协议"
E[137]="Uninstalled protocols."
C[137]="未安装的协议"
E[138]="Confirm all protocols for reloading."
C[138]="确认重装的所有协议"
E[139]="Hysteria2 Port Hopping  (current: \${HY2_PORT_HOPPING_RANGE:-disabled}) [leave blank to disable]"
C[139]="Hysteria2 端口跳跃  (当前: \${HY2_PORT_HOPPING_RANGE:-禁用}) [留空则禁用]"
E[140]="Hysteria2 bandwidth  (current: up \${HY2_UP_NOW} Mbps, down \${HY2_DOWN_NOW} Mbps)"
C[140]="Hysteria2 带宽  (当前: 上行 \${HY2_UP_NOW} Mbps, 下行 \${HY2_DOWN_NOW} Mbps)"
E[141]="Please enter Hysteria2 client upload speed in Mbps (e.g. 200):"
C[141]="请输入 Hysteria2 客户端上行速率 Mbps（纯数字，如 200）:"
E[142]="Please enter Hysteria2 client download speed in Mbps (e.g. 1000):"
C[142]="请输入 Hysteria2 客户端下行速率 Mbps（纯数字，如 1000）:"
E[143]="Invalid input, please enter a positive integer."
C[143]="输入无效，请输入正整数。"
E[144]="UFW was detected. PortHopping forwarding rules will be managed by UFW, and iptables / netfilter-persistent will not be installed."
C[144]="检测到 UFW。PortHopping 转发规则将由 UFW 管理，不再安装 iptables / netfilter-persistent"
E[145]="UFW is not active. PortHopping forwarding rules were written, but you should manually enable UFW to make sure the policy is applied."
C[145]="UFW 未处于激活状态。PortHopping 转发规则已写入，但建议手动启用 UFW 以确保策略生效"
E[146]="Failed to update UFW PortHopping forwarding rules. Please check UFW configuration files manually."
C[146]="更新 UFW 的 PortHopping 转发规则失败，请手动检查 UFW 配置文件"
E[147]="Hysteria2 Realm is useful for China-back routing or machines without public inbound access. It is not recommended when the server already has a public inbound IP/port. Enable Realm? [y/N] (default is N):"
C[147]="Hysteria2 Realm 适用于回国或者没有公网入口的机器；有公网入口时不建议使用。是否启用？[y/N] (默认为 N):"
E[148]="WARP-assisted hole punching is useful in strict NAT environments. When direct hole punching fails, Cloudflare WARP can provide a CF egress path to improve success. Enable it? [y/N]:"
C[148]="WARP 辅助打洞（适用于 NAT 严格环境）：当 NAT 类型较严格（如对称 NAT）导致直连打洞失败时，可借助 Cloudflare WARP 获取一个 CF 出口 IP 作为中转，提升打洞成功率。是否启用？[y/N]:"
E[149]="Invalid domain format: \${DOMAIN}"
C[149]="无效的域名格式: \${DOMAIN}"
E[150]="Custom warp-ep outbounds rules  (rules: \${CUSTOM_ROUTE_COUNT:-0})"
C[150]="自定义 warp-ep 出站路由规则  (规则数: \${CUSTOM_ROUTE_COUNT:-0})"
E[151]="1. Add rule\n 2. View rules\n 3. Delete rule\n 0. Back"
C[151]="1. 添加规则\n 2. 查看规则\n 3. 删除规则\n 0. 返回"
E[152]="Select rule type:\\n 1. domain_suffix\\n 2. rule_set"
C[152]="选择规则类型:\\n 1. domain_suffix (域名后缀)\\n 2. rule_set (规则集)"
E[153]="Enter domain suffix (comma-separated, e.g. google.com,telegram.org):"
C[153]="输入域名后缀 (逗号分隔，如 google.com,telegram.org):"
E[154]="Enter rule_set name (comma-separated, e.g. geosite-google,geosite-telegram):"
C[154]="输入规则集名称 (逗号分隔，如 geosite-google,geosite-telegram):"
E[155]="Matched custom route rules will use warp-ep outbound."
C[155]="命中的自定义路由规则将使用 warp-ep 出站。"
E[156]="Rule set \"\${RULE_NAME}\" not found in SagerNet or MetaCubeX repositories. Please re-enter:"
C[156]="规则集 \"\${RULE_NAME}\" 在 SagerNet 和 MetaCubeX 仓库中均未找到，请重新输入:"
E[157]="Custom route rule added successfully."
C[157]="自定义路由规则添加成功。"
E[158]="No custom route rules configured."
C[158]="未配置自定义路由规则。"
E[159]="Enter warp-ep outbound rule number(s) to delete (comma-separated):"
C[159]="输入要删除的 warp-ep 出站规则编号 (逗号分隔):"
E[160]="Custom route rule(s) deleted."
C[160]="自定义路由规则已删除。"
E[161]="Port modification mode:\n 1. Modify start port (protocols occupy sequential ports, default)\n 2. Set an independent port for each protocol"
C[161]="端口修改方式:\n 1. 修改开始端口（各协议按顺序占用，默认）\n 2. 修改为各协议独立端口"
E[162]="Select the protocols whose ports to change (multi-select, e.g. bcf; asked in the same order as typed; blank = nothing to change):\n a. all (default)"
C[162]="多选需要修改端口的协议（如 bcf，询问顺序与输入顺序一致，留空表示不修改）:\n a. all (默认)"
E[163]="Enter the new port for \${PROTO} (current: \${PORT}, leave blank to keep):"
C[163]="请输入「\${PROTO}」的新端口 (当前: \${PORT}，留空保持不变):"
E[164]="Listening ports (current: \${PORTS})"
C[164]="监听端口 (当前: \${PORTS})"
E[165]="Ports unchanged, nothing to modify."
C[165]="端口未变化，未做任何修改。"
E[166]="Port \${PORT} is occupied by another protocol or service."
C[166]="端口 \${PORT} 已被其他协议或服务占用。"
E[167]="Port change preview:"
C[167]="端口变更预览:"
E[168]="Apply the changes [y/N] (default N):"
C[168]="是否应用以上修改 [y/N] (默认为 N):"
E[169]="\${PROTO}: \${OLD} -> \${NEW}"
C[169]="\${PROTO}: \${OLD} -> \${NEW}"
E[170]="Ports updated and hot-reloaded."
C[170]="端口已更新并已热加载。"
E[171]="Port \${PORT} is already in use by \${PROTO}."
C[171]="端口 \${PORT} 已被 \${PROTO} 使用。"
E[172]="\${LETTER}. \${PROTO} (\${PORT})"
C[172]="\${LETTER}. \${PROTO} (\${PORT})"
E[173]="Start port \${OLD_START} -> \${NEW_START}: \${NUM} protocol ports will become \${NEW_START} - \${NEW_END}."
C[173]="起始端口 \${OLD_START} -> \${NEW_START}: \${NUM} 个协议端口将变为 \${NEW_START} - \${NEW_END}。"
E[174]="Change WARP account"
C[174]="更换 WARP 账户"
E[175]="Select WARP account operation:\n 1. Register a new free account\n 2. Enter account info manually\n 0. Back"
C[175]="请选择 WARP 账户操作:\n 1. 重新注册免费账户\n 2. 手动输入信息\n 0. 返回"
E[176]="New account registration failed. Please try again later. The existing account is kept."
C[176]="注册新账户失败，请稍后再试。已保留原有账户。"
E[177]="Enter the WARP IPv6 address:"
C[177]="请输入 WARP IPv6 地址:"
E[178]="Enter the WARP private key:"
C[178]="请输入 WARP Private Key:"
E[179]="Enter WARP reserved values (format: 123,456,789):"
C[179]="请输入 WARP reserved 保留值（格式: 123,456,789）:"
E[180]="Invalid reserved format. Please enter 3 numbers like 123,456,789"
C[180]="reserved 格式错误，请输入 3 个数字，如 123,456,789"
E[181]="Checking configuration..."
C[181]="正在校验配置..."
E[182]="Change WARP endpoint"
C[182]="更换 warp endpoint"
E[183]="Realm is enabled. Enabling port hopping will disable Realm. Continue? [y/N] (default N):"
C[183]="Realm 已开启，启用端口跳跃将关闭 Realm。是否继续？[y/N]（默认 N）:"
E[184]="Invalid private key format. Please enter a 43-character base64 key ending with \"=\"."
C[184]="Private Key 格式错误，请输入 43 位 base64 密钥且以 \"=\" 结尾"
E[185]="New WARP endpoint:\n IPv6: \${ADDRESS6}\n Private Key: \${PRIVATE_KEY}\n Reserved: [\${R1}, \${R2}, \${R3}]"
C[185]="新 WARP 端点:\n IPv6: \${ADDRESS6}\n Private Key: \${PRIVATE_KEY}\n Reserved: [\${R1}, \${R2}, \${R3}]"
E[186]="Hysteria2 Realm and port hopping cannot be used together (choose one). Realm is for NAT VPS without public inbound access. If you enable Realm, port hopping will be skipped."
C[186]="Hysteria2 Realm 与端口跳跃不能同时使用（二选一）。Realm 适用于没有公网入站的 NAT 机器；启用 Realm 后将跳过端口跳跃。"
E[187]="Detected IP addresses (IPv4 / IPv6) on this server:"
C[187]="检测到本机以下 IP 地址（IPv4 / IPv6）:"
E[188]="Enter the number(s) of the IP(s) to REMOVE (space-separated, press Enter to keep all):"
C[188]="请输入要【去掉】的 IP 编号（多选用空格分隔，回车保留全部）:"
E[189]="You cannot remove all IPs. Keeping all detected IPs."
C[189]="不能去掉所有 IP，已保留全部检测到的 IP。"
E[190]="Static IPv6 (from NIC):"
C[190]="静态 IPv6（来自网卡）:"
E[191]="An existing Sing-box installation was detected. To prevent old services, ports, and configuration files from conflicting with this clean installation, it must be removed first."
C[191]="检测到已有 Sing-box 安装。为避免旧服务、端口和配置与新版冲突，必须先卸载旧安装后才能重新安装。"
E[192]="Back up, uninstall the existing Sing-box installation, and continue? [y/N] (default N):"
C[192]="是否备份并卸载旧 Sing-box 后继续安装？[y/N]（默认为 N）："
E[193]="The existing installation was kept. The script exited without changing it."
C[193]="已保留旧安装，脚本退出；现有代理配置没有被修改。"
E[194]="The old installation was backed up and removed. Continuing with the new installation."
C[194]="旧安装已经备份并卸载，继续安装新版。"
E[195]="A non-interactive installation detected an existing Sing-box. Run interactively and confirm removal, or pass --REINSTALL true after making a backup."
C[195]="无交互安装检测到已有 Sing-box。请改为交互运行并确认卸载，或在自行备份后添加 --REINSTALL true。"
E[196]="A Sing-box installation managed by another script was detected: ${FOREIGN_SINGBOX_REASON}."
C[196]="检测到由其他脚本管理的 Sing-box 安装：${FOREIGN_SINGBOX_REASON}。"
E[197]="Backup location:"
C[197]="备份位置："
E[198]="Initializing the Hysteria2/TUIC multi-user manager..."
C[198]="正在初始化 Hysteria2/TUIC 多用户管理器……"
E[199]="The Hysteria2/TUIC multi-user manager is ready."
C[199]="Hysteria2/TUIC 多用户管理器已经就绪。"

# 自定义字体彩色，read 函数
warning() { echo -e "\033[31m\033[01m$*\033[0m"; }  # 红色
error() { echo -e "\033[31m\033[01m$*\033[0m" && exit 1; } # 红色
info() { echo -e "\033[32m\033[01m$*\033[0m"; }   # 绿色
hint() { echo -e "\033[33m\033[01m$*\033[0m"; }   # 黄色
reading() { read -rp "$(info "$1")" "$2"; }

# 预处理：扫描 E/C 数组，把含 $ 的条目下标记录到关联数组，避免 text() 每次调用都启动 grep 子进程
declare -A TEXT_NEEDS_EVAL
for TEXT_I in "${!E[@]}"; do
  [[ "${E[${TEXT_I}]}" == *'$'* || "${C[${TEXT_I}]}" == *'$'* ]] && TEXT_NEEDS_EVAL[${TEXT_I}]=1
done
unset TEXT_I

# text <index>：输出当前语言对应的字符串，含 $ 变量的条目用 eval 展开，其余直接 printf
text() {
  local -n TEXT_ARR="${L}"        # nameref 指向 E 或 C，零子进程
  local TEXT_VAL="${TEXT_ARR[$*]}"
  if [[ -n "${TEXT_NEEDS_EVAL[$*]}" ]]; then
    eval "printf '%s' \"${TEXT_VAL}\""
  else
    printf '%s' "${TEXT_VAL}"
  fi
}

# 根据 INSTALL_PROTOCOLS 计算安装流程总步骤数
# sing-box 协议分类：Reality 类 (b/j/k)、Hysteria2(c)、WS 类 (h/i)
calc_install_steps() {
  local STEP_TOTAL=5  # 固定步骤：协议选择、起始端口、VPS IP、UUID、节点名
  local HAS_REALITY=false HAS_WS=false HAS_HY2=false
  for PROTO in "${INSTALL_PROTOCOLS[@]}"; do
    [[ "$PROTO" =~ ^[bjk]$ ]] && HAS_REALITY=true
    [[ "$PROTO" =~ ^[hi]$ ]] && HAS_WS=true
    [[ "$PROTO" == 'c' ]] && HAS_HY2=true
  done
  [[ "$IS_SUB" = 'is_sub' || "$IS_ARGO" = 'is_argo' ]] && (( STEP_TOTAL++ ))  # nginx 端口
  $HAS_REALITY && (( STEP_TOTAL++ ))                # Reality 私钥
  $HAS_WS && (( STEP_TOTAL++ ))                     # CDN / 域名
  # Hysteria2 Realm / WARP / Port Hopping are protocol sub-options and are not counted as install steps.
  [ "$IS_ARGO" = 'is_argo' ] && (( STEP_TOTAL++ ))  # Argo 域名
  TOTAL_STEPS=$STEP_TOTAL
}

# 检测是否需要启用 Github CDN，如能直接连通 api.github.com，则不使用
check_cdn() {
  local PROXY CODE PID CMD
  local WAIT_COUNT=40
  local PIDS=()
  local API_URL='https://api.github.com/repos/SagerNet/sing-box/releases'

  # 确定下载工具：优先 wget，次选 curl
  if command -v wget >/dev/null 2>&1; then
    CMD='wget'
  elif command -v curl >/dev/null 2>&1; then
    CMD='curl'
  else
    GH_PROXY=''
    return
  fi

  # 获取 HTTP 状态码（HEAD 探测：只取响应头，不下载 body；--tries=1 避免被墙时 wget 默认 20 次重试放大延迟）
  get_code() {
    local url=$1
    if [ "$CMD" = 'wget' ]; then
      wget -q --spider --tries=1 -T5 -O /dev/null --server-response "$url" 2>&1 | awk '/HTTP\//{code=$2} END{print code}'
    else
      curl -skL -I --connect-timeout 3 --max-time 5 -o /dev/null -w '%{http_code}' "$url"
    fi
  }

  # 直连检测
  CODE=$(get_code "$API_URL")
  if [ "$CODE" = '200' ]; then
    GH_PROXY=''
    return
  fi

  # 并发探测代理
  for PROXY in "${GITHUB_PROXY[@]}"; do
    {
      CODE=$(get_code "${PROXY}${API_URL}")
      [ "$CODE" = '200' ] && [ ! -e "${TEMP_DIR}/cdn_proxy" ] && printf '%s' "$PROXY" > "${TEMP_DIR}/cdn_proxy"
    } &
    PIDS+=("$!")
  done

  # 等第一个返回 200 的代理，超时则回退为直连，避免无限等待卡死
  while [ ! -e "${TEMP_DIR}/cdn_proxy" ] && [ "$WAIT_COUNT" -gt 0 ]; do
    sleep 0.05
    (( WAIT_COUNT-- )) || true
  done

  [ -e "${TEMP_DIR}/cdn_proxy" ] && GH_PROXY=$(cat "${TEMP_DIR}/cdn_proxy") || GH_PROXY=''

  # 清理后台任务和临时文件
  for PID in "${PIDS[@]}"; do kill "$PID" >/dev/null 2>&1 || true; done
  for PID in "${PIDS[@]}"; do wait "$PID" 2>/dev/null || true; done
  rm -f "${TEMP_DIR}/cdn_proxy"
}

# 检测是否解锁 chatGPT，以决定是否使用 warp 链式代理或者是 direct out，此处判断改编自 https://github.com/lmc999/RegionRestrictionCheck
check_chatgpt() {
  local CHECK_STACK=$1
  local UA_BROWSER="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36"
  local UA_SEC_CH_UA='"Google Chrome";v="125", "Chromium";v="125", "Not.A/Brand";v="24"'
  wget --help | grep -q '\-\-ciphers' && local IS_CIPHERS=is_ciphers

  # 首先检查API访问
  local CHECK_RESULT1=$(wget --timeout=2 --tries=2 --retry-connrefused --waitretry=5 ${CHECK_STACK} -qO- --content-on-error --header='authority: api.openai.com' --header='accept: */*' --header='accept-language: en-US,en;q=0.9' --header='authorization: Bearer null' --header='content-type: application/json' --header='origin: https://platform.openai.com' --header='referer: https://platform.openai.com/' --header="sec-ch-ua: ${UA_SEC_CH_UA}" --header='sec-ch-ua-mobile: ?0' --header='sec-ch-ua-platform: "Windows"' --header='sec-fetch-dest: empty' --header='sec-fetch-mode: cors' --header='sec-fetch-site: same-site' --user-agent="${UA_BROWSER}" 'https://api.openai.com/compliance/cookie_requirements')

  [ -z "$CHECK_RESULT1" ] && grep -qw is_ciphers <<< "$IS_CIPHERS" && local CHECK_RESULT1=$(wget --timeout=2 --tries=2 --retry-connrefused --waitretry=5 ${CHECK_STACK} --ciphers=DEFAULT@SECLEVEL=1 --no-check-certificate -qO- --content-on-error --header='authority: api.openai.com' --header='accept: */*' --header='accept-language: en-US,en;q=0.9' --header='authorization: Bearer null' --header='content-type: application/json' --header='origin: https://platform.openai.com' --header='referer: https://platform.openai.com/' --header="sec-ch-ua: ${UA_SEC_CH_UA}" --header='sec-ch-ua-mobile: ?0' --header='sec-ch-ua-platform: "Windows"' --header='sec-fetch-dest: empty' --header='sec-fetch-mode: cors' --header='sec-fetch-site: same-site' --user-agent="${UA_BROWSER}" 'https://api.openai.com/compliance/cookie_requirements')

  # 如果API检测失败或者检测到unsupported_country,直接返回ban
  if [ -z "$CHECK_RESULT1" ] || grep -qi 'unsupported_country' <<< "$CHECK_RESULT1"; then
    echo "ban"
    return
  fi

  # API检测通过后,继续检查网页访问
  local CHECK_RESULT2=$(wget --timeout=2 --tries=2 --retry-connrefused --waitretry=5 ${CHECK_STACK} -qO- --content-on-error --header='authority: ios.chat.openai.com' --header='accept: */*;q=0.8,application/signed-exchange;v=b3;q=0.7' --header='accept-language: en-US,en;q=0.9' --header="sec-ch-ua: ${UA_SEC_CH_UA}" --header='sec-ch-ua-mobile: ?0' --header='sec-ch-ua-platform: "Windows"' --header='sec-fetch-dest: document' --header='sec-fetch-mode: navigate' --header='sec-fetch-site: none' --header='sec-fetch-user: ?1' --header='upgrade-insecure-requests: 1' --user-agent="${UA_BROWSER}" https://ios.chat.openai.com/)

  [ -z "$CHECK_RESULT2" ] && grep -qw is_ciphers <<< "$IS_CIPHERS" && local CHECK_RESULT2=$(wget --timeout=2 --tries=2 --retry-connrefused --waitretry=5 ${CHECK_STACK} --ciphers=DEFAULT@SECLEVEL=1 --no-check-certificate -qO- --content-on-error --header='authority: ios.chat.openai.com' --header='accept: */*;q=0.8,application/signed-exchange;v=b3;q=0.7' --header='accept-language: en-US,en;q=0.9' --header="sec-ch-ua: ${UA_SEC_CH_UA}" --header='sec-ch-ua-mobile: ?0' --header='sec-ch-ua-platform: "Windows"' --header='sec-fetch-dest: document' --header='sec-fetch-mode: navigate' --header='sec-fetch-site: none' --header='sec-fetch-user: ?1' --header='upgrade-insecure-requests: 1' --user-agent="${UA_BROWSER}" https://ios.chat.openai.com/)

  # 检查第二个结果
  if [ -z "$CHECK_RESULT2" ] || grep -qi 'VPN' <<< "$CHECK_RESULT2"; then
    echo "ban"
  else
    echo "unlock"
  fi
}

# 脚本当天及累计运行次数统计
statistics_of_run_times() {
  local UPDATE_OR_GET=$1
  local SCRIPT=$2
  if grep -q 'update' <<< "$UPDATE_OR_GET"; then
    { wget --no-check-certificate -qO- --timeout=3 "https://stat.cloudflare.now.cc/updateStats?script=${SCRIPT}" > $TEMP_DIR/statistics 2>/dev/null || true; }&
  elif grep -q 'get' <<< "$UPDATE_OR_GET"; then
    [ -s $TEMP_DIR/statistics ] && [[ $(cat $TEMP_DIR/statistics) =~ \"todayCount\":([0-9]+),\"totalCount\":([0-9]+) ]] && local TODAY="${BASH_REMATCH[1]}" && local TOTAL="${BASH_REMATCH[2]}" && rm -f $TEMP_DIR/statistics
    hint "\n *******************************************\n\n $(text 55) \n"
  fi
}

# 选择中英语言
select_language() {
  if [ -z "$L" ]; then
    if [ -s ${WORK_DIR}/language ]; then
      L=$(cat ${WORK_DIR}/language)
    else
      L=E && hint "\n $(text 0) \n" && reading " $(text 24) " LANGUAGE
      [ "$LANGUAGE" = 2 ] && L=C
    fi
  fi
}

# 字母与数字的 ASCII 码值转换
asc() {
  if [[ "$1" = [a-z] ]]; then
    [ "$2" = '++' ] && printf "\\$(printf '%03o' "$(( $(printf "%d" "'$1'") + 1 ))")" || printf "%d" "'$1'"
  else
    [[ "$1" =~ ^[0-9]+$ ]] && printf "\\$(printf '%03o' "$1")"
  fi
}

# 收录一些热心网友和官网的 cdn
parse_host_port() {
  local INPUT_VALUE=$1
  local DEFAULT_PORT=$2
  local HOST_VALUE PORT_VALUE

  INPUT_VALUE=$(sed 's/^[[:space:]]*//; s/[[:space:]]*$//' <<< "$INPUT_VALUE")
  [ -z "$INPUT_VALUE" ] && return 1

  if [[ "$INPUT_VALUE" =~ ^\[([^][]+)\]:([0-9]{1,5})$ ]]; then
    HOST_VALUE="${BASH_REMATCH[1]}"
    PORT_VALUE="${BASH_REMATCH[2]}"
  elif [[ "$INPUT_VALUE" =~ ^([^:]+):([0-9]{1,5})$ ]] && [[ "${BASH_REMATCH[1]}" != *:* ]]; then
    HOST_VALUE="${BASH_REMATCH[1]}"
    PORT_VALUE="${BASH_REMATCH[2]}"
  else
    HOST_VALUE="$INPUT_VALUE"
    PORT_VALUE=$DEFAULT_PORT
  fi

  if [[ -n "$PORT_VALUE" && ( ! "$PORT_VALUE" =~ ^[0-9]+$ || "$PORT_VALUE" -lt 1 || "$PORT_VALUE" -gt 65535 ) ]]; then
    return 1
  fi

  PARSED_HOST="$HOST_VALUE"
  PARSED_PORT="$PORT_VALUE"
  return 0
}

format_uri_host() {
  local HOST_VALUE=$1
  if [[ "$HOST_VALUE" == *:* && ! "$HOST_VALUE" =~ ^\[.*\]$ ]]; then
    printf '[%s]' "$HOST_VALUE"
  else
    printf '%s' "$HOST_VALUE"
  fi
}

# 输入优选 CDN
input_cdn() {
  echo ""
  unset CUSTOM_CDN PARSED_HOST PARSED_PORT
  for c in "${!CDN_DOMAIN[@]}"; do
    hint " $(( c+1 )). ${CDN_DOMAIN[c]} "
  done

  while true; do
    reading "\n ${TOTAL_STEPS:+(${STEP_NUM}/${TOTAL_STEPS}) }$(text 53) " CUSTOM_CDN
    case "$CUSTOM_CDN" in
      [1-${#CDN_DOMAIN[@]}] )
        CDN="${CDN_DOMAIN[$((CUSTOM_CDN-1))]}"
        CDN_PORT[17]='80' && CDN_PORT[18]='443'
        break
        ;;
      ?????* )
        parse_host_port "$CUSTOM_CDN" '' || {
          warning "\n $(text 36) \n"
          continue
        }
        CDN="$PARSED_HOST"
        if grep -q '.' <<< $PARSED_PORT; then
          CDN_PORT[17]=$PARSED_PORT && CDN_PORT[18]=$PARSED_PORT
        else
          CDN_PORT[17]='80' && CDN_PORT[18]='443'
        fi
        break
        ;;
      * )
        CDN="${CDN_DOMAIN[0]}"
        CDN_PORT[17]='80' && CDN_PORT[18]='443'
        break
    esac
  done
}

# 输入 UUID
input_uuid() {
  # 输入 UUID ，错误超过 5 次将会退出
  local UUID_DEFAULT=$(cat /proc/sys/kernel/random/uuid)
  [[ "$IS_FAST_INSTALL" = 'is_fast_install' || "$NONINTERACTIVE_INSTALL" = 'noninteractive_install' ]] && UUID_CONFIRM=${UUID_CONFIRM:-"$UUID_DEFAULT"}
  if [ -z "$UUID_CONFIRM" ]; then
    (( STEP_NUM++ )) || true
    reading "\n ${TOTAL_STEPS:+(${STEP_NUM}/${TOTAL_STEPS}) }$(text 12) " UUID_CONFIRM
  fi
  local UUID_ERROR_TIME=5
  until [[ -z "$UUID_CONFIRM" || "${UUID_CONFIRM,,}" =~ ^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$ ]]; do
    (( UUID_ERROR_TIME-- )) || true
    [ "$UUID_ERROR_TIME" = 0 ] && error "\n $(text 3) \n" || reading "\n $(text 4) " UUID_CONFIRM
  done
  UUID_CONFIRM=${UUID_CONFIRM:-"$UUID_DEFAULT"}
}

# 生成 256 位随机订阅令牌；该令牌只用于 URL 路径，不承担节点认证职责。
generate_subscribe_token() {
  od -An -N 32 -tx1 /dev/urandom | tr -d ' \n'
}

# Hysteria2/TUIC 多用户订阅是严格模式：不创建公共订阅 URL，也不保留公共入站。
# 用户必须通过 sb-user add 创建，才会获得各自的协议端口、密码和订阅令牌。
is_strict_multi_user_mode() {
  [ "$IS_SUB" = 'is_sub' ] && [ -n "$PORT_HYSTERIA2" ]
}

# 严格模式会删除旧的 subscribe/qr，不能再只靠二维码文件判断是否启用了订阅。
# 兼容旧公共订阅、已迁移的严格模式，以及中途升级时 Nginx 中遗留的订阅路由。
has_subscription_artifacts() {
  [ -s "${WORK_DIR}/subscribe/qr" ] || \
    [ -s "${WORK_DIR}/users/subscription-base-url" ] || \
    [ -s "${WORK_DIR}/subscribe/clash-campus-free" ] || \
    { [ -s "${WORK_DIR}/nginx.conf" ] && grep -q '/subscribe/' "${WORK_DIR}/nginx.conf"; }
}

# 订阅基地址只能是无路径的 http(s) URL；用户令牌和资源路径由管理器另外拼接。
is_valid_subscription_base_url() {
  [[ "$1" =~ ^https?://(\[[0-9a-fA-F:]+\]|[A-Za-z0-9.-]+)(:[0-9]{1,5})?$ ]]
}

# 非严格模式的订阅 URL 使用独立的 256 位随机令牌，避免与节点认证 UUID 复用。
# Hysteria2/TUIC 严格多用户模式没有公共 URL，因此不生成该令牌。
ensure_subscribe_token() {
  [ "$IS_SUB" = 'is_sub' ] || return
  is_strict_multi_user_mode && return
  if [ -z "$SUBSCRIBE_TOKEN" ]; then
    SUBSCRIBE_TOKEN=$(generate_subscribe_token)
  fi
  SUBSCRIBE_TOKEN=${SUBSCRIBE_TOKEN,,}
  [[ "$SUBSCRIBE_TOKEN" =~ ^[a-f0-9]{64}$ ]] || error " Invalid subscription token. It must be 64 hexadecimal characters."
}

# 安装 Hysteria2/TUIC 多用户管理器。Python 源码同时保留在项目根目录的 sb-user.py，便于审阅和测试。
install_multi_user_manager() {
  [ "$IS_SUB" = 'is_sub' ] || return 0
  [ -n "$PORT_HYSTERIA2" ] || return 0

  if ! command -v python3 >/dev/null 2>&1; then
    local PYTHON_PACKAGE=python3
    [ "$SYSTEM" = 'Arch' ] && PYTHON_PACKAGE=python
    ${PACKAGE_UPDATE[int]} >/dev/null 2>&1 || true
    ${PACKAGE_INSTALL[int]} "$PYTHON_PACKAGE" >/dev/null 2>&1 || {
      warning " Hysteria2/TUIC multi-user manager requires Python 3."
      return 1
    }
  fi

  if ! command -v iptables >/dev/null 2>&1; then
    ${PACKAGE_INSTALL[int]} iptables >/dev/null 2>&1 || {
      warning " Hysteria2/TUIC multi-user traffic accounting requires iptables."
      return 1
    }
  fi

  mkdir -p "${WORK_DIR}/users"
  chmod 700 "${WORK_DIR}/users"
  # 严格模式不能从公共订阅路径反推服务器地址；仅以 root 可读的状态文件保存基地址。
  if ! is_valid_subscription_base_url "${SUBSCRIBE_ADDRESS%/}"; then
    warning " Cannot determine a valid subscription server address; preserving existing multi-user state."
    return 1
  fi
  printf '%s\n' "${SUBSCRIBE_ADDRESS%/}" > "${WORK_DIR}/users/subscription-base-url"
  chmod 600 "${WORK_DIR}/users/subscription-base-url"
  # 脚本可能由 Windows 上传而带有 CRLF。使用 Python 的宽容 Base64 解码器，
  # 忽略行尾 \r，避免不同发行版的 base64 命令只解出第一行而截断管理器。
  python3 -c 'import base64, pathlib, sys; pathlib.Path(sys.argv[1]).write_bytes(base64.b64decode(sys.stdin.buffer.read()))' "${WORK_DIR}/sb-user.py" << 'SB_USER_MANAGER_B64'
IyEvdXNyL2Jpbi9lbnYgcHl0aG9uMwoiIiJTbWFsbCBtdWx0aS11c2VyIG1hbmFnZXIgZm9yIHNp
bmctYm94IEh5c3RlcmlhMi9UVUlDIGRlcGxveW1lbnRzLgoKRWFjaCBtYW5hZ2VkIHVzZXIgcmVj
ZWl2ZXMgYSBkZWRpY2F0ZWQgVURQIHBvcnQgZm9yIGVhY2ggaW5zdGFsbGVkIHByb3RvY29sLgpM
aW51eCBmaXJld2FsbCBjb3VudGVycyBvbiB0aG9zZSBwb3J0cyBwcm92aWRlIHBlcnNpc3RlbnQg
cGVyLXVzZXIgYWNjb3VudGluZyB3aXRob3V0CmRlcGVuZGluZyBvbiB0aGUgb3B0aW9uYWwgc2lu
Zy1ib3ggdjJyYXlfYXBpIGJ1aWxkIHRhZy4KIiIiCgpmcm9tIF9fZnV0dXJlX18gaW1wb3J0IGFu
bm90YXRpb25zCgppbXBvcnQgYXJncGFyc2UKaW1wb3J0IGNvcHkKaW1wb3J0IGNvbnRleHRsaWIK
aW1wb3J0IGRhdGV0aW1lIGFzIGR0CmltcG9ydCBkZWNpbWFsCmltcG9ydCBodHRwLnNlcnZlcgpp
bXBvcnQgaW8KaW1wb3J0IGpzb24KaW1wb3J0IG9zCmltcG9ydCByZQppbXBvcnQgc2VjcmV0cwpp
bXBvcnQgc2h1dGlsCmltcG9ydCBzb2NrZXQKaW1wb3J0IHNxbGl0ZTMKaW1wb3J0IHN1YnByb2Nl
c3MKaW1wb3J0IHN5cwppbXBvcnQgdXJsbGliLnBhcnNlCmltcG9ydCB1dWlkCmZyb20gcGF0aGxp
YiBpbXBvcnQgUGF0aAoKdHJ5OgogICAgaW1wb3J0IGZjbnRsCmV4Y2VwdCBJbXBvcnRFcnJvcjog
ICMgV2luZG93cyB1bml0IHRlc3RzOyBkZXBsb3llZCB0YXJnZXRzIGFyZSBMaW51eC4KICAgIGZj
bnRsID0gTm9uZQoKCldPUktfRElSID0gUGF0aChvcy5lbnZpcm9uLmdldCgiU0JfV09SS19ESVIi
LCAiL2V0Yy9zaW5nLWJveCIpKQpDT05GX0RJUiA9IFdPUktfRElSIC8gImNvbmYiClNVQlNDUklC
RV9ESVIgPSBXT1JLX0RJUiAvICJzdWJzY3JpYmUiClVTRVJTX0RJUiA9IFdPUktfRElSIC8gInVz
ZXJzIgpEQl9QQVRIID0gV09SS19ESVIgLyAidXNlcnMuZGIiClNJTkdfQk9YID0gV09SS19ESVIg
LyAic2luZy1ib3giCkFETUlOX1BBR0VfUEFUSCA9IFdPUktfRElSIC8gImFkbWluLXBhZ2UuaHRt
bCIKV0VCX0hPU1QgPSAiMTI3LjAuMC4xIgpXRUJfUE9SVCA9IGludChvcy5lbnZpcm9uLmdldCgi
U0JfVVNFUl9XRUJfUE9SVCIsICIxODA4MSIpKQpEUllfUlVOID0gb3MuZW52aXJvbi5nZXQoIlNC
X1VTRVJfRFJZX1JVTiIpID09ICIxIgpHSUIgPSAxMDI0ICoqIDMKVElCID0gMTAyNCAqKiA0CkRF
RkFVTFRfU0VSVkVSX01PTlRITFlfUVVPVEEgPSA0ICogVElCClNFUlZFUl9RVU9UQV9NRVRBX0tF
WSA9ICJzZXJ2ZXJfbW9udGhseV9xdW90YV9ieXRlcyIKVFJBRkZJQ19NT05USF9NRVRBX0tFWSA9
ICJ0cmFmZmljX2N5Y2xlX21vbnRoIgpQT1JUX01JTiA9IDMwMDAwClBPUlRfTUFYID0gMzk5OTkK
VFVJQ19QT1JUX01JTiA9IDQwMDAwClRVSUNfUE9SVF9NQVggPSA0OTk5OQpDT1VOVEVSX0lOID0g
IlNCVV9JTiIKQ09VTlRFUl9PVVQgPSAiU0JVX09VVCIKQ09VTlRFUl9QUkVGSVggPSAiU0JVIgpN
QU5BR0VEX0NPTkZfR0xPQlMgPSAoCiAgICAiMzBfc2J1c2VyXypfaHlzdGVyaWEyX2luYm91bmRz
Lmpzb24iLAogICAgIjMxX3NidXNlcl8qX3R1aWNfaW5ib3VuZHMuanNvbiIsCikKVVNFUk5BTUVf
UkUgPSByZS5jb21waWxlKHIiXltBLVphLXowLTlfLV17MSwzMn0kIikKVE9LRU5fUkUgPSByZS5j
b21waWxlKHIiXlthLWYwLTldezY0fSQiKQpBTlNJX1JFID0gcmUuY29tcGlsZShyIlx4MWJcW1sw
LTk7XSptIikKCgpjbGFzcyBNYW5hZ2VyRXJyb3IoUnVudGltZUVycm9yKToKICAgIHBhc3MKCgpj
bGFzcyBXZWJSZXF1ZXN0RXJyb3IoTWFuYWdlckVycm9yKToKICAgIGRlZiBfX2luaXRfXyhzZWxm
LCBzdGF0dXM6IGludCwgbWVzc2FnZTogc3RyKToKICAgICAgICBzdXBlcigpLl9faW5pdF9fKG1l
c3NhZ2UpCiAgICAgICAgc2VsZi5zdGF0dXMgPSBzdGF0dXMKCgpkZWYgbm93X2lzbygpIC0+IHN0
cjoKICAgIHJldHVybiBkdC5kYXRldGltZS5ub3coZHQudGltZXpvbmUudXRjKS5yZXBsYWNlKG1p
Y3Jvc2Vjb25kPTApLmlzb2Zvcm1hdCgpCgoKZGVmIHJ1bihjbWQ6IGxpc3Rbc3RyXSwgKiwgY2hl
Y2s6IGJvb2wgPSBUcnVlLCBjYXB0dXJlOiBib29sID0gRmFsc2UpIC0+IHN1YnByb2Nlc3MuQ29t
cGxldGVkUHJvY2Vzc1tzdHJdOgogICAgaWYgRFJZX1JVTjoKICAgICAgICByZXR1cm4gc3VicHJv
Y2Vzcy5Db21wbGV0ZWRQcm9jZXNzKGNtZCwgMCwgIiIsICIiKQogICAgcmV0dXJuIHN1YnByb2Nl
c3MucnVuKAogICAgICAgIGNtZCwKICAgICAgICBjaGVjaz1jaGVjaywKICAgICAgICB0ZXh0PVRy
dWUsCiAgICAgICAgc3Rkb3V0PXN1YnByb2Nlc3MuUElQRSBpZiBjYXB0dXJlIGVsc2Ugc3VicHJv
Y2Vzcy5ERVZOVUxMLAogICAgICAgIHN0ZGVycj1zdWJwcm9jZXNzLlBJUEUgaWYgY2FwdHVyZSBl
bHNlIHN1YnByb2Nlc3MuREVWTlVMTCwKICAgICkKCgpkZWYgY29tbWFuZF9leGlzdHMobmFtZTog
c3RyKSAtPiBib29sOgogICAgcmV0dXJuIHNodXRpbC53aGljaChuYW1lKSBpcyBub3QgTm9uZQoK
CmRlZiBjb25uZWN0KCkgLT4gc3FsaXRlMy5Db25uZWN0aW9uOgogICAgV09SS19ESVIubWtkaXIo
cGFyZW50cz1UcnVlLCBleGlzdF9vaz1UcnVlKQogICAgb3MuY2htb2QoV09SS19ESVIsIDBvNzU1
KQogICAgY29ubiA9IHNxbGl0ZTMuY29ubmVjdChEQl9QQVRILCB0aW1lb3V0PTMwKQogICAgY29u
bi5yb3dfZmFjdG9yeSA9IHNxbGl0ZTMuUm93CiAgICBjb25uLmV4ZWN1dGUoIlBSQUdNQSBqb3Vy
bmFsX21vZGU9V0FMIikKICAgIGNvbm4uZXhlY3V0ZSgiUFJBR01BIGZvcmVpZ25fa2V5cz1PTiIp
CiAgICBjb25uLmV4ZWN1dGVzY3JpcHQoCiAgICAgICAgIiIiCiAgICAgICAgQ1JFQVRFIFRBQkxF
IElGIE5PVCBFWElTVFMgdXNlcnMgKAogICAgICAgICAgICBpZCBJTlRFR0VSIFBSSU1BUlkgS0VZ
IEFVVE9JTkNSRU1FTlQsCiAgICAgICAgICAgIHVzZXJuYW1lIFRFWFQgTk9UIE5VTEwgVU5JUVVF
LAogICAgICAgICAgICBpc19hZG1pbiBJTlRFR0VSIE5PVCBOVUxMIERFRkFVTFQgMCBDSEVDSyAo
aXNfYWRtaW4gSU4gKDAsIDEpKSwKICAgICAgICAgICAgdG9rZW4gVEVYVCBOT1QgTlVMTCBVTklR
VUUsCiAgICAgICAgICAgIHBhc3N3b3JkIFRFWFQgTk9UIE5VTEwsCiAgICAgICAgICAgIHBvcnQg
SU5URUdFUiBOT1QgTlVMTCBVTklRVUUsCiAgICAgICAgICAgIHF1b3RhX2J5dGVzIElOVEVHRVIg
Tk9UIE5VTEwgREVGQVVMVCAwIENIRUNLIChxdW90YV9ieXRlcyA+PSAwKSwKICAgICAgICAgICAg
dXBsb2FkX2J5dGVzIElOVEVHRVIgTk9UIE5VTEwgREVGQVVMVCAwIENIRUNLICh1cGxvYWRfYnl0
ZXMgPj0gMCksCiAgICAgICAgICAgIGRvd25sb2FkX2J5dGVzIElOVEVHRVIgTk9UIE5VTEwgREVG
QVVMVCAwIENIRUNLIChkb3dubG9hZF9ieXRlcyA+PSAwKSwKICAgICAgICAgICAgbGFzdF91cGxv
YWRfY291bnRlciBJTlRFR0VSIE5PVCBOVUxMIERFRkFVTFQgMCwKICAgICAgICAgICAgbGFzdF9k
b3dubG9hZF9jb3VudGVyIElOVEVHRVIgTk9UIE5VTEwgREVGQVVMVCAwLAogICAgICAgICAgICBl
bmFibGVkIElOVEVHRVIgTk9UIE5VTEwgREVGQVVMVCAxIENIRUNLIChlbmFibGVkIElOICgwLCAx
KSksCiAgICAgICAgICAgIGNyZWF0ZWRfYXQgVEVYVCBOT1QgTlVMTCwKICAgICAgICAgICAgdXBk
YXRlZF9hdCBURVhUIE5PVCBOVUxMCiAgICAgICAgKTsKICAgICAgICBDUkVBVEUgVEFCTEUgSUYg
Tk9UIEVYSVNUUyBtZXRhICgKICAgICAgICAgICAga2V5IFRFWFQgUFJJTUFSWSBLRVksCiAgICAg
ICAgICAgIHZhbHVlIFRFWFQgTk9UIE5VTEwKICAgICAgICApOwogICAgICAgICIiIgogICAgKQog
ICAgY29sdW1ucyA9IHtyb3dbMV0gZm9yIHJvdyBpbiBjb25uLmV4ZWN1dGUoIlBSQUdNQSB0YWJs
ZV9pbmZvKHVzZXJzKSIpfQogICAgaWYgInR1aWNfcG9ydCIgbm90IGluIGNvbHVtbnM6CiAgICAg
ICAgY29ubi5leGVjdXRlKAogICAgICAgICAgICAiQUxURVIgVEFCTEUgdXNlcnMgQUREIENPTFVN
TiB0dWljX3BvcnQgSU5URUdFUiBOT1QgTlVMTCBERUZBVUxUIDAgQ0hFQ0sgKHR1aWNfcG9ydCA+
PSAwKSIKICAgICAgICApCiAgICBjb25uLmV4ZWN1dGUoCiAgICAgICAgIkNSRUFURSBVTklRVUUg
SU5ERVggSUYgTk9UIEVYSVNUUyBpZHhfdXNlcnNfdHVpY19wb3J0ICIKICAgICAgICAiT04gdXNl
cnModHVpY19wb3J0KSBXSEVSRSB0dWljX3BvcnQgPiAwIgogICAgKQogICAgY29ubi5leGVjdXRl
KAogICAgICAgICJJTlNFUlQgT1IgSUdOT1JFIElOVE8gbWV0YShrZXksdmFsdWUpIFZBTFVFUyAo
Pyw/KSIsCiAgICAgICAgKFNFUlZFUl9RVU9UQV9NRVRBX0tFWSwgc3RyKERFRkFVTFRfU0VSVkVS
X01PTlRITFlfUVVPVEEpKSwKICAgICkKICAgIGNvbm4uZXhlY3V0ZSgKICAgICAgICAiSU5TRVJU
IE9SIElHTk9SRSBJTlRPIG1ldGEoa2V5LHZhbHVlKSBWQUxVRVMgKD8sPykiLAogICAgICAgIChU
UkFGRklDX01PTlRIX01FVEFfS0VZLCBjdXJyZW50X3RyYWZmaWNfbW9udGgoKSksCiAgICApCiAg
ICBjb25uLmNvbW1pdCgpCiAgICB0cnk6CiAgICAgICAgb3MuY2htb2QoREJfUEFUSCwgMG82MDAp
CiAgICBleGNlcHQgRmlsZU5vdEZvdW5kRXJyb3I6CiAgICAgICAgcGFzcwogICAgcmV0dXJuIGNv
bm4KCgpAY29udGV4dGxpYi5jb250ZXh0bWFuYWdlcgpkZWYgcHJvY2Vzc19sb2NrKCk6CiAgICBX
T1JLX0RJUi5ta2RpcihwYXJlbnRzPVRydWUsIGV4aXN0X29rPVRydWUpCiAgICBsb2NrX3BhdGgg
PSBXT1JLX0RJUiAvICJzYi11c2VyLmxvY2siCiAgICB3aXRoIGxvY2tfcGF0aC5vcGVuKCJhKyIs
IGVuY29kaW5nPSJ1dGYtOCIpIGFzIGxvY2tfZmlsZToKICAgICAgICBvcy5jaG1vZChsb2NrX3Bh
dGgsIDBvNjAwKQogICAgICAgIGlmIGZjbnRsIGlzIG5vdCBOb25lOgogICAgICAgICAgICBmY250
bC5mbG9jayhsb2NrX2ZpbGUuZmlsZW5vKCksIGZjbnRsLkxPQ0tfRVgpCiAgICAgICAgeWllbGQK
CgpkZWYgcGFyc2VfcXVvdGFfZ2IodmFsdWU6IHN0cikgLT4gaW50OgogICAgdHJ5OgogICAgICAg
IGFtb3VudCA9IGRlY2ltYWwuRGVjaW1hbCh2YWx1ZSkKICAgIGV4Y2VwdCBkZWNpbWFsLkludmFs
aWRPcGVyYXRpb24gYXMgZXhjOgogICAgICAgIHJhaXNlIE1hbmFnZXJFcnJvcigi5rWB6YeP6aKd
5bqm5b+F6aG75piv5pWw5a2X77yM5Y2V5L2N5Li6IEdC77ybMCDooajnpLrkuI3pmZDph4/jgIIi
KSBmcm9tIGV4YwogICAgaWYgbm90IGFtb3VudC5pc19maW5pdGUoKToKICAgICAgICByYWlzZSBN
YW5hZ2VyRXJyb3IoIua1gemHj+mineW6puW/hemhu+aYr+aciemZkOaVsOWtl++8jOWNleS9jeS4
uiBHQu+8mzAg6KGo56S65LiN6ZmQ6YeP44CCIikKICAgIGlmIGFtb3VudCA8IDA6CiAgICAgICAg
cmFpc2UgTWFuYWdlckVycm9yKCLmtYHph4/pop3luqbkuI3og73lsI/kuo4gMOOAgiIpCiAgICBx
dW90YV9ieXRlcyA9IGludChhbW91bnQgKiBHSUIpCiAgICBpZiBxdW90YV9ieXRlcyA+IDIgKiog
NjMgLSAxOgogICAgICAgIHJhaXNlIE1hbmFnZXJFcnJvcigi5rWB6YeP6aKd5bqm6L+H5aSn44CC
IikKICAgIHJldHVybiBxdW90YV9ieXRlcwoKCmRlZiBwYXJzZV9zZXJ2ZXJfcXVvdGFfdGIodmFs
dWU6IHN0cikgLT4gaW50OgogICAgdHJ5OgogICAgICAgIGFtb3VudCA9IGRlY2ltYWwuRGVjaW1h
bCh2YWx1ZSkKICAgIGV4Y2VwdCBkZWNpbWFsLkludmFsaWRPcGVyYXRpb24gYXMgZXhjOgogICAg
ICAgIHJhaXNlIE1hbmFnZXJFcnJvcigi5pyN5Yqh5Zmo5pyI5rWB6YeP5b+F6aG75piv5pWw5a2X
77yM5Y2V5L2N5Li6IFRC44CCIikgZnJvbSBleGMKICAgIGlmIG5vdCBhbW91bnQuaXNfZmluaXRl
KCkgb3IgYW1vdW50IDw9IDA6CiAgICAgICAgcmFpc2UgTWFuYWdlckVycm9yKCLmnI3liqHlmajm
nIjmtYHph4/lv4XpobvmmK/lpKfkuo4gMCDnmoTmnInpmZDmlbDlrZfvvIzljZXkvY3kuLogVELj
gIIiKQogICAgcXVvdGFfYnl0ZXMgPSBpbnQoYW1vdW50ICogVElCKQogICAgaWYgcXVvdGFfYnl0
ZXMgPiAyICoqIDYzIC0gMToKICAgICAgICByYWlzZSBNYW5hZ2VyRXJyb3IoIuacjeWKoeWZqOac
iOa1gemHj+S4iumZkOi/h+Wkp+OAgiIpCiAgICByZXR1cm4gcXVvdGFfYnl0ZXMKCgpkZWYgZm10
X2diKHZhbHVlOiBpbnQpIC0+IHN0cjoKICAgIHJldHVybiBmInt2YWx1ZSAvIEdJQjouMmZ9IEdC
IgoKCmRlZiBmbXRfdHJhZmZpYyh2YWx1ZTogaW50KSAtPiBzdHI6CiAgICBpZiB2YWx1ZSA+PSBU
SUI6CiAgICAgICAgcmV0dXJuIGYie3ZhbHVlIC8gVElCOi4yZn0gVEIiCiAgICByZXR1cm4gZm10
X2diKHZhbHVlKQoKCmRlZiBjdXJyZW50X3RyYWZmaWNfbW9udGgoKSAtPiBzdHI6CiAgICByZXR1
cm4gZHQuZGF0ZXRpbWUubm93KGR0LnRpbWV6b25lLnV0Yykuc3RyZnRpbWUoIiVZLSVtIikKCgpk
ZWYgc2VydmVyX21vbnRobHlfcXVvdGEoY29ubjogc3FsaXRlMy5Db25uZWN0aW9uKSAtPiBpbnQ6
CiAgICByb3cgPSBjb25uLmV4ZWN1dGUoIlNFTEVDVCB2YWx1ZSBGUk9NIG1ldGEgV0hFUkUga2V5
PT8iLCAoU0VSVkVSX1FVT1RBX01FVEFfS0VZLCkpLmZldGNob25lKCkKICAgIHRyeToKICAgICAg
ICB2YWx1ZSA9IGludChyb3dbInZhbHVlIl0pIGlmIHJvdyBpcyBub3QgTm9uZSBlbHNlIERFRkFV
TFRfU0VSVkVSX01PTlRITFlfUVVPVEEKICAgIGV4Y2VwdCAoVHlwZUVycm9yLCBWYWx1ZUVycm9y
KToKICAgICAgICB2YWx1ZSA9IERFRkFVTFRfU0VSVkVSX01PTlRITFlfUVVPVEEKICAgIGlmIHZh
bHVlIDw9IDAgb3IgdmFsdWUgPiAyICoqIDYzIC0gMToKICAgICAgICB2YWx1ZSA9IERFRkFVTFRf
U0VSVkVSX01PTlRITFlfUVVPVEEKICAgIGNvbm4uZXhlY3V0ZSgKICAgICAgICAiSU5TRVJUIElO
VE8gbWV0YShrZXksdmFsdWUpIFZBTFVFUyAoPyw/KSAiCiAgICAgICAgIk9OIENPTkZMSUNUKGtl
eSkgRE8gVVBEQVRFIFNFVCB2YWx1ZT1leGNsdWRlZC52YWx1ZSIsCiAgICAgICAgKFNFUlZFUl9R
VU9UQV9NRVRBX0tFWSwgc3RyKHZhbHVlKSksCiAgICApCiAgICBjb25uLmNvbW1pdCgpCiAgICBy
ZXR1cm4gdmFsdWUKCgpkZWYgc2V0X3NlcnZlcl9tb250aGx5X3F1b3RhKGNvbm46IHNxbGl0ZTMu
Q29ubmVjdGlvbiwgcXVvdGFfYnl0ZXM6IGludCkgLT4gTm9uZToKICAgIGNvbm4uZXhlY3V0ZSgK
ICAgICAgICAiSU5TRVJUIElOVE8gbWV0YShrZXksdmFsdWUpIFZBTFVFUyAoPyw/KSAiCiAgICAg
ICAgIk9OIENPTkZMSUNUKGtleSkgRE8gVVBEQVRFIFNFVCB2YWx1ZT1leGNsdWRlZC52YWx1ZSIs
CiAgICAgICAgKFNFUlZFUl9RVU9UQV9NRVRBX0tFWSwgc3RyKHF1b3RhX2J5dGVzKSksCiAgICAp
CiAgICBjb25uLmNvbW1pdCgpCgoKZGVmIHN1YnNjcmlwdGlvbl91c2FnZShyb3c6IHNxbGl0ZTMu
Um93LCBldmVyeW9uZTogbGlzdFtzcWxpdGUzLlJvd10sIHNlcnZlcl9xdW90YTogaW50KSAtPiBk
aWN0W3N0ciwgb2JqZWN0XToKICAgIHNoYXJlZCA9IGJvb2wocm93WyJpc19hZG1pbiJdKSBvciBy
b3dbInF1b3RhX2J5dGVzIl0gPT0gMAogICAgaWYgc2hhcmVkOgogICAgICAgIHVwbG9hZCA9IHN1
bShpdGVtWyJ1cGxvYWRfYnl0ZXMiXSBmb3IgaXRlbSBpbiBldmVyeW9uZSkKICAgICAgICBkb3du
bG9hZCA9IHN1bShpdGVtWyJkb3dubG9hZF9ieXRlcyJdIGZvciBpdGVtIGluIGV2ZXJ5b25lKQog
ICAgICAgIHRvdGFsID0gc2VydmVyX3F1b3RhCiAgICBlbHNlOgogICAgICAgIHVwbG9hZCA9IHJv
d1sidXBsb2FkX2J5dGVzIl0KICAgICAgICBkb3dubG9hZCA9IHJvd1siZG93bmxvYWRfYnl0ZXMi
XQogICAgICAgIHRvdGFsID0gcm93WyJxdW90YV9ieXRlcyJdCiAgICB1c2VkID0gdXBsb2FkICsg
ZG93bmxvYWQKICAgIHJldHVybiB7CiAgICAgICAgInVwbG9hZF9ieXRlcyI6IHVwbG9hZCwKICAg
ICAgICAiZG93bmxvYWRfYnl0ZXMiOiBkb3dubG9hZCwKICAgICAgICAidXNlZF9ieXRlcyI6IHVz
ZWQsCiAgICAgICAgInRvdGFsX2J5dGVzIjogdG90YWwsCiAgICAgICAgInJlbWFpbmluZ19ieXRl
cyI6IG1heCh0b3RhbCAtIHVzZWQsIDApLAogICAgICAgICJ1c2VzX3NlcnZlcl9xdW90YSI6IHNo
YXJlZCwKICAgIH0KCgpkZWYgc3Vic2NyaXB0aW9uX3VzZXJpbmZvX2hlYWRlcihyb3c6IHNxbGl0
ZTMuUm93LCBldmVyeW9uZTogbGlzdFtzcWxpdGUzLlJvd10sIHNlcnZlcl9xdW90YTogaW50KSAt
PiBzdHI6CiAgICB1c2FnZSA9IHN1YnNjcmlwdGlvbl91c2FnZShyb3csIGV2ZXJ5b25lLCBzZXJ2
ZXJfcXVvdGEpCiAgICByZXR1cm4gKAogICAgICAgIGYidXBsb2FkPXt1c2FnZVsndXBsb2FkX2J5
dGVzJ119OyBkb3dubG9hZD17dXNhZ2VbJ2Rvd25sb2FkX2J5dGVzJ119OyAiCiAgICAgICAgZiJ0
b3RhbD17dXNhZ2VbJ3RvdGFsX2J5dGVzJ119IgogICAgKQoKCmRlZiB1c2FnZV9zdGF0dXMocm93
OiBzcWxpdGUzLlJvdywgKiwgY29tcGFjdDogYm9vbCA9IEZhbHNlKSAtPiBzdHI6CiAgICB1c2Vk
ID0gcm93WyJ1cGxvYWRfYnl0ZXMiXSArIHJvd1siZG93bmxvYWRfYnl0ZXMiXQogICAgaWYgbm90
IHJvd1siZW5hYmxlZCJdOgogICAgICAgIHJldHVybiBmIntyb3dbJ3VzZXJuYW1lJ119IOW3suWB
nOeUqCDlt7LnlKh7Zm10X2diKHVzZWQpfSIKICAgIHF1b3RhID0gcm93WyJxdW90YV9ieXRlcyJd
CiAgICBpZiBxdW90YSA9PSAwOgogICAgICAgIHJldHVybiBmIntyb3dbJ3VzZXJuYW1lJ119IOW3
sueUqHtmbXRfZ2IodXNlZCl9IOWPr+eUqOS4jemZkOmHjyIKICAgIHJlbWFpbmluZyA9IG1heChx
dW90YSAtIHVzZWQsIDApCiAgICBwcmVmaXggPSAi4pqg77iP6LaF6aKdICIgaWYgdXNlZCA+PSBx
dW90YSBlbHNlICIiCiAgICBpZiBjb21wYWN0OgogICAgICAgIHJldHVybiBmIntwcmVmaXh9e3Jv
d1sndXNlcm5hbWUnXX0g5bey55Soe2ZtdF9nYih1c2VkKX0g5Y+v55Soe2ZtdF9nYihyZW1haW5p
bmcpfSDpmZDpop17Zm10X2diKHF1b3RhKX0iCiAgICByZXR1cm4gZiJ7cHJlZml4fXtyb3dbJ3Vz
ZXJuYW1lJ119IOW3sueUqHtmbXRfZ2IodXNlZCl9IOWJqeS9mXtmbXRfZ2IocmVtYWluaW5nKX0g
6ZmQ6aKde2ZtdF9nYihxdW90YSl9IgoKCmRlZiBhY3RpdmVfdXNlcnMoY29ubjogc3FsaXRlMy5D
b25uZWN0aW9uKSAtPiBsaXN0W3NxbGl0ZTMuUm93XToKICAgIHJldHVybiBjb25uLmV4ZWN1dGUo
IlNFTEVDVCAqIEZST00gdXNlcnMgV0hFUkUgZW5hYmxlZD0xIE9SREVSIEJZIGlkIikuZmV0Y2hh
bGwoKQoKCmRlZiBhbGxfdXNlcnMoY29ubjogc3FsaXRlMy5Db25uZWN0aW9uKSAtPiBsaXN0W3Nx
bGl0ZTMuUm93XToKICAgIHJldHVybiBjb25uLmV4ZWN1dGUoIlNFTEVDVCAqIEZST00gdXNlcnMg
T1JERVIgQlkgaWQiKS5mZXRjaGFsbCgpCgoKZGVmIGZpbmRfYmFzZV9oeTJfY29uZmlnKCkgLT4g
dHVwbGVbUGF0aCwgZGljdF06CiAgICBwcmVmZXJyZWQgPSBDT05GX0RJUiAvICIxMl9oeXN0ZXJp
YTJfaW5ib3VuZHMuanNvbiIKICAgIGNhbmRpZGF0ZXMgPSBbcHJlZmVycmVkXSBpZiBwcmVmZXJy
ZWQuZXhpc3RzKCkgZWxzZSBbXQogICAgY2FuZGlkYXRlcy5leHRlbmQoCiAgICAgICAgcCBmb3Ig
cCBpbiBzb3J0ZWQoQ09ORl9ESVIuZ2xvYigiKmh5c3RlcmlhMl9pbmJvdW5kcy5qc29uIikpCiAg
ICAgICAgaWYgcCAhPSBwcmVmZXJyZWQgYW5kIG5vdCBwLm5hbWUuc3RhcnRzd2l0aCgiMzBfc2J1
c2VyXyIpCiAgICApCiAgICBmb3IgcGF0aCBpbiBjYW5kaWRhdGVzOgogICAgICAgIHRyeToKICAg
ICAgICAgICAgZGF0YSA9IGpzb24ubG9hZHMocGF0aC5yZWFkX3RleHQoZW5jb2Rpbmc9InV0Zi04
IikpCiAgICAgICAgICAgIGluYm91bmQgPSBkYXRhLmdldCgiaW5ib3VuZHMiLCBbXSlbMF0KICAg
ICAgICAgICAgaWYgaW5ib3VuZC5nZXQoInR5cGUiKSA9PSAiaHlzdGVyaWEyIjoKICAgICAgICAg
ICAgICAgIHJldHVybiBwYXRoLCBpbmJvdW5kCiAgICAgICAgZXhjZXB0IChPU0Vycm9yLCBqc29u
LkpTT05EZWNvZGVFcnJvciwgSW5kZXhFcnJvciwgVHlwZUVycm9yKToKICAgICAgICAgICAgY29u
dGludWUKICAgIHJhaXNlIE1hbmFnZXJFcnJvcigi5pyq5om+5Yiw5Z+656GAIEh5c3RlcmlhMiDl
haXnq5nphY3nva7vvIzor7flhYjnlKjkuLvohJrmnKzlronoo4UgSHlzdGVyaWEy44CCIikKCgpk
ZWYgZmluZF9iYXNlX3R1aWNfY29uZmlnKCkgLT4gdHVwbGVbUGF0aCwgZGljdF0gfCBOb25lOgog
ICAgcHJlZmVycmVkID0gQ09ORl9ESVIgLyAiMTNfdHVpY19pbmJvdW5kcy5qc29uIgogICAgY2Fu
ZGlkYXRlcyA9IFtwcmVmZXJyZWRdIGlmIHByZWZlcnJlZC5leGlzdHMoKSBlbHNlIFtdCiAgICBj
YW5kaWRhdGVzLmV4dGVuZCgKICAgICAgICBwIGZvciBwIGluIHNvcnRlZChDT05GX0RJUi5nbG9i
KCIqdHVpY19pbmJvdW5kcy5qc29uIikpCiAgICAgICAgaWYgcCAhPSBwcmVmZXJyZWQgYW5kIG5v
dCBwLm5hbWUuc3RhcnRzd2l0aCgiMzFfc2J1c2VyXyIpCiAgICApCiAgICBmb3IgcGF0aCBpbiBj
YW5kaWRhdGVzOgogICAgICAgIHRyeToKICAgICAgICAgICAgZGF0YSA9IGpzb24ubG9hZHMocGF0
aC5yZWFkX3RleHQoZW5jb2Rpbmc9InV0Zi04IikpCiAgICAgICAgICAgIGluYm91bmQgPSBkYXRh
LmdldCgiaW5ib3VuZHMiLCBbXSlbMF0KICAgICAgICAgICAgaWYgaW5ib3VuZC5nZXQoInR5cGUi
KSA9PSAidHVpYyI6CiAgICAgICAgICAgICAgICByZXR1cm4gcGF0aCwgaW5ib3VuZAogICAgICAg
IGV4Y2VwdCAoT1NFcnJvciwganNvbi5KU09ORGVjb2RlRXJyb3IsIEluZGV4RXJyb3IsIFR5cGVF
cnJvcik6CiAgICAgICAgICAgIGNvbnRpbnVlCiAgICByZXR1cm4gTm9uZQoKCmRlZiBiYXNlX3By
b3h5X2xpbmVzKCkgLT4gbGlzdFtzdHJdOgogICAgcGF0aCA9IFNVQlNDUklCRV9ESVIgLyAicHJv
eGllcyIKICAgIGlmIG5vdCBwYXRoLmV4aXN0cygpOgogICAgICAgIHJhaXNlIE1hbmFnZXJFcnJv
cigi5pyq5om+5YiwIHN1YnNjcmliZS9wcm94aWVz77yM6K+35YWI5ZCv55So6K6i6ZiF5bm255Sf
5oiQ6IqC54K55L+h5oGv44CCIikKICAgIHJlc3VsdCA9IFsKICAgICAgICBsaW5lIGZvciBsaW5l
IGluIHBhdGgucmVhZF90ZXh0KGVuY29kaW5nPSJ1dGYtOCIpLnNwbGl0bGluZXMoKQogICAgICAg
IGlmICgidHlwZTogaHlzdGVyaWEyIiBpbiBsaW5lIG9yICJ0eXBlOiB0dWljIiBpbiBsaW5lKQog
ICAgICAgIGFuZCBsaW5lLmxzdHJpcCgpLnN0YXJ0c3dpdGgoIi0iKQogICAgXQogICAgaWYgbm90
IGFueSgidHlwZTogaHlzdGVyaWEyIiBpbiBsaW5lIGZvciBsaW5lIGluIHJlc3VsdCk6CiAgICAg
ICAgcmFpc2UgTWFuYWdlckVycm9yKCLln7rnoYDorqLpmIXkuK3msqHmnIkgSHlzdGVyaWEyIOiK
gueCueOAgiIpCiAgICBpZiBmaW5kX2Jhc2VfdHVpY19jb25maWcoKSBpcyBub3QgTm9uZSBhbmQg
bm90IGFueSgidHlwZTogdHVpYyIgaW4gbGluZSBmb3IgbGluZSBpbiByZXN1bHQpOgogICAgICAg
IHJhaXNlIE1hbmFnZXJFcnJvcigi5bey5a6J6KOFIFRVSUPvvIzkvYbln7rnoYDorqLpmIXkuK3m
sqHmnIkgVFVJQyDoioLngrnjgIIiKQoKICAgICMgQ2xhc2gg5Lya6buY6K6k6YCJ5LitIHNlbGVj
dCDnu4Tph4znmoTnrKzkuIDkuKroioLngrnjgILml6Dorrrlronoo4Xml7bnvZHljaHlnLDlnYDn
moQKICAgICMg5Y6f5aeL6aG65bqP5aaC5L2V77yM6YO95oqK5Y+M5Y2P6K6u55qEIElQdjYg6IqC
54K55pS+5ZyoIElQdjQg6IqC54K55YmN6Z2i77yb5ZCM5LiACiAgICAjIOWcsOWdgOaXj+WGheS7
jeS/neaMgSBIeXN0ZXJpYTIvVFVJQyDlkozlkITlnLDlnYDljp/mnInnmoTnqLPlrprpobrluo/j
gIIKICAgIGRlZiBpc19pcHY2X3Byb3h5KGxpbmU6IHN0cikgLT4gYm9vbDoKICAgICAgICBtYXRj
aCA9IHJlLnNlYXJjaChyIig/Ol58LFxzKilzZXJ2ZXI6XHMqKFwiW15cIl0qXCJ8J1teJ10qJ3xb
Xix9XHNdKykiLCBsaW5lKQogICAgICAgIGlmIG1hdGNoIGlzIE5vbmU6CiAgICAgICAgICAgIHJl
dHVybiBGYWxzZQogICAgICAgIHNlcnZlciA9IG1hdGNoLmdyb3VwKDEpLnN0cmlwKCJcIidbXSIp
CiAgICAgICAgcmV0dXJuICI6IiBpbiBzZXJ2ZXIKCiAgICByZXR1cm4gKAogICAgICAgIFtsaW5l
IGZvciBsaW5lIGluIHJlc3VsdCBpZiBpc19pcHY2X3Byb3h5KGxpbmUpXQogICAgICAgICsgW2xp
bmUgZm9yIGxpbmUgaW4gcmVzdWx0IGlmIG5vdCBpc19pcHY2X3Byb3h5KGxpbmUpXQogICAgKQoK
CmRlZiBiYXNlX2h5Ml9wcm94eV9saW5lcygpIC0+IGxpc3Rbc3RyXToKICAgIHJldHVybiBbbGlu
ZSBmb3IgbGluZSBpbiBiYXNlX3Byb3h5X2xpbmVzKCkgaWYgInR5cGU6IGh5c3RlcmlhMiIgaW4g
bGluZV0KCgpkZWYgc3Vic2NyaXB0aW9uX2Jhc2VfdXJsX3N0YXRlX3BhdGgoKSAtPiBQYXRoOgog
ICAgIiIiUmV0dXJuIHRoZSByb290LW9ubHkgc3RhdGUgZmlsZSB3cml0dGVuIGJ5IHRoZSBpbnN0
YWxsZXIuCgogICAgU3RyaWN0IG11bHRpLXVzZXIgaW5zdGFsbGF0aW9ucyBpbnRlbnRpb25hbGx5
IGhhdmUgbm8gcHVibGljIHN1YnNjcmlwdGlvbgogICAgVVJMLCBzbyB0aGUgbWFuYWdlciBtdXN0
IG5vdCB0cnkgdG8gcmVjb25zdHJ1Y3QgaXRzIG93biBhZGRyZXNzIGZyb20gYW4KICAgIGV4dGVy
bmFsbHkgcmVhY2hhYmxlIHN1YnNjcmlwdGlvbiBwYXRoLgogICAgIiIiCiAgICByZXR1cm4gVVNF
UlNfRElSIC8gInN1YnNjcmlwdGlvbi1iYXNlLXVybCIKCgpkZWYgc3Vic2NyaXB0aW9uX2Jhc2Vf
dXJsKCkgLT4gc3RyOgogICAgc3RhdGVfcGF0aCA9IHN1YnNjcmlwdGlvbl9iYXNlX3VybF9zdGF0
ZV9wYXRoKCkKICAgIGlmIHN0YXRlX3BhdGguZXhpc3RzKCk6CiAgICAgICAgdmFsdWUgPSBzdGF0
ZV9wYXRoLnJlYWRfdGV4dChlbmNvZGluZz0idXRmLTgiLCBlcnJvcnM9InN0cmljdCIpLnN0cmlw
KCkucnN0cmlwKCIvIikKICAgICAgICBpZiByZS5mdWxsbWF0Y2gociJodHRwcz86Ly8oPzpcW1te
XS9cc10rXF18W0EtWmEtejAtOS4tXSspKD86OlswLTldezEsNX0pPyIsIHZhbHVlKToKICAgICAg
ICAgICAgcmV0dXJuIHZhbHVlCiAgICAgICAgcmFpc2UgTWFuYWdlckVycm9yKGYi6K6i6ZiF5pyN
5Yqh5Zmo5Zyw5Z2A54q25oCB5paH5Lu25peg5pWI77yae3N0YXRlX3BhdGh9IikKCiAgICAjIENv
bXBhdGliaWxpdHkgd2l0aCBpbnN0YWxsYXRpb25zIGNyZWF0ZWQgYmVmb3JlIHN0cmljdCBtdWx0
aS11c2VyIG1vZGUuCiAgICBzb3VyY2VzID0gW1dPUktfRElSIC8gImxpc3QiLCBTVUJTQ1JJQkVf
RElSIC8gImNsYXNoLWNhbXB1cy1mcmVlIiwgU1VCU0NSSUJFX0RJUiAvICJjbGFzaCJdCiAgICBw
YXR0ZXJucyA9IFsKICAgICAgICByZS5jb21waWxlKHIiKGh0dHBzPzovLyg/OlxbW15dXStcXXxb
Xi9cc10rPykoPzo6XGQrKT8pL1teL1xzXSsvY2xhc2gtY2FtcHVzLWZyZWUiKSwKICAgICAgICBy
ZS5jb21waWxlKHIidXJsOlxzKihodHRwcz86Ly8oPzpcW1teXV0rXF18W14vXHNdKz8pKD86Olxk
Kyk/KS9bXi9cc10rL3Byb3hpZXMiKSwKICAgIF0KICAgIGZvciBwYXRoIGluIHNvdXJjZXM6CiAg
ICAgICAgaWYgbm90IHBhdGguZXhpc3RzKCk6CiAgICAgICAgICAgIGNvbnRpbnVlCiAgICAgICAg
dGV4dCA9IEFOU0lfUkUuc3ViKCIiLCBwYXRoLnJlYWRfdGV4dChlbmNvZGluZz0idXRmLTgiLCBl
cnJvcnM9Imlnbm9yZSIpKQogICAgICAgIGZvciBwYXR0ZXJuIGluIHBhdHRlcm5zOgogICAgICAg
ICAgICBtYXRjaCA9IHBhdHRlcm4uc2VhcmNoKHRleHQpCiAgICAgICAgICAgIGlmIG1hdGNoOgog
ICAgICAgICAgICAgICAgcmV0dXJuIG1hdGNoLmdyb3VwKDEpLnJzdHJpcCgiLyIpCiAgICByYWlz
ZSBNYW5hZ2VyRXJyb3IoIuaXoOazleS7jueOsOacieiuoumYheaWh+S7tuehruWumuiuoumYheac
jeWKoeWZqOWcsOWdgOOAguivt+WFiOi/kOihjOS4u+iEmuacrOafpeeci+iKgueCueS/oeaBr+OA
giIpCgoKZGVmIGF0b21pY193cml0ZShwYXRoOiBQYXRoLCBjb250ZW50OiBzdHIsIG1vZGU6IGlu
dCA9IDBvNjAwKSAtPiBOb25lOgogICAgcGF0aC5wYXJlbnQubWtkaXIocGFyZW50cz1UcnVlLCBl
eGlzdF9vaz1UcnVlKQogICAgdGVtcCA9IHBhdGgud2l0aF9uYW1lKGYiLntwYXRoLm5hbWV9Lntv
cy5nZXRwaWQoKX0udG1wIikKICAgIHRlbXAud3JpdGVfdGV4dChjb250ZW50LCBlbmNvZGluZz0i
dXRmLTgiKQogICAgb3MuY2htb2QodGVtcCwgbW9kZSkKICAgIG9zLnJlcGxhY2UodGVtcCwgcGF0
aCkKCgpkZWYgeWFtbF9xdW90ZSh2YWx1ZTogc3RyKSAtPiBzdHI6CiAgICByZXR1cm4ganNvbi5k
dW1wcyh2YWx1ZSwgZW5zdXJlX2FzY2lpPUZhbHNlKQoKCmRlZiB0dWljX3V1aWQocm93OiBzcWxp
dGUzLlJvdykgLT4gc3RyOgogICAgIiIiRGVyaXZlIGEgc3RhYmxlIG5vbi1zZWNyZXQgVFVJQyBV
VUlEIGZyb20gdGhlIHJvdGF0YWJsZSB1c2VyIHBhc3N3b3JkLiIiIgogICAgcmV0dXJuIHN0cih1
dWlkLnV1aWQ1KHV1aWQuTkFNRVNQQUNFX1VSTCwgZiJzYi11c2VyLXR1aWM6e3Jvd1sncGFzc3dv
cmQnXX0iKSkKCgpkZWYgY3VzdG9taXplX3Byb3h5X2xpbmUobGluZTogc3RyLCByb3c6IHNxbGl0
ZTMuUm93LCBuYW1lOiBzdHIpIC0+IHN0cjoKICAgIHVwZGF0ZWQgPSByZS5zdWIociduYW1lOlxz
KiJbXiJdKiInLCBmIm5hbWU6IHt5YW1sX3F1b3RlKG5hbWUpfSIsIGxpbmUsIGNvdW50PTEpCiAg
ICBpZiAidHlwZTogdHVpYyIgaW4gbGluZToKICAgICAgICBpZiBub3Qgcm93WyJ0dWljX3BvcnQi
XToKICAgICAgICAgICAgcmFpc2UgTWFuYWdlckVycm9yKGYi55So5oi3IHtyb3dbJ3VzZXJuYW1l
J119IOWwmuacquWIhumFjSBUVUlDIOerr+WPo+OAgiIpCiAgICAgICAgdXBkYXRlZCA9IHJlLnN1
YihyInBvcnQ6XHMqWzAtOV0rIiwgZiJwb3J0OiB7cm93Wyd0dWljX3BvcnQnXX0iLCB1cGRhdGVk
LCBjb3VudD0xKQogICAgICAgIHVwZGF0ZWQgPSByZS5zdWIociJ1dWlkOlxzKlteLH1dKyIsIGYi
dXVpZDoge3lhbWxfcXVvdGUodHVpY191dWlkKHJvdykpfSIsIHVwZGF0ZWQsIGNvdW50PTEpCiAg
ICBlbHNlOgogICAgICAgIHVwZGF0ZWQgPSByZS5zdWIociJwb3J0OlxzKlswLTldKyIsIGYicG9y
dDoge3Jvd1sncG9ydCddfSIsIHVwZGF0ZWQsIGNvdW50PTEpCiAgICB1cGRhdGVkID0gcmUuc3Vi
KHIicGFzc3dvcmQ6XHMqW14sfV0rIiwgZiJwYXNzd29yZDoge3lhbWxfcXVvdGUocm93WydwYXNz
d29yZCddKX0iLCB1cGRhdGVkLCBjb3VudD0xKQogICAgdXBkYXRlZCA9IHJlLnN1YihyIiw/XHMq
cG9ydHM6XHMqW14sXSssXHMqaG9wLWludGVydmFsOlxzKlteLF0rIiwgIiIsIHVwZGF0ZWQsIGNv
dW50PTEpCiAgICB1cGRhdGVkID0gcmUuc3ViKHIiLFxzKnJlYWxtLW9wdHM6XHMqXHsuKlx9KD89
XH0pIiwgIiIsIHVwZGF0ZWQsIGNvdW50PTEpCiAgICByZXR1cm4gdXBkYXRlZAoKCmRlZiB1c2Vy
X3Byb3h5X2xpbmVzKHJvdzogc3FsaXRlMy5Sb3csIGV2ZXJ5b25lOiBsaXN0W3NxbGl0ZTMuUm93
XSkgLT4gbGlzdFtzdHJdOgogICAgYmFzZV9saW5lcyA9IGJhc2VfcHJveHlfbGluZXMoKQogICAg
cmVzdWx0ID0gW10KICAgIGZvciBpbmRleCwgbGluZSBpbiBlbnVtZXJhdGUoYmFzZV9saW5lcywg
MSk6CiAgICAgICAgbWF0Y2ggPSByZS5zZWFyY2gociduYW1lOlxzKiIoW14iXSopIicsIGxpbmUp
CiAgICAgICAgcHJvdG9jb2wgPSAiVFVJQyIgaWYgInR5cGU6IHR1aWMiIGluIGxpbmUgZWxzZSAi
SHlzdGVyaWEyIgogICAgICAgIG9yaWdpbmFsX25hbWUgPSBtYXRjaC5ncm91cCgxKSBpZiBtYXRj
aCBlbHNlIGYie3Byb3RvY29sfSAje2luZGV4fSIKICAgICAgICAjIOecn+WunuiKgueCueWPquS/
neeVmeato+W4uOWQjeensOOAgua1gemHj+S/oeaBr+WNleeLrOaUvuWFpeS4gOS4quS4jeWPguS4
jua1i+mAn+aIluWIhua1geeahOS7o+eQhue7hOOAggogICAgICAgIHJlc3VsdC5hcHBlbmQoY3Vz
dG9taXplX3Byb3h5X2xpbmUobGluZSwgcm93LCBvcmlnaW5hbF9uYW1lKSkKICAgIHJldHVybiBy
ZXN1bHQKCgpkZWYgdXNhZ2VfcHJveHlfbmFtZShyb3c6IHNxbGl0ZTMuUm93LCBzZXJ2ZXJfcXVv
dGE6IGludCwgc2VydmVyX3JlbWFpbmluZzogaW50KSAtPiBzdHI6CiAgICAiIiJSZXR1cm4gb25l
IGRpc3BsYXktb25seSBwcm94eSBuYW1lIGZvciBvbmUgdmlzaWJsZSB1c2VyJ3MgdXNhZ2UuIiIi
CiAgICByb2xlID0gIueuoeeQhuWRmCIgaWYgcm93WyJpc19hZG1pbiJdIGVsc2UgIueUqOaItyIK
ICAgIGlmIHJvd1sicXVvdGFfYnl0ZXMiXSA9PSAwOgogICAgICAgIHVzZWQgPSByb3dbInVwbG9h
ZF9ieXRlcyJdICsgcm93WyJkb3dubG9hZF9ieXRlcyJdCiAgICAgICAgc3RhdGUgPSAi5bey5YGc
55SoICIgaWYgbm90IHJvd1siZW5hYmxlZCJdIGVsc2UgIiIKICAgICAgICByZXR1cm4gKAogICAg
ICAgICAgICBmIvCfk4oge3JvbGV9IHtyb3dbJ3VzZXJuYW1lJ119IHtzdGF0ZX3lt7LnlKh7Zm10
X3RyYWZmaWModXNlZCl9ICIKICAgICAgICAgICAgZiLlhbHkuqvlj6/nlKh7Zm10X3RyYWZmaWMo
c2VydmVyX3JlbWFpbmluZyl9IOaciOS4iumZkHtmbXRfdHJhZmZpYyhzZXJ2ZXJfcXVvdGEpfSIK
ICAgICAgICApCiAgICByZXR1cm4gZiLwn5OKIHtyb2xlfSB7dXNhZ2Vfc3RhdHVzKHJvdywgY29t
cGFjdD1UcnVlKX0iCgoKZGVmIHN1YnNjcmlwdGlvbl9zdW1tYXJ5X3Byb3h5X25hbWUoCiAgICBy
b3c6IHNxbGl0ZTMuUm93LCBldmVyeW9uZTogbGlzdFtzcWxpdGUzLlJvd10sIHNlcnZlcl9xdW90
YTogaW50CikgLT4gc3RyOgogICAgdXNhZ2UgPSBzdWJzY3JpcHRpb25fdXNhZ2Uocm93LCBldmVy
eW9uZSwgc2VydmVyX3F1b3RhKQogICAgaWYgdXNhZ2VbInVzZXNfc2VydmVyX3F1b3RhIl06CiAg
ICAgICAgcmV0dXJuICgKICAgICAgICAgICAgZiLwn5OKIOaciOa1gemHj+aAu+iuoSDlt7LnlKh7
Zm10X3RyYWZmaWModXNhZ2VbJ3VzZWRfYnl0ZXMnXSl9ICIKICAgICAgICAgICAgZiLlj6/nlKh7
Zm10X3RyYWZmaWModXNhZ2VbJ3JlbWFpbmluZ19ieXRlcyddKX0g5LiK6ZmQe2ZtdF90cmFmZmlj
KHVzYWdlWyd0b3RhbF9ieXRlcyddKX0iCiAgICAgICAgKQogICAgcmV0dXJuIHVzYWdlX3Byb3h5
X25hbWUocm93LCBzZXJ2ZXJfcXVvdGEsIG1heChzZXJ2ZXJfcXVvdGEgLSB1c2FnZVsidXNlZF9i
eXRlcyJdLCAwKSkKCgpkZWYgYWRkX3VzYWdlX3Byb3h5X2dyb3VwKAogICAgY29uZmlnOiBzdHIs
IHJvdzogc3FsaXRlMy5Sb3csIGV2ZXJ5b25lOiBsaXN0W3NxbGl0ZTMuUm93XSwgc2VydmVyX3F1
b3RhOiBpbnQKKSAtPiBzdHI6CiAgICAiIiJJbnNlcnQgb25lIGZpeGVkIHVzYWdlIGdyb3VwIGJh
Y2tlZCBvbmx5IGJ5IGxvY2FsIGRpcmVjdCBkaXNwbGF5IGl0ZW1zLiIiIgogICAgdXNhZ2UgPSBz
dWJzY3JpcHRpb25fdXNhZ2Uocm93LCBldmVyeW9uZSwgc2VydmVyX3F1b3RhKQogICAgaWYgdXNh
Z2VbInVzZXNfc2VydmVyX3F1b3RhIl06CiAgICAgICAgbmFtZXMgPSBbc3Vic2NyaXB0aW9uX3N1
bW1hcnlfcHJveHlfbmFtZShyb3csIGV2ZXJ5b25lLCBzZXJ2ZXJfcXVvdGEpXQogICAgICAgIG5h
bWVzLmV4dGVuZCgKICAgICAgICAgICAgdXNhZ2VfcHJveHlfbmFtZShpdGVtLCBzZXJ2ZXJfcXVv
dGEsIHVzYWdlWyJyZW1haW5pbmdfYnl0ZXMiXSkKICAgICAgICAgICAgZm9yIGl0ZW0gaW4gZXZl
cnlvbmUKICAgICAgICApCiAgICBlbHNlOgogICAgICAgIG5hbWVzID0gW3N1YnNjcmlwdGlvbl9z
dW1tYXJ5X3Byb3h5X25hbWUocm93LCBldmVyeW9uZSwgc2VydmVyX3F1b3RhKV0KICAgIGRpc3Bs
YXlfcHJveGllcyA9ICIiLmpvaW4oCiAgICAgICAgZiIgIC0gbmFtZToge3lhbWxfcXVvdGUobmFt
ZSl9XG4iCiAgICAgICAgIiAgICB0eXBlOiBkaXJlY3RcbiIKICAgICAgICAiICAgIHVkcDogdHJ1
ZVxuIgogICAgICAgIGZvciBuYW1lIGluIG5hbWVzCiAgICApCiAgICBncm91cCA9ICgKICAgICAg
ICBmIiAgLSBuYW1lOiB7eWFtbF9xdW90ZSgn8J+TiiDmlbTkvZPmtYHph4/mo4DmtYsnKX1cbiIK
ICAgICAgICAiICAgIHR5cGU6IHNlbGVjdFxuIgogICAgICAgICIgICAgcHJveGllczpcbiIKICAg
ICAgICArICIiLmpvaW4oZiIgICAgICAtIHt5YW1sX3F1b3RlKG5hbWUpfVxuIiBmb3IgbmFtZSBp
biBuYW1lcykKICAgICkKICAgIHVwZGF0ZWQsIHByb3hpZXNfY291bnQgPSByZS5zdWJuKAogICAg
ICAgIHIiKD9tKV5wcm94aWVzOlsgXHRdKiQiLCBmInByb3hpZXM6XG57ZGlzcGxheV9wcm94aWVz
fSIsIGNvbmZpZywgY291bnQ9MQogICAgKQogICAgaWYgcHJveGllc19jb3VudCAhPSAxOgogICAg
ICAgIHJhaXNlIE1hbmFnZXJFcnJvcigi6K6i6ZiF5qih5p2/57y65bCRIHByb3hpZXPvvIzml6Dm
s5XliqDlhaXmtYHph4/kv6Hmga/lsZXnpLrpobnjgIIiKQogICAgdXBkYXRlZCwgZ3JvdXBzX2Nv
dW50ID0gcmUuc3VibigKICAgICAgICByIig/bSlecHJveHktZ3JvdXBzOlsgXHRdKiQiLCBmInBy
b3h5LWdyb3Vwczpcbntncm91cH0iLCB1cGRhdGVkLCBjb3VudD0xCiAgICApCiAgICBpZiBncm91
cHNfY291bnQgIT0gMToKICAgICAgICByYWlzZSBNYW5hZ2VyRXJyb3IoIuiuoumYheaooeadv+e8
uuWwkSBwcm94eS1ncm91cHPvvIzml6Dms5XliqDlhaXmtYHph4/kv6Hmga/ku6PnkIbnu4TjgIIi
KQogICAgcmV0dXJuIHVwZGF0ZWQKCgpkZWYgcmVuZGVyX3N1YnNjcmlwdGlvbnMoY29ubjogc3Fs
aXRlMy5Db25uZWN0aW9uKSAtPiBOb25lOgogICAgdGVtcGxhdGVfcGF0aCA9IFNVQlNDUklCRV9E
SVIgLyAiY2xhc2gtY2FtcHVzLWZyZWUiCiAgICBpZiBub3QgdGVtcGxhdGVfcGF0aC5leGlzdHMo
KToKICAgICAgICByYWlzZSBNYW5hZ2VyRXJyb3IoIuacquaJvuWIsCBjbGFzaC1jYW1wdXMtZnJl
ZSDmqKHmnb/vvIzor7flhYjlkK/nlKjorqLpmIXjgIIiKQogICAgZW5zdXJlX3R1aWNfcG9ydHMo
Y29ubikKICAgIHRlbXBsYXRlID0gdGVtcGxhdGVfcGF0aC5yZWFkX3RleHQoZW5jb2Rpbmc9InV0
Zi04IikKICAgIGJhc2VfdXJsID0gc3Vic2NyaXB0aW9uX2Jhc2VfdXJsKCkKICAgIGV2ZXJ5b25l
ID0gYWxsX3VzZXJzKGNvbm4pCiAgICBtb250aGx5X3F1b3RhID0gc2VydmVyX21vbnRobHlfcXVv
dGEoY29ubikKICAgIFVTRVJTX0RJUi5ta2RpcihwYXJlbnRzPVRydWUsIGV4aXN0X29rPVRydWUp
CiAgICBvcy5jaG1vZChVU0VSU19ESVIsIDBvNzAwKQogICAgdmFsaWRfdG9rZW5zID0ge3Jvd1si
dG9rZW4iXSBmb3Igcm93IGluIGV2ZXJ5b25lfQoKICAgIGZvciBlbnRyeSBpbiBVU0VSU19ESVIu
aXRlcmRpcigpOgogICAgICAgIGlmIGVudHJ5LmlzX2RpcigpIGFuZCBUT0tFTl9SRS5mdWxsbWF0
Y2goZW50cnkubmFtZSkgYW5kIGVudHJ5Lm5hbWUgbm90IGluIHZhbGlkX3Rva2VuczoKICAgICAg
ICAgICAgc2h1dGlsLnJtdHJlZShlbnRyeSkKCiAgICBmb3Igcm93IGluIGV2ZXJ5b25lOgogICAg
ICAgIHVzZXJfZGlyID0gVVNFUlNfRElSIC8gcm93WyJ0b2tlbiJdCiAgICAgICAgdXNlcl9kaXIu
bWtkaXIocGFyZW50cz1UcnVlLCBleGlzdF9vaz1UcnVlKQogICAgICAgIG9zLmNobW9kKHVzZXJf
ZGlyLCAwbzcwMCkKICAgICAgICBwcm92aWRlcl91cmwgPSBmIntiYXNlX3VybH0vdXNlci97cm93
Wyd0b2tlbiddfS9wcm94aWVzIgogICAgICAgIGNvbmZpZyA9IHJlLnN1YigKICAgICAgICAgICAg
ciIoP20pXihccyp1cmw6XHMqKVxTKy9wcm94aWVzXHMqJCIsCiAgICAgICAgICAgIGxhbWJkYSBt
YXRjaDogZiJ7bWF0Y2guZ3JvdXAoMSl9e3Byb3ZpZGVyX3VybH0iLAogICAgICAgICAgICB0ZW1w
bGF0ZSwKICAgICAgICApCiAgICAgICAgY29uZmlnID0gcmUuc3ViKHIiKD9tKV4oXHMqaW50ZXJ2
YWw6KVxzKjM2MDBccyokIiwgciJcMSAzMDAiLCBjb25maWcpCiAgICAgICAgY29uZmlnID0gYWRk
X3VzYWdlX3Byb3h5X2dyb3VwKGNvbmZpZywgcm93LCBldmVyeW9uZSwgbW9udGhseV9xdW90YSkK
ICAgICAgICBwcm94aWVzID0gInByb3hpZXM6XG4iICsgIlxuIi5qb2luKHVzZXJfcHJveHlfbGlu
ZXMocm93LCBldmVyeW9uZSkpICsgIlxuIgogICAgICAgIGF0b21pY193cml0ZSh1c2VyX2RpciAv
ICJjbGFzaC1jYW1wdXMtZnJlZSIsIGNvbmZpZykKICAgICAgICBhdG9taWNfd3JpdGUodXNlcl9k
aXIgLyAicHJveGllcyIsIHByb3hpZXMpCgoKZGVmIHJlbmRlcl9pbmJvdW5kcyhjb25uOiBzcWxp
dGUzLkNvbm5lY3Rpb24pIC0+IE5vbmU6CiAgICBfLCBiYXNlID0gZmluZF9iYXNlX2h5Ml9jb25m
aWcoKQogICAgdHVpY19iYXNlX3Jlc3VsdCA9IGZpbmRfYmFzZV90dWljX2NvbmZpZygpCiAgICB0
dWljX2Jhc2UgPSB0dWljX2Jhc2VfcmVzdWx0WzFdIGlmIHR1aWNfYmFzZV9yZXN1bHQgaXMgbm90
IE5vbmUgZWxzZSBOb25lCiAgICBleHBlY3RlZDogc2V0W1BhdGhdID0gc2V0KCkKICAgIGZvciBy
b3cgaW4gYWN0aXZlX3VzZXJzKGNvbm4pOgogICAgICAgIGluYm91bmQgPSBjb3B5LmRlZXBjb3B5
KGJhc2UpCiAgICAgICAgaW5ib3VuZFsidGFnIl0gPSBmInNiLXVzZXIte3Jvd1snaWQnXX0te3Jv
d1sndXNlcm5hbWUnXX0iCiAgICAgICAgIyBUaGUgYmFzZSBpbmJvdW5kIGlzIGtlcHQgb24gbG9v
cGJhY2sgYXMgYW4gaW50ZXJuYWwgdGVtcGxhdGUgaW4KICAgICAgICAjIHN0cmljdCBtb2RlLiAg
TWFuYWdlZCB1c2VycyBtdXN0IGV4cGxpY2l0bHkgbGlzdGVuIG9uIHRoZSBwdWJsaWMKICAgICAg
ICAjIGR1YWwtc3RhY2sgYWRkcmVzczsgb21pdHRpbmcgYGxpc3RlbmAgbWFrZXMgc2luZy1ib3gg
dXNlIGxvb3BiYWNrLgogICAgICAgIGluYm91bmRbImxpc3RlbiJdID0gIjo6IgogICAgICAgIGlu
Ym91bmRbImxpc3Rlbl9wb3J0Il0gPSByb3dbInBvcnQiXQogICAgICAgIGluYm91bmRbInVzZXJz
Il0gPSBbeyJuYW1lIjogcm93WyJ1c2VybmFtZSJdLCAicGFzc3dvcmQiOiByb3dbInBhc3N3b3Jk
Il19XQogICAgICAgIGluYm91bmQucG9wKCJyZWFsbSIsIE5vbmUpCiAgICAgICAgdGFyZ2V0ID0g
Q09ORl9ESVIgLyBmIjMwX3NidXNlcl97cm93WydpZCddfV9oeXN0ZXJpYTJfaW5ib3VuZHMuanNv
biIKICAgICAgICBleHBlY3RlZC5hZGQodGFyZ2V0KQogICAgICAgIGF0b21pY193cml0ZSh0YXJn
ZXQsIGpzb24uZHVtcHMoeyJpbmJvdW5kcyI6IFtpbmJvdW5kXX0sIGVuc3VyZV9hc2NpaT1GYWxz
ZSwgaW5kZW50PTIpICsgIlxuIikKICAgICAgICBpZiB0dWljX2Jhc2UgaXMgbm90IE5vbmU6CiAg
ICAgICAgICAgIHR1aWNfaW5ib3VuZCA9IGNvcHkuZGVlcGNvcHkodHVpY19iYXNlKQogICAgICAg
ICAgICB0dWljX2luYm91bmRbInRhZyJdID0gZiJzYi11c2VyLXR1aWMte3Jvd1snaWQnXX0te3Jv
d1sndXNlcm5hbWUnXX0iCiAgICAgICAgICAgIHR1aWNfaW5ib3VuZFsibGlzdGVuIl0gPSAiOjoi
CiAgICAgICAgICAgIHR1aWNfaW5ib3VuZFsibGlzdGVuX3BvcnQiXSA9IHJvd1sidHVpY19wb3J0
Il0KICAgICAgICAgICAgdHVpY19pbmJvdW5kWyJ1c2VycyJdID0gW3sKICAgICAgICAgICAgICAg
ICJuYW1lIjogcm93WyJ1c2VybmFtZSJdLAogICAgICAgICAgICAgICAgInV1aWQiOiB0dWljX3V1
aWQocm93KSwKICAgICAgICAgICAgICAgICJwYXNzd29yZCI6IHJvd1sicGFzc3dvcmQiXSwKICAg
ICAgICAgICAgfV0KICAgICAgICAgICAgdHVpY190YXJnZXQgPSBDT05GX0RJUiAvIGYiMzFfc2J1
c2VyX3tyb3dbJ2lkJ119X3R1aWNfaW5ib3VuZHMuanNvbiIKICAgICAgICAgICAgZXhwZWN0ZWQu
YWRkKHR1aWNfdGFyZ2V0KQogICAgICAgICAgICBhdG9taWNfd3JpdGUoCiAgICAgICAgICAgICAg
ICB0dWljX3RhcmdldCwKICAgICAgICAgICAgICAgIGpzb24uZHVtcHMoeyJpbmJvdW5kcyI6IFt0
dWljX2luYm91bmRdfSwgZW5zdXJlX2FzY2lpPUZhbHNlLCBpbmRlbnQ9MikgKyAiXG4iLAogICAg
ICAgICAgICApCiAgICBmb3IgcGF0dGVybiBpbiBNQU5BR0VEX0NPTkZfR0xPQlM6CiAgICAgICAg
Zm9yIHBhdGggaW4gQ09ORl9ESVIuZ2xvYihwYXR0ZXJuKToKICAgICAgICAgICAgaWYgcGF0aCBu
b3QgaW4gZXhwZWN0ZWQ6CiAgICAgICAgICAgICAgICBwYXRoLnVubGluayhtaXNzaW5nX29rPVRy
dWUpCgoKZGVmIGxvY2tfYmFzZV9pbmJvdW5kKHByb3RvY29sOiBzdHIpIC0+IE5vbmU6CiAgICAi
IiJNYWtlIGFuIG9yaWdpbmFsIHByb3RvY29sIGluYm91bmQgYW4gaW50ZXJuYWwtb25seSB0ZW1w
bGF0ZS4KCiAgICBUaGlzIGludmFsaWRhdGVzIGNhY2hlZCBsZWdhY3kgcHVibGljIG5vZGVzOiB1
c2VyLXNwZWNpZmljIGluYm91bmRzIGFyZQogICAgdGhlIG9ubHkgbWFuYWdlZCBwcm90b2NvbCBl
bmRwb2ludHMgcmVhY2hhYmxlIGZyb20gdGhlIEludGVybmV0LgogICAgIiIiCiAgICBpZiBwcm90
b2NvbCA9PSAiaHlzdGVyaWEyIjoKICAgICAgICBwYXRoLCBpbmJvdW5kID0gZmluZF9iYXNlX2h5
Ml9jb25maWcoKQogICAgZWxzZToKICAgICAgICByZXN1bHQgPSBmaW5kX2Jhc2VfdHVpY19jb25m
aWcoKQogICAgICAgIGlmIHJlc3VsdCBpcyBOb25lOgogICAgICAgICAgICByZXR1cm4KICAgICAg
ICBwYXRoLCBpbmJvdW5kID0gcmVzdWx0CiAgICBpZiBpbmJvdW5kLmdldCgibGlzdGVuIikgPT0g
IjEyNy4wLjAuMSI6CiAgICAgICAgcmV0dXJuCiAgICBkYXRhID0ganNvbi5sb2FkcyhwYXRoLnJl
YWRfdGV4dChlbmNvZGluZz0idXRmLTgiKSkKICAgIGZvciBjYW5kaWRhdGUgaW4gZGF0YS5nZXQo
ImluYm91bmRzIiwgW10pOgogICAgICAgIGlmIGNhbmRpZGF0ZS5nZXQoInR5cGUiKSA9PSBwcm90
b2NvbCBhbmQgY2FuZGlkYXRlLmdldCgidGFnIikgPT0gaW5ib3VuZC5nZXQoInRhZyIpOgogICAg
ICAgICAgICBjYW5kaWRhdGVbImxpc3RlbiJdID0gIjEyNy4wLjAuMSIKICAgICAgICAgICAgYXRv
bWljX3dyaXRlKHBhdGgsIGpzb24uZHVtcHMoZGF0YSwgZW5zdXJlX2FzY2lpPUZhbHNlLCBpbmRl
bnQ9MikgKyAiXG4iKQogICAgICAgICAgICByZXR1cm4KICAgIHJhaXNlIE1hbmFnZXJFcnJvcihm
IuaXoOazlemUgeWumuWfuuehgCB7cHJvdG9jb2x9IOWFpeerme+8mntwYXRofSIpCgoKZGVmIGxv
Y2tfYmFzZV9oeTJfaW5ib3VuZCgpIC0+IE5vbmU6CiAgICBsb2NrX2Jhc2VfaW5ib3VuZCgiaHlz
dGVyaWEyIikKCgpkZWYgbG9ja19iYXNlX3R1aWNfaW5ib3VuZCgpIC0+IE5vbmU6CiAgICBsb2Nr
X2Jhc2VfaW5ib3VuZCgidHVpYyIpCgoKZGVmIGlzX3BvcnRfYXZhaWxhYmxlKHBvcnQ6IGludCkg
LT4gYm9vbDoKICAgIHdpdGggc29ja2V0LnNvY2tldChzb2NrZXQuQUZfSU5FVDYsIHNvY2tldC5T
T0NLX0RHUkFNKSBhcyBzb2NrOgogICAgICAgIHRyeToKICAgICAgICAgICAgc29jay5zZXRzb2Nr
b3B0KHNvY2tldC5JUFBST1RPX0lQVjYsIHNvY2tldC5JUFY2X1Y2T05MWSwgMCkKICAgICAgICAg
ICAgc29jay5iaW5kKCgiOjoiLCBwb3J0KSkKICAgICAgICAgICAgcmV0dXJuIFRydWUKICAgICAg
ICBleGNlcHQgT1NFcnJvcjoKICAgICAgICAgICAgcmV0dXJuIEZhbHNlCgoKZGVmIGFsbG9jYXRl
X3BvcnQoY29ubjogc3FsaXRlMy5Db25uZWN0aW9uKSAtPiBpbnQ6CiAgICB1c2VkID0gewogICAg
ICAgIHZhbHVlCiAgICAgICAgZm9yIHJvdyBpbiBjb25uLmV4ZWN1dGUoIlNFTEVDVCBwb3J0LHR1
aWNfcG9ydCBGUk9NIHVzZXJzIikKICAgICAgICBmb3IgdmFsdWUgaW4gcm93CiAgICAgICAgaWYg
dmFsdWUKICAgIH0KICAgIGZvciBwb3J0IGluIHJhbmdlKFBPUlRfTUlOLCBQT1JUX01BWCArIDEp
OgogICAgICAgIGlmIHBvcnQgbm90IGluIHVzZWQgYW5kIGlzX3BvcnRfYXZhaWxhYmxlKHBvcnQp
OgogICAgICAgICAgICByZXR1cm4gcG9ydAogICAgcmFpc2UgTWFuYWdlckVycm9yKGYie1BPUlRf
TUlOfS17UE9SVF9NQVh9IOiMg+WbtOWGheayoeacieWPr+eUqCBVRFAg56uv5Y+j44CCIikKCgpk
ZWYgYWxsb2NhdGVfdHVpY19wb3J0KGNvbm46IHNxbGl0ZTMuQ29ubmVjdGlvbikgLT4gaW50Ogog
ICAgdXNlZCA9IHsKICAgICAgICB2YWx1ZQogICAgICAgIGZvciByb3cgaW4gY29ubi5leGVjdXRl
KCJTRUxFQ1QgcG9ydCx0dWljX3BvcnQgRlJPTSB1c2VycyIpCiAgICAgICAgZm9yIHZhbHVlIGlu
IHJvdwogICAgICAgIGlmIHZhbHVlCiAgICB9CiAgICBmb3IgcG9ydCBpbiByYW5nZShUVUlDX1BP
UlRfTUlOLCBUVUlDX1BPUlRfTUFYICsgMSk6CiAgICAgICAgaWYgcG9ydCBub3QgaW4gdXNlZCBh
bmQgaXNfcG9ydF9hdmFpbGFibGUocG9ydCk6CiAgICAgICAgICAgIHJldHVybiBwb3J0CiAgICBy
YWlzZSBNYW5hZ2VyRXJyb3IoZiJ7VFVJQ19QT1JUX01JTn0te1RVSUNfUE9SVF9NQVh9IOiMg+Wb
tOWGheayoeacieWPr+eUqCBUVUlDIFVEUCDnq6/lj6PjgIIiKQoKCmRlZiBlbnN1cmVfdHVpY19w
b3J0cyhjb25uOiBzcWxpdGUzLkNvbm5lY3Rpb24pIC0+IGJvb2w6CiAgICAiIiJBbGxvY2F0ZSBU
VUlDIHBvcnRzIGxhemlseSBzbyBleGlzdGluZyBIeXN0ZXJpYTItb25seSBkYXRhYmFzZXMgbWln
cmF0ZSBzYWZlbHkuIiIiCiAgICBpZiBmaW5kX2Jhc2VfdHVpY19jb25maWcoKSBpcyBOb25lOgog
ICAgICAgIHJldHVybiBGYWxzZQogICAgY2hhbmdlZCA9IEZhbHNlCiAgICBmb3Igcm93IGluIGNv
bm4uZXhlY3V0ZSgiU0VMRUNUICogRlJPTSB1c2VycyBXSEVSRSB0dWljX3BvcnQ9MCBPUkRFUiBC
WSBpZCIpLmZldGNoYWxsKCk6CiAgICAgICAgY29ubi5leGVjdXRlKAogICAgICAgICAgICAiVVBE
QVRFIHVzZXJzIFNFVCB0dWljX3BvcnQ9Pyx1cGRhdGVkX2F0PT8gV0hFUkUgaWQ9PyIsCiAgICAg
ICAgICAgIChhbGxvY2F0ZV90dWljX3BvcnQoY29ubiksIG5vd19pc28oKSwgcm93WyJpZCJdKSwK
ICAgICAgICApCiAgICAgICAgY2hhbmdlZCA9IFRydWUKICAgIGlmIGNoYW5nZWQ6CiAgICAgICAg
Y29ubi5jb21taXQoKQogICAgcmV0dXJuIFRydWUKCgpkZWYgdXNlcl9wb3J0cyhyb3c6IHNxbGl0
ZTMuUm93LCAqLCBpbmNsdWRlX3N0YWxlX3R1aWM6IGJvb2wgPSBGYWxzZSkgLT4gbGlzdFtpbnRd
OgogICAgcG9ydHMgPSBbcm93WyJwb3J0Il1dCiAgICBpZiByb3dbInR1aWNfcG9ydCJdIGFuZCAo
aW5jbHVkZV9zdGFsZV90dWljIG9yIGZpbmRfYmFzZV90dWljX2NvbmZpZygpIGlzIG5vdCBOb25l
KToKICAgICAgICBwb3J0cy5hcHBlbmQocm93WyJ0dWljX3BvcnQiXSkKICAgIHJldHVybiBwb3J0
cwoKCmRlZiBmaXJld2FsbF9iYWNrZW5kKCkgLT4gc3RyOgogICAgaWYgY29tbWFuZF9leGlzdHMo
InVmdyIpOgogICAgICAgIHJlc3VsdCA9IHJ1bihbInVmdyIsICJzdGF0dXMiXSwgY2hlY2s9RmFs
c2UsIGNhcHR1cmU9VHJ1ZSkKICAgICAgICBpZiByZS5zZWFyY2gociJeU3RhdHVzOlxzK2FjdGl2
ZSIsIHJlc3VsdC5zdGRvdXQsIHJlLk1VTFRJTElORSB8IHJlLklHTk9SRUNBU0UpOgogICAgICAg
ICAgICByZXR1cm4gInVmdyIKICAgIGlmIGNvbW1hbmRfZXhpc3RzKCJmaXJld2FsbC1jbWQiKToK
ICAgICAgICByZXN1bHQgPSBydW4oWyJmaXJld2FsbC1jbWQiLCAiLS1zdGF0ZSJdLCBjaGVjaz1G
YWxzZSwgY2FwdHVyZT1UcnVlKQogICAgICAgIGlmIHJlc3VsdC5yZXR1cm5jb2RlID09IDA6CiAg
ICAgICAgICAgIHJldHVybiAiZmlyZXdhbGxkIgogICAgcmV0dXJuICJpcHRhYmxlcyIKCgpkZWYg
ZmlyZXdhbGxfb3Blbihwb3J0OiBpbnQpIC0+IE5vbmU6CiAgICBpZiBEUllfUlVOOgogICAgICAg
IHJldHVybgogICAgYmFja2VuZCA9IGZpcmV3YWxsX2JhY2tlbmQoKQogICAgaWYgYmFja2VuZCA9
PSAidWZ3IjoKICAgICAgICBydW4oWyJ1ZnciLCAiYWxsb3ciLCBmIntwb3J0fS91ZHAiLCAiY29t
bWVudCIsIGYiU2luZy1ib3ggbXVsdGktdXNlciB7cG9ydH0iXSwgY2hlY2s9RmFsc2UpCiAgICBl
bGlmIGJhY2tlbmQgPT0gImZpcmV3YWxsZCI6CiAgICAgICAgcnVuKFsiZmlyZXdhbGwtY21kIiwg
Ii0tem9uZT1wdWJsaWMiLCBmIi0tYWRkLXBvcnQ9e3BvcnR9L3VkcCIsICItLXBlcm1hbmVudCJd
LCBjaGVjaz1GYWxzZSkKICAgICAgICBydW4oWyJmaXJld2FsbC1jbWQiLCAiLS1yZWxvYWQiXSwg
Y2hlY2s9RmFsc2UpCiAgICBlbHNlOgogICAgICAgIGZvciB0b29sIGluICgiaXB0YWJsZXMiLCAi
aXA2dGFibGVzIik6CiAgICAgICAgICAgIGlmIG5vdCBjb21tYW5kX2V4aXN0cyh0b29sKToKICAg
ICAgICAgICAgICAgIGNvbnRpbnVlCiAgICAgICAgICAgIGNvbW1lbnQgPSBmIlNpbmctYm94IG11
bHRpLXVzZXIge3BvcnR9IgogICAgICAgICAgICBydWxlID0gWyJJTlBVVCIsICItcCIsICJ1ZHAi
LCAiLS1kcG9ydCIsIHN0cihwb3J0KSwgIi1tIiwgImNvbW1lbnQiLCAiLS1jb21tZW50IiwgY29t
bWVudCwgIi1qIiwgIkFDQ0VQVCJdCiAgICAgICAgICAgIGlmIHJ1bihbdG9vbCwgIi1DIiwgKnJ1
bGVdLCBjaGVjaz1GYWxzZSkucmV0dXJuY29kZSAhPSAwOgogICAgICAgICAgICAgICAgcnVuKFt0
b29sLCAiLUEiLCAqcnVsZV0sIGNoZWNrPUZhbHNlKQoKCmRlZiBmaXJld2FsbF9jbG9zZShwb3J0
OiBpbnQpIC0+IE5vbmU6CiAgICBpZiBEUllfUlVOOgogICAgICAgIHJldHVybgogICAgYmFja2Vu
ZCA9IGZpcmV3YWxsX2JhY2tlbmQoKQogICAgaWYgYmFja2VuZCA9PSAidWZ3IjoKICAgICAgICBy
dW4oWyJ1ZnciLCAiLS1mb3JjZSIsICJkZWxldGUiLCAiYWxsb3ciLCBmIntwb3J0fS91ZHAiXSwg
Y2hlY2s9RmFsc2UpCiAgICBlbGlmIGJhY2tlbmQgPT0gImZpcmV3YWxsZCI6CiAgICAgICAgcnVu
KFsiZmlyZXdhbGwtY21kIiwgIi0tem9uZT1wdWJsaWMiLCBmIi0tcmVtb3ZlLXBvcnQ9e3BvcnR9
L3VkcCIsICItLXBlcm1hbmVudCJdLCBjaGVjaz1GYWxzZSkKICAgICAgICBydW4oWyJmaXJld2Fs
bC1jbWQiLCAiLS1yZWxvYWQiXSwgY2hlY2s9RmFsc2UpCiAgICBlbHNlOgogICAgICAgIGZvciB0
b29sIGluICgiaXB0YWJsZXMiLCAiaXA2dGFibGVzIik6CiAgICAgICAgICAgIGlmIG5vdCBjb21t
YW5kX2V4aXN0cyh0b29sKToKICAgICAgICAgICAgICAgIGNvbnRpbnVlCiAgICAgICAgICAgIGNv
bW1lbnQgPSBmIlNpbmctYm94IG11bHRpLXVzZXIge3BvcnR9IgogICAgICAgICAgICBydWxlID0g
WyJJTlBVVCIsICItcCIsICJ1ZHAiLCAiLS1kcG9ydCIsIHN0cihwb3J0KSwgIi1tIiwgImNvbW1l
bnQiLCAiLS1jb21tZW50IiwgY29tbWVudCwgIi1qIiwgIkFDQ0VQVCJdCiAgICAgICAgICAgIHdo
aWxlIHJ1bihbdG9vbCwgIi1DIiwgKnJ1bGVdLCBjaGVjaz1GYWxzZSkucmV0dXJuY29kZSA9PSAw
OgogICAgICAgICAgICAgICAgcnVuKFt0b29sLCAiLUQiLCAqcnVsZV0sIGNoZWNrPUZhbHNlKQoK
CmRlZiBlbnN1cmVfY2hhaW4odG9vbDogc3RyLCBjaGFpbjogc3RyLCBob29rOiBzdHIpIC0+IE5v
bmU6CiAgICBpZiBub3QgY29tbWFuZF9leGlzdHModG9vbCk6CiAgICAgICAgcmV0dXJuCiAgICBp
ZiBydW4oW3Rvb2wsICItbkwiLCBjaGFpbl0sIGNoZWNrPUZhbHNlKS5yZXR1cm5jb2RlICE9IDA6
CiAgICAgICAgcnVuKFt0b29sLCAiLU4iLCBjaGFpbl0pCiAgICBpZiBydW4oW3Rvb2wsICItQyIs
IGhvb2ssICItaiIsIGNoYWluXSwgY2hlY2s9RmFsc2UpLnJldHVybmNvZGUgIT0gMDoKICAgICAg
ICBydW4oW3Rvb2wsICItSSIsIGhvb2ssICIxIiwgIi1qIiwgY2hhaW5dKQogICAgcnVuKFt0b29s
LCAiLUYiLCBjaGFpbl0pCgoKZGVmIHN5bmNfY291bnRlcl9ydWxlcyhjb25uOiBzcWxpdGUzLkNv
bm5lY3Rpb24pIC0+IE5vbmU6CiAgICB1c2VycyA9IGFjdGl2ZV91c2Vycyhjb25uKQogICAgZm9y
IHRvb2wgaW4gKCJpcHRhYmxlcyIsICJpcDZ0YWJsZXMiKToKICAgICAgICBpZiBub3QgY29tbWFu
ZF9leGlzdHModG9vbCk6CiAgICAgICAgICAgIGNvbnRpbnVlCiAgICAgICAgZW5zdXJlX2NoYWlu
KHRvb2wsIENPVU5URVJfSU4sICJJTlBVVCIpCiAgICAgICAgZW5zdXJlX2NoYWluKHRvb2wsIENP
VU5URVJfT1VULCAiT1VUUFVUIikKICAgICAgICBmb3Igcm93IGluIHVzZXJzOgogICAgICAgICAg
ICBmb3IgcG9ydCBpbiB1c2VyX3BvcnRzKHJvdyk6CiAgICAgICAgICAgICAgICBydW4oWwogICAg
ICAgICAgICAgICAgICAgIHRvb2wsICItQSIsIENPVU5URVJfSU4sICItcCIsICJ1ZHAiLCAiLS1k
cG9ydCIsIHN0cihwb3J0KSwKICAgICAgICAgICAgICAgICAgICAiLW0iLCAiY29tbWVudCIsICIt
LWNvbW1lbnQiLCBmIntDT1VOVEVSX1BSRUZJWH06e3Jvd1snaWQnXX06dXAiLCAiLWoiLCAiUkVU
VVJOIiwKICAgICAgICAgICAgICAgIF0pCiAgICAgICAgICAgICAgICBydW4oWwogICAgICAgICAg
ICAgICAgICAgIHRvb2wsICItQSIsIENPVU5URVJfT1VULCAiLXAiLCAidWRwIiwgIi0tc3BvcnQi
LCBzdHIocG9ydCksCiAgICAgICAgICAgICAgICAgICAgIi1tIiwgImNvbW1lbnQiLCAiLS1jb21t
ZW50IiwgZiJ7Q09VTlRFUl9QUkVGSVh9Ontyb3dbJ2lkJ119OmRvd24iLCAiLWoiLCAiUkVUVVJO
IiwKICAgICAgICAgICAgICAgIF0pCiAgICBjb25uLmV4ZWN1dGUoIlVQREFURSB1c2VycyBTRVQg
bGFzdF91cGxvYWRfY291bnRlcj0wLCBsYXN0X2Rvd25sb2FkX2NvdW50ZXI9MCBXSEVSRSBlbmFi
bGVkPTEiKQogICAgY29ubi5jb21taXQoKQoKCmRlZiByZW1vdmVfY291bnRlcl9ydWxlcygpIC0+
IE5vbmU6CiAgICBmb3IgdG9vbCBpbiAoImlwdGFibGVzIiwgImlwNnRhYmxlcyIpOgogICAgICAg
IGlmIG5vdCBjb21tYW5kX2V4aXN0cyh0b29sKToKICAgICAgICAgICAgY29udGludWUKICAgICAg
ICBmb3IgaG9vaywgY2hhaW4gaW4gKCgiSU5QVVQiLCBDT1VOVEVSX0lOKSwgKCJPVVRQVVQiLCBD
T1VOVEVSX09VVCkpOgogICAgICAgICAgICB3aGlsZSBydW4oW3Rvb2wsICItQyIsIGhvb2ssICIt
aiIsIGNoYWluXSwgY2hlY2s9RmFsc2UpLnJldHVybmNvZGUgPT0gMDoKICAgICAgICAgICAgICAg
IHJ1bihbdG9vbCwgIi1EIiwgaG9vaywgIi1qIiwgY2hhaW5dLCBjaGVjaz1GYWxzZSkKICAgICAg
ICAgICAgcnVuKFt0b29sLCAiLUYiLCBjaGFpbl0sIGNoZWNrPUZhbHNlKQogICAgICAgICAgICBy
dW4oW3Rvb2wsICItWCIsIGNoYWluXSwgY2hlY2s9RmFsc2UpCgoKZGVmIHJlYWRfY291bnRlcnMo
KSAtPiB0dXBsZVtkaWN0W2ludCwgZGljdFtzdHIsIGludF1dLCBzZXRbdHVwbGVbaW50LCBzdHJd
XV06CiAgICB0b3RhbHM6IGRpY3RbaW50LCBkaWN0W3N0ciwgaW50XV0gPSB7fQogICAgc2Vlbjog
c2V0W3R1cGxlW2ludCwgc3RyXV0gPSBzZXQoKQogICAgcGF0dGVybiA9IHJlLmNvbXBpbGUociJe
XFtbMC05XSs6KFswLTldKylcXS4qLS1jb21tZW50XHMrXCI/U0JVOihbMC05XSspOih1cHxkb3du
KVwiPyIpCiAgICBmb3IgdG9vbCBpbiAoImlwdGFibGVzLXNhdmUiLCAiaXA2dGFibGVzLXNhdmUi
KToKICAgICAgICBpZiBub3QgY29tbWFuZF9leGlzdHModG9vbCk6CiAgICAgICAgICAgIGNvbnRp
bnVlCiAgICAgICAgcmVzdWx0ID0gcnVuKFt0b29sLCAiLWMiLCAiLXQiLCAiZmlsdGVyIl0sIGNo
ZWNrPUZhbHNlLCBjYXB0dXJlPVRydWUpCiAgICAgICAgZm9yIGxpbmUgaW4gcmVzdWx0LnN0ZG91
dC5zcGxpdGxpbmVzKCk6CiAgICAgICAgICAgIG1hdGNoID0gcGF0dGVybi5zZWFyY2gobGluZSkK
ICAgICAgICAgICAgaWYgbm90IG1hdGNoOgogICAgICAgICAgICAgICAgY29udGludWUKICAgICAg
ICAgICAgY291bnQsIHVzZXJfaWQsIGRpcmVjdGlvbiA9IGludChtYXRjaC5ncm91cCgxKSksIGlu
dChtYXRjaC5ncm91cCgyKSksIG1hdGNoLmdyb3VwKDMpCiAgICAgICAgICAgIHRvdGFscy5zZXRk
ZWZhdWx0KHVzZXJfaWQsIHsidXAiOiAwLCAiZG93biI6IDB9KVtkaXJlY3Rpb25dICs9IGNvdW50
CiAgICAgICAgICAgIHNlZW4uYWRkKCh1c2VyX2lkLCBkaXJlY3Rpb24pKQogICAgcmV0dXJuIHRv
dGFscywgc2VlbgoKCmRlZiByb2xsb3Zlcl9tb250aGx5X3VzYWdlKGNvbm46IHNxbGl0ZTMuQ29u
bmVjdGlvbikgLT4gYm9vbDoKICAgICIiIlJlc2V0IG1vbnRobHkgdXNhZ2Ugb25jZSB3aGVuIHRo
ZSBVVEMgY2FsZW5kYXIgbW9udGggY2hhbmdlcy4iIiIKICAgIGN1cnJlbnQgPSBjdXJyZW50X3Ry
YWZmaWNfbW9udGgoKQogICAgcm93ID0gY29ubi5leGVjdXRlKCJTRUxFQ1QgdmFsdWUgRlJPTSBt
ZXRhIFdIRVJFIGtleT0/IiwgKFRSQUZGSUNfTU9OVEhfTUVUQV9LRVksKSkuZmV0Y2hvbmUoKQog
ICAgcHJldmlvdXMgPSByb3dbInZhbHVlIl0gaWYgcm93IGlzIG5vdCBOb25lIGVsc2UgY3VycmVu
dAogICAgaWYgcHJldmlvdXMgPT0gY3VycmVudDoKICAgICAgICByZXR1cm4gRmFsc2UKICAgIGNv
bm4uZXhlY3V0ZSgKICAgICAgICAiIiJVUERBVEUgdXNlcnMgU0VUIHVwbG9hZF9ieXRlcz0wLGRv
d25sb2FkX2J5dGVzPTAsCiAgICAgICAgICAgbGFzdF91cGxvYWRfY291bnRlcj0wLGxhc3RfZG93
bmxvYWRfY291bnRlcj0wLHVwZGF0ZWRfYXQ9PyIiIiwKICAgICAgICAobm93X2lzbygpLCksCiAg
ICApCiAgICBjb25uLmV4ZWN1dGUoCiAgICAgICAgIklOU0VSVCBJTlRPIG1ldGEoa2V5LHZhbHVl
KSBWQUxVRVMgKD8sPykgIgogICAgICAgICJPTiBDT05GTElDVChrZXkpIERPIFVQREFURSBTRVQg
dmFsdWU9ZXhjbHVkZWQudmFsdWUiLAogICAgICAgIChUUkFGRklDX01PTlRIX01FVEFfS0VZLCBj
dXJyZW50KSwKICAgICkKICAgIGNvbm4uY29tbWl0KCkKICAgIHN5bmNfY291bnRlcl9ydWxlcyhj
b25uKQogICAgcmV0dXJuIFRydWUKCgpkZWYgY29sbGVjdF91c2FnZShjb25uOiBzcWxpdGUzLkNv
bm5lY3Rpb24sICosIHJlbmRlcjogYm9vbCA9IFRydWUpIC0+IE5vbmU6CiAgICByb2xsb3Zlcl9t
b250aGx5X3VzYWdlKGNvbm4pCiAgICBjb3VudGVycywgc2VlbiA9IHJlYWRfY291bnRlcnMoKQog
ICAgdXNlcnMgPSBhY3RpdmVfdXNlcnMoY29ubikKICAgIGZvciByb3cgaW4gdXNlcnM6CiAgICAg
ICAgY3VycmVudCA9IGNvdW50ZXJzLmdldChyb3dbImlkIl0sIHsidXAiOiAwLCAiZG93biI6IDB9
KQogICAgICAgIG9sZF91cCA9IHJvd1sibGFzdF91cGxvYWRfY291bnRlciJdCiAgICAgICAgb2xk
X2Rvd24gPSByb3dbImxhc3RfZG93bmxvYWRfY291bnRlciJdCiAgICAgICAgZGVsdGFfdXAgPSBj
dXJyZW50WyJ1cCJdIC0gb2xkX3VwIGlmIGN1cnJlbnRbInVwIl0gPj0gb2xkX3VwIGVsc2UgY3Vy
cmVudFsidXAiXQogICAgICAgIGRlbHRhX2Rvd24gPSBjdXJyZW50WyJkb3duIl0gLSBvbGRfZG93
biBpZiBjdXJyZW50WyJkb3duIl0gPj0gb2xkX2Rvd24gZWxzZSBjdXJyZW50WyJkb3duIl0KICAg
ICAgICBjb25uLmV4ZWN1dGUoCiAgICAgICAgICAgICIiIlVQREFURSB1c2VycyBTRVQgdXBsb2Fk
X2J5dGVzPXVwbG9hZF9ieXRlcys/LCBkb3dubG9hZF9ieXRlcz1kb3dubG9hZF9ieXRlcys/LAog
ICAgICAgICAgICAgICBsYXN0X3VwbG9hZF9jb3VudGVyPT8sIGxhc3RfZG93bmxvYWRfY291bnRl
cj0/LCB1cGRhdGVkX2F0PT8gV0hFUkUgaWQ9PyIiIiwKICAgICAgICAgICAgKGRlbHRhX3VwLCBk
ZWx0YV9kb3duLCBjdXJyZW50WyJ1cCJdLCBjdXJyZW50WyJkb3duIl0sIG5vd19pc28oKSwgcm93
WyJpZCJdKSwKICAgICAgICApCiAgICBjb25uLmNvbW1pdCgpCiAgICBleHBlY3RlZCA9IHsocm93
WyJpZCJdLCBkaXJlY3Rpb24pIGZvciByb3cgaW4gdXNlcnMgZm9yIGRpcmVjdGlvbiBpbiAoInVw
IiwgImRvd24iKX0KICAgIGlmIG5vdCBleHBlY3RlZC5pc3N1YnNldChzZWVuKToKICAgICAgICBm
b3Igcm93IGluIHVzZXJzOgogICAgICAgICAgICBmb3IgcG9ydCBpbiB1c2VyX3BvcnRzKHJvdyk6
CiAgICAgICAgICAgICAgICBmaXJld2FsbF9vcGVuKHBvcnQpCiAgICAgICAgc3luY19jb3VudGVy
X3J1bGVzKGNvbm4pCiAgICBpZiByZW5kZXIgYW5kIGFsbF91c2Vycyhjb25uKToKICAgICAgICBy
ZW5kZXJfc3Vic2NyaXB0aW9ucyhjb25uKQoKCmRlZiB2YWxpZGF0ZV9hbmRfcmVsb2FkKCkgLT4g
Tm9uZToKICAgIGlmIERSWV9SVU46CiAgICAgICAgcmV0dXJuCiAgICByZXN1bHQgPSBydW4oW3N0
cihTSU5HX0JPWCksICJjaGVjayIsICItQyIsIHN0cihDT05GX0RJUildLCBjaGVjaz1GYWxzZSwg
Y2FwdHVyZT1UcnVlKQogICAgaWYgcmVzdWx0LnJldHVybmNvZGUgIT0gMDoKICAgICAgICByYWlz
ZSBNYW5hZ2VyRXJyb3IoZiJzaW5nLWJveCDphY3nva7mo4Dmn6XlpLHotKXvvJpcbntyZXN1bHQu
c3RkZXJyLnN0cmlwKCl9IikKICAgIGlmIGNvbW1hbmRfZXhpc3RzKCJzeXN0ZW1jdGwiKToKICAg
ICAgICByZXN1bHQgPSBydW4oWyJzeXN0ZW1jdGwiLCAicmVsb2FkIiwgInNpbmctYm94Il0sIGNo
ZWNrPUZhbHNlKQogICAgICAgIGlmIHJlc3VsdC5yZXR1cm5jb2RlICE9IDA6CiAgICAgICAgICAg
IHJ1bihbInN5c3RlbWN0bCIsICJyZXN0YXJ0IiwgInNpbmctYm94Il0pCiAgICBlbHNlOgogICAg
ICAgIHJlc3VsdCA9IHJ1bihbInJjLXNlcnZpY2UiLCAic2luZy1ib3giLCAicmVsb2FkIl0sIGNo
ZWNrPUZhbHNlKQogICAgICAgIGlmIHJlc3VsdC5yZXR1cm5jb2RlICE9IDA6CiAgICAgICAgICAg
IHJ1bihbInJjLXNlcnZpY2UiLCAic2luZy1ib3giLCAicmVzdGFydCJdKQoKCmRlZiBhcHBseV9y
dW50aW1lKGNvbm46IHNxbGl0ZTMuQ29ubmVjdGlvbiwgcmVtb3ZlZF9wb3J0czogbGlzdFtpbnRd
IHwgTm9uZSA9IE5vbmUpIC0+IE5vbmU6CiAgICBlbnN1cmVfdHVpY19wb3J0cyhjb25uKQogICAg
cmVuZGVyX2luYm91bmRzKGNvbm4pCiAgICByZW5kZXJfc3Vic2NyaXB0aW9ucyhjb25uKQogICAg
dmFsaWRhdGVfYW5kX3JlbG9hZCgpCiAgICBmb3IgcG9ydCBpbiByZW1vdmVkX3BvcnRzIG9yIFtd
OgogICAgICAgIGZpcmV3YWxsX2Nsb3NlKHBvcnQpCiAgICBmb3Igcm93IGluIGFjdGl2ZV91c2Vy
cyhjb25uKToKICAgICAgICBmb3IgcG9ydCBpbiB1c2VyX3BvcnRzKHJvdyk6CiAgICAgICAgICAg
IGZpcmV3YWxsX29wZW4ocG9ydCkKICAgIHN5bmNfY291bnRlcl9ydWxlcyhjb25uKQoKCmRlZiBn
ZXRfdXNlcihjb25uOiBzcWxpdGUzLkNvbm5lY3Rpb24sIHVzZXJuYW1lOiBzdHIpIC0+IHNxbGl0
ZTMuUm93OgogICAgcm93ID0gY29ubi5leGVjdXRlKCJTRUxFQ1QgKiBGUk9NIHVzZXJzIFdIRVJF
IHVzZXJuYW1lPT8iLCAodXNlcm5hbWUsKSkuZmV0Y2hvbmUoKQogICAgaWYgcm93IGlzIE5vbmU6
CiAgICAgICAgcmFpc2UgTWFuYWdlckVycm9yKGYi55So5oi35LiN5a2Y5Zyo77yae3VzZXJuYW1l
fSIpCiAgICByZXR1cm4gcm93CgoKZGVmIHVzZXJfbGluayhyb3c6IHNxbGl0ZTMuUm93KSAtPiBz
dHI6CiAgICByZXR1cm4gZiJ7c3Vic2NyaXB0aW9uX2Jhc2VfdXJsKCl9L3VzZXIve3Jvd1sndG9r
ZW4nXX0vY2xhc2gtY2FtcHVzLWZyZWUiCgoKZGVmIGFkbWluX3BhZ2VfbGluayhyb3c6IHNxbGl0
ZTMuUm93KSAtPiBzdHI6CiAgICByZXR1cm4gZiJ7c3Vic2NyaXB0aW9uX2Jhc2VfdXJsKCl9L3Vz
ZXIve3Jvd1sndG9rZW4nXX0vcGFnZSIKCgpkZWYgY21kX2luaXQoY29ubjogc3FsaXRlMy5Db25u
ZWN0aW9uLCBfYXJnczogYXJncGFyc2UuTmFtZXNwYWNlKSAtPiBOb25lOgogICAgZmluZF9iYXNl
X2h5Ml9jb25maWcoKQogICAgYmFzZV9wcm94eV9saW5lcygpCiAgICBzdWJzY3JpcHRpb25fYmFz
ZV91cmwoKQogICAgZW5zdXJlX3R1aWNfcG9ydHMoY29ubikKICAgIGxvY2tfYmFzZV9oeTJfaW5i
b3VuZCgpCiAgICBsb2NrX2Jhc2VfdHVpY19pbmJvdW5kKCkKICAgIGlmIG5vdCBEUllfUlVOIGFu
ZCBub3QgY29tbWFuZF9leGlzdHMoImlwdGFibGVzLXNhdmUiKToKICAgICAgICByYWlzZSBNYW5h
Z2VyRXJyb3IoIuacquaJvuWIsCBpcHRhYmxlcy1zYXZl77yM5peg5rOV6L+b6KGM5oyJ55So5oi3
5rWB6YeP57uf6K6h44CCIikKICAgIFVTRVJTX0RJUi5ta2RpcihwYXJlbnRzPVRydWUsIGV4aXN0
X29rPVRydWUpCiAgICBvcy5jaG1vZChVU0VSU19ESVIsIDBvNzAwKQogICAgaWYgYWxsX3VzZXJz
KGNvbm4pOgogICAgICAgIHJlbmRlcl9pbmJvdW5kcyhjb25uKQogICAgICAgIHJlbmRlcl9zdWJz
Y3JpcHRpb25zKGNvbm4pCiAgICBmb3Igcm93IGluIGFjdGl2ZV91c2Vycyhjb25uKToKICAgICAg
ICBmb3IgcG9ydCBpbiB1c2VyX3BvcnRzKHJvdyk6CiAgICAgICAgICAgIGZpcmV3YWxsX29wZW4o
cG9ydCkKICAgIHN5bmNfY291bnRlcl9ydWxlcyhjb25uKQogICAgdmFsaWRhdGVfYW5kX3JlbG9h
ZCgpCiAgICBwcmludChmIuWkmueUqOaIt+aVsOaNruW6k+W3suWwsee7qu+8mntEQl9QQVRIfSIp
CgoKZGVmIGNtZF9hZGQoY29ubjogc3FsaXRlMy5Db25uZWN0aW9uLCBhcmdzOiBhcmdwYXJzZS5O
YW1lc3BhY2UpIC0+IE5vbmU6CiAgICBpZiBub3QgVVNFUk5BTUVfUkUuZnVsbG1hdGNoKGFyZ3Mu
dXNlcm5hbWUpOgogICAgICAgIHJhaXNlIE1hbmFnZXJFcnJvcigi55So5oi35ZCN5Y+q6IO95YyF
5ZCr5a2X5q+N44CB5pWw5a2X44CB5LiL5YiS57q/5ZKM6L+e5a2X56ym77yM6ZW/5bqmIDEtMzLj
gIIiKQogICAgY29sbGVjdF91c2FnZShjb25uKQogICAgaXNfYWRtaW4gPSAxIGlmIGNvbm4uZXhl
Y3V0ZSgiU0VMRUNUIENPVU5UKCopIEZST00gdXNlcnMiKS5mZXRjaG9uZSgpWzBdID09IDAgZWxz
ZSAwCiAgICBzdGFtcCA9IG5vd19pc28oKQogICAgdHJ5OgogICAgICAgIGNvbm4uZXhlY3V0ZSgK
ICAgICAgICAgICAgIiIiSU5TRVJUIElOVE8gdXNlcnMKICAgICAgICAgICAgICAgKHVzZXJuYW1l
LGlzX2FkbWluLHRva2VuLHBhc3N3b3JkLHBvcnQscXVvdGFfYnl0ZXMsY3JlYXRlZF9hdCx1cGRh
dGVkX2F0KQogICAgICAgICAgICAgICBWQUxVRVMgKD8sPyw/LD8sPyw/LD8sPykiIiIsCiAgICAg
ICAgICAgICgKICAgICAgICAgICAgICAgIGFyZ3MudXNlcm5hbWUsCiAgICAgICAgICAgICAgICBp
c19hZG1pbiwKICAgICAgICAgICAgICAgIHNlY3JldHMudG9rZW5faGV4KDMyKSwKICAgICAgICAg
ICAgICAgIHNlY3JldHMudG9rZW5faGV4KDMyKSwKICAgICAgICAgICAgICAgIGFsbG9jYXRlX3Bv
cnQoY29ubiksCiAgICAgICAgICAgICAgICBwYXJzZV9xdW90YV9nYihhcmdzLnF1b3RhX2diKSwK
ICAgICAgICAgICAgICAgIHN0YW1wLAogICAgICAgICAgICAgICAgc3RhbXAsCiAgICAgICAgICAg
ICksCiAgICAgICAgKQogICAgICAgIGNvbm4uY29tbWl0KCkKICAgIGV4Y2VwdCBzcWxpdGUzLklu
dGVncml0eUVycm9yIGFzIGV4YzoKICAgICAgICByYWlzZSBNYW5hZ2VyRXJyb3IoZiLnlKjmiLfl
t7LlrZjlnKjmiJbpmo/mnLrlh63mja7lj5HnlJ/lhrLnqoHvvJp7YXJncy51c2VybmFtZX0iKSBm
cm9tIGV4YwogICAgYXBwbHlfcnVudGltZShjb25uKQogICAgcm93ID0gZ2V0X3VzZXIoY29ubiwg
YXJncy51c2VybmFtZSkKICAgIHByaW50KGYi55So5oi377yae3Jvd1sndXNlcm5hbWUnXX0gKHsn
566h55CG5ZGYJyBpZiByb3dbJ2lzX2FkbWluJ10gZWxzZSAn5pmu6YCa55So5oi3J30pIikKICAg
IHByaW50KGYiSHlzdGVyaWEyIOerr+WPo++8mntyb3dbJ3BvcnQnXX0vdWRwIikKICAgIGlmIHJv
d1sidHVpY19wb3J0Il06CiAgICAgICAgcHJpbnQoZiJUVUlDIOerr+WPo++8mntyb3dbJ3R1aWNf
cG9ydCddfS91ZHAiKQogICAgICAgIHByaW50KGYiVFVJQyBVVUlE77yae3R1aWNfdXVpZChyb3cp
fSIpCiAgICBwcmludChmIuWNj+iuruWvhuegge+8mntyb3dbJ3Bhc3N3b3JkJ119IikKICAgIHBy
aW50KGYi6aKd5bqm77yaeyfkuI3pmZDph48nIGlmIHJvd1sncXVvdGFfYnl0ZXMnXSA9PSAwIGVs
c2UgZm10X2diKHJvd1sncXVvdGFfYnl0ZXMnXSl9IikKICAgIHByaW50KGYi6K6i6ZiF77yae3Vz
ZXJfbGluayhyb3cpfSIpCiAgICBpZiByb3dbImlzX2FkbWluIl06CiAgICAgICAgcHJpbnQoZiLn
rqHnkIbnvZHpobXvvJp7YWRtaW5fcGFnZV9saW5rKHJvdyl9IikKCgpkZWYgcHJpbnRfdXNlcihy
b3c6IHNxbGl0ZTMuUm93LCAqLCBpbmNsdWRlX3NlY3JldDogYm9vbCA9IEZhbHNlKSAtPiBOb25l
OgogICAgdXNlZCA9IHJvd1sidXBsb2FkX2J5dGVzIl0gKyByb3dbImRvd25sb2FkX2J5dGVzIl0K
ICAgIHF1b3RhID0gIuS4jemZkOmHjyIgaWYgcm93WyJxdW90YV9ieXRlcyJdID09IDAgZWxzZSBm
bXRfZ2Iocm93WyJxdW90YV9ieXRlcyJdKQogICAgcmVtYWluaW5nID0gIuS4jemZkOmHjyIgaWYg
cm93WyJxdW90YV9ieXRlcyJdID09IDAgZWxzZSBmbXRfZ2IobWF4KHJvd1sicXVvdGFfYnl0ZXMi
XSAtIHVzZWQsIDApKQogICAgc3RhdGUgPSAi5ZCv55SoIgogICAgaWYgbm90IHJvd1siZW5hYmxl
ZCJdOgogICAgICAgIHN0YXRlID0gIuWBnOeUqCIKICAgIGVsaWYgcm93WyJxdW90YV9ieXRlcyJd
IGFuZCB1c2VkID49IHJvd1sicXVvdGFfYnl0ZXMiXToKICAgICAgICBzdGF0ZSA9ICLlt7LotoXp
op3vvIjku4Xmj5DnpLrvvIkiCiAgICBwcm90b2NvbF9wb3J0cyA9IGYiSHlzdGVyaWEyIHtyb3db
J3BvcnQnXX0iCiAgICBpZiByb3dbInR1aWNfcG9ydCJdIGFuZCBmaW5kX2Jhc2VfdHVpY19jb25m
aWcoKSBpcyBub3QgTm9uZToKICAgICAgICBwcm90b2NvbF9wb3J0cyArPSBmIiAvIFRVSUMge3Jv
d1sndHVpY19wb3J0J119IgogICAgcHJpbnQoCiAgICAgICAgZiJ7cm93WydpZCddOj4zfSAge3Jv
d1sndXNlcm5hbWUnXTo8MTZ9ICB7J+euoeeQhuWRmCcgaWYgcm93Wydpc19hZG1pbiddIGVsc2Ug
J+eUqOaItyc6PDR9ICAiCiAgICAgICAgZiJ7c3RhdGU6PDEyfSAg56uv5Y+jIHtwcm90b2NvbF9w
b3J0c30gIOS4iuS8oCB7Zm10X2diKHJvd1sndXBsb2FkX2J5dGVzJ10pfSAgIgogICAgICAgIGYi
5LiL6L29IHtmbXRfZ2Iocm93Wydkb3dubG9hZF9ieXRlcyddKX0gIOW3sueUqCB7Zm10X2diKHVz
ZWQpfSAg5Y+v55SoIHtyZW1haW5pbmd9ICDpmZDpop0ge3F1b3RhfSIKICAgICkKICAgIGlmIGlu
Y2x1ZGVfc2VjcmV0OgogICAgICAgIHByaW50KGYiICAgICDljY/orq7lr4bnoIHvvJp7cm93Wydw
YXNzd29yZCddfSIpCiAgICAgICAgaWYgcm93WyJ0dWljX3BvcnQiXSBhbmQgZmluZF9iYXNlX3R1
aWNfY29uZmlnKCkgaXMgbm90IE5vbmU6CiAgICAgICAgICAgIHByaW50KGYiICAgICBUVUlDIFVV
SUTvvJp7dHVpY191dWlkKHJvdyl9IikKICAgICAgICBwcmludChmIiAgICAg6K6i6ZiF77yae3Vz
ZXJfbGluayhyb3cpfSIpCiAgICAgICAgaWYgcm93WyJpc19hZG1pbiJdOgogICAgICAgICAgICBw
cmludChmIiAgICAg566h55CG572R6aG177yae2FkbWluX3BhZ2VfbGluayhyb3cpfSIpCgoKZGVm
IGNtZF9saXN0KGNvbm46IHNxbGl0ZTMuQ29ubmVjdGlvbiwgX2FyZ3M6IGFyZ3BhcnNlLk5hbWVz
cGFjZSkgLT4gTm9uZToKICAgIGNvbGxlY3RfdXNhZ2UoY29ubikKICAgIHJvd3MgPSBhbGxfdXNl
cnMoY29ubikKICAgIGlmIG5vdCByb3dzOgogICAgICAgIHByaW50KCLov5jmsqHmnInnlKjmiLfj
gILnrKzkuIDkuKrliJvlu7rnmoTnlKjmiLflsIbmiJDkuLrnrqHnkIblkZjjgIIiKQogICAgICAg
IHJldHVybgogICAgZm9yIHJvdyBpbiByb3dzOgogICAgICAgIHByaW50X3VzZXIocm93KQogICAg
dG90YWxfdXAgPSBzdW0ocm93WyJ1cGxvYWRfYnl0ZXMiXSBmb3Igcm93IGluIHJvd3MpCiAgICB0
b3RhbF9kb3duID0gc3VtKHJvd1siZG93bmxvYWRfYnl0ZXMiXSBmb3Igcm93IGluIHJvd3MpCiAg
ICBwcmludChmIuaAu+iuoe+8mueUqOaItyB7bGVuKHJvd3Mpfe+8jOS4iuS8oCB7Zm10X2diKHRv
dGFsX3VwKX3vvIzkuIvovb0ge2ZtdF9nYih0b3RhbF9kb3duKX3vvIzlt7LnlKgge2ZtdF9nYih0
b3RhbF91cCArIHRvdGFsX2Rvd24pfSIpCgoKZGVmIGNtZF9zaG93KGNvbm46IHNxbGl0ZTMuQ29u
bmVjdGlvbiwgYXJnczogYXJncGFyc2UuTmFtZXNwYWNlKSAtPiBOb25lOgogICAgY29sbGVjdF91
c2FnZShjb25uKQogICAgcHJpbnRfdXNlcihnZXRfdXNlcihjb25uLCBhcmdzLnVzZXJuYW1lKSwg
aW5jbHVkZV9zZWNyZXQ9VHJ1ZSkKCgpkZWYgY21kX3F1b3RhKGNvbm46IHNxbGl0ZTMuQ29ubmVj
dGlvbiwgYXJnczogYXJncGFyc2UuTmFtZXNwYWNlKSAtPiBOb25lOgogICAgY29sbGVjdF91c2Fn
ZShjb25uKQogICAgcm93ID0gZ2V0X3VzZXIoY29ubiwgYXJncy51c2VybmFtZSkKICAgIGNvbm4u
ZXhlY3V0ZSgiVVBEQVRFIHVzZXJzIFNFVCBxdW90YV9ieXRlcz0/LHVwZGF0ZWRfYXQ9PyBXSEVS
RSBpZD0/IiwgKHBhcnNlX3F1b3RhX2diKGFyZ3MucXVvdGFfZ2IpLCBub3dfaXNvKCksIHJvd1si
aWQiXSkpCiAgICBjb25uLmNvbW1pdCgpCiAgICByZW5kZXJfc3Vic2NyaXB0aW9ucyhjb25uKQog
ICAgcHJpbnRfdXNlcihnZXRfdXNlcihjb25uLCBhcmdzLnVzZXJuYW1lKSkKCgpkZWYgY21kX3Jl
c2V0KGNvbm46IHNxbGl0ZTMuQ29ubmVjdGlvbiwgYXJnczogYXJncGFyc2UuTmFtZXNwYWNlKSAt
PiBOb25lOgogICAgY29sbGVjdF91c2FnZShjb25uLCByZW5kZXI9RmFsc2UpCiAgICByb3cgPSBn
ZXRfdXNlcihjb25uLCBhcmdzLnVzZXJuYW1lKQogICAgY29ubi5leGVjdXRlKAogICAgICAgICIi
IlVQREFURSB1c2VycyBTRVQgdXBsb2FkX2J5dGVzPTAsZG93bmxvYWRfYnl0ZXM9MCwKICAgICAg
ICAgICBsYXN0X3VwbG9hZF9jb3VudGVyPTAsbGFzdF9kb3dubG9hZF9jb3VudGVyPTAsdXBkYXRl
ZF9hdD0/IFdIRVJFIGlkPT8iIiIsCiAgICAgICAgKG5vd19pc28oKSwgcm93WyJpZCJdKSwKICAg
ICkKICAgIGNvbm4uY29tbWl0KCkKICAgIHN5bmNfY291bnRlcl9ydWxlcyhjb25uKQogICAgcmVu
ZGVyX3N1YnNjcmlwdGlvbnMoY29ubikKICAgIHByaW50KGYi5bey5riF6Zu255So5oi3IHthcmdz
LnVzZXJuYW1lfSDnmoTkuIrkvKDlkozkuIvovb3ntK/orqHmtYHph4/jgIIiKQoKCmRlZiBjbWRf
dG9nZ2xlKGNvbm46IHNxbGl0ZTMuQ29ubmVjdGlvbiwgYXJnczogYXJncGFyc2UuTmFtZXNwYWNl
LCBlbmFibGVkOiBib29sKSAtPiBOb25lOgogICAgY29sbGVjdF91c2FnZShjb25uLCByZW5kZXI9
RmFsc2UpCiAgICByb3cgPSBnZXRfdXNlcihjb25uLCBhcmdzLnVzZXJuYW1lKQogICAgY29ubi5l
eGVjdXRlKCJVUERBVEUgdXNlcnMgU0VUIGVuYWJsZWQ9Pyx1cGRhdGVkX2F0PT8gV0hFUkUgaWQ9
PyIsICgxIGlmIGVuYWJsZWQgZWxzZSAwLCBub3dfaXNvKCksIHJvd1siaWQiXSkpCiAgICBjb25u
LmNvbW1pdCgpCiAgICBhcHBseV9ydW50aW1lKGNvbm4sIHJlbW92ZWRfcG9ydHM9Tm9uZSBpZiBl
bmFibGVkIGVsc2UgdXNlcl9wb3J0cyhyb3csIGluY2x1ZGVfc3RhbGVfdHVpYz1UcnVlKSkKICAg
IHByaW50KGYi55So5oi3IHthcmdzLnVzZXJuYW1lfSDlt7J7J+WQr+eUqCcgaWYgZW5hYmxlZCBl
bHNlICflgZznlKgnfeOAgiIpCgoKZGVmIGNtZF9kZWxldGUoY29ubjogc3FsaXRlMy5Db25uZWN0
aW9uLCBhcmdzOiBhcmdwYXJzZS5OYW1lc3BhY2UpIC0+IE5vbmU6CiAgICBpZiBub3QgYXJncy55
ZXM6CiAgICAgICAgcmFpc2UgTWFuYWdlckVycm9yKCLliKDpmaTnlKjmiLfkvJrkvb/lhbblh63m
ja7lkozorqLpmIXlpLHmlYjvvJvor7fov73liqAgLS15ZXMg56Gu6K6k44CCIikKICAgIGNvbGxl
Y3RfdXNhZ2UoY29ubiwgcmVuZGVyPUZhbHNlKQogICAgcm93ID0gZ2V0X3VzZXIoY29ubiwgYXJn
cy51c2VybmFtZSkKICAgIGlmIHJvd1siaXNfYWRtaW4iXToKICAgICAgICBzdWNjZXNzb3IgPSBj
b25uLmV4ZWN1dGUoIlNFTEVDVCBpZCBGUk9NIHVzZXJzIFdIRVJFIGlkPD4/IE9SREVSIEJZIGlk
IExJTUlUIDEiLCAocm93WyJpZCJdLCkpLmZldGNob25lKCkKICAgICAgICBpZiBzdWNjZXNzb3Ig
aXMgbm90IE5vbmU6CiAgICAgICAgICAgIGNvbm4uZXhlY3V0ZSgiVVBEQVRFIHVzZXJzIFNFVCBp
c19hZG1pbj0xLHVwZGF0ZWRfYXQ9PyBXSEVSRSBpZD0/IiwgKG5vd19pc28oKSwgc3VjY2Vzc29y
WyJpZCJdKSkKICAgIGNvbm4uZXhlY3V0ZSgiREVMRVRFIEZST00gdXNlcnMgV0hFUkUgaWQ9PyIs
IChyb3dbImlkIl0sKSkKICAgIGNvbm4uY29tbWl0KCkKICAgIGFwcGx5X3J1bnRpbWUoY29ubiwg
cmVtb3ZlZF9wb3J0cz11c2VyX3BvcnRzKHJvdywgaW5jbHVkZV9zdGFsZV90dWljPVRydWUpKQog
ICAgcHJpbnQoZiLnlKjmiLcge2FyZ3MudXNlcm5hbWV9IOW3suWIoOmZpOOAgiIpCgoKZGVmIGNt
ZF9yb3RhdGUoY29ubjogc3FsaXRlMy5Db25uZWN0aW9uLCBhcmdzOiBhcmdwYXJzZS5OYW1lc3Bh
Y2UsIGZpZWxkOiBzdHIpIC0+IE5vbmU6CiAgICBjb2xsZWN0X3VzYWdlKGNvbm4sIHJlbmRlcj1G
YWxzZSkKICAgIHJvdyA9IGdldF91c2VyKGNvbm4sIGFyZ3MudXNlcm5hbWUpCiAgICB2YWx1ZSA9
IHNlY3JldHMudG9rZW5faGV4KDMyKQogICAgY29ubi5leGVjdXRlKGYiVVBEQVRFIHVzZXJzIFNF
VCB7ZmllbGR9PT8sdXBkYXRlZF9hdD0/IFdIRVJFIGlkPT8iLCAodmFsdWUsIG5vd19pc28oKSwg
cm93WyJpZCJdKSkKICAgIGNvbm4uY29tbWl0KCkKICAgIGlmIGZpZWxkID09ICJwYXNzd29yZCI6
CiAgICAgICAgYXBwbHlfcnVudGltZShjb25uKQogICAgICAgIHByaW50KGYi55So5oi3IHthcmdz
LnVzZXJuYW1lfSDnmoQgSHlzdGVyaWEyL1RVSUMg5a+G56CB5bey6L2u5o2i77yM5pen6IqC54K5
56uL5Y2z5aSx5pWI44CCIikKICAgIGVsc2U6CiAgICAgICAgcmVuZGVyX3N1YnNjcmlwdGlvbnMo
Y29ubikKICAgICAgICBwcmludChmIueUqOaItyB7YXJncy51c2VybmFtZX0g55qE6K6i6ZiF5Luk
54mM5bey6L2u5o2i77yM5pen6K6i6ZiFIFVSTCDnq4vljbPlpLHmlYjjgIIiKQogICAgcHJpbnRf
dXNlcihnZXRfdXNlcihjb25uLCBhcmdzLnVzZXJuYW1lKSwgaW5jbHVkZV9zZWNyZXQ9VHJ1ZSkK
CgpkZWYgY21kX2NvbGxlY3QoY29ubjogc3FsaXRlMy5Db25uZWN0aW9uLCBfYXJnczogYXJncGFy
c2UuTmFtZXNwYWNlKSAtPiBOb25lOgogICAgY29sbGVjdF91c2FnZShjb25uKQoKCmRlZiBjbWRf
cmVuZGVyKGNvbm46IHNxbGl0ZTMuQ29ubmVjdGlvbiwgX2FyZ3M6IGFyZ3BhcnNlLk5hbWVzcGFj
ZSkgLT4gTm9uZToKICAgIGNvbGxlY3RfdXNhZ2UoY29ubiwgcmVuZGVyPUZhbHNlKQogICAgYXBw
bHlfcnVudGltZShjb25uKQogICAgcHJpbnQoIueUqOaIt+mFjee9ruOAgeiuoumYheOAgeerr+WP
o+WSjOiuoeaVsOinhOWImeW3sumHjeaWsOeUn+aIkOOAgiIpCgoKZGVmIGNtZF9jbGVhbnVwKGNv
bm46IHNxbGl0ZTMuQ29ubmVjdGlvbiwgX2FyZ3M6IGFyZ3BhcnNlLk5hbWVzcGFjZSkgLT4gTm9u
ZToKICAgIGNvbGxlY3RfdXNhZ2UoY29ubiwgcmVuZGVyPUZhbHNlKQogICAgZm9yIHJvdyBpbiBh
bGxfdXNlcnMoY29ubik6CiAgICAgICAgZm9yIHBvcnQgaW4gdXNlcl9wb3J0cyhyb3csIGluY2x1
ZGVfc3RhbGVfdHVpYz1UcnVlKToKICAgICAgICAgICAgZmlyZXdhbGxfY2xvc2UocG9ydCkKICAg
IHJlbW92ZV9jb3VudGVyX3J1bGVzKCkKCgpkZWYgd2ViX3VzZXJfcGF5bG9hZCgKICAgIHJvdzog
c3FsaXRlMy5Sb3csIGV2ZXJ5b25lOiBsaXN0W3NxbGl0ZTMuUm93XSwgbW9udGhseV9xdW90YTog
aW50CikgLT4gZGljdFtzdHIsIG9iamVjdF06CiAgICB1c2VkID0gcm93WyJ1cGxvYWRfYnl0ZXMi
XSArIHJvd1siZG93bmxvYWRfYnl0ZXMiXQogICAgcXVvdGEgPSByb3dbInF1b3RhX2J5dGVzIl0K
ICAgIGRpc3BsYXkgPSBzdWJzY3JpcHRpb25fdXNhZ2Uocm93LCBldmVyeW9uZSwgbW9udGhseV9x
dW90YSkKICAgIHJldHVybiB7CiAgICAgICAgInVzZXJuYW1lIjogcm93WyJ1c2VybmFtZSJdLAog
ICAgICAgICJpc19hZG1pbiI6IGJvb2wocm93WyJpc19hZG1pbiJdKSwKICAgICAgICAiZW5hYmxl
ZCI6IGJvb2wocm93WyJlbmFibGVkIl0pLAogICAgICAgICJoeXN0ZXJpYTJfcG9ydCI6IHJvd1si
cG9ydCJdLAogICAgICAgICJ0dWljX3BvcnQiOiByb3dbInR1aWNfcG9ydCJdLAogICAgICAgICJ1
cGxvYWRfYnl0ZXMiOiByb3dbInVwbG9hZF9ieXRlcyJdLAogICAgICAgICJkb3dubG9hZF9ieXRl
cyI6IHJvd1siZG93bmxvYWRfYnl0ZXMiXSwKICAgICAgICAidXNlZF9ieXRlcyI6IHVzZWQsCiAg
ICAgICAgInF1b3RhX2J5dGVzIjogcXVvdGEsCiAgICAgICAgInJlbWFpbmluZ19ieXRlcyI6IG1h
eChxdW90YSAtIHVzZWQsIDApIGlmIHF1b3RhIGVsc2UgMCwKICAgICAgICAicXVvdGFfZ2IiOiBy
b3VuZChxdW90YSAvIEdJQiwgNiksCiAgICAgICAgImRpc3BsYXlfdXNlZF9ieXRlcyI6IGRpc3Bs
YXlbInVzZWRfYnl0ZXMiXSwKICAgICAgICAiZGlzcGxheV90b3RhbF9ieXRlcyI6IGRpc3BsYXlb
InRvdGFsX2J5dGVzIl0sCiAgICAgICAgImRpc3BsYXlfcmVtYWluaW5nX2J5dGVzIjogZGlzcGxh
eVsicmVtYWluaW5nX2J5dGVzIl0sCiAgICAgICAgInVzZXNfc2VydmVyX3F1b3RhIjogZGlzcGxh
eVsidXNlc19zZXJ2ZXJfcXVvdGEiXSwKICAgICAgICAic3Vic2NyaXB0aW9uIjogdXNlcl9saW5r
KHJvdyksCiAgICB9CgoKZGVmIHdlYl91c2Vyc19wYXlsb2FkKGNvbm46IHNxbGl0ZTMuQ29ubmVj
dGlvbiwgYWRtaW46IHNxbGl0ZTMuUm93KSAtPiBkaWN0W3N0ciwgb2JqZWN0XToKICAgIGNvbGxl
Y3RfdXNhZ2UoY29ubikKICAgIHJvd3MgPSBhbGxfdXNlcnMoY29ubikKICAgIG1vbnRobHlfcXVv
dGEgPSBzZXJ2ZXJfbW9udGhseV9xdW90YShjb25uKQogICAgdG90YWxfdXAgPSBzdW0ocm93WyJ1
cGxvYWRfYnl0ZXMiXSBmb3Igcm93IGluIHJvd3MpCiAgICB0b3RhbF9kb3duID0gc3VtKHJvd1si
ZG93bmxvYWRfYnl0ZXMiXSBmb3Igcm93IGluIHJvd3MpCiAgICB0b3RhbF91c2VkID0gdG90YWxf
dXAgKyB0b3RhbF9kb3duCiAgICByZXR1cm4gewogICAgICAgICJhZG1pbiI6IGFkbWluWyJ1c2Vy
bmFtZSJdLAogICAgICAgICJyZWZyZXNoZWRfYXQiOiBub3dfaXNvKCksCiAgICAgICAgInRyYWZm
aWNfbW9udGgiOiBjdXJyZW50X3RyYWZmaWNfbW9udGgoKSwKICAgICAgICAic2VydmVyX21vbnRo
bHlfcXVvdGFfYnl0ZXMiOiBtb250aGx5X3F1b3RhLAogICAgICAgICJzZXJ2ZXJfbW9udGhseV9x
dW90YV90YiI6IHJvdW5kKG1vbnRobHlfcXVvdGEgLyBUSUIsIDYpLAogICAgICAgICJzZXJ2ZXJf
bW9udGhseV9yZW1haW5pbmdfYnl0ZXMiOiBtYXgobW9udGhseV9xdW90YSAtIHRvdGFsX3VzZWQs
IDApLAogICAgICAgICJ0b3RhbHMiOiB7CiAgICAgICAgICAgICJ1c2VyX2NvdW50IjogbGVuKHJv
d3MpLAogICAgICAgICAgICAidXBsb2FkX2J5dGVzIjogdG90YWxfdXAsCiAgICAgICAgICAgICJk
b3dubG9hZF9ieXRlcyI6IHRvdGFsX2Rvd24sCiAgICAgICAgICAgICJ1c2VkX2J5dGVzIjogdG90
YWxfdXNlZCwKICAgICAgICB9LAogICAgICAgICJ1c2VycyI6IFt3ZWJfdXNlcl9wYXlsb2FkKHJv
dywgcm93cywgbW9udGhseV9xdW90YSkgZm9yIHJvdyBpbiByb3dzXSwKICAgIH0KCgpjbGFzcyBT
YlVzZXJXZWJTZXJ2ZXIoaHR0cC5zZXJ2ZXIuVGhyZWFkaW5nSFRUUFNlcnZlcik6CiAgICBhbGxv
d19yZXVzZV9hZGRyZXNzID0gVHJ1ZQogICAgZGFlbW9uX3RocmVhZHMgPSBUcnVlCgoKY2xhc3Mg
QWRtaW5XZWJIYW5kbGVyKGh0dHAuc2VydmVyLkJhc2VIVFRQUmVxdWVzdEhhbmRsZXIpOgogICAg
c2VydmVyX3ZlcnNpb24gPSAic2ItdXNlci1hZG1pbiIKICAgIHN5c192ZXJzaW9uID0gIiIKICAg
IG1heF9ib2R5X2J5dGVzID0gNDA5NgogICAgcm91dGVfcmUgPSByZS5jb21waWxlKAogICAgICAg
IHIiXi91c2VyLyhbYS1mMC05XXs2NH0pLyhwYWdlfGNsYXNoLWNhbXB1cy1mcmVlfHByb3hpZXN8
YXBpKD86Ly4qKT8pJCIKICAgICkKCiAgICBkZWYgbG9nX21lc3NhZ2Uoc2VsZiwgX2Zvcm1hdDog
c3RyLCAqX2FyZ3M6IG9iamVjdCkgLT4gTm9uZToKICAgICAgICAjIFVSTCBwYXRocyBjb250YWlu
IGFkbWluaXN0cmF0b3IgY3JlZGVudGlhbHMuIE5ldmVyIGNvcHkgdGhlbSB0byBsb2dzLgogICAg
ICAgIHJldHVybgoKICAgIGRlZiBfc2VjdXJpdHlfaGVhZGVycyhzZWxmKSAtPiBOb25lOgogICAg
ICAgIHNlbGYuc2VuZF9oZWFkZXIoIkNhY2hlLUNvbnRyb2wiLCAibm8tc3RvcmUsIG1heC1hZ2U9
MCIpCiAgICAgICAgc2VsZi5zZW5kX2hlYWRlcigiUHJhZ21hIiwgIm5vLWNhY2hlIikKICAgICAg
ICBzZWxmLnNlbmRfaGVhZGVyKCJSZWZlcnJlci1Qb2xpY3kiLCAibm8tcmVmZXJyZXIiKQogICAg
ICAgIHNlbGYuc2VuZF9oZWFkZXIoIlgtQ29udGVudC1UeXBlLU9wdGlvbnMiLCAibm9zbmlmZiIp
CiAgICAgICAgc2VsZi5zZW5kX2hlYWRlcigiWC1GcmFtZS1PcHRpb25zIiwgIkRFTlkiKQogICAg
ICAgIHNlbGYuc2VuZF9oZWFkZXIoCiAgICAgICAgICAgICJDb250ZW50LVNlY3VyaXR5LVBvbGlj
eSIsCiAgICAgICAgICAgICJkZWZhdWx0LXNyYyAnbm9uZSc7IHNjcmlwdC1zcmMgJ3Vuc2FmZS1p
bmxpbmUnOyBzdHlsZS1zcmMgJ3Vuc2FmZS1pbmxpbmUnOyAiCiAgICAgICAgICAgICJjb25uZWN0
LXNyYyAnc2VsZic7IGltZy1zcmMgJ3NlbGYnIGRhdGE6OyBiYXNlLXVyaSAnbm9uZSc7IGZvcm0t
YWN0aW9uICdzZWxmJzsgIgogICAgICAgICAgICAiZnJhbWUtYW5jZXN0b3JzICdub25lJyIsCiAg
ICAgICAgKQoKICAgIGRlZiBfc2VuZF9ieXRlcygKICAgICAgICBzZWxmLAogICAgICAgIHN0YXR1
czogaW50LAogICAgICAgIGJvZHk6IGJ5dGVzLAogICAgICAgIGNvbnRlbnRfdHlwZTogc3RyLAog
ICAgICAgIGhlYWRlcnM6IGRpY3Rbc3RyLCBzdHJdIHwgTm9uZSA9IE5vbmUsCiAgICApIC0+IE5v
bmU6CiAgICAgICAgc2VsZi5zZW5kX3Jlc3BvbnNlKHN0YXR1cykKICAgICAgICBzZWxmLl9zZWN1
cml0eV9oZWFkZXJzKCkKICAgICAgICBzZWxmLnNlbmRfaGVhZGVyKCJDb250ZW50LVR5cGUiLCBj
b250ZW50X3R5cGUpCiAgICAgICAgZm9yIG5hbWUsIHZhbHVlIGluIChoZWFkZXJzIG9yIHt9KS5p
dGVtcygpOgogICAgICAgICAgICBzZWxmLnNlbmRfaGVhZGVyKG5hbWUsIHZhbHVlKQogICAgICAg
IHNlbGYuc2VuZF9oZWFkZXIoIkNvbnRlbnQtTGVuZ3RoIiwgc3RyKGxlbihib2R5KSkpCiAgICAg
ICAgc2VsZi5lbmRfaGVhZGVycygpCiAgICAgICAgc2VsZi53ZmlsZS53cml0ZShib2R5KQoKICAg
IGRlZiBfc2VuZF9qc29uKHNlbGYsIHN0YXR1czogaW50LCBwYXlsb2FkOiBkaWN0W3N0ciwgb2Jq
ZWN0XSkgLT4gTm9uZToKICAgICAgICBib2R5ID0ganNvbi5kdW1wcyhwYXlsb2FkLCBlbnN1cmVf
YXNjaWk9RmFsc2UsIHNlcGFyYXRvcnM9KCIsIiwgIjoiKSkuZW5jb2RlKCJ1dGYtOCIpCiAgICAg
ICAgc2VsZi5fc2VuZF9ieXRlcyhzdGF0dXMsIGJvZHksICJhcHBsaWNhdGlvbi9qc29uOyBjaGFy
c2V0PXV0Zi04IikKCiAgICBkZWYgX2Vycm9yKHNlbGYsIHN0YXR1czogaW50LCBtZXNzYWdlOiBz
dHIpIC0+IE5vbmU6CiAgICAgICAgc2VsZi5fc2VuZF9qc29uKHN0YXR1cywgeyJlcnJvciI6IG1l
c3NhZ2V9KQoKICAgIGRlZiBfcm91dGUoc2VsZikgLT4gdHVwbGVbc3RyLCBzdHJdOgogICAgICAg
IHBhdGggPSB1cmxsaWIucGFyc2UudXJsc3BsaXQoc2VsZi5wYXRoKS5wYXRoCiAgICAgICAgbWF0
Y2ggPSBzZWxmLnJvdXRlX3JlLmZ1bGxtYXRjaChwYXRoKQogICAgICAgIGlmIG1hdGNoIGlzIE5v
bmU6CiAgICAgICAgICAgIHJhaXNlIFdlYlJlcXVlc3RFcnJvcig0MDQsICLpobXpnaLmiJbmjqXl
j6PkuI3lrZjlnKjjgIIiKQogICAgICAgIHJldHVybiBtYXRjaC5ncm91cCgxKSwgbWF0Y2guZ3Jv
dXAoMikKCiAgICBkZWYgX2F1dGhlbnRpY2F0ZShzZWxmLCBjb25uOiBzcWxpdGUzLkNvbm5lY3Rp
b24sIHRva2VuOiBzdHIpIC0+IHNxbGl0ZTMuUm93OgogICAgICAgIHJvdyA9IGNvbm4uZXhlY3V0
ZSgiU0VMRUNUICogRlJPTSB1c2VycyBXSEVSRSB0b2tlbj0/IiwgKHRva2VuLCkpLmZldGNob25l
KCkKICAgICAgICBpZiByb3cgaXMgTm9uZSBvciBub3Qgcm93WyJpc19hZG1pbiJdOgogICAgICAg
ICAgICByYWlzZSBXZWJSZXF1ZXN0RXJyb3IoNDAzLCAi566h55CG5ZGY5Luk54mM5peg5pWI5oiW
5peg5p2D6K6/6Zeu44CCIikKICAgICAgICByZXR1cm4gcm93CgogICAgZGVmIF9hdXRoZW50aWNh
dGVfc3Vic2NyaXB0aW9uKHNlbGYsIGNvbm46IHNxbGl0ZTMuQ29ubmVjdGlvbiwgdG9rZW46IHN0
cikgLT4gc3FsaXRlMy5Sb3c6CiAgICAgICAgcm93ID0gY29ubi5leGVjdXRlKCJTRUxFQ1QgKiBG
Uk9NIHVzZXJzIFdIRVJFIHRva2VuPT8iLCAodG9rZW4sKSkuZmV0Y2hvbmUoKQogICAgICAgIGlm
IHJvdyBpcyBOb25lIG9yIG5vdCByb3dbImVuYWJsZWQiXToKICAgICAgICAgICAgcmFpc2UgV2Vi
UmVxdWVzdEVycm9yKDQwMywgIuiuoumYheS7pOeJjOaXoOaViOaIlueUqOaIt+W3suWBnOeUqOOA
giIpCiAgICAgICAgcmV0dXJuIHJvdwoKICAgIGRlZiBfanNvbl9ib2R5KHNlbGYpIC0+IGRpY3Rb
c3RyLCBvYmplY3RdOgogICAgICAgIHNlbGYuX3JlcXVpcmVfd3JpdGVfaGVhZGVycygpCiAgICAg
ICAgcmF3X2xlbmd0aCA9IHNlbGYuaGVhZGVycy5nZXQoIkNvbnRlbnQtTGVuZ3RoIikKICAgICAg
ICB0cnk6CiAgICAgICAgICAgIGxlbmd0aCA9IGludChyYXdfbGVuZ3RoIG9yICIiKQogICAgICAg
IGV4Y2VwdCBWYWx1ZUVycm9yIGFzIGV4YzoKICAgICAgICAgICAgcmFpc2UgV2ViUmVxdWVzdEVy
cm9yKDQwMCwgIuivt+axgumVv+W6puaXoOaViOOAgiIpIGZyb20gZXhjCiAgICAgICAgaWYgbGVu
Z3RoIDwgMCBvciBsZW5ndGggPiBzZWxmLm1heF9ib2R5X2J5dGVzOgogICAgICAgICAgICByYWlz
ZSBXZWJSZXF1ZXN0RXJyb3IoNDEzLCAi6K+35rGC5YaF5a656L+H5aSn44CCIikKICAgICAgICB0
cnk6CiAgICAgICAgICAgIGRhdGEgPSBqc29uLmxvYWRzKHNlbGYucmZpbGUucmVhZChsZW5ndGgp
KQogICAgICAgIGV4Y2VwdCAoanNvbi5KU09ORGVjb2RlRXJyb3IsIFVuaWNvZGVEZWNvZGVFcnJv
cikgYXMgZXhjOgogICAgICAgICAgICByYWlzZSBXZWJSZXF1ZXN0RXJyb3IoNDAwLCAiSlNPTiDl
hoXlrrnml6DmlYjjgIIiKSBmcm9tIGV4YwogICAgICAgIGlmIG5vdCBpc2luc3RhbmNlKGRhdGEs
IGRpY3QpOgogICAgICAgICAgICByYWlzZSBXZWJSZXF1ZXN0RXJyb3IoNDAwLCAiSlNPTiDpobbl
sYLlv4XpobvmmK/lr7nosaHjgIIiKQogICAgICAgIHJldHVybiBkYXRhCgogICAgZGVmIF9yZXF1
aXJlX3dyaXRlX2hlYWRlcnMoc2VsZikgLT4gTm9uZToKICAgICAgICBpZiBzZWxmLmhlYWRlcnMu
Z2V0KCJYLVNCLUFkbWluIikgIT0gIjEiOgogICAgICAgICAgICByYWlzZSBXZWJSZXF1ZXN0RXJy
b3IoNDAzLCAi57y65bCR566h55CG5pON5L2c56Gu6K6k5qCH5aS044CCIikKICAgICAgICBpZiBu
b3Qgc2VsZi5oZWFkZXJzLmdldCgiQ29udGVudC1UeXBlIiwgIiIpLmxvd2VyKCkuc3RhcnRzd2l0
aCgiYXBwbGljYXRpb24vanNvbiIpOgogICAgICAgICAgICByYWlzZSBXZWJSZXF1ZXN0RXJyb3Io
NDE1LCAi6K+35rGC5YaF5a655b+F6aG75pivIEpTT07jgIIiKQoKICAgIEBjb250ZXh0bGliLmNv
bnRleHRtYW5hZ2VyCiAgICBkZWYgX2FkbWluX2Nvbm5lY3Rpb24oc2VsZiwgdG9rZW46IHN0cik6
CiAgICAgICAgd2l0aCBwcm9jZXNzX2xvY2soKToKICAgICAgICAgICAgd2l0aCBjb250ZXh0bGli
LmNsb3NpbmcoY29ubmVjdCgpKSBhcyBjb25uOgogICAgICAgICAgICAgICAgeWllbGQgY29ubiwg
c2VsZi5fYXV0aGVudGljYXRlKGNvbm4sIHRva2VuKQoKICAgIEBzdGF0aWNtZXRob2QKICAgIGRl
ZiBfcXVpZXRfY2FsbChmdW5jdGlvbiwgY29ubjogc3FsaXRlMy5Db25uZWN0aW9uLCBhcmdzOiBh
cmdwYXJzZS5OYW1lc3BhY2UsICpleHRyYTogb2JqZWN0KSAtPiBOb25lOgogICAgICAgIHdpdGgg
Y29udGV4dGxpYi5yZWRpcmVjdF9zdGRvdXQoaW8uU3RyaW5nSU8oKSk6CiAgICAgICAgICAgIGZ1
bmN0aW9uKGNvbm4sIGFyZ3MsICpleHRyYSkKCiAgICBAc3RhdGljbWV0aG9kCiAgICBkZWYgX3dl
Yl91c2VyKGNvbm46IHNxbGl0ZTMuQ29ubmVjdGlvbiwgdXNlcm5hbWU6IHN0cikgLT4gc3FsaXRl
My5Sb3c6CiAgICAgICAgaWYgbm90IFVTRVJOQU1FX1JFLmZ1bGxtYXRjaCh1c2VybmFtZSk6CiAg
ICAgICAgICAgIHJhaXNlIFdlYlJlcXVlc3RFcnJvcig0MDAsICLnlKjmiLflkI3moLzlvI/ml6Dm
lYjjgIIiKQogICAgICAgIHJvdyA9IGNvbm4uZXhlY3V0ZSgiU0VMRUNUICogRlJPTSB1c2VycyBX
SEVSRSB1c2VybmFtZT0/IiwgKHVzZXJuYW1lLCkpLmZldGNob25lKCkKICAgICAgICBpZiByb3cg
aXMgTm9uZToKICAgICAgICAgICAgcmFpc2UgV2ViUmVxdWVzdEVycm9yKDQwNCwgIueUqOaIt+S4
jeWtmOWcqOOAgiIpCiAgICAgICAgcmV0dXJuIHJvdwoKICAgIGRlZiBfZGlzcGF0Y2goc2VsZikg
LT4gTm9uZToKICAgICAgICB0b2tlbiwgcmVzb3VyY2UgPSBzZWxmLl9yb3V0ZSgpCiAgICAgICAg
aWYgc2VsZi5jb21tYW5kID09ICJHRVQiIGFuZCByZXNvdXJjZSBpbiB7ImNsYXNoLWNhbXB1cy1m
cmVlIiwgInByb3hpZXMifToKICAgICAgICAgICAgd2l0aCBwcm9jZXNzX2xvY2soKToKICAgICAg
ICAgICAgICAgIHdpdGggY29udGV4dGxpYi5jbG9zaW5nKGNvbm5lY3QoKSkgYXMgY29ubjoKICAg
ICAgICAgICAgICAgICAgICByb3cgPSBzZWxmLl9hdXRoZW50aWNhdGVfc3Vic2NyaXB0aW9uKGNv
bm4sIHRva2VuKQogICAgICAgICAgICAgICAgICAgIGNvbGxlY3RfdXNhZ2UoY29ubikKICAgICAg
ICAgICAgICAgICAgICByb3cgPSBjb25uLmV4ZWN1dGUoIlNFTEVDVCAqIEZST00gdXNlcnMgV0hF
UkUgaWQ9PyIsIChyb3dbImlkIl0sKSkuZmV0Y2hvbmUoKQogICAgICAgICAgICAgICAgICAgIGV2
ZXJ5b25lID0gYWxsX3VzZXJzKGNvbm4pCiAgICAgICAgICAgICAgICAgICAgbW9udGhseV9xdW90
YSA9IHNlcnZlcl9tb250aGx5X3F1b3RhKGNvbm4pCiAgICAgICAgICAgICAgICAgICAgdGFyZ2V0
ID0gVVNFUlNfRElSIC8gdG9rZW4gLyByZXNvdXJjZQogICAgICAgICAgICAgICAgICAgIGlmIG5v
dCB0YXJnZXQuaXNfZmlsZSgpOgogICAgICAgICAgICAgICAgICAgICAgICByYWlzZSBXZWJSZXF1
ZXN0RXJyb3IoNDA0LCAi6K6i6ZiF5paH5Lu25LiN5a2Y5Zyo77yM6K+36L+Q6KGMIHNiLXVzZXIg
cmVuZGVy44CCIikKICAgICAgICAgICAgICAgICAgICBzZWxmLl9zZW5kX2J5dGVzKAogICAgICAg
ICAgICAgICAgICAgICAgICAyMDAsCiAgICAgICAgICAgICAgICAgICAgICAgIHRhcmdldC5yZWFk
X2J5dGVzKCksCiAgICAgICAgICAgICAgICAgICAgICAgICJ0ZXh0L3lhbWw7IGNoYXJzZXQ9dXRm
LTgiLAogICAgICAgICAgICAgICAgICAgICAgICB7CiAgICAgICAgICAgICAgICAgICAgICAgICAg
ICAiU3Vic2NyaXB0aW9uLVVzZXJpbmZvIjogc3Vic2NyaXB0aW9uX3VzZXJpbmZvX2hlYWRlcigK
ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICByb3csIGV2ZXJ5b25lLCBtb250aGx5X3F1
b3RhCiAgICAgICAgICAgICAgICAgICAgICAgICAgICApLAogICAgICAgICAgICAgICAgICAgICAg
ICAgICAgIlByb2ZpbGUtVXBkYXRlLUludGVydmFsIjogIjEiLAogICAgICAgICAgICAgICAgICAg
ICAgICB9LAogICAgICAgICAgICAgICAgICAgICkKICAgICAgICAgICAgcmV0dXJuCgogICAgICAg
IGlmIHNlbGYuY29tbWFuZCA9PSAiR0VUIiBhbmQgcmVzb3VyY2UgPT0gInBhZ2UiOgogICAgICAg
ICAgICB3aXRoIHNlbGYuX2FkbWluX2Nvbm5lY3Rpb24odG9rZW4pOgogICAgICAgICAgICAgICAg
aWYgbm90IEFETUlOX1BBR0VfUEFUSC5pc19maWxlKCk6CiAgICAgICAgICAgICAgICAgICAgcmFp
c2UgV2ViUmVxdWVzdEVycm9yKDUwMywgIueuoeeQhuWRmOmhtemdouWwmuacquWuieijheOAgiIp
CiAgICAgICAgICAgICAgICBzZWxmLl9zZW5kX2J5dGVzKDIwMCwgQURNSU5fUEFHRV9QQVRILnJl
YWRfYnl0ZXMoKSwgInRleHQvaHRtbDsgY2hhcnNldD11dGYtOCIpCiAgICAgICAgICAgIHJldHVy
bgoKICAgICAgICBpZiByZXNvdXJjZSA9PSAiYXBpL3VzZXJzIiBhbmQgc2VsZi5jb21tYW5kID09
ICJHRVQiOgogICAgICAgICAgICB3aXRoIHNlbGYuX2FkbWluX2Nvbm5lY3Rpb24odG9rZW4pIGFz
IChjb25uLCBhZG1pbik6CiAgICAgICAgICAgICAgICBzZWxmLl9zZW5kX2pzb24oMjAwLCB3ZWJf
dXNlcnNfcGF5bG9hZChjb25uLCBhZG1pbikpCiAgICAgICAgICAgIHJldHVybgoKICAgICAgICBp
ZiByZXNvdXJjZSA9PSAiYXBpL3VzZXJzIiBhbmQgc2VsZi5jb21tYW5kID09ICJQT1NUIjoKICAg
ICAgICAgICAgZGF0YSA9IHNlbGYuX2pzb25fYm9keSgpCiAgICAgICAgICAgIHVzZXJuYW1lID0g
ZGF0YS5nZXQoInVzZXJuYW1lIikKICAgICAgICAgICAgcXVvdGFfZ2IgPSBkYXRhLmdldCgicXVv
dGFfZ2IiKQogICAgICAgICAgICBpZiBub3QgaXNpbnN0YW5jZSh1c2VybmFtZSwgc3RyKSBvciBu
b3QgVVNFUk5BTUVfUkUuZnVsbG1hdGNoKHVzZXJuYW1lKToKICAgICAgICAgICAgICAgIHJhaXNl
IFdlYlJlcXVlc3RFcnJvcig0MDAsICLnlKjmiLflkI3lj6rog73ljIXlkKvlrZfmr43jgIHmlbDl
rZfjgIHkuIvliJLnur/lkozov57lrZfnrKbvvIzplb/luqYgMS0zMuOAgiIpCiAgICAgICAgICAg
IGlmIGlzaW5zdGFuY2UocXVvdGFfZ2IsIGJvb2wpIG9yIG5vdCBpc2luc3RhbmNlKHF1b3RhX2di
LCAoc3RyLCBpbnQsIGZsb2F0KSk6CiAgICAgICAgICAgICAgICByYWlzZSBXZWJSZXF1ZXN0RXJy
b3IoNDAwLCAi5rWB6YeP6aKd5bqm5b+F6aG75piv5pWw5a2X77yM5Y2V5L2N5Li6IEdC44CCIikK
ICAgICAgICAgICAgd2l0aCBzZWxmLl9hZG1pbl9jb25uZWN0aW9uKHRva2VuKSBhcyAoY29ubiwg
X2FkbWluKToKICAgICAgICAgICAgICAgIGlmIGNvbm4uZXhlY3V0ZSgiU0VMRUNUIDEgRlJPTSB1
c2VycyBXSEVSRSB1c2VybmFtZT0/IiwgKHVzZXJuYW1lLCkpLmZldGNob25lKCk6CiAgICAgICAg
ICAgICAgICAgICAgcmFpc2UgV2ViUmVxdWVzdEVycm9yKDQwOSwgIueUqOaIt+W3suWtmOWcqOOA
giIpCiAgICAgICAgICAgICAgICBzZWxmLl9xdWlldF9jYWxsKGNtZF9hZGQsIGNvbm4sIGFyZ3Bh
cnNlLk5hbWVzcGFjZSh1c2VybmFtZT11c2VybmFtZSwgcXVvdGFfZ2I9c3RyKHF1b3RhX2diKSkp
CiAgICAgICAgICAgIHNlbGYuX3NlbmRfanNvbigyMDEsIHsib2siOiBUcnVlfSkKICAgICAgICAg
ICAgcmV0dXJuCgogICAgICAgIGlmIHJlc291cmNlID09ICJhcGkvc2VydmVyLXF1b3RhIiBhbmQg
c2VsZi5jb21tYW5kID09ICJQQVRDSCI6CiAgICAgICAgICAgIGRhdGEgPSBzZWxmLl9qc29uX2Jv
ZHkoKQogICAgICAgICAgICBxdW90YV90YiA9IGRhdGEuZ2V0KCJxdW90YV90YiIpCiAgICAgICAg
ICAgIGlmIGlzaW5zdGFuY2UocXVvdGFfdGIsIGJvb2wpIG9yIG5vdCBpc2luc3RhbmNlKHF1b3Rh
X3RiLCAoc3RyLCBpbnQsIGZsb2F0KSk6CiAgICAgICAgICAgICAgICByYWlzZSBXZWJSZXF1ZXN0
RXJyb3IoNDAwLCAi5pyN5Yqh5Zmo5pyI5rWB6YeP5b+F6aG75piv5pWw5a2X77yM5Y2V5L2N5Li6
IFRC44CCIikKICAgICAgICAgICAgcXVvdGFfYnl0ZXMgPSBwYXJzZV9zZXJ2ZXJfcXVvdGFfdGIo
c3RyKHF1b3RhX3RiKSkKICAgICAgICAgICAgd2l0aCBzZWxmLl9hZG1pbl9jb25uZWN0aW9uKHRv
a2VuKSBhcyAoY29ubiwgX2FkbWluKToKICAgICAgICAgICAgICAgIHNldF9zZXJ2ZXJfbW9udGhs
eV9xdW90YShjb25uLCBxdW90YV9ieXRlcykKICAgICAgICAgICAgICAgIHJlbmRlcl9zdWJzY3Jp
cHRpb25zKGNvbm4pCiAgICAgICAgICAgIHNlbGYuX3NlbmRfanNvbigyMDAsIHsib2siOiBUcnVl
fSkKICAgICAgICAgICAgcmV0dXJuCgogICAgICAgIG1hdGNoID0gcmUuZnVsbG1hdGNoKHIiYXBp
L3VzZXJzLyhbXi9dKykvKHF1b3RhfHN0YXR1cykiLCByZXNvdXJjZSkKICAgICAgICBpZiBtYXRj
aCBhbmQgc2VsZi5jb21tYW5kID09ICJQQVRDSCI6CiAgICAgICAgICAgIHVzZXJuYW1lID0gdXJs
bGliLnBhcnNlLnVucXVvdGUobWF0Y2guZ3JvdXAoMSkpCiAgICAgICAgICAgIG9wZXJhdGlvbiA9
IG1hdGNoLmdyb3VwKDIpCiAgICAgICAgICAgIGRhdGEgPSBzZWxmLl9qc29uX2JvZHkoKQogICAg
ICAgICAgICB3aXRoIHNlbGYuX2FkbWluX2Nvbm5lY3Rpb24odG9rZW4pIGFzIChjb25uLCBfYWRt
aW4pOgogICAgICAgICAgICAgICAgcm93ID0gc2VsZi5fd2ViX3VzZXIoY29ubiwgdXNlcm5hbWUp
CiAgICAgICAgICAgICAgICBpZiBvcGVyYXRpb24gPT0gInF1b3RhIjoKICAgICAgICAgICAgICAg
ICAgICBxdW90YV9nYiA9IGRhdGEuZ2V0KCJxdW90YV9nYiIpCiAgICAgICAgICAgICAgICAgICAg
aWYgaXNpbnN0YW5jZShxdW90YV9nYiwgYm9vbCkgb3Igbm90IGlzaW5zdGFuY2UocXVvdGFfZ2Is
IChzdHIsIGludCwgZmxvYXQpKToKICAgICAgICAgICAgICAgICAgICAgICAgcmFpc2UgV2ViUmVx
dWVzdEVycm9yKDQwMCwgIua1gemHj+mineW6puW/hemhu+aYr+aVsOWtl++8jOWNleS9jeS4uiBH
QuOAgiIpCiAgICAgICAgICAgICAgICAgICAgc2VsZi5fcXVpZXRfY2FsbChjbWRfcXVvdGEsIGNv
bm4sIGFyZ3BhcnNlLk5hbWVzcGFjZSh1c2VybmFtZT11c2VybmFtZSwgcXVvdGFfZ2I9c3RyKHF1
b3RhX2diKSkpCiAgICAgICAgICAgICAgICBlbHNlOgogICAgICAgICAgICAgICAgICAgIGVuYWJs
ZWQgPSBkYXRhLmdldCgiZW5hYmxlZCIpCiAgICAgICAgICAgICAgICAgICAgaWYgbm90IGlzaW5z
dGFuY2UoZW5hYmxlZCwgYm9vbCk6CiAgICAgICAgICAgICAgICAgICAgICAgIHJhaXNlIFdlYlJl
cXVlc3RFcnJvcig0MDAsICJlbmFibGVkIOW/hemhu+aYr+W4g+WwlOWAvOOAgiIpCiAgICAgICAg
ICAgICAgICAgICAgaWYgcm93WyJpc19hZG1pbiJdOgogICAgICAgICAgICAgICAgICAgICAgICBy
YWlzZSBXZWJSZXF1ZXN0RXJyb3IoNDAzLCAi5LiN6IO95Zyo572R6aG15Lit5YGc55So566h55CG
5ZGY44CCIikKICAgICAgICAgICAgICAgICAgICBzZWxmLl9xdWlldF9jYWxsKGNtZF90b2dnbGUs
IGNvbm4sIGFyZ3BhcnNlLk5hbWVzcGFjZSh1c2VybmFtZT11c2VybmFtZSksIGVuYWJsZWQpCiAg
ICAgICAgICAgIHNlbGYuX3NlbmRfanNvbigyMDAsIHsib2siOiBUcnVlfSkKICAgICAgICAgICAg
cmV0dXJuCgogICAgICAgIG1hdGNoID0gcmUuZnVsbG1hdGNoKHIiYXBpL3VzZXJzLyhbXi9dKyki
LCByZXNvdXJjZSkKICAgICAgICBpZiBtYXRjaCBhbmQgc2VsZi5jb21tYW5kID09ICJERUxFVEUi
OgogICAgICAgICAgICBzZWxmLl9yZXF1aXJlX3dyaXRlX2hlYWRlcnMoKQogICAgICAgICAgICB1
c2VybmFtZSA9IHVybGxpYi5wYXJzZS51bnF1b3RlKG1hdGNoLmdyb3VwKDEpKQogICAgICAgICAg
ICB3aXRoIHNlbGYuX2FkbWluX2Nvbm5lY3Rpb24odG9rZW4pIGFzIChjb25uLCBfYWRtaW4pOgog
ICAgICAgICAgICAgICAgcm93ID0gc2VsZi5fd2ViX3VzZXIoY29ubiwgdXNlcm5hbWUpCiAgICAg
ICAgICAgICAgICBpZiByb3dbImlzX2FkbWluIl06CiAgICAgICAgICAgICAgICAgICAgcmFpc2Ug
V2ViUmVxdWVzdEVycm9yKDQwMywgIuS4jeiDveWIoOmZpOW9k+WJjeeuoeeQhuWRmOOAgiIpCiAg
ICAgICAgICAgICAgICBzZWxmLl9xdWlldF9jYWxsKGNtZF9kZWxldGUsIGNvbm4sIGFyZ3BhcnNl
Lk5hbWVzcGFjZSh1c2VybmFtZT11c2VybmFtZSwgeWVzPVRydWUpKQogICAgICAgICAgICBzZWxm
Ll9zZW5kX2pzb24oMjAwLCB7Im9rIjogVHJ1ZX0pCiAgICAgICAgICAgIHJldHVybgoKICAgICAg
ICByYWlzZSBXZWJSZXF1ZXN0RXJyb3IoNDA0LCAi6aG16Z2i5oiW5o6l5Y+j5LiN5a2Y5Zyo44CC
IikKCiAgICBkZWYgX2hhbmRsZShzZWxmKSAtPiBOb25lOgogICAgICAgIHRyeToKICAgICAgICAg
ICAgc2VsZi5fZGlzcGF0Y2goKQogICAgICAgIGV4Y2VwdCBXZWJSZXF1ZXN0RXJyb3IgYXMgZXhj
OgogICAgICAgICAgICBzZWxmLl9lcnJvcihleGMuc3RhdHVzLCBzdHIoZXhjKSkKICAgICAgICBl
eGNlcHQgTWFuYWdlckVycm9yIGFzIGV4YzoKICAgICAgICAgICAgc2VsZi5fZXJyb3IoNDAwLCBz
dHIoZXhjKSkKICAgICAgICBleGNlcHQgKE9TRXJyb3IsIHNxbGl0ZTMuRXJyb3IsIHN1YnByb2Nl
c3MuU3VicHJvY2Vzc0Vycm9yKToKICAgICAgICAgICAgc2VsZi5fZXJyb3IoNTAwLCAi5pyN5Yqh
5Zmo5aSE55CG6K+35rGC5aSx6LSl44CC6K+35p+l55yLIHNiLXVzZXItd2ViIOacjeWKoeaXpeW/
l+OAgiIpCgogICAgZG9fR0VUID0gX2hhbmRsZQogICAgZG9fUE9TVCA9IF9oYW5kbGUKICAgIGRv
X1BBVENIID0gX2hhbmRsZQogICAgZG9fREVMRVRFID0gX2hhbmRsZQoKCmRlZiBjcmVhdGVfd2Vi
X3NlcnZlcihwb3J0OiBpbnQgPSBXRUJfUE9SVCwgaG9zdDogc3RyID0gV0VCX0hPU1QpIC0+IFNi
VXNlcldlYlNlcnZlcjoKICAgIHJldHVybiBTYlVzZXJXZWJTZXJ2ZXIoKGhvc3QsIHBvcnQpLCBB
ZG1pbldlYkhhbmRsZXIpCgoKZGVmIGNtZF93ZWIoYXJnczogYXJncGFyc2UuTmFtZXNwYWNlKSAt
PiBOb25lOgogICAgaWYgbm90IDEgPD0gYXJncy5wb3J0IDw9IDY1NTM1OgogICAgICAgIHJhaXNl
IE1hbmFnZXJFcnJvcigi572R6aG15pyN5Yqh56uv5Y+j5b+F6aG75ZyoIDEtNjU1MzUg5LmL6Ze0
44CCIikKICAgIGlmIG5vdCBBRE1JTl9QQUdFX1BBVEguaXNfZmlsZSgpOgogICAgICAgIHJhaXNl
IE1hbmFnZXJFcnJvcihmIueuoeeQhuWRmOmhtemdouaWh+S7tuS4jeWtmOWcqO+8mntBRE1JTl9Q
QUdFX1BBVEh9IikKICAgIHdpdGggY29udGV4dGxpYi5jbG9zaW5nKGNvbm5lY3QoKSk6CiAgICAg
ICAgcGFzcwogICAgc2VydmVyID0gY3JlYXRlX3dlYl9zZXJ2ZXIoYXJncy5wb3J0KQogICAgcHJp
bnQoZiLnrqHnkIblkZjnvZHpobXmnI3liqHmraPlnKjnm5HlkKwge1dFQl9IT1NUfTp7YXJncy5w
b3J0fSIsIGZsdXNoPVRydWUpCiAgICB0cnk6CiAgICAgICAgc2VydmVyLnNlcnZlX2ZvcmV2ZXIo
cG9sbF9pbnRlcnZhbD0wLjUpCiAgICBleGNlcHQgS2V5Ym9hcmRJbnRlcnJ1cHQ6CiAgICAgICAg
cGFzcwogICAgZmluYWxseToKICAgICAgICBzZXJ2ZXIuc2VydmVyX2Nsb3NlKCkKCgpkZWYgYnVp
bGRfcGFyc2VyKCkgLT4gYXJncGFyc2UuQXJndW1lbnRQYXJzZXI6CiAgICBwYXJzZXIgPSBhcmdw
YXJzZS5Bcmd1bWVudFBhcnNlcihwcm9nPSJzYi11c2VyIiwgZGVzY3JpcHRpb249InNpbmctYm94
IEh5c3RlcmlhMi9UVUlDIOWkmueUqOaIt+S4jua1gemHj+euoeeQhiIpCiAgICBzdWIgPSBwYXJz
ZXIuYWRkX3N1YnBhcnNlcnMoZGVzdD0iY29tbWFuZCIsIHJlcXVpcmVkPVRydWUpCiAgICBzdWIu
YWRkX3BhcnNlcigiaW5pdCIsIGhlbHA9IuWIneWni+WMluaVsOaNruW6k+S4juiuoeaVsOinhOWI
mSIpCiAgICBhZGQgPSBzdWIuYWRkX3BhcnNlcigiYWRkIiwgaGVscD0i5Yib5bu655So5oi377yb
56ys5LiA5Liq55So5oi36Ieq5Yqo5oiQ5Li6566h55CG5ZGYIikKICAgIGFkZC5hZGRfYXJndW1l
bnQoInVzZXJuYW1lIikKICAgIGFkZC5hZGRfYXJndW1lbnQoInF1b3RhX2diIiwgaGVscD0i5rWB
6YeP6aKd5bqm77yM5Y2V5L2NIEdC77ybMCDooajnpLrkuI3pmZDph48iKQogICAgc3ViLmFkZF9w
YXJzZXIoImxpc3QiLCBoZWxwPSLliJflh7rlhajpg6jnlKjmiLflkozmgLvmtYHph48iKQogICAg
c2hvdyA9IHN1Yi5hZGRfcGFyc2VyKCJzaG93IiwgaGVscD0i5p+l55yL55So5oi344CB5a+G56CB
5ZKM6K6i6ZiFIFVSTCIpCiAgICBzaG93LmFkZF9hcmd1bWVudCgidXNlcm5hbWUiKQogICAgcXVv
dGEgPSBzdWIuYWRkX3BhcnNlcigicXVvdGEiLCBoZWxwPSLkv67mlLnnlKjmiLfmtYHph4/pop3l
uqYiKQogICAgcXVvdGEuYWRkX2FyZ3VtZW50KCJ1c2VybmFtZSIpCiAgICBxdW90YS5hZGRfYXJn
dW1lbnQoInF1b3RhX2diIikKICAgIHJlc2V0ID0gc3ViLmFkZF9wYXJzZXIoInJlc2V0IiwgaGVs
cD0i5riF6Zu255So5oi357Sv6K6h5rWB6YePIikKICAgIHJlc2V0LmFkZF9hcmd1bWVudCgidXNl
cm5hbWUiKQogICAgZW5hYmxlID0gc3ViLmFkZF9wYXJzZXIoImVuYWJsZSIsIGhlbHA9IuWQr+eU
qOeUqOaItyIpCiAgICBlbmFibGUuYWRkX2FyZ3VtZW50KCJ1c2VybmFtZSIpCiAgICBkaXNhYmxl
ID0gc3ViLmFkZF9wYXJzZXIoImRpc2FibGUiLCBoZWxwPSLlgZznlKjnlKjmiLciKQogICAgZGlz
YWJsZS5hZGRfYXJndW1lbnQoInVzZXJuYW1lIikKICAgIGRlbGV0ZSA9IHN1Yi5hZGRfcGFyc2Vy
KCJkZWxldGUiLCBoZWxwPSLliKDpmaTnlKjmiLciKQogICAgZGVsZXRlLmFkZF9hcmd1bWVudCgi
dXNlcm5hbWUiKQogICAgZGVsZXRlLmFkZF9hcmd1bWVudCgiLS15ZXMiLCBhY3Rpb249InN0b3Jl
X3RydWUiKQogICAgcm90YXRlX3Rva2VuID0gc3ViLmFkZF9wYXJzZXIoInJvdGF0ZS10b2tlbiIs
IGhlbHA9Iui9ruaNouiuoumYhSBVUkwiKQogICAgcm90YXRlX3Rva2VuLmFkZF9hcmd1bWVudCgi
dXNlcm5hbWUiKQogICAgcm90YXRlX3Bhc3N3b3JkID0gc3ViLmFkZF9wYXJzZXIoInJvdGF0ZS1w
YXNzd29yZCIsIGhlbHA9Iui9ruaNoiBIeXN0ZXJpYTIvVFVJQyDlr4bnoIEiKQogICAgcm90YXRl
X3Bhc3N3b3JkLmFkZF9hcmd1bWVudCgidXNlcm5hbWUiKQogICAgc3ViLmFkZF9wYXJzZXIoImNv
bGxlY3QiLCBoZWxwPWFyZ3BhcnNlLlNVUFBSRVNTKQogICAgc3ViLmFkZF9wYXJzZXIoImNsZWFu
dXAiLCBoZWxwPWFyZ3BhcnNlLlNVUFBSRVNTKQogICAgc3ViLmFkZF9wYXJzZXIoInJlbmRlciIs
IGhlbHA9IumHjeW7uuWFqOmDqOeUqOaIt+mFjee9riIpCiAgICB3ZWIgPSBzdWIuYWRkX3BhcnNl
cigid2ViIiwgaGVscD0i6L+Q6KGM5LuF6ZmQ5pys5py66K6/6Zeu55qE566h55CG5ZGY572R6aG1
5ZCO56uvIikKICAgIHdlYi5hZGRfYXJndW1lbnQoIi0tcG9ydCIsIHR5cGU9aW50LCBkZWZhdWx0
PVdFQl9QT1JUKQogICAgcmV0dXJuIHBhcnNlcgoKCmRlZiBtYWluKCkgLT4gaW50OgogICAgb3Mu
dW1hc2soMG8wNzcpCiAgICBwYXJzZXIgPSBidWlsZF9wYXJzZXIoKQogICAgYXJncyA9IHBhcnNl
ci5wYXJzZV9hcmdzKCkKICAgIHRyeToKICAgICAgICBpZiBhcmdzLmNvbW1hbmQgPT0gIndlYiI6
CiAgICAgICAgICAgIGNtZF93ZWIoYXJncykKICAgICAgICAgICAgcmV0dXJuIDAKICAgICAgICB3
aXRoIHByb2Nlc3NfbG9jaygpOgogICAgICAgICAgICB3aXRoIGNvbm5lY3QoKSBhcyBjb25uOgog
ICAgICAgICAgICAgICAgaGFuZGxlcnMgPSB7CiAgICAgICAgICAgICAgICAgICAgImluaXQiOiBj
bWRfaW5pdCwKICAgICAgICAgICAgICAgICAgICAiYWRkIjogY21kX2FkZCwKICAgICAgICAgICAg
ICAgICAgICAibGlzdCI6IGNtZF9saXN0LAogICAgICAgICAgICAgICAgICAgICJzaG93IjogY21k
X3Nob3csCiAgICAgICAgICAgICAgICAgICAgInF1b3RhIjogY21kX3F1b3RhLAogICAgICAgICAg
ICAgICAgICAgICJyZXNldCI6IGNtZF9yZXNldCwKICAgICAgICAgICAgICAgICAgICAiZW5hYmxl
IjogbGFtYmRhIGMsIGE6IGNtZF90b2dnbGUoYywgYSwgVHJ1ZSksCiAgICAgICAgICAgICAgICAg
ICAgImRpc2FibGUiOiBsYW1iZGEgYywgYTogY21kX3RvZ2dsZShjLCBhLCBGYWxzZSksCiAgICAg
ICAgICAgICAgICAgICAgImRlbGV0ZSI6IGNtZF9kZWxldGUsCiAgICAgICAgICAgICAgICAgICAg
InJvdGF0ZS10b2tlbiI6IGxhbWJkYSBjLCBhOiBjbWRfcm90YXRlKGMsIGEsICJ0b2tlbiIpLAog
ICAgICAgICAgICAgICAgICAgICJyb3RhdGUtcGFzc3dvcmQiOiBsYW1iZGEgYywgYTogY21kX3Jv
dGF0ZShjLCBhLCAicGFzc3dvcmQiKSwKICAgICAgICAgICAgICAgICAgICAiY29sbGVjdCI6IGNt
ZF9jb2xsZWN0LAogICAgICAgICAgICAgICAgICAgICJjbGVhbnVwIjogY21kX2NsZWFudXAsCiAg
ICAgICAgICAgICAgICAgICAgInJlbmRlciI6IGNtZF9yZW5kZXIsCiAgICAgICAgICAgICAgICB9
CiAgICAgICAgICAgICAgICBoYW5kbGVyc1thcmdzLmNvbW1hbmRdKGNvbm4sIGFyZ3MpCiAgICAg
ICAgcmV0dXJuIDAKICAgIGV4Y2VwdCAoTWFuYWdlckVycm9yLCBPU0Vycm9yLCBzcWxpdGUzLkVy
cm9yLCBzdWJwcm9jZXNzLlN1YnByb2Nlc3NFcnJvcikgYXMgZXhjOgogICAgICAgIHByaW50KGYi
6ZSZ6K+v77yae2V4Y30iLCBmaWxlPXN5cy5zdGRlcnIpCiAgICAgICAgcmV0dXJuIDEKCgppZiBf
X25hbWVfXyA9PSAiX19tYWluX18iOgogICAgcmFpc2UgU3lzdGVtRXhpdChtYWluKCkpCg==
SB_USER_MANAGER_B64
  python3 -c 'import base64, pathlib, sys; pathlib.Path(sys.argv[1]).write_bytes(base64.b64decode(sys.stdin.buffer.read()))' "${WORK_DIR}/admin-page.html" << 'SB_USER_ADMIN_PAGE_B64'
PCFkb2N0eXBlIGh0bWw+CjxodG1sIGxhbmc9InpoLUNOIj4KPGhlYWQ+CiAgPG1ldGEgY2hhcnNl
dD0idXRmLTgiPgogIDxtZXRhIG5hbWU9InZpZXdwb3J0IiBjb250ZW50PSJ3aWR0aD1kZXZpY2Ut
d2lkdGgsaW5pdGlhbC1zY2FsZT0xIj4KICA8bWV0YSBuYW1lPSJyZWZlcnJlciIgY29udGVudD0i
bm8tcmVmZXJyZXIiPgogIDx0aXRsZT7mtYHph4/nrqHnkIbmjqfliLblj7A8L3RpdGxlPgogIDxz
dHlsZT4KICAgIDpyb290IHsKICAgICAgY29sb3Itc2NoZW1lOiBsaWdodCBkYXJrOwogICAgICAt
LWJnOiBsaWdodC1kYXJrKCNmM2Y2ZmIsICMwYjEwMTgpOwogICAgICAtLXN1cmZhY2U6IGxpZ2h0
LWRhcmsoI2ZmZmZmZiwgIzE0MWIyNik7CiAgICAgIC0tc3VyZmFjZS0yOiBsaWdodC1kYXJrKCNl
ZGYyZjgsICMxYjI1MzMpOwogICAgICAtLXRleHQ6IGxpZ2h0LWRhcmsoIzE3MjAzMywgI2VkZjNm
Yik7CiAgICAgIC0tbXV0ZWQ6IGxpZ2h0LWRhcmsoIzY2NzA4NSwgIzlhYThiYSk7CiAgICAgIC0t
bGluZTogbGlnaHQtZGFyaygjZGJlM2VkLCAjMjkzNjQ4KTsKICAgICAgLS1wcmltYXJ5OiBsaWdo
dC1kYXJrKCMyNTU4ZDgsICM3OGE2ZmYpOwogICAgICAtLXByaW1hcnktc29mdDogbGlnaHQtZGFy
aygjZThlZmZmLCAjMWMzMTVmKTsKICAgICAgLS1nb29kOiBsaWdodC1kYXJrKCMwODdhNTUsICM1
ZGQ2YTcpOwogICAgICAtLXdhcm46IGxpZ2h0LWRhcmsoI2ExNWEwMCwgI2ZmYmQ2Mik7CiAgICAg
IC0tZGFuZ2VyOiBsaWdodC1kYXJrKCNiNDIzMTgsICNmZjgyNzkpOwogICAgICAtLXNoYWRvdzog
bGlnaHQtZGFyaygwIDE2cHggNDJweCByZ2JhKDI4LDM5LDU4LC4wOCksIDAgMjBweCA1NHB4IHJn
YmEoMCwwLDAsLjI1KSk7CiAgICB9CiAgICAqIHsgYm94LXNpemluZzogYm9yZGVyLWJveDsgfQog
ICAgYm9keSB7IG1hcmdpbjogMDsgbWluLXdpZHRoOiAzMjBweDsgYmFja2dyb3VuZDogdmFyKC0t
YmcpOyBjb2xvcjogdmFyKC0tdGV4dCk7IGZvbnQtZmFtaWx5OiBJbnRlciwiUGluZ0ZhbmcgU0Mi
LCJNaWNyb3NvZnQgWWFIZWkiLHN5c3RlbS11aSxzYW5zLXNlcmlmOyB9CiAgICBidXR0b24saW5w
dXQgeyBmb250OiBpbmhlcml0OyB9CiAgICBidXR0b24geyBjdXJzb3I6IHBvaW50ZXI7IH0KICAg
IGJ1dHRvbjpkaXNhYmxlZCB7IGN1cnNvcjogbm90LWFsbG93ZWQ7IG9wYWNpdHk6IC40ODsgfQog
ICAgLnNoZWxsIHsgd2lkdGg6IG1pbigxMTgwcHgsIGNhbGMoMTAwJSAtIDQwcHgpKTsgbWFyZ2lu
OiAwIGF1dG87IHBhZGRpbmc6IDI4cHggMCA0OHB4OyB9CiAgICAudG9wYmFyLC5icmFuZCwuYXV0
aCwudG9wLWFjdGlvbnMsLm1ldHJpYy1oZWFkLC5wYW5lbC1oZWFkLC5hY3Rpb25zLC5kaWFsb2ct
YWN0aW9ucywudXNlci1jZWxsLC5wcm90b2NvbHMgeyBkaXNwbGF5OiBmbGV4OyBhbGlnbi1pdGVt
czogY2VudGVyOyB9CiAgICAudG9wYmFyIHsganVzdGlmeS1jb250ZW50OiBzcGFjZS1iZXR3ZWVu
OyBnYXA6IDIwcHg7IG1hcmdpbi1ib3R0b206IDI0cHg7IH0KICAgIC5icmFuZCB7IGdhcDogMTJw
eDsgfQogICAgLmxvZ28geyB3aWR0aDogNDBweDsgaGVpZ2h0OiA0MHB4OyBkaXNwbGF5OiBncmlk
OyBwbGFjZS1pdGVtczogY2VudGVyOyBib3JkZXItcmFkaXVzOiAxMnB4OyBjb2xvcjogI2ZmZjsg
YmFja2dyb3VuZDogdmFyKC0tcHJpbWFyeSk7IGZvbnQtc2l6ZTogMTlweDsgfQogICAgaDEgeyBt
YXJnaW46IDA7IGZvbnQtc2l6ZTogMjFweDsgZm9udC13ZWlnaHQ6IDY1MDsgfQogICAgLnN1YnRp
dGxlIHsgbWFyZ2luOiA0cHggMCAwOyBjb2xvcjogdmFyKC0tbXV0ZWQpOyBmb250LXNpemU6IDEy
cHg7IH0KICAgIC5hdXRoIHsgZ2FwOiA4cHg7IGNvbG9yOiB2YXIoLS1nb29kKTsgZm9udC1zaXpl
OiAxM3B4OyB3aGl0ZS1zcGFjZTogbm93cmFwOyB9CiAgICAuYXV0aDo6YmVmb3JlIHsgY29udGVu
dDogIiI7IHdpZHRoOiA4cHg7IGhlaWdodDogOHB4OyBib3JkZXItcmFkaXVzOiA1MCU7IGJhY2tn
cm91bmQ6IGN1cnJlbnRDb2xvcjsgfQogICAgLnRvcC1hY3Rpb25zIHsgZ2FwOiAxMHB4OyBmbGV4
LXdyYXA6IHdyYXA7IGp1c3RpZnktY29udGVudDogZmxleC1lbmQ7IH0KICAgIC5tZXRyaWNzIHsg
ZGlzcGxheTogZ3JpZDsgZ3JpZC10ZW1wbGF0ZS1jb2x1bW5zOiByZXBlYXQoMyxtaW5tYXgoMCwx
ZnIpKTsgZ2FwOiAxNHB4OyBtYXJnaW4tYm90dG9tOiAyMnB4OyB9CiAgICAubWV0cmljLC5wYW5l
bCB7IGJhY2tncm91bmQ6IHZhcigtLXN1cmZhY2UpOyBib3JkZXI6IDFweCBzb2xpZCB2YXIoLS1s
aW5lKTsgYm94LXNoYWRvdzogdmFyKC0tc2hhZG93KTsgfQogICAgLm1ldHJpYyB7IHBhZGRpbmc6
IDE3cHg7IGJvcmRlci1yYWRpdXM6IDE0cHg7IH0KICAgIC5tZXRyaWMtaGVhZCB7IGp1c3RpZnkt
Y29udGVudDogc3BhY2UtYmV0d2VlbjsgZ2FwOiA4cHg7IH0KICAgIC5tZXRyaWMtbGFiZWwgeyBj
b2xvcjogdmFyKC0tbXV0ZWQpOyBmb250LXNpemU6IDEycHg7IG1hcmdpbi1ib3R0b206IDhweDsg
fQogICAgLm1ldHJpYy12YWx1ZSB7IGZvbnQtc2l6ZTogMjNweDsgZm9udC13ZWlnaHQ6IDY1MDsg
Zm9udC12YXJpYW50LW51bWVyaWM6IHRhYnVsYXItbnVtczsgfQogICAgLnBhbmVsIHsgYm9yZGVy
LXJhZGl1czogMTZweDsgb3ZlcmZsb3c6IGhpZGRlbjsgfQogICAgLnBhbmVsLWhlYWQgeyBqdXN0
aWZ5LWNvbnRlbnQ6IHNwYWNlLWJldHdlZW47IGdhcDogMThweDsgcGFkZGluZzogMThweCAyMHB4
OyBib3JkZXItYm90dG9tOiAxcHggc29saWQgdmFyKC0tbGluZSk7IH0KICAgIGgyIHsgbWFyZ2lu
OiAwOyBmb250LXNpemU6IDE2cHg7IGZvbnQtd2VpZ2h0OiA2NTA7IH0KICAgIC5wYW5lbC1ub3Rl
IHsgbWFyZ2luOiA1cHggMCAwOyBjb2xvcjogdmFyKC0tbXV0ZWQpOyBmb250LXNpemU6IDEycHg7
IH0KICAgIC5idXR0b24geyBtaW4taGVpZ2h0OiAzNnB4OyBwYWRkaW5nOiA3cHggMTJweDsgYm9y
ZGVyOiAxcHggc29saWQgdmFyKC0tbGluZSk7IGJvcmRlci1yYWRpdXM6IDlweDsgY29sb3I6IHZh
cigtLXRleHQpOyBiYWNrZ3JvdW5kOiB2YXIoLS1zdXJmYWNlKTsgdHJhbnNpdGlvbjogYm9yZGVy
LWNvbG9yIC4xNXMsYmFja2dyb3VuZCAuMTVzLHRyYW5zZm9ybSAuMTVzOyB9CiAgICAuYnV0dG9u
OmhvdmVyOm5vdCg6ZGlzYWJsZWQpIHsgYm9yZGVyLWNvbG9yOiB2YXIoLS1wcmltYXJ5KTsgYmFj
a2dyb3VuZDogdmFyKC0tcHJpbWFyeS1zb2Z0KTsgfQogICAgLmJ1dHRvbjphY3RpdmU6bm90KDpk
aXNhYmxlZCkgeyB0cmFuc2Zvcm06IHRyYW5zbGF0ZVkoMXB4KTsgfQogICAgLmJ1dHRvbi5wcmlt
YXJ5IHsgYm9yZGVyLWNvbG9yOiB2YXIoLS1wcmltYXJ5KTsgYmFja2dyb3VuZDogdmFyKC0tcHJp
bWFyeSk7IGNvbG9yOiBsaWdodC1kYXJrKCNmZmYsIzA3MTAxZSk7IH0KICAgIC5idXR0b24uZGFu
Z2VyIHsgY29sb3I6IHZhcigtLWRhbmdlcik7IH0KICAgIC5idXR0b24uc21hbGwgeyBtaW4taGVp
Z2h0OiAzMnB4OyBwYWRkaW5nOiA1cHggOXB4OyBmb250LXNpemU6IDEycHg7IH0KICAgIC50YWJs
ZS13cmFwIHsgb3ZlcmZsb3cteDogYXV0bzsgfQogICAgdGFibGUgeyB3aWR0aDogMTAwJTsgbWlu
LXdpZHRoOiAxMDIwcHg7IGJvcmRlci1jb2xsYXBzZTogY29sbGFwc2U7IH0KICAgIHRoIHsgcGFk
ZGluZzogMTJweCAxM3B4OyBiYWNrZ3JvdW5kOiB2YXIoLS1zdXJmYWNlLTIpOyBjb2xvcjogdmFy
KC0tbXV0ZWQpOyB0ZXh0LWFsaWduOiBsZWZ0OyBmb250LXNpemU6IDEycHg7IGZvbnQtd2VpZ2h0
OiA2MDA7IH0KICAgIHRkIHsgcGFkZGluZzogMTVweCAxM3B4OyBib3JkZXItdG9wOiAxcHggc29s
aWQgdmFyKC0tbGluZSk7IGZvbnQtc2l6ZTogMTNweDsgdmVydGljYWwtYWxpZ246IG1pZGRsZTsg
fQogICAgdGJvZHkgdHI6Zmlyc3QtY2hpbGQgdGQgeyBib3JkZXItdG9wOiAwOyB9CiAgICAudXNl
ci1jZWxsIHsgZ2FwOiAxMHB4OyB9CiAgICAuYXZhdGFyIHsgd2lkdGg6IDM0cHg7IGhlaWdodDog
MzRweDsgZGlzcGxheTogZ3JpZDsgcGxhY2UtaXRlbXM6IGNlbnRlcjsgZmxleDogMCAwIGF1dG87
IGJvcmRlci1yYWRpdXM6IDEwcHg7IGJhY2tncm91bmQ6IHZhcigtLXByaW1hcnktc29mdCk7IGNv
bG9yOiB2YXIoLS1wcmltYXJ5KTsgZm9udC13ZWlnaHQ6IDY1MDsgfQogICAgLnVzZXJuYW1lIHsg
Zm9udC13ZWlnaHQ6IDY1MDsgfQogICAgLnJvbGUsLnNlY29uZGFyeSB7IG1hcmdpbi10b3A6IDJw
eDsgY29sb3I6IHZhcigtLW11dGVkKTsgZm9udC1zaXplOiAxMXB4OyB9CiAgICAuc3RhdHVzIHsg
Y29sb3I6IHZhcigtLWdvb2QpOyB3aGl0ZS1zcGFjZTogbm93cmFwOyB9CiAgICAuc3RhdHVzLmRp
c2FibGVkIHsgY29sb3I6IHZhcigtLW11dGVkKTsgfQogICAgLnByb3RvY29scyB7IGdhcDogNXB4
OyBmbGV4LXdyYXA6IHdyYXA7IH0KICAgIC5wcm90b2NvbCB7IHBhZGRpbmc6IDNweCA3cHg7IGJv
cmRlci1yYWRpdXM6IDZweDsgYmFja2dyb3VuZDogdmFyKC0tc3VyZmFjZS0yKTsgY29sb3I6IHZh
cigtLW11dGVkKTsgZm9udC1zaXplOiAxMXB4OyB9CiAgICAubnVtYmVyIHsgd2hpdGUtc3BhY2U6
IG5vd3JhcDsgZm9udC12YXJpYW50LW51bWVyaWM6IHRhYnVsYXItbnVtczsgfQogICAgLnF1b3Rh
IHsgbWluLXdpZHRoOiAxNzRweDsgfQogICAgLnF1b3RhLXRleHQgeyBkaXNwbGF5OiBmbGV4OyBq
dXN0aWZ5LWNvbnRlbnQ6IHNwYWNlLWJldHdlZW47IGdhcDogMTBweDsgbWFyZ2luLWJvdHRvbTog
N3B4OyBmb250LXZhcmlhbnQtbnVtZXJpYzogdGFidWxhci1udW1zOyB9CiAgICAudHJhY2sgeyBo
ZWlnaHQ6IDdweDsgb3ZlcmZsb3c6IGhpZGRlbjsgYm9yZGVyLXJhZGl1czogOTlweDsgYmFja2dy
b3VuZDogdmFyKC0tc3VyZmFjZS0yKTsgfQogICAgLmJhciB7IGhlaWdodDogMTAwJTsgYm9yZGVy
LXJhZGl1czogaW5oZXJpdDsgYmFja2dyb3VuZDogdmFyKC0tcHJpbWFyeSk7IH0KICAgIC5iYXIu
d2FybmluZyB7IGJhY2tncm91bmQ6IHZhcigtLXdhcm4pOyB9CiAgICAuYmFyLm92ZXIgeyBiYWNr
Z3JvdW5kOiB2YXIoLS1kYW5nZXIpOyB9CiAgICAuYWN0aW9ucyB7IGp1c3RpZnktY29udGVudDog
ZmxleC1lbmQ7IGdhcDogNnB4OyB3aGl0ZS1zcGFjZTogbm93cmFwOyB9CiAgICAuZW1wdHksLmxv
YWRpbmcgeyBwYWRkaW5nOiA1NnB4IDIwcHg7IHRleHQtYWxpZ246IGNlbnRlcjsgY29sb3I6IHZh
cigtLW11dGVkKTsgfQogICAgLmVycm9yLXBhbmVsIHsgZGlzcGxheTogbm9uZTsgcGFkZGluZzog
MTJweCAxNnB4OyBtYXJnaW4tYm90dG9tOiAxNnB4OyBib3JkZXI6IDFweCBzb2xpZCBjb2xvci1t
aXgoaW4gc3JnYix2YXIoLS1kYW5nZXIpIDQwJSx0cmFuc3BhcmVudCk7IGJvcmRlci1yYWRpdXM6
IDEwcHg7IGNvbG9yOiB2YXIoLS1kYW5nZXIpOyBiYWNrZ3JvdW5kOiBjb2xvci1taXgoaW4gc3Jn
Yix2YXIoLS1kYW5nZXIpIDglLHZhcigtLXN1cmZhY2UpKTsgfQogICAgZGlhbG9nIHsgd2lkdGg6
IG1pbig0NDBweCxjYWxjKDEwMCUgLSAyOHB4KSk7IHBhZGRpbmc6IDA7IGJvcmRlcjogMXB4IHNv
bGlkIHZhcigtLWxpbmUpOyBib3JkZXItcmFkaXVzOiAxNnB4OyBjb2xvcjogdmFyKC0tdGV4dCk7
IGJhY2tncm91bmQ6IHZhcigtLXN1cmZhY2UpOyBib3gtc2hhZG93OiAwIDI0cHggNzBweCByZ2Jh
KDAsMCwwLC4zNSk7IH0KICAgIGRpYWxvZzo6YmFja2Ryb3AgeyBiYWNrZ3JvdW5kOiByZ2JhKDQs
OSwxNywuNjIpOyBiYWNrZHJvcC1maWx0ZXI6IGJsdXIoMnB4KTsgfQogICAgLmRpYWxvZy1ib2R5
IHsgcGFkZGluZzogMjFweDsgfQogICAgLmRpYWxvZy10aXRsZSB7IG1hcmdpbjogMCAwIDZweDsg
Zm9udC1zaXplOiAxOHB4OyB9CiAgICAuZGlhbG9nLWNvcHkgeyBtYXJnaW46IDAgMCAxOHB4OyBj
b2xvcjogdmFyKC0tbXV0ZWQpOyBmb250LXNpemU6IDEzcHg7IGxpbmUtaGVpZ2h0OiAxLjU1OyB9
CiAgICAuZmllbGQgeyBtYXJnaW4tYm90dG9tOiAxNXB4OyB9CiAgICBsYWJlbCB7IGRpc3BsYXk6
IGJsb2NrOyBtYXJnaW4tYm90dG9tOiA2cHg7IGZvbnQtc2l6ZTogMTNweDsgZm9udC13ZWlnaHQ6
IDYwMDsgfQogICAgaW5wdXQgeyB3aWR0aDogMTAwJTsgbWluLWhlaWdodDogNDBweDsgcGFkZGlu
ZzogOHB4IDEwcHg7IGJvcmRlcjogMXB4IHNvbGlkIHZhcigtLWxpbmUpOyBib3JkZXItcmFkaXVz
OiA5cHg7IG91dGxpbmU6IG5vbmU7IGNvbG9yOiB2YXIoLS10ZXh0KTsgYmFja2dyb3VuZDogdmFy
KC0tYmcpOyB9CiAgICBpbnB1dDpmb2N1cyB7IGJvcmRlci1jb2xvcjogdmFyKC0tcHJpbWFyeSk7
IGJveC1zaGFkb3c6IDAgMCAwIDNweCBjb2xvci1taXgoaW4gc3JnYix2YXIoLS1wcmltYXJ5KSAx
OCUsdHJhbnNwYXJlbnQpOyB9CiAgICAuaGVscCB7IG1hcmdpbi10b3A6IDZweDsgY29sb3I6IHZh
cigtLW11dGVkKTsgZm9udC1zaXplOiAxMXB4OyB9CiAgICAuZGlhbG9nLWFjdGlvbnMgeyBqdXN0
aWZ5LWNvbnRlbnQ6IGZsZXgtZW5kOyBnYXA6IDhweDsgbWFyZ2luLXRvcDogMjBweDsgfQogICAg
LnRvYXN0IHsgcG9zaXRpb246IGZpeGVkOyByaWdodDogMjJweDsgYm90dG9tOiAyMHB4OyBtYXgt
d2lkdGg6IG1pbig0MjBweCxjYWxjKDEwMCUgLSA0NHB4KSk7IHBhZGRpbmc6IDExcHggMTRweDsg
Ym9yZGVyLXJhZGl1czogMTBweDsgY29sb3I6IHZhcigtLXN1cmZhY2UpOyBiYWNrZ3JvdW5kOiB2
YXIoLS10ZXh0KTsgYm94LXNoYWRvdzogdmFyKC0tc2hhZG93KTsgb3BhY2l0eTogMDsgdHJhbnNm
b3JtOiB0cmFuc2xhdGVZKDhweCk7IHBvaW50ZXItZXZlbnRzOiBub25lOyB0cmFuc2l0aW9uOiAu
MnM7IGZvbnQtc2l6ZTogMTNweDsgfQogICAgLnRvYXN0LnNob3cgeyBvcGFjaXR5OiAxOyB0cmFu
c2Zvcm06IHRyYW5zbGF0ZVkoMCk7IH0KICAgIC50b2FzdC5lcnJvciB7IGNvbG9yOiAjZmZmOyBi
YWNrZ3JvdW5kOiB2YXIoLS1kYW5nZXIpOyB9CiAgICBAbWVkaWEgKG1heC13aWR0aDo4NTBweCkg
eyAubWV0cmljcyB7IGdyaWQtdGVtcGxhdGUtY29sdW1uczogcmVwZWF0KDIsbWlubWF4KDAsMWZy
KSk7IH0gfQogICAgQG1lZGlhIChtYXgtd2lkdGg6NTYwcHgpIHsKICAgICAgLnNoZWxsIHsgd2lk
dGg6IG1pbigxMDAlIC0gMjRweCwxMTgwcHgpOyBwYWRkaW5nLXRvcDogMThweDsgfQogICAgICAu
dG9wYmFyLC5wYW5lbC1oZWFkIHsgYWxpZ24taXRlbXM6IHN0cmV0Y2g7IGZsZXgtZGlyZWN0aW9u
OiBjb2x1bW47IH0KICAgICAgLnRvcC1hY3Rpb25zIHsganVzdGlmeS1jb250ZW50OiBmbGV4LXN0
YXJ0OyB9CiAgICAgIC5hdXRoIHsgYWxpZ24tc2VsZjogZmxleC1zdGFydDsgfQogICAgICAubWV0
cmljcyB7IGdyaWQtdGVtcGxhdGUtY29sdW1uczogMWZyOyBnYXA6IDEwcHg7IH0KICAgICAgLnBh
bmVsLWhlYWQgLmJ1dHRvbiB7IHdpZHRoOiAxMDAlOyB9CiAgICB9CiAgPC9zdHlsZT4KPC9oZWFk
Pgo8Ym9keT4KICA8bWFpbiBjbGFzcz0ic2hlbGwiPgogICAgPGhlYWRlciBjbGFzcz0idG9wYmFy
Ij4KICAgICAgPGRpdiBjbGFzcz0iYnJhbmQiPjxkaXYgY2xhc3M9ImxvZ28iIGFyaWEtaGlkZGVu
PSJ0cnVlIj7il4c8L2Rpdj48ZGl2PjxoMT7mtYHph4/nrqHnkIbmjqfliLblj7A8L2gxPjxwIGNs
YXNzPSJzdWJ0aXRsZSI+PHNwYW4gaWQ9InBhZ2UtcGF0aCI+566h55CG5ZGY5LiT5bGe6aG16Z2i
PC9zcGFuPiDCtyA8c3BhbiBpZD0idXBkYXRlZCI+5q2j5Zyo6L+e5o6lPC9zcGFuPjwvcD48L2Rp
dj48L2Rpdj4KICAgICAgPGRpdiBjbGFzcz0idG9wLWFjdGlvbnMiPjxkaXYgY2xhc3M9ImF1dGgi
IGlkPSJhZG1pbi1uYW1lIj7nrqHnkIblkZjpqozor4HkuK08L2Rpdj48YnV0dG9uIGNsYXNzPSJi
dXR0b24gc21hbGwiIGlkPSJzZXJ2ZXItcXVvdGEtYnV0dG9uIiB0eXBlPSJidXR0b24iPuiuvue9
ruaciOa1gemHjzwvYnV0dG9uPjwvZGl2PgogICAgPC9oZWFkZXI+CgogICAgPGRpdiBjbGFzcz0i
ZXJyb3ItcGFuZWwiIGlkPSJlcnJvci1wYW5lbCIgcm9sZT0iYWxlcnQiPjwvZGl2PgogICAgPHNl
Y3Rpb24gY2xhc3M9Im1ldHJpY3MiIGFyaWEtbGFiZWw9IuaVtOS9k+a1gemHj+aRmOimgSI+CiAg
ICAgIDxhcnRpY2xlIGNsYXNzPSJtZXRyaWMiPjxkaXYgY2xhc3M9Im1ldHJpYy1sYWJlbCI+55So
5oi35pWw6YePPC9kaXY+PGRpdiBjbGFzcz0ibWV0cmljLXZhbHVlIiBpZD0idXNlci1jb3VudCI+
4oCUPC9kaXY+PC9hcnRpY2xlPgogICAgICA8YXJ0aWNsZSBjbGFzcz0ibWV0cmljIj48ZGl2IGNs
YXNzPSJtZXRyaWMtaGVhZCI+PGRpdiBjbGFzcz0ibWV0cmljLWxhYmVsIj7mnI3liqHlmajmnIjm
tYHph4/kuIrpmZA8L2Rpdj48ZGl2IGNsYXNzPSJzZWNvbmRhcnkiIGlkPSJ0cmFmZmljLW1vbnRo
Ij7igJQ8L2Rpdj48L2Rpdj48ZGl2IGNsYXNzPSJtZXRyaWMtdmFsdWUiIGlkPSJzZXJ2ZXItcXVv
dGEiPuKAlDwvZGl2PjwvYXJ0aWNsZT4KICAgICAgPGFydGljbGUgY2xhc3M9Im1ldHJpYyI+PGRp
diBjbGFzcz0ibWV0cmljLWxhYmVsIj7mnI3liqHlmajmnIjmtYHph4/lj6/nlKg8L2Rpdj48ZGl2
IGNsYXNzPSJtZXRyaWMtdmFsdWUiIGlkPSJzZXJ2ZXItcmVtYWluaW5nIj7igJQ8L2Rpdj48L2Fy
dGljbGU+CiAgICAgIDxhcnRpY2xlIGNsYXNzPSJtZXRyaWMiPjxkaXYgY2xhc3M9Im1ldHJpYy1s
YWJlbCI+5pys5pyI5LiK5LygPC9kaXY+PGRpdiBjbGFzcz0ibWV0cmljLXZhbHVlIiBpZD0idG90
YWwtdXBsb2FkIj7igJQ8L2Rpdj48L2FydGljbGU+CiAgICAgIDxhcnRpY2xlIGNsYXNzPSJtZXRy
aWMiPjxkaXYgY2xhc3M9Im1ldHJpYy1sYWJlbCI+5pys5pyI5LiL6L29PC9kaXY+PGRpdiBjbGFz
cz0ibWV0cmljLXZhbHVlIiBpZD0idG90YWwtZG93bmxvYWQiPuKAlDwvZGl2PjwvYXJ0aWNsZT4K
ICAgICAgPGFydGljbGUgY2xhc3M9Im1ldHJpYyI+PGRpdiBjbGFzcz0ibWV0cmljLWxhYmVsIj7m
nKzmnIjmgLvorqHlt7LnlKg8L2Rpdj48ZGl2IGNsYXNzPSJtZXRyaWMtdmFsdWUiIGlkPSJ0b3Rh
bC11c2VkIj7igJQ8L2Rpdj48L2FydGljbGU+CiAgICA8L3NlY3Rpb24+CgogICAgPHNlY3Rpb24g
Y2xhc3M9InBhbmVsIiBhcmlhLWxhYmVsbGVkYnk9InVzZXJzLXRpdGxlIj4KICAgICAgPGRpdiBj
bGFzcz0icGFuZWwtaGVhZCI+PGRpdj48aDIgaWQ9InVzZXJzLXRpdGxlIj7nlKjmiLfkuI7pop3l
uqY8L2gyPjxwIGNsYXNzPSJwYW5lbC1ub3RlIj5IeXN0ZXJpYTIg5LiOIFRVSUMg5rWB6YeP5ZCI
5bm257uf6K6h77yb6aKd5bqmIDAgR0Ig6KGo56S65LiN6ZmQ6YePPC9wPjwvZGl2PjxidXR0b24g
Y2xhc3M9ImJ1dHRvbiBwcmltYXJ5IiBpZD0iYWRkLXVzZXIiIHR5cGU9ImJ1dHRvbiI+77yLIOaW
sOW7uueUqOaItzwvYnV0dG9uPjwvZGl2PgogICAgICA8ZGl2IGNsYXNzPSJ0YWJsZS13cmFwIj4K
ICAgICAgICA8dGFibGUgYXJpYS1sYWJlbD0i55So5oi35rWB6YeP5ZKM6ZmQ6aKdIj4KICAgICAg
ICAgIDx0aGVhZD48dHI+PHRoPueUqOaItzwvdGg+PHRoPueKtuaAgTwvdGg+PHRoPuWNj+iuruS4
juerr+WPozwvdGg+PHRoPuS4iuS8oDwvdGg+PHRoPuS4i+i9vTwvdGg+PHRoIHRpdGxlPSLor6Xn
lKjmiLfmnKzmnIjkuIrkvKDkuI7kuIvovb3kuYvlkowiPuS4quS6uuW3sueUqDwvdGg+PHRoPuaA
u+a1gemHjzwvdGg+PHRoIHN0eWxlPSJ0ZXh0LWFsaWduOnJpZ2h0Ij7nrqHnkIY8L3RoPjwvdHI+
PC90aGVhZD4KICAgICAgICAgIDx0Ym9keSBpZD0idXNlcnMiPjx0cj48dGQgY29sc3Bhbj0iOCIg
Y2xhc3M9ImxvYWRpbmciPuato+WcqOivu+WPlueUqOaIt+aVsOaNruKApjwvdGQ+PC90cj48L3Ri
b2R5PgogICAgICAgIDwvdGFibGU+CiAgICAgIDwvZGl2PgogICAgPC9zZWN0aW9uPgogIDwvbWFp
bj4KCiAgPGRpYWxvZyBpZD0iZWRpdC1kaWFsb2ciPgogICAgPGZvcm0gY2xhc3M9ImRpYWxvZy1i
b2R5IiBpZD0iZWRpdC1mb3JtIj4KICAgICAgPGgyIGNsYXNzPSJkaWFsb2ctdGl0bGUiIGlkPSJl
ZGl0LXRpdGxlIj7mlrDlu7rnlKjmiLc8L2gyPgogICAgICA8cCBjbGFzcz0iZGlhbG9nLWNvcHki
IGlkPSJlZGl0LWNvcHkiPuWIm+W7uuaIkOWKn+WQjuS8muiHquWKqOeUn+aIkOeLrOeri+iuoumY
heWcsOWdgOOAgUh5c3RlcmlhMiDkuI4gVFVJQyDnq6/lj6PjgII8L3A+CiAgICAgIDxkaXYgY2xh
c3M9ImZpZWxkIiBpZD0idXNlcm5hbWUtZmllbGQiPjxsYWJlbCBmb3I9InVzZXJuYW1lIj7nlKjm
iLflkI08L2xhYmVsPjxpbnB1dCBpZD0idXNlcm5hbWUiIG1heGxlbmd0aD0iMzIiIHBhdHRlcm49
IltBLVphLXowLTlfLV17MSwzMn0iIGF1dG9jb21wbGV0ZT0ib2ZmIiBwbGFjZWhvbGRlcj0i5L6L
5aaCIGFsaWNlIj48ZGl2IGNsYXNzPSJoZWxwIj7lj6rog73ljIXlkKvlrZfmr43jgIHmlbDlrZfj
gIHkuIvliJLnur/lkozov57lrZfnrKY8L2Rpdj48L2Rpdj4KICAgICAgPGRpdiBjbGFzcz0iZmll
bGQiPjxsYWJlbCBmb3I9InF1b3RhIj7mtYHph4/pmZDpop3vvIhHQu+8iTwvbGFiZWw+PGlucHV0
IGlkPSJxdW90YSIgdHlwZT0ibnVtYmVyIiBtaW49IjAiIHN0ZXA9IjAuMSIgdmFsdWU9IjEwMCIg
aW5wdXRtb2RlPSJkZWNpbWFsIiByZXF1aXJlZD48ZGl2IGNsYXNzPSJoZWxwIj4wIOihqOekuuS4
jemZkOmHj++8m+S/ruaUuemineW6puS4jeS8mua4hemZpOW3sue7j+S9v+eUqOeahOa1gemHjzwv
ZGl2PjwvZGl2PgogICAgICA8ZGl2IGNsYXNzPSJkaWFsb2ctYWN0aW9ucyI+PGJ1dHRvbiBjbGFz
cz0iYnV0dG9uIiBkYXRhLWNsb3NlPSJlZGl0LWRpYWxvZyIgdHlwZT0iYnV0dG9uIj7lj5bmtog8
L2J1dHRvbj48YnV0dG9uIGNsYXNzPSJidXR0b24gcHJpbWFyeSIgaWQ9ImVkaXQtc3VibWl0IiB0
eXBlPSJzdWJtaXQiPuWIm+W7uueUqOaItzwvYnV0dG9uPjwvZGl2PgogICAgPC9mb3JtPgogIDwv
ZGlhbG9nPgoKICA8ZGlhbG9nIGlkPSJkZWxldGUtZGlhbG9nIj4KICAgIDxkaXYgY2xhc3M9ImRp
YWxvZy1ib2R5Ij48aDIgY2xhc3M9ImRpYWxvZy10aXRsZSI+5Yig6Zmk55So5oi3PC9oMj48cCBj
bGFzcz0iZGlhbG9nLWNvcHkiIGlkPSJkZWxldGUtY29weSI+PC9wPjxkaXYgY2xhc3M9ImRpYWxv
Zy1hY3Rpb25zIj48YnV0dG9uIGNsYXNzPSJidXR0b24iIGRhdGEtY2xvc2U9ImRlbGV0ZS1kaWFs
b2ciIHR5cGU9ImJ1dHRvbiI+5Y+W5raIPC9idXR0b24+PGJ1dHRvbiBjbGFzcz0iYnV0dG9uIGRh
bmdlciIgaWQ9ImRlbGV0ZS1jb25maXJtIiB0eXBlPSJidXR0b24iPuehruiupOWIoOmZpDwvYnV0
dG9uPjwvZGl2PjwvZGl2PgogIDwvZGlhbG9nPgogIDxkaWFsb2cgaWQ9InNlcnZlci1xdW90YS1k
aWFsb2ciPgogICAgPGZvcm0gY2xhc3M9ImRpYWxvZy1ib2R5IiBpZD0ic2VydmVyLXF1b3RhLWZv
cm0iPgogICAgICA8aDIgY2xhc3M9ImRpYWxvZy10aXRsZSI+6K6+572u5pyN5Yqh5Zmo5pyI5rWB
6YePPC9oMj4KICAgICAgPHAgY2xhc3M9ImRpYWxvZy1jb3B5Ij7ov5nmmK/miYDmnInkuI3pmZDp
op3nlKjmiLflkoznrqHnkIblkZjorqLpmIXlhbHlkIzmmL7npLrnmoTmgLvmtYHph4/kuIrpmZDj
gILmr4/kuKroh6rnhLbmnIjoh6rliqjph43mlrDnu5/orqHvvIzpu5jorqQgNCBUQuOAgjwvcD4K
ICAgICAgPGRpdiBjbGFzcz0iZmllbGQiPjxsYWJlbCBmb3I9InNlcnZlci1xdW90YS1pbnB1dCI+
5pyI5rWB6YeP5LiK6ZmQ77yIVELvvIk8L2xhYmVsPjxpbnB1dCBpZD0ic2VydmVyLXF1b3RhLWlu
cHV0IiB0eXBlPSJudW1iZXIiIG1pbj0iMC4wMSIgc3RlcD0iMC4wMSIgdmFsdWU9IjQiIGlucHV0
bW9kZT0iZGVjaW1hbCIgcmVxdWlyZWQ+PGRpdiBjbGFzcz0iaGVscCI+5b+F6aG75aSn5LqOIDDv
vJvkv67mlLnlkI7kvJrnq4vljbPmm7TmlrDnvZHpobXjgIHorqLpmIXov5vluqbmnaHlkozmlbTk
vZPmtYHph4/mo4DmtYvnu4Q8L2Rpdj48L2Rpdj4KICAgICAgPGRpdiBjbGFzcz0iZGlhbG9nLWFj
dGlvbnMiPjxidXR0b24gY2xhc3M9ImJ1dHRvbiIgZGF0YS1jbG9zZT0ic2VydmVyLXF1b3RhLWRp
YWxvZyIgdHlwZT0iYnV0dG9uIj7lj5bmtog8L2J1dHRvbj48YnV0dG9uIGNsYXNzPSJidXR0b24g
cHJpbWFyeSIgdHlwZT0ic3VibWl0Ij7kv53lrZjorr7nva48L2J1dHRvbj48L2Rpdj4KICAgIDwv
Zm9ybT4KICA8L2RpYWxvZz4KICA8ZGl2IGNsYXNzPSJ0b2FzdCIgaWQ9InRvYXN0IiBhcmlhLWxp
dmU9InBvbGl0ZSI+PC9kaXY+CgogIDxzY3JpcHQ+CiAgICAoKCkgPT4gewogICAgICAndXNlIHN0
cmljdCc7CiAgICAgIGNvbnN0ICQgPSBzZWxlY3RvciA9PiBkb2N1bWVudC5xdWVyeVNlbGVjdG9y
KHNlbGVjdG9yKTsKICAgICAgY29uc3QgdXNlcnNCb2R5ID0gJCgnI3VzZXJzJyk7CiAgICAgIGNv
bnN0IGVkaXREaWFsb2cgPSAkKCcjZWRpdC1kaWFsb2cnKTsKICAgICAgY29uc3QgZGVsZXRlRGlh
bG9nID0gJCgnI2RlbGV0ZS1kaWFsb2cnKTsKICAgICAgY29uc3Qgc2VydmVyUXVvdGFEaWFsb2cg
PSAkKCcjc2VydmVyLXF1b3RhLWRpYWxvZycpOwogICAgICBjb25zdCBlZGl0Rm9ybSA9ICQoJyNl
ZGl0LWZvcm0nKTsKICAgICAgY29uc3Qgc3RhdGUgPSB7IHVzZXJzOiBbXSwgZWRpdGluZzogbnVs
bCwgZGVsZXRpbmc6IG51bGwsIGJ1c3k6IGZhbHNlIH07CiAgICAgIGxldCB0b2FzdFRpbWVyOwoK
ICAgICAgY29uc3QgZXNjYXBlSHRtbCA9IHZhbHVlID0+IFN0cmluZyh2YWx1ZSkucmVwbGFjZSgv
WyY8PiInXS9nLCBjaGFyID0+ICh7JyYnOicmYW1wOycsJzwnOicmbHQ7JywnPic6JyZndDsnLCci
JzonJnF1b3Q7JywiJyI6JyYjMzk7J31bY2hhcl0pKTsKICAgICAgY29uc3QgZm9ybWF0Qnl0ZXMg
PSB2YWx1ZSA9PiB7CiAgICAgICAgY29uc3QgYnl0ZXMgPSBOdW1iZXIodmFsdWUgfHwgMCksIHVu
aXRzID0gWydCJywnS0InLCdNQicsJ0dCJywnVEInXTsKICAgICAgICBpZiAoYnl0ZXMgPD0gMCkg
cmV0dXJuICcwIEInOwogICAgICAgIGNvbnN0IGluZGV4ID0gTWF0aC5taW4oTWF0aC5mbG9vcihN
YXRoLmxvZyhieXRlcykgLyBNYXRoLmxvZygxMDI0KSksIHVuaXRzLmxlbmd0aCAtIDEpOwogICAg
ICAgIHJldHVybiBgJHsoYnl0ZXMgLyAxMDI0ICoqIGluZGV4KS50b0ZpeGVkKGluZGV4IDwgMyA/
IDEgOiAyKX0gJHt1bml0c1tpbmRleF19YDsKICAgICAgfTsKICAgICAgZnVuY3Rpb24gdG9hc3Qo
bWVzc2FnZSwgZXJyb3IgPSBmYWxzZSkgewogICAgICAgIGNvbnN0IGVsZW1lbnQgPSAkKCcjdG9h
c3QnKTsgZWxlbWVudC50ZXh0Q29udGVudCA9IG1lc3NhZ2U7IGVsZW1lbnQuY2xhc3NOYW1lID0g
YHRvYXN0IHNob3cke2Vycm9yID8gJyBlcnJvcicgOiAnJ31gOwogICAgICAgIGNsZWFyVGltZW91
dCh0b2FzdFRpbWVyKTsgdG9hc3RUaW1lciA9IHNldFRpbWVvdXQoKCkgPT4gZWxlbWVudC5jbGFz
c05hbWUgPSAndG9hc3QnLCAyNjAwKTsKICAgICAgfQogICAgICBmdW5jdGlvbiBzZXRFcnJvciht
ZXNzYWdlID0gJycpIHsgY29uc3QgcGFuZWwgPSAkKCcjZXJyb3ItcGFuZWwnKTsgcGFuZWwudGV4
dENvbnRlbnQgPSBtZXNzYWdlOyBwYW5lbC5zdHlsZS5kaXNwbGF5ID0gbWVzc2FnZSA/ICdibG9j
aycgOiAnbm9uZSc7IH0KICAgICAgYXN5bmMgZnVuY3Rpb24gcmVxdWVzdChwYXRoLCBvcHRpb25z
ID0ge30pIHsKICAgICAgICBjb25zdCBoZWFkZXJzID0geyBBY2NlcHQ6ICdhcHBsaWNhdGlvbi9q
c29uJywgLi4uKG9wdGlvbnMuaGVhZGVycyB8fCB7fSkgfTsKICAgICAgICBpZiAob3B0aW9ucy5t
ZXRob2QgJiYgb3B0aW9ucy5tZXRob2QgIT09ICdHRVQnKSB7IGhlYWRlcnNbJ0NvbnRlbnQtVHlw
ZSddID0gJ2FwcGxpY2F0aW9uL2pzb24nOyBoZWFkZXJzWydYLVNCLUFkbWluJ10gPSAnMSc7IH0K
ICAgICAgICBjb25zdCByZXNwb25zZSA9IGF3YWl0IGZldGNoKGBhcGkke3BhdGh9YCwgeyBjYWNo
ZTogJ25vLXN0b3JlJywgY3JlZGVudGlhbHM6ICdzYW1lLW9yaWdpbicsIC4uLm9wdGlvbnMsIGhl
YWRlcnMgfSk7CiAgICAgICAgbGV0IGRhdGEgPSB7fTsgdHJ5IHsgZGF0YSA9IGF3YWl0IHJlc3Bv
bnNlLmpzb24oKTsgfSBjYXRjaCAoXykge30KICAgICAgICBpZiAoIXJlc3BvbnNlLm9rKSB0aHJv
dyBuZXcgRXJyb3IoZGF0YS5lcnJvciB8fCBg6K+35rGC5aSx6LSl77yIJHtyZXNwb25zZS5zdGF0
dXN977yJYCk7CiAgICAgICAgcmV0dXJuIGRhdGE7CiAgICAgIH0KICAgICAgZnVuY3Rpb24gcmVu
ZGVyKGRhdGEpIHsKICAgICAgICBzdGF0ZS51c2VycyA9IGRhdGEudXNlcnMgfHwgW107CiAgICAg
ICAgc3RhdGUuc2VydmVyUXVvdGFUYiA9IGRhdGEuc2VydmVyX21vbnRobHlfcXVvdGFfdGI7CiAg
ICAgICAgJCgnI2FkbWluLW5hbWUnKS50ZXh0Q29udGVudCA9IGDnrqHnkIblkZggJHtkYXRhLmFk
bWlufWA7CiAgICAgICAgJCgnI3VzZXItY291bnQnKS50ZXh0Q29udGVudCA9IGRhdGEudG90YWxz
LnVzZXJfY291bnQ7CiAgICAgICAgJCgnI3NlcnZlci1xdW90YScpLnRleHRDb250ZW50ID0gZm9y
bWF0Qnl0ZXMoZGF0YS5zZXJ2ZXJfbW9udGhseV9xdW90YV9ieXRlcyk7CiAgICAgICAgJCgnI3Nl
cnZlci1yZW1haW5pbmcnKS50ZXh0Q29udGVudCA9IGZvcm1hdEJ5dGVzKGRhdGEuc2VydmVyX21v
bnRobHlfcmVtYWluaW5nX2J5dGVzKTsKICAgICAgICAkKCcjdHJhZmZpYy1tb250aCcpLnRleHRD
b250ZW50ID0gYCR7ZGF0YS50cmFmZmljX21vbnRofSBVVENgOwogICAgICAgICQoJyN0b3RhbC11
cGxvYWQnKS50ZXh0Q29udGVudCA9IGZvcm1hdEJ5dGVzKGRhdGEudG90YWxzLnVwbG9hZF9ieXRl
cyk7CiAgICAgICAgJCgnI3RvdGFsLWRvd25sb2FkJykudGV4dENvbnRlbnQgPSBmb3JtYXRCeXRl
cyhkYXRhLnRvdGFscy5kb3dubG9hZF9ieXRlcyk7CiAgICAgICAgJCgnI3RvdGFsLXVzZWQnKS50
ZXh0Q29udGVudCA9IGZvcm1hdEJ5dGVzKGRhdGEudG90YWxzLnVzZWRfYnl0ZXMpOwogICAgICAg
ICQoJyN1cGRhdGVkJykudGV4dENvbnRlbnQgPSBg5pu05paw5LqOICR7bmV3IERhdGUoZGF0YS5y
ZWZyZXNoZWRfYXQpLnRvTG9jYWxlVGltZVN0cmluZygpfWA7CiAgICAgICAgJCgnI3BhZ2UtcGF0
aCcpLnRleHRDb250ZW50ID0gbG9jYXRpb24ucGF0aG5hbWUucmVwbGFjZSgvW2EtZjAtOV17NjR9
LywgdG9rZW4gPT4gYCR7dG9rZW4uc2xpY2UoMCw2KX3igKYke3Rva2VuLnNsaWNlKC02KX1gKTsK
ICAgICAgICBpZiAoIXN0YXRlLnVzZXJzLmxlbmd0aCkgeyB1c2Vyc0JvZHkuaW5uZXJIVE1MID0g
Jzx0cj48dGQgY29sc3Bhbj0iOCIgY2xhc3M9ImVtcHR5Ij7mmoLml6DnlKjmiLc8L3RkPjwvdHI+
JzsgcmV0dXJuOyB9CiAgICAgICAgdXNlcnNCb2R5LmlubmVySFRNTCA9IHN0YXRlLnVzZXJzLm1h
cCh1c2VyID0+IHsKICAgICAgICAgIGNvbnN0IGRpc3BsYXlUb3RhbCA9IHVzZXIuZGlzcGxheV90
b3RhbF9ieXRlczsKICAgICAgICAgIGNvbnN0IGRpc3BsYXlVc2VkID0gdXNlci5kaXNwbGF5X3Vz
ZWRfYnl0ZXM7CiAgICAgICAgICBjb25zdCBwZXJjZW50ID0gZGlzcGxheVRvdGFsID8gTWF0aC5t
aW4oMTAwLCBkaXNwbGF5VXNlZCAvIGRpc3BsYXlUb3RhbCAqIDEwMCkgOiAwOwogICAgICAgICAg
Y29uc3QgbGV2ZWwgPSBwZXJjZW50ID49IDEwMCA/ICdvdmVyJyA6IHBlcmNlbnQgPj0gODAgPyAn
d2FybmluZycgOiAnJzsKICAgICAgICAgIGNvbnN0IHBvcnRzID0gW2BIeXN0ZXJpYTIgJHt1c2Vy
Lmh5c3RlcmlhMl9wb3J0fWBdOyBpZiAodXNlci50dWljX3BvcnQpIHBvcnRzLnB1c2goYFRVSUMg
JHt1c2VyLnR1aWNfcG9ydH1gKTsKICAgICAgICAgIHJldHVybiBgPHRyPgogICAgICAgICAgICA8
dGQ+PGRpdiBjbGFzcz0idXNlci1jZWxsIj48ZGl2IGNsYXNzPSJhdmF0YXIiPiR7ZXNjYXBlSHRt
bCh1c2VyLnVzZXJuYW1lLnNsaWNlKDAsMSkudG9VcHBlckNhc2UoKSl9PC9kaXY+PGRpdj48ZGl2
IGNsYXNzPSJ1c2VybmFtZSI+JHtlc2NhcGVIdG1sKHVzZXIudXNlcm5hbWUpfTwvZGl2PjxkaXYg
Y2xhc3M9InJvbGUiPiR7dXNlci5pc19hZG1pbiA/ICfnrqHnkIblkZgnIDogJ+aZrumAmueUqOaI
tyd9PC9kaXY+PC9kaXY+PC9kaXY+PC90ZD4KICAgICAgICAgICAgPHRkPjxzcGFuIGNsYXNzPSJz
dGF0dXMgJHt1c2VyLmVuYWJsZWQgPyAnJyA6ICdkaXNhYmxlZCd9Ij4ke3VzZXIuZW5hYmxlZCA/
ICfil48g5ZCv55SoJyA6ICfil4sg5YGc55SoJ308L3NwYW4+PC90ZD4KICAgICAgICAgICAgPHRk
PjxkaXYgY2xhc3M9InByb3RvY29scyI+JHtwb3J0cy5tYXAocG9ydCA9PiBgPHNwYW4gY2xhc3M9
InByb3RvY29sIj4ke2VzY2FwZUh0bWwocG9ydCl9PC9zcGFuPmApLmpvaW4oJycpfTwvZGl2Pjwv
dGQ+CiAgICAgICAgICAgIDx0ZCBjbGFzcz0ibnVtYmVyIj4ke2Zvcm1hdEJ5dGVzKHVzZXIudXBs
b2FkX2J5dGVzKX08L3RkPjx0ZCBjbGFzcz0ibnVtYmVyIj4ke2Zvcm1hdEJ5dGVzKHVzZXIuZG93
bmxvYWRfYnl0ZXMpfTwvdGQ+PHRkIGNsYXNzPSJudW1iZXIiPiR7Zm9ybWF0Qnl0ZXModXNlci51
c2VkX2J5dGVzKX08L3RkPgogICAgICAgICAgICA8dGQ+PGRpdiBjbGFzcz0icXVvdGEiPjxkaXYg
Y2xhc3M9InF1b3RhLXRleHQiPjxzcGFuPiR7Zm9ybWF0Qnl0ZXMoZGlzcGxheVVzZWQpfTwvc3Bh
bj48c3Bhbj4ke2Zvcm1hdEJ5dGVzKGRpc3BsYXlUb3RhbCl9PC9zcGFuPjwvZGl2PjxkaXYgY2xh
c3M9InRyYWNrIj48ZGl2IGNsYXNzPSJiYXIgJHtsZXZlbH0iIHN0eWxlPSJ3aWR0aDoke3BlcmNl
bnR9JSI+PC9kaXY+PC9kaXY+PGRpdiBjbGFzcz0ic2Vjb25kYXJ5Ij4ke3VzZXIudXNlc19zZXJ2
ZXJfcXVvdGEgPyAn5YWx5Lqr5pyN5Yqh5Zmo5pyI5rWB6YePJyA6ICfkuKrkurrpmZDpop0nfSDC
tyDlj6/nlKggJHtmb3JtYXRCeXRlcyh1c2VyLmRpc3BsYXlfcmVtYWluaW5nX2J5dGVzKX08L2Rp
dj48L2Rpdj48L3RkPgogICAgICAgICAgICA8dGQ+PGRpdiBjbGFzcz0iYWN0aW9ucyI+PGJ1dHRv
biBjbGFzcz0iYnV0dG9uIHNtYWxsIiBkYXRhLWFjdGlvbj0iY29weSIgZGF0YS11c2VyPSIke2Vz
Y2FwZUh0bWwodXNlci51c2VybmFtZSl9Ij7orqLpmIU8L2J1dHRvbj48YnV0dG9uIGNsYXNzPSJi
dXR0b24gc21hbGwiIGRhdGEtYWN0aW9uPSJxdW90YSIgZGF0YS11c2VyPSIke2VzY2FwZUh0bWwo
dXNlci51c2VybmFtZSl9Ij7pop3luqY8L2J1dHRvbj48YnV0dG9uIGNsYXNzPSJidXR0b24gc21h
bGwiIGRhdGEtYWN0aW9uPSJ0b2dnbGUiIGRhdGEtdXNlcj0iJHtlc2NhcGVIdG1sKHVzZXIudXNl
cm5hbWUpfSIgJHt1c2VyLmlzX2FkbWluID8gJ2Rpc2FibGVkJyA6ICcnfT4ke3VzZXIuZW5hYmxl
ZCA/ICflgZznlKgnIDogJ+WQr+eUqCd9PC9idXR0b24+PGJ1dHRvbiBjbGFzcz0iYnV0dG9uIHNt
YWxsIGRhbmdlciIgZGF0YS1hY3Rpb249ImRlbGV0ZSIgZGF0YS11c2VyPSIke2VzY2FwZUh0bWwo
dXNlci51c2VybmFtZSl9IiAke3VzZXIuaXNfYWRtaW4gPyAnZGlzYWJsZWQnIDogJyd9PuWIoOmZ
pDwvYnV0dG9uPjwvZGl2PjwvdGQ+CiAgICAgICAgICA8L3RyPmA7CiAgICAgICAgfSkuam9pbign
Jyk7CiAgICAgIH0KICAgICAgYXN5bmMgZnVuY3Rpb24gbG9hZChzaG93RXJyb3IgPSB0cnVlKSB7
CiAgICAgICAgdHJ5IHsgY29uc3QgZGF0YSA9IGF3YWl0IHJlcXVlc3QoJy91c2VycycpOyBzZXRF
cnJvcigpOyByZW5kZXIoZGF0YSk7IH0KICAgICAgICBjYXRjaCAoZXJyb3IpIHsgaWYgKHNob3dF
cnJvcikgc2V0RXJyb3IoZXJyb3IubWVzc2FnZSk7IH0KICAgICAgfQogICAgICBhc3luYyBmdW5j
dGlvbiBtdXRhdGUocGF0aCwgbWV0aG9kLCBib2R5LCBzdWNjZXNzKSB7CiAgICAgICAgaWYgKHN0
YXRlLmJ1c3kpIHJldHVybjsgc3RhdGUuYnVzeSA9IHRydWU7CiAgICAgICAgdHJ5IHsgYXdhaXQg
cmVxdWVzdChwYXRoLCB7IG1ldGhvZCwgYm9keTogYm9keSA9PT0gdW5kZWZpbmVkID8gdW5kZWZp
bmVkIDogSlNPTi5zdHJpbmdpZnkoYm9keSkgfSk7IHRvYXN0KHN1Y2Nlc3MpOyBhd2FpdCBsb2Fk
KCk7IHJldHVybiB0cnVlOyB9CiAgICAgICAgY2F0Y2ggKGVycm9yKSB7IHRvYXN0KGVycm9yLm1l
c3NhZ2UsIHRydWUpOyByZXR1cm4gZmFsc2U7IH0KICAgICAgICBmaW5hbGx5IHsgc3RhdGUuYnVz
eSA9IGZhbHNlOyB9CiAgICAgIH0KICAgICAgZnVuY3Rpb24gb3BlbkNyZWF0ZSgpIHsKICAgICAg
ICBzdGF0ZS5lZGl0aW5nID0gbnVsbDsgJCgnI2VkaXQtdGl0bGUnKS50ZXh0Q29udGVudCA9ICfm
lrDlu7rnlKjmiLcnOyAkKCcjZWRpdC1jb3B5JykudGV4dENvbnRlbnQgPSAn5Yib5bu65oiQ5Yqf
5ZCO5Lya6Ieq5Yqo55Sf5oiQ54us56uL6K6i6ZiF5Zyw5Z2A44CBSHlzdGVyaWEyIOS4jiBUVUlD
IOerr+WPo+OAgic7CiAgICAgICAgJCgnI3VzZXJuYW1lLWZpZWxkJykuaGlkZGVuID0gZmFsc2U7
ICQoJyN1c2VybmFtZScpLnJlcXVpcmVkID0gdHJ1ZTsgJCgnI3VzZXJuYW1lJykudmFsdWUgPSAn
JzsgJCgnI3F1b3RhJykudmFsdWUgPSAnMTAwJzsgJCgnI2VkaXQtc3VibWl0JykudGV4dENvbnRl
bnQgPSAn5Yib5bu655So5oi3JzsgZWRpdERpYWxvZy5zaG93TW9kYWwoKTsgJCgnI3VzZXJuYW1l
JykuZm9jdXMoKTsKICAgICAgfQogICAgICBmdW5jdGlvbiBvcGVuUXVvdGEodXNlcikgewogICAg
ICAgIHN0YXRlLmVkaXRpbmcgPSB1c2VyLnVzZXJuYW1lOyAkKCcjZWRpdC10aXRsZScpLnRleHRD
b250ZW50ID0gYOS/ruaUuSAke3VzZXIudXNlcm5hbWV9IOeahOa1gemHj+mZkOminWA7ICQoJyNl
ZGl0LWNvcHknKS50ZXh0Q29udGVudCA9ICfmlrDnmoTpop3luqbkvJrnq4vljbPlhpnlhaXorqLp
mIXkuK3nmoTmtYHph4/kv6Hmga/vvIzkuI3kvJrph43nva7lt7LnlKjmtYHph4/jgIInOwogICAg
ICAgICQoJyN1c2VybmFtZS1maWVsZCcpLmhpZGRlbiA9IHRydWU7ICQoJyN1c2VybmFtZScpLnJl
cXVpcmVkID0gZmFsc2U7ICQoJyNxdW90YScpLnZhbHVlID0gdXNlci5xdW90YV9nYjsgJCgnI2Vk
aXQtc3VibWl0JykudGV4dENvbnRlbnQgPSAn5L+d5a2Y6ZmQ6aKdJzsgZWRpdERpYWxvZy5zaG93
TW9kYWwoKTsgJCgnI3F1b3RhJykuZm9jdXMoKTsKICAgICAgfQogICAgICBhc3luYyBmdW5jdGlv
biBjb3B5U3Vic2NyaXB0aW9uKHVzZXIpIHsKICAgICAgICB0cnkgeyBhd2FpdCBuYXZpZ2F0b3Iu
Y2xpcGJvYXJkLndyaXRlVGV4dCh1c2VyLnN1YnNjcmlwdGlvbik7IHRvYXN0KGAke3VzZXIudXNl
cm5hbWV9IOeahOiuoumYheWcsOWdgOW3suWkjeWItmApOyB9CiAgICAgICAgY2F0Y2ggKF8pIHsg
Y29uc3QgYXJlYSA9IGRvY3VtZW50LmNyZWF0ZUVsZW1lbnQoJ3RleHRhcmVhJyk7IGFyZWEudmFs
dWUgPSB1c2VyLnN1YnNjcmlwdGlvbjsgZG9jdW1lbnQuYm9keS5hcHBlbmQoYXJlYSk7IGFyZWEu
c2VsZWN0KCk7IGRvY3VtZW50LmV4ZWNDb21tYW5kKCdjb3B5Jyk7IGFyZWEucmVtb3ZlKCk7IHRv
YXN0KGAke3VzZXIudXNlcm5hbWV9IOeahOiuoumYheWcsOWdgOW3suWkjeWItmApOyB9CiAgICAg
IH0KICAgICAgJCgnI2FkZC11c2VyJykuYWRkRXZlbnRMaXN0ZW5lcignY2xpY2snLCBvcGVuQ3Jl
YXRlKTsKICAgICAgJCgnI3NlcnZlci1xdW90YS1idXR0b24nKS5hZGRFdmVudExpc3RlbmVyKCdj
bGljaycsICgpID0+IHsgJCgnI3NlcnZlci1xdW90YS1pbnB1dCcpLnZhbHVlID0gc3RhdGUuc2Vy
dmVyUXVvdGFUYiB8fCA0OyBzZXJ2ZXJRdW90YURpYWxvZy5zaG93TW9kYWwoKTsgJCgnI3NlcnZl
ci1xdW90YS1pbnB1dCcpLmZvY3VzKCk7IH0pOwogICAgICBkb2N1bWVudC5xdWVyeVNlbGVjdG9y
QWxsKCdbZGF0YS1jbG9zZV0nKS5mb3JFYWNoKGJ1dHRvbiA9PiBidXR0b24uYWRkRXZlbnRMaXN0
ZW5lcignY2xpY2snLCAoKSA9PiAkKGAjJHtidXR0b24uZGF0YXNldC5jbG9zZX1gKS5jbG9zZSgp
KSk7CiAgICAgIGVkaXRGb3JtLmFkZEV2ZW50TGlzdGVuZXIoJ3N1Ym1pdCcsIGFzeW5jIGV2ZW50
ID0+IHsKICAgICAgICBldmVudC5wcmV2ZW50RGVmYXVsdCgpOyBjb25zdCBxdW90YSA9ICQoJyNx
dW90YScpLnZhbHVlOwogICAgICAgIGlmIChzdGF0ZS5lZGl0aW5nKSB7IGlmIChhd2FpdCBtdXRh
dGUoYC91c2Vycy8ke2VuY29kZVVSSUNvbXBvbmVudChzdGF0ZS5lZGl0aW5nKX0vcXVvdGFgLCAn
UEFUQ0gnLCB7IHF1b3RhX2diOiBxdW90YSB9LCBgJHtzdGF0ZS5lZGl0aW5nfSDnmoTpop3luqbl
t7Lmm7TmlrBgKSkgZWRpdERpYWxvZy5jbG9zZSgpOyB9CiAgICAgICAgZWxzZSB7IGNvbnN0IHVz
ZXJuYW1lID0gJCgnI3VzZXJuYW1lJykudmFsdWUudHJpbSgpOyBpZiAoYXdhaXQgbXV0YXRlKCcv
dXNlcnMnLCAnUE9TVCcsIHsgdXNlcm5hbWUsIHF1b3RhX2diOiBxdW90YSB9LCBg55So5oi3ICR7
dXNlcm5hbWV9IOW3suWIm+W7umApKSBlZGl0RGlhbG9nLmNsb3NlKCk7IH0KICAgICAgfSk7CiAg
ICAgICQoJyNzZXJ2ZXItcXVvdGEtZm9ybScpLmFkZEV2ZW50TGlzdGVuZXIoJ3N1Ym1pdCcsIGFz
eW5jIGV2ZW50ID0+IHsKICAgICAgICBldmVudC5wcmV2ZW50RGVmYXVsdCgpOyBjb25zdCBxdW90
YVRiID0gJCgnI3NlcnZlci1xdW90YS1pbnB1dCcpLnZhbHVlOwogICAgICAgIGlmIChhd2FpdCBt
dXRhdGUoJy9zZXJ2ZXItcXVvdGEnLCAnUEFUQ0gnLCB7IHF1b3RhX3RiOiBxdW90YVRiIH0sICfm
nI3liqHlmajmnIjmtYHph4/kuIrpmZDlt7Lmm7TmlrAnKSkgc2VydmVyUXVvdGFEaWFsb2cuY2xv
c2UoKTsKICAgICAgfSk7CiAgICAgIHVzZXJzQm9keS5hZGRFdmVudExpc3RlbmVyKCdjbGljaycs
IGFzeW5jIGV2ZW50ID0+IHsKICAgICAgICBjb25zdCBidXR0b24gPSBldmVudC50YXJnZXQuY2xv
c2VzdCgnW2RhdGEtYWN0aW9uXScpOyBpZiAoIWJ1dHRvbikgcmV0dXJuOwogICAgICAgIGNvbnN0
IHVzZXIgPSBzdGF0ZS51c2Vycy5maW5kKGl0ZW0gPT4gaXRlbS51c2VybmFtZSA9PT0gYnV0dG9u
LmRhdGFzZXQudXNlcik7IGlmICghdXNlcikgcmV0dXJuOwogICAgICAgIGlmIChidXR0b24uZGF0
YXNldC5hY3Rpb24gPT09ICdjb3B5JykgY29weVN1YnNjcmlwdGlvbih1c2VyKTsKICAgICAgICBp
ZiAoYnV0dG9uLmRhdGFzZXQuYWN0aW9uID09PSAncXVvdGEnKSBvcGVuUXVvdGEodXNlcik7CiAg
ICAgICAgaWYgKGJ1dHRvbi5kYXRhc2V0LmFjdGlvbiA9PT0gJ3RvZ2dsZScpIGF3YWl0IG11dGF0
ZShgL3VzZXJzLyR7ZW5jb2RlVVJJQ29tcG9uZW50KHVzZXIudXNlcm5hbWUpfS9zdGF0dXNgLCAn
UEFUQ0gnLCB7IGVuYWJsZWQ6ICF1c2VyLmVuYWJsZWQgfSwgYOeUqOaItyAke3VzZXIudXNlcm5h
bWV9IOW3siR7dXNlci5lbmFibGVkID8gJ+WBnOeUqCcgOiAn5ZCv55SoJ31gKTsKICAgICAgICBp
ZiAoYnV0dG9uLmRhdGFzZXQuYWN0aW9uID09PSAnZGVsZXRlJykgeyBzdGF0ZS5kZWxldGluZyA9
IHVzZXIudXNlcm5hbWU7ICQoJyNkZWxldGUtY29weScpLnRleHRDb250ZW50ID0gYOWIoOmZpCAk
e3VzZXIudXNlcm5hbWV9IOWQju+8jOWFtuiuoumYheWcsOWdgOWSjOWPjOWNj+iuruWHreaNruWw
hueri+WNs+WkseaViO+8jOatpOaTjeS9nOS4jeWPr+aSpOmUgOOAgmA7IGRlbGV0ZURpYWxvZy5z
aG93TW9kYWwoKTsgfQogICAgICB9KTsKICAgICAgJCgnI2RlbGV0ZS1jb25maXJtJykuYWRkRXZl
bnRMaXN0ZW5lcignY2xpY2snLCBhc3luYyAoKSA9PiB7IGlmIChhd2FpdCBtdXRhdGUoYC91c2Vy
cy8ke2VuY29kZVVSSUNvbXBvbmVudChzdGF0ZS5kZWxldGluZyl9YCwgJ0RFTEVURScsIHVuZGVm
aW5lZCwgYOeUqOaItyAke3N0YXRlLmRlbGV0aW5nfSDlt7LliKDpmaRgKSkgZGVsZXRlRGlhbG9n
LmNsb3NlKCk7IH0pOwogICAgICBsb2FkKCk7IHNldEludGVydmFsKCgpID0+IHsgaWYgKCFlZGl0
RGlhbG9nLm9wZW4gJiYgIWRlbGV0ZURpYWxvZy5vcGVuICYmICFzZXJ2ZXJRdW90YURpYWxvZy5v
cGVuKSBsb2FkKGZhbHNlKTsgfSwgMzAwMDApOwogICAgfSkoKTsKICA8L3NjcmlwdD4KPC9ib2R5
Pgo8L2h0bWw+Cg==
SB_USER_ADMIN_PAGE_B64
  chmod 700 "${WORK_DIR}/sb-user.py"
  chmod 600 "${WORK_DIR}/admin-page.html"
  ln -sf "${WORK_DIR}/sb-user.py" /usr/bin/sb-user

  # 每次安装/升级均初始化：这会把旧的公共 Hysteria2/TUIC 入站收缩为仅本机可用的模板，
  # 使已缓存的旧公共节点不能绕过用户流量统计与额度。
  local SB_USER_INIT_STATUS=0
  if command -v timeout >/dev/null 2>&1; then
    timeout 60s /usr/bin/sb-user init >/dev/null 2>&1 || SB_USER_INIT_STATUS=$?
  else
    /usr/bin/sb-user init >/dev/null 2>&1 || SB_USER_INIT_STATUS=$?
  fi
  [ "$SB_USER_INIT_STATUS" -eq 0 ] || {
    warning " Failed to initialize Hysteria2/TUIC multi-user manager. Run [sb-user init] for details."
    return 1
  }

  if command -v systemctl >/dev/null 2>&1; then
    cat > /etc/systemd/system/sb-user-collect.service << EOF
[Unit]
Description=Sing-box per-user traffic accounting
After=network-online.target sing-box.service

[Service]
Type=oneshot
ExecStart=/usr/bin/sb-user collect
EOF

    cat > /etc/systemd/system/sb-user-collect.timer << EOF
[Unit]
Description=Collect Sing-box per-user traffic every 30 seconds

[Timer]
OnBootSec=30s
OnUnitActiveSec=30s
AccuracySec=5s
Persistent=true

[Install]
WantedBy=timers.target
EOF
    cat > /etc/systemd/system/sb-user-web.service << EOF
[Unit]
Description=Sing-box user subscriptions and administrator web console
After=network-online.target sing-box.service
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/bin/sb-user web --port 18081
Restart=on-failure
RestartSec=2s
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable --now sb-user-collect.timer >/dev/null 2>&1 || true
    systemctl enable --now sb-user-web.service >/dev/null 2>&1 || {
      warning " Failed to start user subscription and administrator web service. Check [systemctl status sb-user-web.service]."
    }
  fi
}

input_node_name() {
  # 输入节点名，以系统的 hostname 作为默认（新安装 / 无既有协议重新添加时询问）
  local NODE_NAME_INPUT=''
  if [ -z "$NODE_NAME_CONFIRM" ]; then
    local EMOJI="${EMOJI4:-$EMOJI6}"
    local EMOJI="${EMOJI}${EMOJI:+ }"
    if command -v hostname >/dev/null 2>&1; then
      local NODE_NAME_DEFAULT="${EMOJI}$(hostname)"
    elif [ -s /etc/hostname ]; then
      local NODE_NAME_DEFAULT="${EMOJI}$(cat /etc/hostname)"
    else
      local NODE_NAME_DEFAULT="${EMOJI}Sing-Box"
    fi
    [[ "$IS_FAST_INSTALL" = 'is_fast_install' || "$NONINTERACTIVE_INSTALL" = 'noninteractive_install' ]] && NODE_NAME_CONFIRM="${NODE_NAME_DEFAULT}"
    if [ -z "$NODE_NAME_CONFIRM" ]; then
      (( STEP_NUM++ )) || true
      reading "\n ${TOTAL_STEPS:+(${STEP_NUM}/${TOTAL_STEPS}) }$(text 13) " NODE_NAME_INPUT
    fi
    grep -q '^$' <<< "$NODE_NAME_INPUT" && NODE_NAME_CONFIRM="$NODE_NAME_DEFAULT" || NODE_NAME_CONFIRM="${EMOJI}${NODE_NAME_INPUT}"
  fi
}

# 更换优选域名 / reality SNI / 节点名 / UUID
change_config() {
  [ ! -d "${WORK_DIR}" ] && error " $(text 107) "

  local MENU_IDX=() MENU_KEY=() MENU_VAL=()

  # 优选 CDN
  ls ${WORK_DIR}/conf/*-ws*inbounds.json >/dev/null 2>&1 && local CDN_NOW=$(awk -F '"' '/"CDN"/{print $4; exit}' ${WORK_DIR}/conf/*-ws*inbounds.json) && MENU_IDX+=(128) && MENU_KEY+=(cdn) && MENU_VAL+=("$CDN_NOW")

  # Reality SNI
  ls ${WORK_DIR}/conf/*reality_inbounds.json >/dev/null 2>&1 && local SNI_NOW=$(awk 'match($0, /"server_name"[[:space:]]*:[[:space:]]*"[^"]+"/){gsub(/.*: *"/,""); gsub(/".*/,""); print; exit}' ${WORK_DIR}/conf/*reality_inbounds.json) && MENU_IDX+=(129) && MENU_KEY+=(sni) && MENU_VAL+=("$SNI_NOW")

  # 监听端口
  local PORTS_NOW=$(awk -F ':|,' '/"listen_port"/{print $2}' ${WORK_DIR}/conf/*_inbounds.json 2>/dev/null)
  if [ -n "$PORTS_NOW" ]; then
    MENU_IDX+=(30) && MENU_KEY+=(ports) && MENU_VAL+=("$(format_ports_display ${PORTS_NOW})")
  fi

  # 节点名
  local NAME_NOW=$(awk '/"tag"/{gsub(/^.*"tag": *"/,""); gsub(/".*/,""); sub(/ [^ ]*$/,""); print; exit}' ${WORK_DIR}/conf/*_inbounds.json 2>/dev/null)
  [ -n "$NAME_NOW" ] && MENU_IDX+=(130) && MENU_KEY+=(name) && MENU_VAL+=("$NAME_NOW")

  # UUID / Password
  local UUID_NOW="$(awk -F'"' '/"uuid"[[:space:]]*:[[:space:]]*"/ || /"id"[[:space:]]*:[[:space:]]*"/ {print $4; exit}' ${WORK_DIR}/conf/*_inbounds.json 2>/dev/null)"
  [ -n "$UUID_NOW" ] && MENU_IDX+=(131) && MENU_KEY+=(uuid) && MENU_VAL+=("$UUID_NOW")

  # 服务器 IP
  ls ${WORK_DIR}/conf/*-ws*inbounds.json >/dev/null 2>&1 && local SERVER_IP_NOW=$(awk -F '"' '/"WS_SERVER_IP_SHOW"/{print $4; exit}' ${WORK_DIR}/conf/*-ws*inbounds.json) || local SERVER_IP_NOW=$([ -s ${WORK_DIR}/list ] && grep -A1 '"tag"' ${WORK_DIR}/list | sed -E '/-ws(-tls)*",$/{N;d}' | awk -F '"' '/"server"/{count++; if (count == 1) {print $4; exit}}')
  [ -n "$SERVER_IP_NOW" ] && MENU_IDX+=(132) && MENU_KEY+=(serverip) && MENU_VAL+=("$SERVER_IP_NOW")

  # 从 sing-box 格式的 list 中提取 client-fingerprint，取第一个匹配值；无 list（未开启订阅）时默认 chrome
  local FP_NOW=chrome
  [ -s ${WORK_DIR}/list ] && FP_NOW=$(awk -F '"' '/"fingerprint"/{print $4; exit}' ${WORK_DIR}/list)
  [ -n "$FP_NOW" ] || FP_NOW=chrome
  [ -n "$FP_NOW" ] && MENU_IDX+=(48) && MENU_KEY+=(fingerprint) && MENU_VAL+=("$FP_NOW")

  # 指定网络出口
  local BIND_IFACE_NOW=$(awk -F '"' '/"bind_interface"[[:space:]]*:[[:space:]]*"/{print $4}' "${WORK_DIR}/conf/01_outbounds.json" 2>/dev/null)
  MENU_IDX+=(67) && MENU_KEY+=(bindinterface) && MENU_VAL+=("${BIND_IFACE_NOW:-default}")

  # 订阅开关（基于 nginx.conf 文件内容检测）
  if [ -s "${WORK_DIR}/nginx.conf" ] && \
     grep -qE 'location ~ \^/[^/]+/auto \{' "${WORK_DIR}/nginx.conf" 2>/dev/null; then
    MENU_IDX+=(109) && MENU_KEY+=(subscribe) && MENU_VAL+=("$(text 109)")
  else
    MENU_IDX+=(108) && MENU_KEY+=(subscribe) && MENU_VAL+=("$(text 108)")
  fi

  # Hysteria2 带宽和端口跳跃（仅在 Hysteria2 已安装时显示）
  if ls ${WORK_DIR}/conf/*_${NODE_TAG[1]}_inbounds.json >/dev/null 2>&1; then
    local HY2_LINE=''
    [ -s ${WORK_DIR}/subscribe/proxies ] && HY2_LINE=$(grep 'type: hysteria2' ${WORK_DIR}/subscribe/proxies)
    if [[ "$HY2_LINE" =~ up:[[:space:]]*\"([0-9]+)[[:space:]]*Mbps\".*down:[[:space:]]*\"([0-9]+)[[:space:]]*Mbps\" ]]; then
      HY2_UP_NOW="${BASH_REMATCH[1]}"
      HY2_DOWN_NOW="${BASH_REMATCH[2]}"
    elif [[ "$HY2_LINE" =~ down:[[:space:]]*\"([0-9]+)[[:space:]]*Mbps\".*up:[[:space:]]*\"([0-9]+)[[:space:]]*Mbps\" ]]; then
      HY2_DOWN_NOW="${BASH_REMATCH[1]}"
      HY2_UP_NOW="${BASH_REMATCH[2]}"
    fi
    HY2_UP_NOW=${HY2_UP_NOW:-200}
    HY2_DOWN_NOW=${HY2_DOWN_NOW:-1000}

    MENU_IDX+=(140) && MENU_KEY+=(hy2bw) && MENU_VAL+=("${HY2_UP_NOW}/${HY2_DOWN_NOW}")

    if grep -q 'realm-opts' <<< "$HY2_LINE"; then
      local HY2_REALM_ACTION="$(text 63)"
      MENU_IDX+=(63)
    else
      local HY2_REALM_ACTION="$(text 65)"
      MENU_IDX+=(65)
    fi
    MENU_KEY+=(hy2realm) && MENU_VAL+=("${HY2_REALM_ACTION}")

    check_port_hopping_nat
    MENU_IDX+=(139) && MENU_KEY+=(hy2hopping) && MENU_VAL+=("${HY2_PORT_HOPPING_RANGE}")
  fi

  # 自定义路由规则（仅在 warp-ep 存在时显示）
  grep -q '"warp-ep"' ${WORK_DIR}/conf/02_endpoints.json 2>/dev/null && {
    CUSTOM_ROUTE_COUNT=$(custom_route_count)
    MENU_IDX+=(150) && MENU_KEY+=(customroute) && MENU_VAL+=("${CUSTOM_ROUTE_COUNT}")
    MENU_IDX+=(174) && MENU_KEY+=(warpaccount) && MENU_VAL+=("")
  }

  [ "${#MENU_IDX[@]}" -eq 0 ] && error " $(text 107) "

  # 显示动态菜单
  hint "\n $(text 127)\n"
  for MENU_INDEX in "${!MENU_IDX[@]}"; do
    local VAL_ITEM="${MENU_VAL[MENU_INDEX]}"
    local RAW_ITEM
    eval "RAW_ITEM=\"\${${L}[${MENU_IDX[MENU_INDEX]}]}\""
    eval "hint \" $(printf '%2d' $(( MENU_INDEX+1 ))). ${RAW_ITEM}\""
  done
  hint ""
  reading " $(text 24) " CHOOSE_NODE_INFO

  if ! [[ "$CHOOSE_NODE_INFO" =~ ^[0-9]+$ ]] || \
     [ "$CHOOSE_NODE_INFO" -lt 1 ] || \
     [ "$CHOOSE_NODE_INFO" -gt "${#MENU_IDX[@]}" ]; then
    info " $(text 135) " && return
  fi

  local IDX=$(( CHOOSE_NODE_INFO - 1 ))
  local KEY="${MENU_KEY[IDX]}"
  local OLD="${MENU_VAL[IDX]}"

  # 特殊操作路由（不走通用替换逻辑）
  if  [ "$KEY" = "cdn" ]; then
    input_cdn
    ls ${WORK_DIR}/conf/*vmess-ws*inbounds.json >/dev/null 2>&1 && sed -i "s|CDN\": \".*\"|CDN\": \"${CDN}\"|g; s|CDN_PORT\": \".*\"|CDN_PORT\": \"${CDN_PORT[17]}\"|g" ${WORK_DIR}/conf/*vmess-ws*inbounds.json 2>/dev/null

    ls ${WORK_DIR}/conf/*vless-ws*inbounds.json >/dev/null 2>&1 && sed -i "s|CDN\": \".*\"|CDN\": \"${CDN}\"|g; s|CDN_PORT\": \".*\"|CDN_PORT\": \"${CDN_PORT[18]}\"|g" ${WORK_DIR}/conf/*vless-ws*inbounds.json 2>/dev/null

    export_list
    return
  elif [ "$KEY" = "serverip" ]; then
    # 重新检测并确认服务器所有 IP（多 IP 订阅）
    detect_all_ips
    confirm_server_ips
    [ "${#SERVER_IPS[@]}" -eq 0 ] && SERVER_IPS=("$OLD")
    SERVER_IP=${SERVER_IPS[0]} && WS_SERVER_IP_SHOW=$SERVER_IP
    find ${WORK_DIR} -type f | xargs -P 50 sed -i -e "s|\"server\": \"${OLD}\"|\"server\": \"${SERVER_IP}\"|g; s|\"WS_SERVER_IP_SHOW\": \"${OLD}\"|\"WS_SERVER_IP_SHOW\": \"${SERVER_IP}\"|g" 2>/dev/null
    export_list
    return
  elif [ "$KEY" = "ports" ]; then
    change_port_mode
    return
  elif [ "$KEY" = "hy2bw" ]; then
    # 修改 Hysteria2 带宽
    local HY2_UP HY2_DOWN
    while true; do
      reading " $(text 141) " HY2_UP
      [[ "$HY2_UP" =~ ^[1-9][0-9]*$ ]] && break
      warning " $(text 143) "
    done
    while true; do
      reading " $(text 142) " HY2_DOWN
      [[ "$HY2_DOWN" =~ ^[1-9][0-9]*$ ]] && break
      warning " $(text 143) "
    done
    [ -s ${WORK_DIR}/subscribe/proxies ] && sed -i -E "s/(up: \")([0-9]+)( Mbps\")/\1${HY2_UP}\3/g; s/(down: \")([0-9]+)( Mbps\")/\1${HY2_DOWN}\3/g" ${WORK_DIR}/subscribe/proxies
    hint " $(text 112) "
    export_list
    return
  elif [ "$KEY" = "hy2realm" ]; then
    # 添加 / 删除 Hysteria2 Realm；菜单已明确显示开启/关闭动作，这里不再二次确认 Realm 本身
    # 判断依据与菜单显示一致：检查 subscribe/proxies 中是否有 realm-opts
    local HY2_LINE=''
    [ -s ${WORK_DIR}/subscribe/proxies ] && HY2_LINE=$(grep 'type: hysteria2' ${WORK_DIR}/subscribe/proxies)
    if grep -q 'realm-opts' <<< "$HY2_LINE"; then
      # 已开启 → 直接关闭，不需要二次确认
      set_hy2_realm_config disable
      sync_hy2_warp_route disable
    else
      # 未开启 → 获取配置后开启，询问 WARP 辅助打洞
      fetch_nodes_value
      # Realm 与端口跳跃互斥：端口跳跃已开启时需确认，确认后先关闭端口跳跃
      check_port_hopping_nat
      if [ -n "$PORT_HOPPING_START" ] && [ -n "$PORT_HOPPING_END" ]; then
        local HY2_CONFIRM
        reading "\n $(text 110) " HY2_CONFIRM
        [[ "${HY2_CONFIRM,,}" =~ ^(y|yes)$ ]] || return
        del_port_hopping_nat
        unset PORT_HOPPING_START PORT_HOPPING_END HY2_PORT_HOPPING_RANGE
      fi
      IS_HY2_REALM=is_hy2_realm
      HY2_REALM_ID="${HY2_REALM_ID:-${UUID[12]:-${UUID_CONFIRM}}}"
      input_hy2_warp
      set_hy2_realm_config enable
      [ "$IS_HY2_WARP" = 'is_hy2_warp' ] && sync_hy2_warp_route enable || sync_hy2_warp_route disable
    fi
    cmd_systemctl reload sing-box
    export_list
    return
  elif [ "$KEY" = "hy2hopping" ]; then
    # 修改 Hysteria2 端口跳跃
    check_port_hopping_nat
    local OLD_START="$PORT_HOPPING_START" OLD_END="$PORT_HOPPING_END"
    # Realm 与端口跳跃互斥：Realm 已开启时先确认，确认后才进入端口跳跃流程
    local HY2_LINE=''
    [ -s ${WORK_DIR}/subscribe/proxies ] && HY2_LINE=$(grep 'type: hysteria2' ${WORK_DIR}/subscribe/proxies)
    if grep -q 'realm-opts' <<< "$HY2_LINE"; then
      local HY2_CONFIRM
      reading "\n $(text 183) " HY2_CONFIRM
      [[ "${HY2_CONFIRM,,}" =~ ^(y|yes)$ ]] || return
      set_hy2_realm_config disable
      sync_hy2_warp_route disable
    fi
    hint "\n $(text 97) \n"

    local HOPPING_ERROR_TIME=6
    local NEW_RANGE=""
    until [ -n "$IS_HOPPING_SET" ]; do
      if [ -z "$NEW_RANGE" ]; then
        (( HOPPING_ERROR_TIME-- )) || true
        case "$HOPPING_ERROR_TIME" in
          0 ) error "\n $(text 3) \n" ;;
          5 ) reading " $(text 98) " NEW_RANGE ;;
          * ) reading " $(text 98) " NEW_RANGE ;;
        esac
      fi

      # 预处理：将所有分隔符统一为冒号，过滤非法字符
      NEW_RANGE=$(sed 's/[-－—：]/:/g' <<< "$NEW_RANGE" | tr -cd '0-9:')

      if [[ -z "$NEW_RANGE" || "${NEW_RANGE,,}" =~ ^(n|no)$ ]]; then
        # 禁用端口跳跃
        [ -n "$OLD_START" ] && [ -n "$OLD_END" ] && del_port_hopping_nat
        unset PORT_HOPPING_START PORT_HOPPING_END HY2_PORT_HOPPING_RANGE
        IS_HOPPING_SET=true
      elif [[ "$NEW_RANGE" =~ ^[0-9]{4,5}:[0-9]{4,5}$ ]]; then
        local NEW_START=${NEW_RANGE%:*} NEW_END=${NEW_RANGE#*:}
        if [[ "$NEW_START" -lt "$NEW_END" && "$NEW_START" -ge "$MIN_HOPPING_PORT" && "$NEW_END" -le "$MAX_HOPPING_PORT" ]]; then
          # 删除旧规则，添加新规则
          [ -n "$OLD_START" ] && [ -n "$OLD_END" ] && del_port_hopping_nat
          PORT_HOPPING_START=$NEW_START
          PORT_HOPPING_END=$NEW_END
          HY2_PORT_HOPPING_RANGE="$NEW_RANGE"
          local HOPPING_TARGET="$PORT_HOPPING_TARGET"
          [ -z "$HOPPING_TARGET" ] && HOPPING_TARGET=$(awk -F '[:,]' '/"listen_port"/{print $2; exit}' ${WORK_DIR}/conf/*_${NODE_TAG[1]}_inbounds.json 2>/dev/null | tr -d ' ')
          # 静默添加端口跳跃规则，不显示 UFW 检测和成功提示
          (add_port_hopping_nat "$PORT_HOPPING_START" "$PORT_HOPPING_END" "$HOPPING_TARGET") >/dev/null 2>&1
          IS_HOPPING_SET=true
        else
          warning "\n $(text 36) " && unset NEW_RANGE
        fi
      else
        warning "\n $(text 36) " && unset NEW_RANGE
      fi
    done

    export_list
    return
  elif [ "$KEY" = "customroute" ]; then
    custom_route_menu
    return
  elif [ "$KEY" = "warpaccount" ]; then
    change_warp_account
    return
  elif [ "$KEY" = "fingerprint" ]; then
    # 修改客户端指纹
    hint "\n $(text 51) \n" && reading " $(text 24) " FP_CHOICE
    case "$FP_CHOICE" in
      ""|1) NEW_VAL="chrome" ;;
      2 ) NEW_VAL="firefox" ;;
      * ) NEW_VAL="$FP_CHOICE" ;;
    esac
    [[ ! "${NEW_VAL,,}" =~ ^[0-9a-z]+$ ]] && error " $(text 56) " || FINGER_PRINT="$NEW_VAL"
    export_list
    return
  elif [ "$KEY" = "bindinterface" ]; then
    # 指定网络出口 — 获取系统接口列表 + 选择 + 更新 JSON
    local IFACE_LIST=() CHOOSE_BIND IDX=2 TMP_FILE="${WORK_DIR}/conf/01_outbounds.json.tmp"

    if command -v ip >/dev/null 2>&1; then
      while read -r _ iface; do
        iface="${iface%%:*}"
        iface="${iface%%@*}"
        [ "$iface" != "lo" ] && IFACE_LIST+=("$iface")
      done < <(ip -o link show up 2>/dev/null)
    elif command -v ifconfig >/dev/null 2>&1; then
      while read -r iface _; do
        iface="${iface%%:}"
        [ "$iface" != "lo" ] && IFACE_LIST+=("$iface")
      done < <(ifconfig -a 2>/dev/null | awk '/^[a-zA-Z]/')
    else
      for IFACE_ITEM in /sys/class/net/*; do
        IFACE_ITEM="${IFACE_ITEM##*/}"
        [ "$IFACE_ITEM" != "lo" ] && IFACE_LIST+=("$IFACE_ITEM")
      done
    fi
    mapfile -t IFACE_LIST < <(printf '%s\n' "${IFACE_LIST[@]}" | sort -u)
    [ "${#IFACE_LIST[@]}" -eq 0 ] && warning " $(text 84) " && return

    hint "\n $(text 77) \n"
    hint " $(text 78) "
    for IFACE_ITEM in "${IFACE_LIST[@]}"; do
      hint " $IDX. $IFACE_ITEM"
      ((IDX++))
    done
    hint " 0. $(text 35)"
    hint ""
    reading " $(text 24) " CHOOSE_BIND

    if [[ "$CHOOSE_BIND" == "1" || "${CHOOSE_BIND,,}" == "default" ]]; then
      jq_exec '.outbounds |= map(if .tag == "direct" then del(.bind_interface) else . end)' \
        "${WORK_DIR}/conf/01_outbounds.json" > "$TMP_FILE" && mv "$TMP_FILE" "${WORK_DIR}/conf/01_outbounds.json"
      info " $(text 84) $(text 78 | sed 's/^1\. //')"
    elif [[ "$CHOOSE_BIND" =~ ^[0-9]+$ ]] && [ "$CHOOSE_BIND" -ge 2 ] && [ "$CHOOSE_BIND" -le "$((IDX - 1))" ]; then
      local SELECTED_IF="${IFACE_LIST[$((CHOOSE_BIND - 2))]}"
      jq_exec --arg iface "$SELECTED_IF" '.outbounds |= map(if .tag == "direct" then .bind_interface = $iface else . end)' \
        "${WORK_DIR}/conf/01_outbounds.json" > "$TMP_FILE" && mv "$TMP_FILE" "${WORK_DIR}/conf/01_outbounds.json"
      info " $(text 84) $SELECTED_IF"
    elif [ "$CHOOSE_BIND" == "0" ]; then
      return
    else
      warning " Invalid selection " && return
    fi

    cmd_systemctl reload sing-box
    export_list
    return
  elif [ "$KEY" = "subscribe" ]; then
    # 订阅开关 — 检测 nginx.conf 中是否存在订阅分发 location 块
    if grep -qE 'location ~ \^/[^/]+/auto \{' "${WORK_DIR}/nginx.conf" 2>/dev/null; then
      # 已开启 → 关闭订阅
      info "\n $(text 109) "
      # 检测 Argo 真实状态（Alpine 和 systemd 通用：检查守护进程文件是否存在）
      [ -s ${ARGO_DAEMON_FILE} ] && IS_ARGO=is_argo || IS_ARGO=no_argo
      # 从旧 nginx.conf 读取 PORT_NGINX（确定文件存在，无需条件判断）
      PORT_NGINX=$(awk '/listen/{print $2; exit}' ${WORK_DIR}/nginx.conf)
      IS_SUB=no_sub
      fetch_nodes_value
      # 判断是否还需要 nginx：有 WS 协议且 Argo 反代
      if { [ -n "$PORT_VMESS_WS" ] || [ -n "$PORT_VLESS_WS" ]; } && [ "$IS_ARGO" = 'is_argo' ]; then
        export_nginx_conf_file
      else
        nginx_stop
        rm -f ${WORK_DIR}/nginx.conf
        unset PORT_NGINX
      fi
      # 重新生成守护文件并同步 nginx（systemd ExecStartPre / OpenRC start_pre 与最终状态一致）
      sing-box_systemd
      nginx_sync
      /bin/rm -f ${WORK_DIR}/subscribe/qr
      export_list
      info " $(text 112) "
    else
      # 未开启 → 开启订阅
      info "\n $(text 108) "
      IS_SUB=is_sub
      # 确保 nginx 已安装
      if ! command -v nginx >/dev/null 2>&1; then
        info "\n $(text 7) nginx"
        ${PACKAGE_INSTALL[int]} nginx >/dev/null 2>&1
      fi
      check_arch
      [ ! -e "${WORK_DIR}/qrencode" ] && \
        wget --no-check-certificate --continue -qO ${WORK_DIR}/qrencode \
          ${GH_PROXY}https://github.com/fscarmen/client_template/raw/main/qrencode-go/qrencode-go-linux-$QRENCODE_ARCH 2>/dev/null \
          && chmod +x ${WORK_DIR}/qrencode
      fetch_nodes_value
      [ -z "$PORT_NGINX" ] && input_nginx_port
      export_nginx_conf_file
      # 重新生成守护文件并同步 nginx（含 Alpine / CentOS7，重启后 nginx 随服务拉起）
      sing-box_systemd
      nginx_sync
      export_list
      info " $(text 112) "
    fi
    return
  fi

  hint ""
  [ -z "$NEW_VAL" ] && reading " $(text 134) " NEW_VAL
  [ -z "$NEW_VAL" ] && info " $(text 135) " && return

  # 各 key 的校验
  if [ "$KEY" = "uuid" ]; then
    [[ ! "${NEW_VAL,,}" =~ ^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$ ]] && error " $(text 4) "
  elif [ "$KEY" = "sni" ]; then
    ssl_certificate "$NEW_VAL"
  fi

  # 批量替换
  find ${WORK_DIR} -type f | xargs -P 50 sed -i "s|${OLD}|${NEW_VAL}|g" 2>/dev/null
  [[ ! "$KEY" =~ ^(fingerprint)$ ]] && cmd_systemctl reload sing-box
  export_list
}

# 创建 Argo Tunnel API
create_argo_tunnel() {
  local CLOUDFLARE_API_TOKEN="$1"
  local ARGO_DOMAIN="$2"
  local SERVICE_PORT="$3"
  local TUNNEL_NAME=${ARGO_DOMAIN%%.*}
  local ROOT_DOMAIN=${ARGO_DOMAIN#*.}

  api_error() {
    local RESPONSE="$1"
    local CHECK_ZONE_ID="$2"

    if grep -q '"code":9109,' <<< "$RESPONSE"; then
      warning " $(text 122) " && sleep 2 && return 2
    elif grep -q '"code":7003,' <<< "$RESPONSE"; then
      warning " $(text 126) " && sleep 2 && return 3
    elif grep -q 'check_zone_id' <<< "$CHECK_ZONE_ID" && grep -q '"count":0,' <<< "$RESPONSE"; then
      warning " $(text 123) " && sleep 2 && return 4
    elif grep -q '"code":10000,' <<< "$RESPONSE"; then
      warning " $(text 124) " && sleep 2 && return 1
    elif grep -q '"success":true' <<< "$RESPONSE"; then
      return 0
    else
      warning " $(text 125) " && sleep 2 && return 5
    fi
  }

  # 步骤 1: 获取 Zone ID 和 Account ID
  local ZONE_RESPONSE=$(wget --no-check-certificate -qO- --content-on-error \
    --header="Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
    --header="Content-Type: application/json" \
    "https://api.cloudflare.com/client/v4/zones?name=${ROOT_DOMAIN}")

  api_error "$ZONE_RESPONSE" 'check_zone_id' || return $?

  [[ "$ZONE_RESPONSE" =~ \"id\":\"([^\"]+)\".*\"account\":\{\"id\":\"([^\"]+)\" ]] && local ZONE_ID="${BASH_REMATCH[1]}" ACCOUNT_ID="${BASH_REMATCH[2]}" || \
  return 5

  # 步骤 2: 查询并处理现有 Tunnel
  local TUNNEL_LIST=$(wget --no-check-certificate -qO- --content-on-error \
    --header="Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
    --header="Content-Type: application/json" \
    "https://api.cloudflare.com/client/v4/accounts/${ACCOUNT_ID}/cfd_tunnel?is_deleted=false")

  api_error "$TUNNEL_LIST" || return $?

  local TUNNEL_LIST_SPLIT=$(awk 'BEGIN{RS="";FS=""}{s=substr($0,index($0,"\"result\":[")+10);d=0;b="";for(i=1;i<=length(s);i++){c=substr(s,i,1);if(c=="{")d++;if(d>0)b=b c;if(c=="}"){d--;if(d==0){print b;b=""}}}}' <<< "$TUNNEL_LIST")

  # 检查是否存在同名 Tunnel
  while true; do
    unset TUNNEL_CHECK EXISTING_TUNNEL_ID EXISTING_TUNNEL_STATUS
    local TUNNEL_CHECK=$(grep '\"name\":\"'$TUNNEL_NAME'\"' <<< "$TUNNEL_LIST_SPLIT")
    if [[ "$TUNNEL_CHECK" =~ \"id\":\"([^\"]+)\".*\"status\":\"([^\"]+)\" ]]; then
      local EXISTING_TUNNEL_ID=${BASH_REMATCH[1]} EXISTING_TUNNEL_STATUS=${BASH_REMATCH[2]}
      # 处理状态显示的本地化
      grep -qw 'C' <<< "$L" && EXISTING_TUNNEL_STATUS=$(sed 's/inactive/停用（未激活）/; s/down/离线/; s/healthy/连接中/; s/degraded/降级/ ' <<< "$EXISTING_TUNNEL_STATUS")
      reading "\n $(text 120) " OVERWRITE
      if grep -qw 'n' <<< "${OVERWRITE,,}"; then
        # 询问用户输入另一个域名前缀
        unset ARGO_DOMAIN
        reading "\n $(text 87) " ARGO_DOMAIN

        # 用户直接回车，使用临时域名，退出当前流程
        ! grep -q '\.' <<< "$ARGO_DOMAIN" && return 5

        # 更新TUNNEL_NAME和ROOT_DOMAIN，循环会自动检查新名称
        TUNNEL_NAME=${ARGO_DOMAIN%%.*}
        ROOT_DOMAIN=${ARGO_DOMAIN#*.}
      else
        # 用户选择覆盖，则跳出循环继续执行创建流程
        break
      fi
    else
      # 如果新域名不存在，则跳出循环继续执行创建流程
      unset TUNNEL_CHECK EXISTING_TUNNEL_ID EXISTING_TUNNEL_STATUS
      break
    fi
  done

  # 如果同名 Tunnel 不存在，则先创建
  if grep -q '^$' <<< "$EXISTING_TUNNEL_ID"; then
    # 生成 Tunnel Secret (至少 32 字节的 base64 编码)
    local TUNNEL_SECRET=$(openssl rand -base64 32)

    # 创建新 Tunnel
    local CREATE_RESPONSE=$(wget --no-check-certificate -qO- --content-on-error \
      --header="Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
      --header="Content-Type: application/json" \
      --post-data="{
        \"name\": \"$TUNNEL_NAME\",
        \"config_src\": \"cloudflare\",
        \"tunnel_secret\": \"$TUNNEL_SECRET\"
      }" \
      "https://api.cloudflare.com/client/v4/accounts/${ACCOUNT_ID}/cfd_tunnel")

    api_error "$CREATE_RESPONSE" || return $?

    [[ $CREATE_RESPONSE =~ \"id\":\"([^\"]+)\".*\"token\":\"([^\"]+)\" ]] && \
    local TUNNEL_ID=${BASH_REMATCH[1]} TUNNEL_TOKEN=${BASH_REMATCH[2]} || \
    return 5
  else
    # 如果有同名 Tunnel (EXISTING_TUNNEL_ID 非空），则获取其 TOKEN
    local EXISTING_TUNNEL_TOKEN=$(wget -qO- --content-on-error \
      --header="Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
      --header="Content-Type: application/json" \
      "https://api.cloudflare.com/client/v4/accounts/${ACCOUNT_ID}/cfd_tunnel/${EXISTING_TUNNEL_ID}/token")

    api_error "$EXISTING_TUNNEL_TOKEN" || return $?

    local TUNNEL_ID=$EXISTING_TUNNEL_ID \
    TUNNEL_TOKEN=$(sed -n 's/.*"result":"\([^"]\+\)".*/\1/p' <<< "$EXISTING_TUNNEL_TOKEN") && \
    TUNNEL_SECRET=$(base64 -d <<< "$TUNNEL_TOKEN" | sed 's/.*"s":"\([^"]\+\)".*/\1/') || \
    return 5
  fi

  # 步骤 3: 配置 Tunnel ingress 规则... 不管原来的规则，一率覆盖处理
 local CONFIG_RESPONSE=$(wget --no-check-certificate -qO- --content-on-error \
  --method=PUT \
  --header="Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
  --header="Content-Type: application/json" \
  --body-data="{
    \"config\": {
      \"ingress\": [
        {
          \"service\": \"http://localhost:${SERVICE_PORT}\",
          \"hostname\": \"${ARGO_DOMAIN}\"
        },
        {
          \"service\": \"http_status:404\"
        }
      ],
      \"warp-routing\": {
        \"enabled\": false
      }
    }
  }" \
  "https://api.cloudflare.com/client/v4/accounts/${ACCOUNT_ID}/cfd_tunnel/${TUNNEL_ID}/configurations")

  api_error "$CONFIG_RESPONSE" || return $?

  # 步骤 4: 管理 DNS 记录
  local DNS_PAYLOAD="{
    \"name\": \"${ARGO_DOMAIN}\",
    \"type\": \"CNAME\",
    \"content\": \"${TUNNEL_ID}.cfargotunnel.com\",
    \"proxied\": true,
    \"settings\": {
      \"flatten_cname\": false
    }
  }"

  local DNS_LIST=$(wget --no-check-certificate -qO- --content-on-error \
    --header="Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
    --header="Content-Type: application/json" \
    "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records?type=CNAME&name=${ARGO_DOMAIN}")

  api_error "$DNS_LIST" || return $?

  # 如果已存在需要的 DNS 记录，就跳过
  if [[ "$DNS_LIST" =~ \"id\":\"([^\"]+)\".*\"$ARGO_DOMAIN\".*\"content\":\"([^\"]+)\" ]]; then
    local EXISTING_DNS_ID="${BASH_REMATCH[1]}" EXISTED_DNS_CONTENT="${BASH_REMATCH[2]}"

    # DNS 记录与隧道 ID 不匹配的话，覆盖原来的 CNAME 记录
    if ! grep -qw "$EXISTING_TUNNEL_ID" <<< "${EXISTED_DNS_CONTENT%%.*}"; then
      local DNS_RESPONSE=$(wget --no-check-certificate -qO- --content-on-error \
        --method=PATCH \
        --header="Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
        --header="Content-Type: application/json" \
        --body-data="$DNS_PAYLOAD" \
        "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records/${EXISTING_DNS_ID}")

      api_error "$DNS_RESPONSE" || return $?
    fi
  else
    # 未找到现有 DNS 记录，使用 POST 创建
    local DNS_RESPONSE=$(wget --no-check-certificate -qO- --content-on-error \
      --method=POST \
      --header="Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
      --header="Content-Type: application/json" \
      --body-data="$DNS_PAYLOAD" \
      "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records")

    api_error "$DNS_RESPONSE" || return $?
  fi

  # 返回 Argo Tunnel Token 或者 Json
  ARGO_JSON="{\"AccountTag\":\"$ACCOUNT_ID\",\"TunnelSecret\":\"$TUNNEL_SECRET\",\"TunnelID\":\"$TUNNEL_ID\",\"Endpoint\":\"\"}"
  ARGO_TOKEN="$TUNNEL_TOKEN"
}

# 输入 Nginx 服务端口
input_nginx_port() {
  local NUM=$1
  local PORT_ERROR_TIME=6
  # 在脚本端口范围（MIN_PORT-MAX_PORT）内随机生成一个未被系统占用的默认端口（与 clash_api 共用 find_free_port）
  local PORT_NGINX_DEFAULT=$(find_free_port)
  [[ "$IS_FAST_INSTALL" = 'is_fast_install' && -z "$PORT_NGINX" ]] && PORT_NGINX="$PORT_NGINX_DEFAULT"
  while true; do
    [[ "$PORT_ERROR_TIME" > 1 && "$PORT_ERROR_TIME" < 6 ]] && unset IN_USED PORT_NGINX
    (( PORT_ERROR_TIME-- )) || true
    if [ "$PORT_ERROR_TIME" = 0 ]; then
      error "\n $(text 3) \n"
    else
      [ -z "$PORT_NGINX" ] && reading "\n ${TOTAL_STEPS:+(${STEP_NUM}/${TOTAL_STEPS}) }$(text 79) " PORT_NGINX
    fi
    PORT_NGINX=${PORT_NGINX:-"$PORT_NGINX_DEFAULT"}
    if [[ "$PORT_NGINX" =~ ^[1-9][0-9]{1,4}$ && "$PORT_NGINX" -ge "$MIN_PORT" && "$PORT_NGINX" -le "$MAX_PORT" ]]; then
      is_port_in_use "$PORT_NGINX" && warning "\n $(text 44) \n" || break
    fi
  done
}

# 输入 hysteria2 跳跃端口
input_hopping_port() {
  local HOPPING_ERROR_TIME=6

  # 参数 / 快速安装模式：不交互。未指定端口跳跃时默认禁用。
  if [[ "$NONINTERACTIVE_INSTALL" = 'noninteractive_install' || "$IS_FAST_INSTALL" = 'is_fast_install' ]]; then
    HY2_PORT_HOPPING_RANGE=$(sed 's/[-－—：]/:/g' <<< "$HY2_PORT_HOPPING_RANGE" | tr -cd '0-9:')
    if [[ "$HY2_PORT_HOPPING_RANGE" =~ ^[0-9]{4,5}:[0-9]{4,5}$ ]]; then
      PORT_HOPPING_START=${HY2_PORT_HOPPING_RANGE%:*}
      PORT_HOPPING_END=${HY2_PORT_HOPPING_RANGE#*:}
      if [[ "$PORT_HOPPING_START" -lt "$PORT_HOPPING_END" && "$PORT_HOPPING_START" -ge "$MIN_HOPPING_PORT" && "$PORT_HOPPING_END" -le "$MAX_HOPPING_PORT" ]]; then
        IS_HOPPING=is_hopping
      else
        unset HY2_PORT_HOPPING_RANGE PORT_HOPPING_START PORT_HOPPING_END
        IS_HOPPING=no_hopping
      fi
    else
      unset HY2_PORT_HOPPING_RANGE PORT_HOPPING_START PORT_HOPPING_END
      IS_HOPPING=no_hopping
    fi
    return
  fi

  until [ -n "$IS_HOPPING" ]; do
    if [ -z "$HY2_PORT_HOPPING_RANGE" ]; then
      (( HOPPING_ERROR_TIME-- )) || true
      case "$HOPPING_ERROR_TIME" in
        0 )
          error "\n $(text 3) \n"
          ;;
        5 )
          hint "\n $(text 97) \n" && reading " ${TOTAL_STEPS:+(${STEP_NUM}/${TOTAL_STEPS}) }$(text 98) " HY2_PORT_HOPPING_RANGE
          ;;
        * )
          reading " ${TOTAL_STEPS:+(${STEP_NUM}/${TOTAL_STEPS}) }$(text 98) " HY2_PORT_HOPPING_RANGE
      esac
    fi

    # 预处理：全角冒号/破折号统一换半角，过滤非法字符
    HY2_PORT_HOPPING_RANGE=$(sed 's/[-－—：]/:/g' <<< "$HY2_PORT_HOPPING_RANGE" | tr -cd '0-9:')

    if [[ "$HY2_PORT_HOPPING_RANGE" =~ ^[0-9]{4,5}:[0-9]{4,5}$ ]]; then
      PORT_HOPPING_START=${HY2_PORT_HOPPING_RANGE%:*}
      PORT_HOPPING_END=${HY2_PORT_HOPPING_RANGE#*:}
      if [[ "$PORT_HOPPING_START" -lt "$PORT_HOPPING_END" && \
            "$PORT_HOPPING_START" -ge "$MIN_HOPPING_PORT" && \
            "$PORT_HOPPING_END" -le "$MAX_HOPPING_PORT" ]]; then
        IS_HOPPING=is_hopping
      else
        warning "\n $(text 114) " && unset HY2_PORT_HOPPING_RANGE
      fi
    elif [[ -z "$HY2_PORT_HOPPING_RANGE" || "${HY2_PORT_HOPPING_RANGE,,}" =~ ^(n|no)$ ]]; then
      IS_HOPPING=no_hopping
    else
      warning "\n $(text 36) " && unset HY2_PORT_HOPPING_RANGE
    fi
  done
}


# 输入 Hysteria2 Realm 选项
input_hy2_realm() {
  HY2_REALM_ID="${HY2_REALM_ID:-${UUID[12]:-${UUID_CONFIRM}}}"

  # 参数 / 快速安装模式：不交互，尊重 --HY2_REALM 和 --HY2_WARP
  # --HY2_WARP=true 隐含启用 Realm，否则 route 规则没有意义。
  if [[ "$NONINTERACTIVE_INSTALL" = 'noninteractive_install' || "$IS_FAST_INSTALL" = 'is_fast_install' ]]; then
    if [ "$IS_HY2_WARP" = 'is_hy2_warp' ]; then
      IS_HY2_REALM=is_hy2_realm
    fi
    if [ "$IS_HY2_REALM" = 'is_hy2_realm' ]; then
      HY2_REALM_ID="${HY2_REALM_ID:-${UUID_CONFIRM}}"
    else
      unset IS_HY2_REALM IS_HY2_WARP HY2_REALM_ID
    fi
    return
  fi

  unset IS_HY2_REALM IS_HY2_WARP
  local CHOOSE_REALM
  reading "\n $(text 147) " CHOOSE_REALM
  if [[ "${CHOOSE_REALM,,}" =~ ^(y|yes)$ ]]; then
    IS_HY2_REALM=is_hy2_realm
    HY2_REALM_ID="${HY2_REALM_ID:-${UUID_CONFIRM}}"
    input_hy2_warp
  fi
}

# 输入 Hysteria2 Realm 的 WARP 辅助打洞选项
input_hy2_warp() {
  local CHOOSE_WARP
  reading "\n $(text 148) " CHOOSE_WARP
  [[ "${CHOOSE_WARP,,}" =~ ^(y|yes)$ ]] && IS_HY2_WARP=is_hy2_warp || unset IS_HY2_WARP
}

# jq 入口，优先使用脚本自带 jq
jq_exec() {
  if [ -x "${WORK_DIR}/jq" ]; then
    "${WORK_DIR}/jq" "$@"
  elif [ -x "${TEMP_DIR}/jq" ]; then
    "${TEMP_DIR}/jq" "$@"
  else
    jq "$@"
  fi
}

# 更新 Hysteria2 服务端 Realm 模块
set_hy2_realm_config() {
  local ACTION=$1
  local HY2_CONF
  HY2_CONF=$(ls ${WORK_DIR}/conf/*_${NODE_TAG[1]}_inbounds.json 2>/dev/null | sed -n '1p') || true
  [ -z "$HY2_CONF" ] && return
  local TMP_FILE="${HY2_CONF}.tmp"
  HY2_REALM_ID="${HY2_REALM_ID:-${UUID[12]:-${UUID_CONFIRM}}}"

  if [ "$ACTION" = 'enable' ]; then
    jq_exec --arg rid "$HY2_REALM_ID" '.inbounds |= map(if .type == "hysteria2" then .realm = {"server_url":"https://realm.hy2.io","token":"public","realm_id":$rid,"stun_servers":["turn.cloudflare.com:3478","stun.nextcloud.com:3478","stun.sip.us:3478","global.stun.twilio.com:3478"]} else . end)' "$HY2_CONF" > "$TMP_FILE" && mv "$TMP_FILE" "$HY2_CONF"
    IS_HY2_REALM=is_hy2_realm
  else
    jq_exec '.inbounds |= map(if .type == "hysteria2" then del(.realm) else . end)' "$HY2_CONF" > "$TMP_FILE" && mv "$TMP_FILE" "$HY2_CONF"
    unset IS_HY2_REALM IS_HY2_WARP HY2_REALM_ID
  fi
}

# Hysteria2 Realm 的 WARP 辅助路由：添加或删除 inbound -> warp-ep
sync_hy2_warp_route() {
  local ACTION=$1
  local ROUTE_FILE="${WORK_DIR}/conf/03_route.json"
  [ ! -s "$ROUTE_FILE" ] && return
  local HY2_TAG="${NODE_NAME[12]} ${NODE_TAG[1]}"
  [ -z "${NODE_NAME[12]}" ] && HY2_TAG=$(awk -F'"' '/"tag"[[:space:]]*:[[:space:]]*".*hysteria2"/{print $4; exit}' ${WORK_DIR}/conf/*_${NODE_TAG[1]}_inbounds.json 2>/dev/null)
  [ -z "$HY2_TAG" ] && return
  local TMP_FILE="${ROUTE_FILE}.tmp"

  if [ "$ACTION" = 'enable' ]; then
    jq_exec --arg tag "$HY2_TAG" '
      .route.rules |= (
        map(select(.inbound != [$tag] or .outbound != "warp-ep")) as $rules |
        ($rules | map(.action == "resolve" and (.rule_set // []) == ["geosite-openai"]) | index(true)) as $idx |
        if $idx == null then
          $rules + [{"inbound":[$tag],"action":"route","outbound":"warp-ep"}]
        else
          $rules[0:$idx+1] + [{"inbound":[$tag],"action":"route","outbound":"warp-ep"}] + $rules[$idx+1:]
        end
      )' "$ROUTE_FILE" > "$TMP_FILE" && mv "$TMP_FILE" "$ROUTE_FILE"
    IS_HY2_WARP=is_hy2_warp
  else
    jq_exec --arg tag "$HY2_TAG" '.route.rules |= map(select(.inbound != [$tag] or .outbound != "warp-ep"))' "$ROUTE_FILE" > "$TMP_FILE" && mv "$TMP_FILE" "$ROUTE_FILE"
    unset IS_HY2_WARP
  fi
}

# ===================== 自定义路由规则 =====================

# 统计自定义路由规则数量（按数组里的单项统计，不按整条 route rule 统计）
custom_route_count() {
  local CUSTOM_FILE="${WORK_DIR}/conf/08_custom_route.json"
  if [ -s "$CUSTOM_FILE" ]; then
    jq_exec '[.route.rules[]? | ((.domain_suffix // []) | length) + ((.rule_set // []) | length)] | add // 0' "$CUSTOM_FILE" 2>/dev/null || echo 0
  else
    echo 0
  fi
}

# 将 warp-ep 的 domain_suffix / rule_set 合并到同一条 route rule，保持 08_custom_route.json 更简洁
custom_route_compact_rules() {
  local CUSTOM_FILE="${WORK_DIR}/conf/08_custom_route.json"
  local TMP_FILE="${CUSTOM_FILE}.tmp"
  [ ! -s "$CUSTOM_FILE" ] && return

  jq_exec '
    (.route.rules // []) as $rules |
    ($rules | map(select((.outbound // "warp-ep") == "warp-ep") | .domain_suffix // []) | add // [] | reduce .[] as $x ([]; if index($x) then . else . + [$x] end)) as $domains |
    ($rules | map(select((.outbound // "warp-ep") == "warp-ep") | .rule_set // []) | add // [] | reduce .[] as $x ([]; if index($x) then . else . + [$x] end)) as $sets |
    ($rules | map(select((.outbound // "warp-ep") != "warp-ep"))) as $others |
    .route.rules = (
      $others +
      (if (($domains | length) + ($sets | length)) > 0 then
        [((if ($sets | length) > 0 then {rule_set:$sets} else {} end)
          + (if ($domains | length) > 0 then {domain_suffix:$domains} else {} end)
          + {action:"route", outbound:"warp-ep"})]
      else [] end)
    )
  ' "$CUSTOM_FILE" > "$TMP_FILE" && mv "$TMP_FILE" "$CUSTOM_FILE"
}

# 通过 GitHub API 校验 rule_set 是否存在，返回下载 URL
# 参数: $1 = rule_set 名称（不含 .srs）
# 输出: 下载 URL 或空字符串
check_rule_set_exists() {
  local NAME="$1"
  local SRS_NAME="${NAME}.srs"
  local CACHE_DIR="${TEMP_DIR}/ruleset_cache"
  mkdir -p "$CACHE_DIR"

  # SagerNet 源
  local SAGERNET_CACHE="${CACHE_DIR}/sagernet_tree.json"
  if [ ! -s "$SAGERNET_CACHE" ]; then
    curl -sL --connect-timeout 5 --max-time 15 "https://api.github.com/repos/SagerNet/sing-geosite/git/trees/rule-set?recursive=1" > "$SAGERNET_CACHE" 2>/dev/null || true
  fi

  if [ -s "$SAGERNET_CACHE" ] && jq_exec -e ".tree[]? | select(.path == \"${SRS_NAME}\")" "$SAGERNET_CACHE" >/dev/null 2>&1; then
    echo "https://raw.githubusercontent.com/SagerNet/sing-geosite/rule-set/${SRS_NAME}"
    return 0
  fi

  # MetaCubeX 源
  local METACUBEX_CACHE="${CACHE_DIR}/metacubex_tree.json"
  if [ ! -s "$METACUBEX_CACHE" ]; then
    curl -sL --connect-timeout 5 --max-time 15 "https://api.github.com/repos/MetaCubeX/meta-rules-dat/git/trees/sing?recursive=1" > "$METACUBEX_CACHE" 2>/dev/null || true
  fi

  if [ -s "$METACUBEX_CACHE" ]; then
    local MATCH_PATH
    MATCH_PATH=$(jq_exec -r "[.tree[]? | select(.path | endswith(\"/${SRS_NAME}\") or . == \"${SRS_NAME}\") | .path] | first // empty" "$METACUBEX_CACHE" 2>/dev/null)
    if [ -n "$MATCH_PATH" ]; then
      echo "https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/sing/${MATCH_PATH}"
      return 0
    fi
  fi

  # 两处 API 都没数据（可能是 rate limit 或网络问题）
  if [ ! -s "$SAGERNET_CACHE" ] && [ ! -s "$METACUBEX_CACHE" ]; then
    # API 不可用，降级使用默认 URL
    warning " $(text 14) "
    echo "https://raw.githubusercontent.com/SagerNet/sing-geosite/rule-set/${SRS_NAME}"
    return 0
  fi

  # 确实在两处都没找到
  return 1
}

# 添加自定义路由规则
custom_route_add() {
  local CUSTOM_FILE="${WORK_DIR}/conf/08_custom_route.json"

  # 选择规则类型
  hint "\n $(text 152) "
  reading " $(text 24) " RULE_TYPE_CHOICE
  case "$RULE_TYPE_CHOICE" in
    1 ) local RULE_TYPE="domain_suffix" ;;
    2 ) local RULE_TYPE="rule_set" ;;
    * ) info " $(text 135) " && return ;;
  esac

  local VALIDATED_VALUES=()
  local RULE_SET_URLS=()

  if [ "$RULE_TYPE" = "domain_suffix" ]; then
    reading " $(text 153) " DOMAIN_INPUT
    [ -z "$DOMAIN_INPUT" ] && info " $(text 135) " && return

    local DOMAINS=()
    custom_route_csv_to_array "$DOMAIN_INPUT" DOMAINS
    local DOMAIN
    for DOMAIN in "${DOMAINS[@]}"; do
      DOMAIN=$(sed 's/。/./g' <<< "${DOMAIN,,}")
      if [[ "$DOMAIN" =~ ^[a-z0-9]([a-z0-9.-]*[a-z0-9])?\.[a-z]{2,}$ ]]; then
        VALIDATED_VALUES+=("$DOMAIN")
      else
        warning " $(text 149) "
      fi
    done
    [ "${#VALIDATED_VALUES[@]}" -eq 0 ] && warning " $(text 135) " && return

  elif [ "$RULE_TYPE" = "rule_set" ]; then
    # 输入规则集名称
    reading " $(text 154) " RULESET_INPUT
    [ -z "$RULESET_INPUT" ] && info " $(text 135) " && return

    local RULESETS=()
    custom_route_csv_to_array "$RULESET_INPUT" RULESETS

    local RULE_NAME RETRY URL
    for RULE_NAME in "${RULESETS[@]}"; do
      RULE_NAME="${RULE_NAME,,}"
      RULE_NAME=$(sed -E 's#^.*/##; s/\.srs$//I' <<< "$RULE_NAME")
      [[ -n "$RULE_NAME" && ! "$RULE_NAME" =~ ^geo(site|ip)- ]] && RULE_NAME="geosite-${RULE_NAME}"
      [ -z "$RULE_NAME" ] && continue

      RETRY=3
      URL=""
      while [ $RETRY -gt 0 ]; do
        URL=$(check_rule_set_exists "$RULE_NAME")
        if [ -n "$URL" ]; then
          VALIDATED_VALUES+=("$RULE_NAME")
          RULE_SET_URLS+=("$URL")
          break
        else
          ((RETRY--))
          if [ $RETRY -gt 0 ]; then
            warning " $(text 156) "
            reading " " RULE_NAME
            RULE_NAME="${RULE_NAME,,}"
            RULE_NAME=$(sed -E 's#^.*/##; s/\.srs$//I' <<< "$RULE_NAME")
            [[ -n "$RULE_NAME" && ! "$RULE_NAME" =~ ^geo(site|ip)- ]] && RULE_NAME="geosite-${RULE_NAME}"
          else
            warning " $(text 156) "
          fi
        fi
      done
    done
    [ "${#VALIDATED_VALUES[@]}" -eq 0 ] && warning " $(text 135) " && return
  fi

  # 自定义路由固定使用 warp-ep 出站
  local OUTBOUND="warp-ep"
  hint " $(text 155) "

  # 初始化 JSON 文件（如果不存在）
  if [ ! -s "$CUSTOM_FILE" ]; then
    echo '{"route":{"rule_set":[],"rules":[]}}' | jq_exec '.' > "$CUSTOM_FILE"
  fi

  local TMP_FILE="${CUSTOM_FILE}.tmp"

  if [ "$RULE_TYPE" = "domain_suffix" ]; then
    # 构建 domain_suffix 数组 JSON，先对输入本身去重
    local DOMAINS_JSON
    DOMAINS_JSON=$(printf '%s\n' "${VALIDATED_VALUES[@]}" | jq_exec -R . | jq_exec -s 'reduce .[] as $x ([]; if index($x) then . else . + [$x] end)')

    # 合并到同一条 warp-ep route rule；rule_set 和 domain_suffix 共用一条规则
    jq_exec --argjson domains "$DOMAINS_JSON" --arg out "$OUTBOUND" '
      .route.rules = (.route.rules // []) |
      (.route.rules | map(select((.outbound // $out) == $out) | .domain_suffix // []) | add // []) as $old_domains |
      (.route.rules | map(select((.outbound // $out) == $out) | .rule_set // []) | add // []) as $old_sets |
      (.route.rules | map(select((.outbound // $out) != $out))) as $others |
      (($old_domains + $domains) | reduce .[] as $x ([]; if index($x) then . else . + [$x] end)) as $new_domains |
      ($old_sets | reduce .[] as $x ([]; if index($x) then . else . + [$x] end)) as $new_sets |
      .route.rules = (
        $others +
        (if (($new_domains | length) + ($new_sets | length)) > 0 then
          [((if ($new_sets | length) > 0 then {rule_set:$new_sets} else {} end)
            + (if ($new_domains | length) > 0 then {domain_suffix:$new_domains} else {} end)
            + {action:"route", outbound:$out})]
        else [] end)
      )
    ' "$CUSTOM_FILE" > "$TMP_FILE" && mv "$TMP_FILE" "$CUSTOM_FILE"

  elif [ "$RULE_TYPE" = "rule_set" ]; then
    # 添加 rule_set 定义到 route.rule_set（去重）
    for i in "${!VALIDATED_VALUES[@]}"; do
      local RS_NAME="${VALIDATED_VALUES[$i]}"
      local RS_URL="${RULE_SET_URLS[$i]}"

      jq_exec --arg tag "$RS_NAME" --arg url "$RS_URL" '
        .route.rule_set = (.route.rule_set // []) |
        .route.rule_set |= (
          if any(.[]; .tag == $tag) then .
          else . + [{"tag": $tag, "type": "remote", "format": "binary", "url": $url}]
          end
        )
      ' "$CUSTOM_FILE" > "$TMP_FILE" && mv "$TMP_FILE" "$CUSTOM_FILE"
    done

    # 构建 rule_set 名称数组，先对输入本身去重
    local RS_NAMES_JSON
    RS_NAMES_JSON=$(printf '%s\n' "${VALIDATED_VALUES[@]}" | jq_exec -R . | jq_exec -s 'reduce .[] as $x ([]; if index($x) then . else . + [$x] end)')

    # 合并到同一条 warp-ep route rule；rule_set 和 domain_suffix 共用一条规则
    jq_exec --argjson names "$RS_NAMES_JSON" --arg out "$OUTBOUND" '
      .route.rules = (.route.rules // []) |
      (.route.rules | map(select((.outbound // $out) == $out) | .domain_suffix // []) | add // []) as $old_domains |
      (.route.rules | map(select((.outbound // $out) == $out) | .rule_set // []) | add // []) as $old_sets |
      (.route.rules | map(select((.outbound // $out) != $out))) as $others |
      ($old_domains | reduce .[] as $x ([]; if index($x) then . else . + [$x] end)) as $new_domains |
      (($old_sets + $names) | reduce .[] as $x ([]; if index($x) then . else . + [$x] end)) as $new_sets |
      .route.rules = (
        $others +
        (if (($new_domains | length) + ($new_sets | length)) > 0 then
          [((if ($new_sets | length) > 0 then {rule_set:$new_sets} else {} end)
            + (if ($new_domains | length) > 0 then {domain_suffix:$new_domains} else {} end)
            + {action:"route", outbound:$out})]
        else [] end)
      )
    ' "$CUSTOM_FILE" > "$TMP_FILE" && mv "$TMP_FILE" "$CUSTOM_FILE"
  fi

  custom_route_compact_rules

  info " $(text 157) "
  cmd_systemctl reload sing-box
  sleep 2
  cmd_systemctl status sing-box &>/dev/null && \
    info "\n Sing-box $(text 28) $(text 37) \n" || \
    warning "\n Sing-box $(text 27) $(text 38) \n"
}

# 将逗号分隔输入转为数组：支持半角/全角逗号、顿号、分号、竖线；不使用 IFS
custom_route_csv_to_array() {
  local INPUT_CSV="$1"
  local -n OUT_ARRAY="$2"
  OUT_ARRAY=()

  mapfile -t OUT_ARRAY < <(
    printf '%s\n' "$INPUT_CSV" |
      sed 's/\x1b\[[0-9;?]*[A-Za-z]//g; s/\^\[\[[0-9;?]*[A-Za-z]//g; s/[，、；;|]/,/g; s/[[:space:]]//g; s/,/\n/g; /^$/d'
  )
}

# 输出展开后的自定义路由项，每个 domain_suffix / rule_set 数组元素单独一行
custom_route_items_json() {
  local CUSTOM_FILE="${WORK_DIR}/conf/08_custom_route.json"
  jq_exec -c '
    [.route.rules[]?] as $rules |
    reduce range(0; ($rules | length)) as $i ([];
      ($rules[$i]) as $r |
      .
      + [($r.rule_set[]? | {rule_index:$i,type:"rule_set",match:.,outbound:($r.outbound // "warp-ep")})]
      + [($r.domain_suffix[]? | {rule_index:$i,type:"domain_suffix",match:.,outbound:($r.outbound // "warp-ep")})]
      + (if (($r.rule_set? == null) and ($r.domain_suffix? == null)) then [{rule_index:$i,type:"unknown",match:"N/A",outbound:($r.outbound // "warp-ep")}] else [] end)
    ) | .[]
  ' "$CUSTOM_FILE" 2>/dev/null
}

# 查看自定义路由规则
custom_route_view() {
  local CUSTOM_FILE="${WORK_DIR}/conf/08_custom_route.json"

  if [ ! -s "$CUSTOM_FILE" ]; then
    hint " $(text 158) "
    return 1
  fi

  local ROUTE_ITEMS=()
  mapfile -t ROUTE_ITEMS < <(custom_route_items_json)

  if [ "${#ROUTE_ITEMS[@]}" -eq 0 ]; then
    hint " $(text 158) "
    return 1
  fi

  hint "\n $(text 45) \n"
  printf "  %-4s %-16s %s\n" "#" "Type" "Match"
  printf "  %-4s %-16s %s\n" "---" "---------------" "---------------------------------------"

  local IDX=0
  local ITEM TYPE MATCH
  for ITEM in "${ROUTE_ITEMS[@]}"; do
    ((IDX++)) || true
    TYPE=$(jq_exec -r '.type' <<< "$ITEM")
    MATCH=$(jq_exec -r '.match' <<< "$ITEM")
    printf "  %-4s %-16s %s\n" "$IDX" "$TYPE" "$MATCH"
  done

  echo ""
  return 0
}

# 删除自定义路由规则：按展开后的单项编号删除，支持删除数组里的某个元素
custom_route_delete() {
  local CUSTOM_FILE="${WORK_DIR}/conf/08_custom_route.json"

  custom_route_view || return

  local ROUTE_ITEMS=()
  mapfile -t ROUTE_ITEMS < <(custom_route_items_json)
  [ "${#ROUTE_ITEMS[@]}" -eq 0 ] && info " $(text 135) " && return

  reading " $(text 159) " DELETE_INPUT
  [ -z "$DELETE_INPUT" ] && info " $(text 135) " && return

  local DELETE_NUMS=()
  custom_route_csv_to_array "$DELETE_INPUT" DELETE_NUMS

  local DELETE_ITEM_LINES=()
  local NUM
  for NUM in "${DELETE_NUMS[@]}"; do
    NUM=$(sed 's/[^0-9]//g' <<< "$NUM")
    if [[ "$NUM" =~ ^[0-9]+$ ]] && [ "$NUM" -ge 1 ] && [ "$NUM" -le "${#ROUTE_ITEMS[@]}" ]; then
      DELETE_ITEM_LINES+=("${ROUTE_ITEMS[$((NUM - 1))]}")
    fi
  done

  [ "${#DELETE_ITEM_LINES[@]}" -eq 0 ] && info " $(text 135) " && return

  local DELETE_ITEMS_JSON TMP_FILE
  DELETE_ITEMS_JSON=$(printf '%s\n' "${DELETE_ITEM_LINES[@]}" | jq_exec -s 'unique_by(.rule_index, .type, .match)')
  TMP_FILE="${CUSTOM_FILE}.tmp"

  # 只删除被选中的数组元素；数组清空后才删除整条 route rule
  jq_exec --argjson del "$DELETE_ITEMS_JSON" '
    .route.rules |= (
      [.[]?] as $rules |
      reduce range(0; ($rules | length)) as $idx ([];
        ($rules[$idx]) as $rule |
        ($del | map(select(.rule_index == $idx and .type == "domain_suffix") | .match)) as $remove_domains |
        ($del | map(select(.rule_index == $idx and .type == "rule_set") | .match)) as $remove_sets |
        ($rule
          | if .domain_suffix? != null then .domain_suffix = ([.domain_suffix[]? as $v | select(($remove_domains | index($v)) | not) | $v]) else . end
          | if .rule_set? != null then .rule_set = ([.rule_set[]? as $v | select(($remove_sets | index($v)) | not) | $v]) else . end
          | if ((.domain_suffix // []) | length) == 0 then del(.domain_suffix) else . end
          | if ((.rule_set // []) | length) == 0 then del(.rule_set) else . end
        ) as $new_rule |
        if (($new_rule.domain_suffix? != null) or ($new_rule.rule_set? != null)) then
          . + [$new_rule]
        elif ($del | any(.rule_index == $idx and .type == "unknown")) then
          .
        else
          . + [$new_rule]
        end
      )
    )
  ' "$CUSTOM_FILE" > "$TMP_FILE" && mv "$TMP_FILE" "$CUSTOM_FILE"

  custom_route_compact_rules

  # 清理孤立的 rule_set 定义：只保留仍被 rules 引用的 rule_set
  jq_exec '
    (.route.rules | [.[]? | .rule_set // [] | .[]] | unique) as $used |
    .route.rule_set |= [.[]? | select(.tag as $t | $used | index($t) | not | not)]
  ' "$CUSTOM_FILE" > "$TMP_FILE" && mv "$TMP_FILE" "$CUSTOM_FILE"

  # 如果没有任何规则了，删除文件
  local REMAINING
  REMAINING=$(jq_exec '.route.rules | length' "$CUSTOM_FILE" 2>/dev/null)
  if [ "${REMAINING:-0}" -eq 0 ]; then
    rm -f "$CUSTOM_FILE"
  fi

  info " $(text 160) "
  cmd_systemctl reload sing-box
  sleep 2
  cmd_systemctl status sing-box &>/dev/null && \
    info "\n Sing-box $(text 28) $(text 37) \n" || \
    warning "\n Sing-box $(text 27) $(text 38) \n"
}

# 自定义路由规则子菜单
custom_route_menu() {
  while true; do
    CUSTOM_ROUTE_COUNT=$(custom_route_count)
    hint "\n $(text 150) \n"
    hint " $(text 151) "
    hint ""
    reading " $(text 24) " CUSTOM_ROUTE_CHOICE

    case "$CUSTOM_ROUTE_CHOICE" in
      1 ) custom_route_add ;;
      2 ) custom_route_view ;;
      3 ) custom_route_delete ;;
      0 ) return ;;
      * ) info " $(text 135) " && return ;;
    esac
  done
}

# ===================== 自定义路由规则 END =====================
# ===================== 更换 WARP 账户 START =====================

# 更换 WARP 账户：二级菜单（重新注册 / 手动输入）
change_warp_account() {
  local WARP_ACCOUNT_CHOICE
  while true; do
    hint "\n $(text 175) \n"
    reading " $(text 24) " WARP_ACCOUNT_CHOICE

    case "$WARP_ACCOUNT_CHOICE" in
      1 ) change_warp_account_register ;;
      2 ) change_warp_account_manual ;;
      0 ) return ;;
      * ) info " $(text 135) " ;;
    esac
  done
}

# 方式1：重新注册免费账户
change_warp_account_register() {
  local WARP_ACCOUNT PRIVATE_KEY ADDRESS6 R1 R2 R3
  WARP_ACCOUNT=$(wget -qO- --tries=10 --waitretry=1 --timeout=2 "https://warp.cloudflare.nyc.mn/?run=register")

  if ! grep -q '"id"' <<< "$WARP_ACCOUNT"; then
    warning "\n $(text 176) \n"
    return
  fi

  PRIVATE_KEY=$(awk -F'"' '/"private_key"/{print $4}' <<< "$WARP_ACCOUNT")
  ADDRESS6=$(awk -F'"' '/"v6":/ && $4 !~ /^\[/ {print $4}' <<< "$WARP_ACCOUNT")
  R1=$(awk '/"reserved":/ {getline; gsub(/[^0-9]/, ""); print}' <<< "$WARP_ACCOUNT")
  R2=$(awk '/"reserved":/ {getline; getline; gsub(/[^0-9]/, ""); print}' <<< "$WARP_ACCOUNT")
  R3=$(awk '/"reserved":/ {getline; getline; getline; gsub(/[^0-9]/, ""); print}' <<< "$WARP_ACCOUNT")

  # 兜底：接口返回格式异常导致提取为空时，按注册失败处理，保留原账户
  if [ -z "$PRIVATE_KEY" ] || [ -z "$ADDRESS6" ] || [ -z "$R1" ] || [ -z "$R2" ] || [ -z "$R3" ]; then
    warning "\n $(text 176) \n"
    return
  fi

  change_warp_account_apply "$ADDRESS6" "$PRIVATE_KEY" "$R1" "$R2" "$R3"
}

# 方式2：手动输入账户信息（IPv6 / Private Key / Reserved）
change_warp_account_manual() {
  local ADDRESS6 PRIVATE_KEY RESERVED_INPUT R1 R2 R3 RESERVED_ERROR_TIME=5

  # 第 1 步：IPv6 地址（校验含冒号）
  while true; do
    reading "\n $(text 177) " ADDRESS6
    [[ "$ADDRESS6" =~ : ]] && break
    warning " $(text 133) "
  done

  # 第 2 步：Private Key（43 位 base64 字符 + 结尾 =）
  while true; do
    reading " $(text 178) " PRIVATE_KEY
    [[ "$PRIVATE_KEY" =~ ^[A-Za-z0-9+/_-]{43}=$ ]] && break
    warning " $(text 184) "
  done

  # 第 3 步：Reserved（先读取一次，再进入校验循环；捕获组提取 3 组连续数字，错误计数复用 UUID_ERROR_TIME 风格）
  reading " $(text 179) " RESERVED_INPUT
  until [[ "$RESERVED_INPUT" =~ ([0-9]+)[^0-9]*([0-9]+)[^0-9]*([0-9]+) ]] || [ "$RESERVED_ERROR_TIME" = 0 ]; do
    (( RESERVED_ERROR_TIME-- )) || true
    [ "$RESERVED_ERROR_TIME" = 0 ] && { warning "\n $(text 180) \n"; return; }
    warning " $(text 180) "
    reading " $(text 179) " RESERVED_INPUT
  done
  R1="${BASH_REMATCH[1]}"; R2="${BASH_REMATCH[2]}"; R3="${BASH_REMATCH[3]}"

  change_warp_account_apply "$ADDRESS6" "$PRIVATE_KEY" "$R1" "$R2" "$R3"
}

# 替换 02_endpoints.json + sing-box check + SIGHUP 热更 + 结果提示
change_warp_account_apply() {
  local ADDRESS6="$1" PRIVATE_KEY="$2" R1="$3" R2="$4" R3="$5"
  local WARP_ENDPOINT_FILE="${WORK_DIR}/conf/02_endpoints.json"
  local SB_PID_BEFORE SB_PID_AFTER

  [ -s "$WARP_ENDPOINT_FILE" ] || return 1

  cp "$WARP_ENDPOINT_FILE" "$WARP_ENDPOINT_FILE.bak"

  sed -i "s|\"private_key\":[ ]*\".*\"|\"private_key\":\"${PRIVATE_KEY}\"|" "$WARP_ENDPOINT_FILE"
  sed -i -E "s|\"([0-9a-fA-F:]+)/128\"|\"${ADDRESS6}/128\"|" "$WARP_ENDPOINT_FILE"
  # reserved 为多行数组，sed 单行正则无法覆盖，用 jq 原子更新（失败不落盘）
  jq_exec --argjson res "[${R1},${R2},${R3}]" \
    '(.endpoints[] | select(.tag == "warp-ep") | .peers[].reserved) = $res' \
    "$WARP_ENDPOINT_FILE" > "${WARP_ENDPOINT_FILE}.tmp" 2>/dev/null && mv "${WARP_ENDPOINT_FILE}.tmp" "$WARP_ENDPOINT_FILE"

  hint "\n $(text 181) \n"

  if ${WORK_DIR}/sing-box check -C ${WORK_DIR}/conf >/dev/null 2>&1; then
    # 热更（SIGHUP，PID 不变）；记录热更前后 PID 判断服务是否存活
    if [ "$SYSTEM" = 'Alpine' ]; then
      SB_PID_BEFORE=$(cat /var/run/sing-box.pid 2>/dev/null)
    else
      SB_PID_BEFORE=$(systemctl show -p MainPID sing-box 2>/dev/null | awk -F= '{print $2}')
    fi
    cmd_systemctl reload sing-box >/dev/null 2>&1
    sleep 1
    if [ "$SYSTEM" = 'Alpine' ]; then
      SB_PID_AFTER=$(cat /var/run/sing-box.pid 2>/dev/null)
    else
      SB_PID_AFTER=$(systemctl show -p MainPID sing-box 2>/dev/null | awk -F= '{print $2}')
    fi
    if [ -n "$SB_PID_AFTER" ] && [ "$SB_PID_AFTER" != '0' ]; then
      rm -f "$WARP_ENDPOINT_FILE.bak"
      info "\n $(text 182) $(text 37) \n"
      info " $(text 185) "
      exit 0
    else
      mv -f "$WARP_ENDPOINT_FILE.bak" "$WARP_ENDPOINT_FILE"
      warning "\n $(text 182) $(text 38) \n"
    fi
  else
    mv -f "$WARP_ENDPOINT_FILE.bak" "$WARP_ENDPOINT_FILE"
    warning "\n $(text 182) $(text 38) \n"
  fi
}

# ===================== 更换 WARP 账户 END =====================


# 输入 Reality 密钥
input_reality_key() {
  [[ "$NONINTERACTIVE_INSTALL" != 'noninteractive_install' && "$IS_FAST_INSTALL" != 'is_fast_install' ]] && [ -z "$REALITY_PRIVATE" ] && reading "\n ${TOTAL_STEPS:+(${STEP_NUM}/${TOTAL_STEPS}) }$(text 70) " REALITY_PRIVATE
  [ -z "$REALITY_PRIVATE" ] && unset REALITY_PRIVATE && return

  local PRIVATEKEY_ERROR_TIME=5
  until [[ "$REALITY_PRIVATE" =~ ^[A-Za-z0-9_-]{43}$ || -z "$REALITY_PRIVATE" ]]; do
    (( PRIVATEKEY_ERROR_TIME-- )) || true
    [ "$PRIVATEKEY_ERROR_TIME" = 0 ] && unset REALITY_PRIVATE && hint "\n $(text 113) \n" && break
    warning "\n $(text 114) "
    reading "\n $(text 70) " REALITY_PRIVATE
    # 即使 REALITY_PRIVATE 为空值，但 REALITY_PRIVATE 数组数量 ${REALITY_PRIVATE[@]} 为 1，影响后续的处理，所以要置空
    [ -z "$REALITY_PRIVATE" ] && unset REALITY_PRIVATE && break
  done
}

# 输入 Argo 域名和认证信息
input_argo_auth() {
  local IS_CHANGE_ARGO=$1
  [ -n "$IS_CHANGE_ARGO" ] && local EMPTY_ERROR_TIME=5
  local DOMAIN_ERROR_TIME=6

  # 处理可能输入的错误，去掉开头和结尾的空格，去掉最后的 :
  if [ "$IS_CHANGE_ARGO" = 'is_change_argo' ]; then
    until [ -n "$ARGO_DOMAIN" ]; do
      (( EMPTY_ERROR_TIME-- )) || true
      [ "$EMPTY_ERROR_TIME" = 0 ] && error "\n $(text 3) \n"
      reading "\n $(text 88) " ARGO_DOMAIN
      [ -n "$IS_CHANGE_ARGO" ] && ARGO_DOMAIN=$(sed 's/[ ]*//g; s/:[ ]*//' <<< "$ARGO_DOMAIN")
    done
  elif [[ "$NONINTERACTIVE_INSTALL" != 'noninteractive_install' && "$IS_FAST_INSTALL" != 'is_fast_install' ]]; then
    [ -z "$ARGO_DOMAIN" ] && reading "\n ${TOTAL_STEPS:+(${STEP_NUM}/${TOTAL_STEPS}) }$(text 87) " ARGO_DOMAIN
    ARGO_DOMAIN=$(sed 's/[ ]*//g; s/:[ ]*//' <<< "$ARGO_DOMAIN")
  fi

  if [[ ( -z "$ARGO_DOMAIN" || "$ARGO_DOMAIN" =~ trycloudflare\.com$ ) && ( "$IS_CHANGE_ARGO" = 'is_add_protocols' || "$IS_CHANGE_ARGO" = 'is_install' || "$NONINTERACTIVE_INSTALL" = 'noninteractive_install' ) ]]; then
    ARGO_RUNS="${WORK_DIR}/cloudflared tunnel --edge-ip-version auto --no-autoupdate --url http://localhost:$PORT_NGINX"
  elif [ -n "${ARGO_DOMAIN}" ]; then
    if [ -z "${ARGO_AUTH}" ]; then
      until [[ "$ARGO_AUTH" =~ TunnelSecret || "$ARGO_AUTH" =~ [A-Z0-9a-z=]{120,250}$ || "${#ARGO_AUTH}" =~ ^[3-6][0-9]$ ]]; do
        [ "$DOMAIN_ERROR_TIME" != 6 ] && warning "\n $(text 86) \n"
      (( DOMAIN_ERROR_TIME-- )) || true
        [ "$DOMAIN_ERROR_TIME" != 0 ] && hint "\n $(text 85) \n " && reading "\n $(text 118) " ARGO_AUTH || error "\n $(text 3) \n"
      done
    fi

    # 根据 ARGO_AUTH 的内容，自行判断是 Json， Token 还是 API 申请
    if [[ "$ARGO_AUTH" =~ TunnelSecret ]]; then
      ARGO_TYPE=is_json_argo
      ARGO_JSON=${ARGO_AUTH//[ ]/}
      [ "$IS_CHANGE_ARGO" = 'is_install' ] && export_argo_json_file $TEMP_DIR || export_argo_json_file ${WORK_DIR}
      ARGO_RUNS="${WORK_DIR}/cloudflared tunnel --edge-ip-version auto --config ${WORK_DIR}/tunnel.yml run"
    elif [[ "${ARGO_AUTH}" =~ [A-Z0-9a-z=]{120,250}$ ]]; then
      ARGO_TYPE=is_token_argo
      ARGO_TOKEN=$(awk '{print $NF}' <<< "$ARGO_AUTH")
      ARGO_RUNS="${WORK_DIR}/cloudflared tunnel --edge-ip-version auto run --token ${ARGO_TOKEN}"
    elif [[ "${#ARGO_AUTH}" =~ ^[3-6][0-9]$ ]]; then
      hint "\n $(text 119) \n "
      create_argo_tunnel "${ARGO_AUTH}" "${ARGO_DOMAIN}" "${PORT_NGINX}"
      if [[ "$ARGO_JSON" =~ TunnelSecret ]]; then
        ARGO_TYPE=is_json_argo
        [ "$IS_CHANGE_ARGO" = 'is_install' ] && export_argo_json_file $TEMP_DIR || export_argo_json_file ${WORK_DIR}
        ARGO_RUNS="${WORK_DIR}/cloudflared tunnel --edge-ip-version auto --config ${WORK_DIR}/tunnel.yml run"
      elif [[ "${#ARGO_TOKEN}" =~ ^[0-9]+$ && "${#ARGO_TOKEN}" -ge 120 && "${#ARGO_TOKEN}" -le 250 ]]; then
        ARGO_TYPE=is_token_argo
        ARGO_RUNS="${WORK_DIR}/cloudflared tunnel --edge-ip-version auto run --token ${ARGO_TOKEN}"
      else
        # 创建隧道失败，回退到使用临时隧道
        hint "\n $(text 117) \n "
        unset ARGO_DOMAIN
        ARGO_RUNS="${WORK_DIR}/cloudflared tunnel --edge-ip-version auto --no-autoupdate --url http://localhost:$PORT_NGINX"
      fi
    fi
  fi
}

# 更换 Argo 隧道类型
change_argo() {
  check_install
  if [ "${STATUS[0]}" =  "$(text 26)" ]; then
    error "\n $(text 39) "
  elif [ "${STATUS[1]}" = "$(text 26)" ]; then
    error "\n $(text 61) "
  fi

  # 根据系统类型检查 Argo 服务配置
  local ARGO_CONFIG=$(grep -E '^(command_args=|ExecStart=)' ${ARGO_DAEMON_FILE})

  case "$ARGO_CONFIG" in
    *--config* )
      ARGO_TYPE='Json'
      ;;
    *--token* )
      ARGO_TYPE='Token'
      ;;
    * )
      ARGO_TYPE='Try'
      cmd_systemctl enable argo && sleep 2 && cmd_systemctl status argo &>/dev/null && fetch_quicktunnel_domain
  esac

  fetch_nodes_value
  hint "\n $(text 90) \n"
  unset ARGO_DOMAIN
  hint " $(text 91) \n" && reading " $(text 24) " CHANGE_TO

  case "$CHANGE_TO" in
    1 )
      cmd_systemctl disable argo
      [ -s ${WORK_DIR}/tunnel.json ] && rm -f ${WORK_DIR}/tunnel.{json,yml}

      # 根据系统类型修改配置文件
      [ "$SYSTEM" = 'Alpine' ] && sed -i "s@^command_args=.*@command_args=\"--edge-ip-version auto --no-autoupdate --url http://localhost:$PORT_NGINX\"@g" ${ARGO_DAEMON_FILE} || sed -i "s@ExecStart=.*@ExecStart=${WORK_DIR}/cloudflared tunnel --edge-ip-version auto --no-autoupdate --url http://localhost:$PORT_NGINX@g" ${ARGO_DAEMON_FILE}
      ;;
    2 )
      [ -s ${WORK_DIR}/tunnel.json ] && rm -f ${WORK_DIR}/tunnel.{json,yml}
      input_argo_auth is_change_argo
      cmd_systemctl disable argo

      if [ -n "$ARGO_TOKEN" ]; then
        [ "$SYSTEM" = 'Alpine' ] && sed -i "s@^command_args=.*@command_args=\"--edge-ip-version auto run --token ${ARGO_TOKEN}\"@g" ${ARGO_DAEMON_FILE} || sed -i "s@ExecStart=.*@ExecStart=${WORK_DIR}/cloudflared tunnel --edge-ip-version auto run --token ${ARGO_TOKEN}@g" ${ARGO_DAEMON_FILE}
      elif [ -n "$ARGO_JSON" ]; then
        [ "$SYSTEM" = 'Alpine' ] && sed -i "s@^command_args=.*@command_args=\"--edge-ip-version auto --config ${WORK_DIR}/tunnel.yml run\"@g" ${ARGO_DAEMON_FILE} || sed -i "s@ExecStart=.*@ExecStart=${WORK_DIR}/cloudflared tunnel --edge-ip-version auto --config ${WORK_DIR}/tunnel.yml run@g" ${ARGO_DAEMON_FILE}
      fi

      # 更新相关配置文件中的域名
      [ -s ${WORK_DIR}/conf/17_${NODE_TAG[6]}_inbounds.json ] && sed -i "s/VMESS_HOST_DOMAIN.*/VMESS_HOST_DOMAIN\": \"$ARGO_DOMAIN\"/" ${WORK_DIR}/conf/17_${NODE_TAG[6]}_inbounds.json
      [ -s ${WORK_DIR}/conf/18_${NODE_TAG[7]}_inbounds.json ] && sed -i "s/\"server_name\":.*/\"server_name\": \"$ARGO_DOMAIN\",/" ${WORK_DIR}/conf/18_${NODE_TAG[7]}_inbounds.json
      ;;
    * )
      exit 0
  esac

  # 启用 Argo 服务
  cmd_systemctl enable argo

  # 更新节点信息和配置
  fetch_nodes_value
  export_nginx_conf_file
  nginx_sync
  export_list
}

check_root() {
  [ "$(id -u)" != 0 ] && error "\n $(text 43) \n"
}

# 判断处理器架构
check_arch() {
  [ "$SYSTEM" = 'Alpine' ] && local IS_MUSL='-musl'

  case "$(uname -m)" in
    aarch64|arm64 )
      SING_BOX_ARCH=arm64${IS_MUSL}; JQ_ARCH=arm64; QRENCODE_ARCH=arm64; ARGO_ARCH=arm64
      ;;
    x86_64|amd64 )
      SING_BOX_ARCH=amd64${IS_MUSL}; JQ_ARCH=amd64; QRENCODE_ARCH=amd64; ARGO_ARCH=amd64
      ;;
    armv7l )
      SING_BOX_ARCH=armv7${IS_MUSL}; JQ_ARCH=armhf; QRENCODE_ARCH=arm; ARGO_ARCH=arm
      ;;
    * )
      error " $(text 25) "
  esac
}

# 检查系统是否已经安装 tcp-brutal
check_brutal() {
  IS_BRUTAL=false && command -v lsmod >/dev/null 2>&1 && lsmod 2>/dev/null | grep -q 'brutal' && IS_BRUTAL=true
  [ "$IS_BRUTAL" = 'false' ] && command -v modprobe >/dev/null 2>&1 && modprobe brutal 2>/dev/null && IS_BRUTAL=true
}

# 不在状态检测阶段直接退出：旧脚本或其他面板安装的 sing-box 要先给用户备份、卸载和重装的机会。
mark_foreign_singbox() {
  FOREIGN_SINGBOX_DETECTED=true
  FOREIGN_SINGBOX_REASON="$1"
  STATUS[0]=$(text 27)
}

# 查安装及运行状态，下标0: sing-box，下标1: argo，下标2: nginx；状态码: 26 未安装， 27 已安装未运行， 28 运行中
check_install() {
  local CHECK_MODE=$1
  local PS_LIST=$(ps -eo pid,args | grep -E "$WORK_DIR.*([s]ing-box|[c]loudflared|[n]ginx)" | sed 's/^[ ]\+//g')

  if [[ "$IS_SUB" = 'is_sub' ]] || has_subscription_artifacts; then
    IS_SUB=is_sub
  else
    IS_SUB=no_sub
  fi
  if ls ${WORK_DIR}/conf/*${NODE_TAG[1]}_inbounds.json >/dev/null 2>&1; then
    check_port_hopping_nat
    [ -n "$PORT_HOPPING_END" ] && IS_HOPPING=is_hopping || IS_HOPPING=no_hopping
  fi

  if [ "$SYSTEM" = 'Alpine' ]; then
    # Alpine 系统使用 OpenRC 检查服务
    if [ -s ${SINGBOX_DAEMON_FILE} ]; then
      local OPENRC_EXECSTART=$(grep '^command=' ${SINGBOX_DAEMON_FILE})
      case "$OPENRC_EXECSTART" in
        *"${WORK_DIR}/sing-box"* )
          if rc-service sing-box status &>/dev/null; then
            STATUS[0]=$(text 28)
          else
            STATUS[0]=$(text 27)
          fi
          ;;
        * )
          mark_foreign_singbox 'Unknown or customized sing-box (OpenRC)'
          ;;
      esac
    else
      STATUS[0]=$(text 26)
    fi
  else
    # 非 Alpine 系统使用 systemd 检查服务
    if [ -s ${SINGBOX_DAEMON_FILE} ]; then
      SYSTEMD_EXECSTART=$(grep '^ExecStart=' ${SINGBOX_DAEMON_FILE})
      case "$SYSTEMD_EXECSTART" in
        "ExecStart=${WORK_DIR}/sing-box run -C ${WORK_DIR}/conf/" | "ExecStart=${WORK_DIR}/sing-box run -C ${WORK_DIR}/conf" )
          [ "$(systemctl is-active sing-box)" = 'active' ] && STATUS[0]=$(text 28) || STATUS[0]=$(text 27)
          ;;
        'ExecStart=/etc/v2ray-agent/sing-box/sing-box run -c /etc/v2ray-agent/sing-box/conf/config.json' )
          mark_foreign_singbox 'mack-a/v2ray-agent'
          ;;
        'ExecStart=/etc/s-box/sing-box run -c /etc/s-box/sb.json' )
          mark_foreign_singbox 'yonggekkk/sing-box_hysteria2_tuic_argo_reality'
          ;;
        'ExecStart=/usr/local/s-ui/bin/runSingbox.sh' )
          mark_foreign_singbox 'alireza0/s-ui'
          ;;
        'ExecStart=/usr/local/bin/sing-box run -c /usr/local/etc/sing-box/config.json' )
          mark_foreign_singbox 'FranzKafkaYu/sing-box-yes'
          ;;
        * )
          # 检查是否是自己的脚本安装的，但路径略有不同
          if [[ "$SYSTEMD_EXECSTART" =~ "ExecStart=${WORK_DIR}/sing-box run" ]]; then
            [ "$(systemctl is-active sing-box)" = 'active' ] && STATUS[0]=$(text 28) || STATUS[0]=$(text 27)
          else
            mark_foreign_singbox 'Unknown or customized sing-box (systemd)'
          fi
          ;;
      esac
    elif [ -s /lib/systemd/system/sing-box.service ]; then
      SYSTEMD_EXECSTART=$(grep '^ExecStart=' /lib/systemd/system/sing-box.service)
      case "$SYSTEMD_EXECSTART" in
        'ExecStart=/etc/sing-box/bin/sing-box run -c /etc/sing-box/config.json -C /etc/sing-box/conf' )
          mark_foreign_singbox '233boy/sing-box'
          ;;
        * )
          # 检查是否是自己的脚本安装的，但路径略有不同
          if [[ "$SYSTEMD_EXECSTART" =~ "ExecStart=${WORK_DIR}/sing-box run" ]]; then
            [ "$(systemctl is-active sing-box)" = 'active' ] && STATUS[0]=$(text 28) || STATUS[0]=$(text 27)
          else
            mark_foreign_singbox 'Unknown or customized sing-box (/lib systemd unit)'
          fi
          ;;
      esac
    else
      STATUS[0]=$(text 26)
    fi
  fi

  # 并发下载订阅模板 (clash, clash2, sing-box-template)，在新安装和更换协议时会用到。
  # export_list 只做状态刷新，不能再次启动一批下载任务，否则会产生竞态并延迟收尾。
  if [ "$CHECK_MODE" != 'status_only' ] && [ "$IS_FAST_INSTALL" != 'is_fast_install' ]; then
    {
      wget --no-check-certificate --tries=3 --timeout=15 -qO $TEMP_DIR/clash ${GH_PROXY}${SUBSCRIBE_TEMPLATE}/clash 2>/dev/null &
      wget --no-check-certificate --tries=3 --timeout=15 -qO $TEMP_DIR/clash2 ${GH_PROXY}${SUBSCRIBE_TEMPLATE}/clash2 2>/dev/null &
      wget --no-check-certificate --tries=3 --timeout=15 -qO $TEMP_DIR/sing-box-template ${GH_PROXY}${SUBSCRIBE_TEMPLATE}/sing-box 2>/dev/null &
      wait
    } &
  fi

  # 如果有需要，后台静默下载 sing-box
  if [ "${STATUS[0]}" = "$(text 26)" ] && [ ! -s ${WORK_DIR}/sing-box ]; then
    # 任务 1: 下载 sing-box
    {
      local ONLINE=$(get_sing_box_version)
      local SB_DIR="$TEMP_DIR/sing-box-$ONLINE-linux-$SING_BOX_ARCH"
      local SB_BIN="$SB_DIR/sing-box"
      wget --no-check-certificate --tries=3 --timeout=15 \
        ${GH_PROXY}https://github.com/SagerNet/sing-box/releases/download/v$ONLINE/sing-box-$ONLINE-linux-$SING_BOX_ARCH.tar.gz \
        -qO- | tar xz -C $TEMP_DIR 2>/dev/null
      [ -s "$SB_BIN" ] && [ -x "$SB_BIN" ] && mv "$SB_BIN" "$TEMP_DIR/sing-box" && chmod +x "$TEMP_DIR/sing-box"
    } &

    # 任务 2: 下载 jq
    {
      wget --no-check-certificate --tries=3 --timeout=15 -qO $TEMP_DIR/jq \
        ${GH_PROXY}https://github.com/jqlang/jq/releases/download/jq-1.7.1/jq-linux-$JQ_ARCH 2>/dev/null \
        && chmod +x $TEMP_DIR/jq
    } &

    # 任务 3: 下载 qrencode
    {
      if [ "$IS_FAST_INSTALL" != 'is_fast_install' ]; then
        wget --no-check-certificate --tries=3 --timeout=15 -qO $TEMP_DIR/qrencode \
          ${GH_PROXY}https://github.com/fscarmen/client_template/raw/main/qrencode-go/qrencode-go-linux-$QRENCODE_ARCH 2>/dev/null \
          && chmod +x $TEMP_DIR/qrencode
      fi
    } &

    # 任务 4: 注册 warp 账号
    {
      if [ "$IS_FAST_INSTALL" != 'is_fast_install' ]; then
        wget -qO- --tries=10 --waitretry=1 --timeout=2 "https://warp.cloudflare.nyc.mn/?run=register" > $TEMP_DIR/warp_account.json 2>/dev/null
      fi
    } &
  elif [ "${STATUS[0]}" != "$(text 26)" ] && [ -x "${WORK_DIR}/sing-box" ]; then
    # 查 sing-box 进程号，运行时长和内存占用，占用的端口
    SING_BOX_VERSION="Version: $(${WORK_DIR}/sing-box version | awk '/version/{print $NF}')"
    [ "${STATUS[0]}" = "$(text 28)" ] && SING_BOX_PID=$(awk '/sing-box run/{print $1}' <<< "$PS_LIST") && [[ "$SING_BOX_PID" =~ ^[0-9]+$ ]] && SING_BOX_MEMORY_USAGE="$(text 58): $(awk '/VmRSS/{printf "%.1f\n", $2/1024}' /proc/$SING_BOX_PID/status) MB"

    NOW_PORTS=$(awk -F ':|,' '/listen_port/{print $2}' ${WORK_DIR}/conf/*)
    NOW_START_PORT=$(awk 'NR == 1 { min = $0 } { if ($0 < min) min = $0; count++ } END {print min}' <<< "$NOW_PORTS")
    NOW_CONSECUTIVE_PORTS=$(awk 'END { print NR }' <<< "$NOW_PORTS")
  fi

  if [ "$NONINTERACTIVE_INSTALL" != 'noninteractive_install' ]; then
    # 检查 Argo 服务状态
    STATUS[1]=$(text 26) && IS_ARGO=no_argo
    [ -s ${ARGO_DAEMON_FILE} ] && IS_ARGO=is_argo && STATUS[1]=$(text 27)
    cmd_systemctl status argo &>/dev/null && STATUS[1]=$(text 28)
  fi

  # 检查 Argo 服务类型
  if [ "$SYSTEM" = 'Alpine' ]; then
    if [ -s ${ARGO_DAEMON_FILE} ]; then
      local ARGO_CONTENT=$(grep '^command_args=' ${ARGO_DAEMON_FILE})
      if grep -q '\--token' <<< "$ARGO_CONTENT"; then
        ARGO_TYPE=is_token_argo
      elif grep -q '\--config' <<< "$ARGO_CONTENT"; then
        ARGO_TYPE=is_json_argo
      elif grep -q '\--url' <<< "$ARGO_CONTENT"; then
        ARGO_TYPE=is_quicktunnel_argo
      fi
    fi
  else
    if [ -s ${ARGO_DAEMON_FILE} ]; then
      local ARGO_CONTENT=$(grep '^ExecStart' ${ARGO_DAEMON_FILE})
      if grep -q '\--token' <<< "$ARGO_CONTENT"; then
        ARGO_TYPE=is_token_argo
      elif grep -q '\--config' <<< "$ARGO_CONTENT"; then
        ARGO_TYPE=is_json_argo
      elif grep -q '\--url' <<< "$ARGO_CONTENT"; then
        ARGO_TYPE=is_quicktunnel_argo
      fi
    fi
  fi

  if [ "${STATUS[1]}" != "$(text 26)" ]; then
    # 查 Argo 进程号，运行时长和内存占用
    if [ -x "${WORK_DIR}/cloudflared" ]; then
      ARGO_VERSION=$(${WORK_DIR}/cloudflared -v | awk '{print $3}' | sed "s@^@Version: &@g")
    else
      ARGO_VERSION="Version: unavailable"
    fi
    [ "${STATUS[1]}" = "$(text 28)" ] && ARGO_PID=$(awk '/cloudflared/{print $1}' <<< "$PS_LIST") && [[ "$ARGO_PID" =~ ^[0-9]+$ ]] && ARGO_MEMORY_USAGE="$(text 58): $(awk '/VmRSS/{printf "%.1f\n", $2/1024}' /proc/$ARGO_PID/status) MB"
  fi

  # 检查 Nginx 状态
  if ! command -v nginx >/dev/null 2>&1; then
    STATUS[2]=$(text 26)
  elif [ -s ${WORK_DIR}/nginx.conf ]; then
    # 查 Nginx 进程号，运行时长和内存占用
    NGINX_VERSION=$(nginx -v 2>&1 | sed "s#.*/##; s/ ([^)]*)//" | sed "s@^@Version: &@g")
    NGINX_PID=$(awk '/nginx/{print $1}' <<< "${PS_LIST}")
    if [[ "$NGINX_PID" =~ ^[0-9]+$ ]]; then
      STATUS[2]=$(text 28)
      NGINX_MEMORY_USAGE="$(text 58): $(awk '/VmRSS/{printf "%.1f\n", $2/1024}' /proc/$NGINX_PID/status) MB"
    else
      STATUS[2]=$(text 27)
    fi
  else
    STATUS[2]=$(text 27)
  fi
}

# Nginx 启动/停止函数（全局定义，供 cmd_systemctl() 和 change_config() 共用）
nginx_run() {
  $(command -v nginx) -c $WORK_DIR/nginx.conf
}

nginx_stop() {
  local NGINX_PID=$(ps -eo pid,args | awk -v work_dir="$WORK_DIR" '$0~(work_dir"/nginx.conf"){print $1;exit}')
  ss -nltp | sed -n "/pid=$NGINX_PID,/ s/,/ /gp" | grep -oP 'pid=\K\S+' | sort -u | xargs kill -9 >/dev/null 2>&1
}

# 让 nginx 进程与最终配置状态保持一致：需要则启动/热重载，不需要则停止
nginx_sync() {
  if [ -s ${WORK_DIR}/nginx.conf ]; then
    if ps -eo pid,args | grep -qE "[n]ginx.*${WORK_DIR}/nginx.conf" 2>/dev/null; then
      nginx -s reload -c ${WORK_DIR}/nginx.conf 2>/dev/null || true
    else
      nginx_run
    fi
  else
    nginx_stop
  fi
}

# 判断是否有会与全新安装冲突的本机 Sing-box 服务、进程或配置目录。
# 这里不依赖 check_install()，因此可在下载任务启动前处理旧脚本和第三方面板。
has_existing_singbox_installation() {
  [ -d "$WORK_DIR" ] && return 0
  [ -x "$WORK_DIR/sing-box" ] && return 0
  [ -e "$SINGBOX_DAEMON_FILE" ] && return 0
  if [ "$SYSTEM" != 'Alpine' ]; then
    [ -e /lib/systemd/system/sing-box.service ] && return 0
    [ -e /usr/lib/systemd/system/sing-box.service ] && return 0
  fi
  pgrep -x sing-box >/dev/null 2>&1 && return 0
  return 1
}

# 只清理 Sing-box 自己的服务和 /etc/sing-box；Nginx 软件包及其他网站配置不会被卸载。
# 所有会删除的配置都会先复制到 root 专属的时间戳备份目录。
backup_and_remove_existing_singbox() {
  REINSTALL_BACKUP_DIR=${REINSTALL_BACKUP_DIR:-"/root/sing-box-pre-reinstall-$(date +%Y%m%d-%H%M%S)"}
  mkdir -p "$REINSTALL_BACKUP_DIR"
  chmod 700 "$REINSTALL_BACKUP_DIR"

  local LEGACY_PATH
  for LEGACY_PATH in \
    "$WORK_DIR" \
    "$SINGBOX_DAEMON_FILE" \
    "$ARGO_DAEMON_FILE" \
    /lib/systemd/system/sing-box.service \
    /usr/lib/systemd/system/sing-box.service \
    /etc/s-box \
    /etc/v2ray-agent/sing-box \
    /usr/local/etc/sing-box; do
    [ -e "$LEGACY_PATH" ] && cp -a "$LEGACY_PATH" "$REINSTALL_BACKUP_DIR/"
  done

  # 先停止旧的自管 Nginx，避免它继续占用旧订阅端口；不会卸载系统 Nginx。
  [ -s "$WORK_DIR/nginx.conf" ] && nginx_stop

  if command -v systemctl >/dev/null 2>&1; then
    systemctl disable --now sb-user-collect.timer >/dev/null 2>&1 || true
    systemctl disable --now sb-user-web.service >/dev/null 2>&1 || true
    systemctl disable --now sing-box >/dev/null 2>&1 || true
    systemctl stop sing-box >/dev/null 2>&1 || true
    systemctl disable --now argo >/dev/null 2>&1 || true
  elif [ "$SYSTEM" = 'Alpine' ]; then
    rc-service sing-box stop >/dev/null 2>&1 || true
    rc-update del sing-box default >/dev/null 2>&1 || true
    rc-service argo stop >/dev/null 2>&1 || true
    rc-update del argo default >/dev/null 2>&1 || true
  fi

  # 有些旧脚本没有留下可用的 service 文件，进程仍会占用 UDP 端口；统一结束它们。
  if command -v pkill >/dev/null 2>&1; then
    pkill -TERM -x sing-box >/dev/null 2>&1 || true
    sleep 1
    pkill -KILL -x sing-box >/dev/null 2>&1 || true
  fi

  purge_service_firewall_rules >/dev/null 2>&1 || true
  del_port_hopping_nat >/dev/null 2>&1 || true
  rm -f /etc/systemd/system/sb-user-collect.service \
        /etc/systemd/system/sb-user-collect.timer \
        /etc/systemd/system/sb-user-web.service \
        "$SINGBOX_DAEMON_FILE" \
        "$ARGO_DAEMON_FILE" \
        /usr/bin/sb-user \
        /usr/bin/sb
  [ "$SYSTEM" = 'Alpine' ] && rm -f /etc/init.d/sing-box /etc/init.d/argo
  rm -rf "$WORK_DIR"
  command -v systemctl >/dev/null 2>&1 && systemctl daemon-reload >/dev/null 2>&1 || true
  FOREIGN_SINGBOX_DETECTED=''
  FOREIGN_SINGBOX_REASON=''
  REINSTALL_PREPARED=true
  info "\n $(text 194)\n $(text 197) ${REINSTALL_BACKUP_DIR} \n"
}

# 快装模式与第三方旧安装都必须经过此入口，避免旧二进制未下载、服务冲突或覆盖旧配置。
prepare_clean_reinstall() {
  [ "$REINSTALL_PREPARED" = true ] && return 0
  has_existing_singbox_installation || return 0

  REINSTALL_BACKUP_DIR="/root/sing-box-pre-reinstall-$(date +%Y%m%d-%H%M%S)"
  warning "\n $(text 191) "
  [ -n "$FOREIGN_SINGBOX_REASON" ] && warning " $(text 196) "
  info " $(text 197) ${REINSTALL_BACKUP_DIR} "

  if [ "$NONINTERACTIVE_INSTALL" = 'noninteractive_install' ] && [[ "${FORCE_REINSTALL,,}" != 'true' ]]; then
    error "\n $(text 195) \n"
  fi
  if [[ "${FORCE_REINSTALL,,}" != 'true' ]]; then
    reading "\n $(text 192) " REINSTALL_CONFIRM
    if [[ ! "${REINSTALL_CONFIRM,,}" =~ ^(y|yes)$ ]]; then
      error "\n $(text 193) \n"
    fi
  fi
  backup_and_remove_existing_singbox
}

# 为了适配 alpine，定义 cmd_systemctl 的函数
cmd_systemctl() {

  if [ "$SYSTEM" = 'Alpine' ]; then
    case "$1" in
      enable )
        rc-update add "$2" default >/dev/null 2>&1
        rc-service "$2" start >/dev/null 2>&1
        ;;
      disable )
        rc-service "$2" stop >/dev/null 2>&1
        rc-update del "$2" default >/dev/null 2>&1
        ;;
      restart )
        rc-service "$2" restart >/dev/null 2>&1
        ;;
      reload )
        rc-service "$2" reload >/dev/null 2>&1 || rc-service "$2" restart >/dev/null 2>&1
        [ -s ${WORK_DIR}/nginx.conf ] && nginx_sync
        local MAINPID=$(cat /var/run/sing-box.pid 2>/dev/null)
        [ -n "$MAINPID" ] && info "\n $(text 95) \n"
        ;;
      status )
        rc-service "$2" status
        ;;
    esac
  else
    systemctl daemon-reload
    case "$1" in
      enable | disable )
        systemctl "$1" --now "$2" >/dev/null 2>&1
        ;;
      restart )
        systemctl restart "$2" >/dev/null 2>&1
        ;;
      reload )
        systemctl reload sing-box >/dev/null 2>&1 || systemctl restart sing-box >/dev/null 2>&1
        [ -s ${WORK_DIR}/nginx.conf ] && nginx_sync
        local MAINPID=$(systemctl show -p MainPID sing-box 2>/dev/null | awk -F= '{print $2}')
        [ -n "$MAINPID" ] && [ "$MAINPID" -gt 0 ] 2>/dev/null && info "\n $(text 95) \n"
        ;;
      status )
        systemctl is-active "$2"
        ;;
      * )
        systemctl "$@" >/dev/null 2>&1
        ;;
    esac
  fi
}

check_system_info() {
  [ -s /etc/os-release ] && SYS="$(awk -F '"' 'tolower($0) ~ /pretty_name/{print $2}' /etc/os-release)"
  [ -s /etc/os-release ] && OS_ID="$(awk -F '=' 'tolower($1) == "id" {gsub(/"/, "", $2); print tolower($2)}' /etc/os-release)"
  [ -s /etc/os-release ] && OS_LIKE="$(awk -F '=' 'tolower($1) == "id_like" {gsub(/"/, "", $2); print tolower($2)}' /etc/os-release)"
  [[ -z "$SYS" ]] && command -v hostnamectl >/dev/null 2>&1 && SYS="$(hostnamectl | awk -F ': ' 'tolower($0) ~ /operating system/{print $2}')"
  [[ -z "$SYS" ]] && command -v lsb_release >/dev/null 2>&1 && SYS="$(lsb_release -sd)"
  [[ -z "$SYS" && -s /etc/lsb-release ]] && SYS="$(awk -F '"' 'tolower($0) ~ /distrib_description/{print $2}' /etc/lsb-release)"
  [[ -z "$SYS" && -s /etc/redhat-release ]] && SYS="$(cat /etc/redhat-release)"
  [[ -z "$SYS" && -s /etc/issue ]] && SYS="$(sed -E '/^$|^\\/d' /etc/issue | awk -F '\\' '{print $1}' | sed 's/[ ]*$//g')"

  REGEX=("debian" "ubuntu" "centos|red hat|kernel|alma|rocky" "arch linux" "alpine" "fedora")
  RELEASE=("Debian" "Ubuntu" "CentOS" "Arch" "Alpine" "Fedora")
  EXCLUDE=("")
  MAJOR=("9" "16" "7" "3" "" "37")
  PACKAGE_UPDATE=("apt -y update" "apt -y update" "yum -y update --skip-broken" "pacman -Sy" "apk update -f" "dnf -y update")
  PACKAGE_INSTALL=("apt -y install" "apt -y install" "yum -y install" "pacman -S --noconfirm" "apk add --no-cache" "dnf -y install")
  PACKAGE_UNINSTALL=("apt -y autoremove" "apt -y autoremove" "yum -y autoremove" "pacman -Rcnsu --noconfirm" "apk del -f" "dnf -y autoremove")

  if [ "$OS_ID" = 'armbian' ]; then
    if [[ "$OS_LIKE" =~ ubuntu ]]; then
      SYSTEM='Ubuntu'
      int=1
    else
      SYSTEM='Debian'
      int=0
    fi
    SYS="${SYS:-Armbian}"
  else
    for int in "${!REGEX[@]}"; do
      [[ "${SYS,,}" =~ ${REGEX[int]} ]] && SYSTEM="${RELEASE[int]}" && break
    done
  fi

  # 针对各厂商的订制系统
  if [ -z "$SYSTEM" ]; then
    command -v yum >/dev/null 2>&1 && int=2 && SYSTEM='CentOS' || error " $(text 5) "
  fi

  # 先排除 EXCLUDE 里包括的特定系统，其他系统需要作大发行版本的比较
  for ex in "${EXCLUDE[@]}"; do [[ ! "{$SYS,,}"  =~ $ex ]]; done &&
  [[ "$(sed -E 's/[^0-9.]//g; s/\..*//' <<< "$SYS")" -lt "${MAJOR[int]}" ]] && error " $(text 6) "

  # 针对部分系统作特殊处理，CentOS7 使用 yum，以上使用 dnf
  ARGO_DAEMON_FILE='/etc/systemd/system/argo.service'; SINGBOX_DAEMON_FILE='/etc/systemd/system/sing-box.service'
  if [ "$SYSTEM" = 'CentOS' ]; then
    IS_CENTOS="CentOS$(sed -E 's/[^0-9.]//g; s/\..*//' <<< "$SYS")"
    [ "$IS_CENTOS" != 'CentOS7' ] && int=5
  elif [ "$SYSTEM" = 'Alpine' ]; then
    ARGO_DAEMON_FILE='/etc/init.d/argo'; SINGBOX_DAEMON_FILE='/etc/init.d/sing-box'
  fi

  # 判断虚拟化
  if command -v systemd-detect-virt >/dev/null 2>&1; then
    VIRT=$(systemd-detect-virt)
  elif grep -qa container= /proc/1/environ 2>/dev/null; then
    VIRT=$(tr '\0' '\n' </proc/1/environ | awk -F= '/container=/{print $2; exit}')
  elif grep -Eq '(lxc|docker|kubepods|containerd)' /proc/1/cgroup 2>/dev/null; then
    VIRT=$(grep -Eo '(lxc|docker|kubepods|containerd)' /proc/1/cgroup | sed -n 1p)
  elif command -v hostnamectl >/dev/null 2>&1; then
    VIRT=$(hostnamectl | awk '/Virtualization/{print $NF}')
  else
    command -v virt-what >/dev/null 2>&1 && ${PACKAGE_INSTALL[int]} virt-what >/dev/null 2>&1
    command -v virt-what >/dev/null 2>&1 && VIRT=$(virt-what | sed -n 1p) || VIRT=unknown
  fi
}

# 获取 sing-box 最新版本
get_sing_box_version() {
  # FORCE_VERSION 用于在 sing-box 某个主程序出现 bug 时，强制为指定版本，以防止运行出错
  local FORCE_VERSION=$(wget --no-check-certificate --tries=2 --timeout=3 -qO- ${GH_PROXY}https://raw.githubusercontent.com/fscarmen/sing-box/refs/heads/main/force_version | sed 's/^[vV]//g; s/\r//g')
  if grep -q '.' <<< "$FORCE_VERSION"; then
    local RESULT_VERSION="$FORCE_VERSION"
  else
    # 先判断 github api 返回 http 状态码是否为 200，有时候 IP 会被限制，导致获取不到最新版本
    local API_RESPONSE=$(wget --no-check-certificate --server-response --tries=2 --timeout=3 -qO- "${GH_PROXY}https://api.github.com/repos/SagerNet/sing-box/releases" 2>&1 | grep -E '^[ ]+HTTP/|tag_name')
    if grep -q 'HTTP.* 200' <<< "$API_RESPONSE"; then
      local VERSION_LATEST=$(awk -F '["v-]' '/tag_name/{print $5}' <<< "$API_RESPONSE" | sort -Vr | sed -n '1p')
      local RESULT_VERSION=$(awk -F '["v]' -v var="tag_name.*$VERSION_LATEST" '$0 ~ var {print $5; exit}' <<< "$API_RESPONSE")
    else
      local RESULT_VERSION="$DEFAULT_NEWEST_VERSION"
    fi
  fi
  echo "$RESULT_VERSION"
}

# 添加端口跳跃
add_port_hopping_nat() {
  local PORT_HOPPING_START=$1
  local PORT_HOPPING_END=$2
  local PORT_HOPPING_TARGET=$3
  local COMMENT="NAT ${PORT_HOPPING_START}:${PORT_HOPPING_END} to ${PORT_HOPPING_TARGET} (Sing-box Family Bucket)"
  local FW_BACKEND
  local FW_CHECK=() FW_INSTALL=() FW_TO_INSTALL=()

  FW_BACKEND=$(check_port_hopping_firewall)

  case "$FW_BACKEND" in
    ufw )
      info "\n $(text 144) \n"
      ;;
    alpine-iptables )
      command -v iptables >/dev/null 2>&1 || FW_TO_INSTALL+=("iptables")
      ;;
    firewalld )
      command -v firewall-cmd >/dev/null 2>&1 || FW_TO_INSTALL+=("firewalld")
      ;;
    * )
      command -v iptables >/dev/null 2>&1 || FW_TO_INSTALL+=("iptables")
      if ! command -v netfilter-persistent >/dev/null 2>&1 ||
         ! dpkg -s iptables-persistent >/dev/null 2>&1; then
        FW_TO_INSTALL+=("iptables-persistent")
      fi
      ;;
  esac

  if [ "${#FW_TO_INSTALL[@]}" -gt 0 ]; then
    FW_TO_INSTALL=($(printf "%s\n" "${FW_TO_INSTALL[@]}" | sort -u))
    info "\n $(text 7) $(sed "s/ /,&/g" <<< "${FW_TO_INSTALL[*]}") \n"
    [ "$SYSTEM" != 'CentOS' ] && ${PACKAGE_UPDATE[int]} >/dev/null 2>&1
    ${PACKAGE_INSTALL[int]} "${FW_TO_INSTALL[@]}" >/dev/null 2>&1
  fi

  if [ "$FW_BACKEND" = 'firewalld' ]; then
    [ "$(systemctl is-active firewalld 2>/dev/null)" != 'active' ] && cmd_systemctl enable firewalld >/dev/null 2>&1
    [ "$(firewall-cmd --zone=public --get-target 2>/dev/null)" != 'ACCEPT' ] && firewall-cmd --zone=public --set-target=ACCEPT --permanent >/dev/null 2>&1
    firewall-cmd --reload >/dev/null 2>&1
  fi

  if [ "$FW_BACKEND" = 'ufw' ]; then
    add_port_hopping_ufw_rules "$PORT_HOPPING_START" "$PORT_HOPPING_END" "$PORT_HOPPING_TARGET" || warning "\n $(text 146) \n"

  elif [ "$SYSTEM" = 'Alpine' ]; then
    # 添加防火墙规则
    iptables  --table nat -A PREROUTING -p udp --dport ${PORT_HOPPING_START}:${PORT_HOPPING_END} -m comment --comment "$COMMENT" -j DNAT --to-destination :${PORT_HOPPING_TARGET} 2>/dev/null
    ip6tables --table nat -A PREROUTING -p udp --dport ${PORT_HOPPING_START}:${PORT_HOPPING_END} -m comment --comment "$COMMENT" -j DNAT --to-destination :${PORT_HOPPING_TARGET} 2>/dev/null

    # 将 iptables, ip6tables 添加到默认运行级别
    rc-update show default | grep -q 'iptables'  || rc-update add iptables  >/dev/null 2>&1
    rc-update show default | grep -q 'ip6tables' || rc-update add ip6tables >/dev/null 2>&1
    rc-update show default | grep -q 'iptables' && rc-update show default | grep -q 'ip6tables' || warning "\n $(text 96) \n"

    # 保存当前的 iptables, ip6tables 规则集，以便在开机时恢复
    rc-service iptables  save >/dev/null 2>&1
    rc-service ip6tables save >/dev/null 2>&1

  elif command -v firewall-cmd >/dev/null 2>&1 || [ "$SYSTEM" = 'CentOS' ]; then
    if [ "$(firewall-cmd --zone=public --query-masquerade --permanent 2>/dev/null)" != 'yes' ]; then
      firewall-cmd --zone=public --add-masquerade --permanent >/dev/null 2>&1
      firewall-cmd --reload >/dev/null 2>&1
      [ "$(firewall-cmd --zone=public --query-masquerade --permanent 2>/dev/null)" = 'yes' ] && info "\n firewalld masquerade $(text 28) $(text 37) \n" || warning "\n firewalld masquerade $(text 28) $(text 38) \n"
    fi

    # 添加防火墙规则
    firewall-cmd --zone=public --add-forward-port=port=${PORT_HOPPING_START}-${PORT_HOPPING_END}:proto=udp:toport=${PORT_HOPPING_TARGET} --permanent >/dev/null 2>&1
    firewall-cmd --reload >/dev/null 2>&1

  else
    # 添加防火墙规则
    iptables  --table nat -A PREROUTING -p udp --dport ${PORT_HOPPING_START}:${PORT_HOPPING_END} -m comment --comment "$COMMENT" -j DNAT --to-destination :${PORT_HOPPING_TARGET} 2>/dev/null
    ip6tables --table nat -A PREROUTING -p udp --dport ${PORT_HOPPING_START}:${PORT_HOPPING_END} -m comment --comment "$COMMENT" -j DNAT --to-destination :${PORT_HOPPING_TARGET} 2>/dev/null

    # 保存当前的 iptables, ip6tables 规则集，以便在开机时恢复
    [ "$(systemctl is-active netfilter-persistent)" != 'active' ] && warning "\n $(text 96) \n" || netfilter-persistent save 2>/dev/null
  fi
}

# 删除端口跳跃
del_port_hopping_nat() {
  local FW_BACKEND
  FW_BACKEND=$(check_port_hopping_firewall)

  check_port_hopping_nat
  [ -z "$PORT_HOPPING_START" ] && return

  if [ "$FW_BACKEND" = 'ufw' ]; then
    del_port_hopping_ufw_rules || warning "\n $(text 146) \n"

  elif [ "$SYSTEM" = 'Alpine' ]; then
    local COMMENT="NAT ${PORT_HOPPING_START}:${PORT_HOPPING_END} to ${PORT_HOPPING_TARGET} (Sing-box Family Bucket)"
    iptables  --table nat -D PREROUTING -p udp --dport ${PORT_HOPPING_START}:${PORT_HOPPING_END} -m comment --comment "$COMMENT" -j DNAT --to-destination :${PORT_HOPPING_TARGET} 2>/dev/null
    ip6tables --table nat -D PREROUTING -p udp --dport ${PORT_HOPPING_START}:${PORT_HOPPING_END} -m comment --comment "$COMMENT" -j DNAT --to-destination :${PORT_HOPPING_TARGET} 2>/dev/null
    rc-service iptables  save >/dev/null 2>&1
    rc-service ip6tables save >/dev/null 2>&1

  elif command -v firewall-cmd >/dev/null 2>&1 || [ "$SYSTEM" = 'CentOS' ]; then
    firewall-cmd --zone=public --permanent --remove-forward-port=port=${PORT_HOPPING_START}-${PORT_HOPPING_END}:proto=udp:toport=${PORT_HOPPING_TARGET} >/dev/null 2>&1
    firewall-cmd --reload >/dev/null 2>&1

  else
    local COMMENT="NAT ${PORT_HOPPING_START}:${PORT_HOPPING_END} to ${PORT_HOPPING_TARGET} (Sing-box Family Bucket)"
    iptables  --table nat -D PREROUTING -p udp --dport ${PORT_HOPPING_START}:${PORT_HOPPING_END} -m comment --comment "$COMMENT" -j DNAT --to-destination :${PORT_HOPPING_TARGET} 2>/dev/null
    ip6tables --table nat -D PREROUTING -p udp --dport ${PORT_HOPPING_START}:${PORT_HOPPING_END} -m comment --comment "$COMMENT" -j DNAT --to-destination :${PORT_HOPPING_TARGET} 2>/dev/null
    [ "$(systemctl is-active netfilter-persistent)" = 'active' ] && netfilter-persistent save 2>/dev/null
  fi
}

# 查端口跳跃的 dnat 端口
check_port_hopping_nat() {
  local FW_BACKEND
  FW_BACKEND=$(check_port_hopping_firewall)

  unset PORT_HOPPING_START PORT_HOPPING_END HY2_PORT_HOPPING_RANGE
  PORT_HOPPING_TARGET=$(awk -F '[:,]' '/"listen_port"/{print $2; exit}' ${WORK_DIR}/conf/*${NODE_TAG[1]}_inbounds.json 2>/dev/null | tr -d ' ')

  if [ "$FW_BACKEND" = 'ufw' ]; then
    check_port_hopping_ufw_rules

  elif [ "$SYSTEM" = 'Alpine' ]; then
    local IPTABLES_PREROUTING_LIST=$(iptables --table nat --list-rules PREROUTING 2>/dev/null | grep 'Sing-box Family Bucket')
    [ -n "$IPTABLES_PREROUTING_LIST" ] && \
      HY2_PORT_HOPPING_RANGE=$(awk '{for (i=1; i<=NF; i++) if ($i=="--dport") {print $(i+1); exit}}' <<< "$IPTABLES_PREROUTING_LIST") && \
      PORT_HOPPING_TARGET=$(awk '{for (i=1; i<=NF; i++) if ($i=="--to-destination") {gsub(/^:/,"",$(i+1)); print $(i+1); exit}}' <<< "$IPTABLES_PREROUTING_LIST")
    [ -n "$HY2_PORT_HOPPING_RANGE" ] && PORT_HOPPING_START=${HY2_PORT_HOPPING_RANGE%:*} && PORT_HOPPING_END=${HY2_PORT_HOPPING_RANGE#*:}

  elif command -v firewall-cmd >/dev/null 2>&1 || [ "$SYSTEM" = 'CentOS' ]; then
    local FIREWALL_LIST=$(firewall-cmd --zone=public --list-forward-ports --permanent 2>/dev/null | grep "toport=${PORT_HOPPING_TARGET}")
    [ -n "$FIREWALL_LIST" ] && \
      PORT_HOPPING_START=$(sed "s/.*port=\([0-9]\+\)-.*/\1/" <<< "$FIREWALL_LIST") && \
      PORT_HOPPING_END=$(sed "s/.*port=${PORT_HOPPING_START}-\([0-9]\+\):.*/\1/" <<< "$FIREWALL_LIST") && \
      PORT_HOPPING_TARGET=$(sed "s/.*toport=\([0-9]\+\).*/\1/" <<< "$FIREWALL_LIST")

  else
    local IPTABLES_PREROUTING_LIST=$(iptables --table nat --list-rules PREROUTING 2>/dev/null | grep 'Sing-box Family Bucket')
    [ -n "$IPTABLES_PREROUTING_LIST" ] && \
      HY2_PORT_HOPPING_RANGE=$(awk '{for (i=1; i<=NF; i++) if ($i=="--dport") {print $(i+1); exit}}' <<< "$IPTABLES_PREROUTING_LIST") && \
      PORT_HOPPING_TARGET=$(awk '{for (i=1; i<=NF; i++) if ($i=="--to-destination") {gsub(/^:/,"",$(i+1)); print $(i+1); exit}}' <<< "$IPTABLES_PREROUTING_LIST")
    [ -n "$HY2_PORT_HOPPING_RANGE" ] && PORT_HOPPING_START=${HY2_PORT_HOPPING_RANGE%:*} && PORT_HOPPING_END=${HY2_PORT_HOPPING_RANGE#*:}
  fi

  [ -n "$PORT_HOPPING_START" ] && [ -n "$PORT_HOPPING_END" ] && HY2_PORT_HOPPING_RANGE="${PORT_HOPPING_START}:${PORT_HOPPING_END}"
}

# 检测 IPv4 IPv6 信息
check_system_ip() {
  [ "$L" = 'C' ] && local IS_CHINESE='?lang=zh-CN'
  local DEFAULT_LOCAL_INTERFACE4=$(ip -4 route show default | awk '/default/ {for (i=0; i<NF; i++) if ($i=="dev") {print $(i+1); exit}}')
  local DEFAULT_LOCAL_INTERFACE6=$(ip -6 route show default | awk '/default/ {for (i=0; i<NF; i++) if ($i=="dev") {print $(i+1); exit}}')
  if [ -n ""${DEFAULT_LOCAL_INTERFACE4}${DEFAULT_LOCAL_INTERFACE6}"" ]; then
    local DEFAULT_LOCAL_IP4=$(ip -4 addr show $DEFAULT_LOCAL_INTERFACE4 | sed -n 's#.*inet \([^/]\+\)/[0-9]\+.*global.*#\1#gp')
    local DEFAULT_LOCAL_IP6=$(ip -6 addr show $DEFAULT_LOCAL_INTERFACE6 | sed -n 's#.*inet6 \([^/]\+\)/[0-9]\+.*global.*#\1#gp')
    [ -n "$DEFAULT_LOCAL_IP4" ] && local BIND_ADDRESS4="--bind-address=$DEFAULT_LOCAL_IP4"
    [ -n "$DEFAULT_LOCAL_IP6" ] && local BIND_ADDRESS6="--bind-address=$DEFAULT_LOCAL_IP6"
  fi

  # 并行检测 IPv4 和 IPv6 信息
  {
    local CHECK_IP4=$(wget $BIND_ADDRESS4 -4 -qO- --no-check-certificate --tries=2 --timeout=2 https://ip.cloudflare.now.cc${IS_CHINESE})
    grep -q '.' <<< "$CHECK_IP4" && echo "$CHECK_IP4" > $TEMP_DIR/ip4.json
  }&

  {
    local CHECK_IP6=$(wget $BIND_ADDRESS6 -6 -qO- --no-check-certificate --tries=2 --timeout=2 https://ip.cloudflare.now.cc${IS_CHINESE})
    grep -q '.' <<< "$CHECK_IP6" && echo "$CHECK_IP6" > $TEMP_DIR/ip6.json
  }&

  wait

  [ -s $TEMP_DIR/ip4.json ] &&
  local IP4_JSON=$(cat $TEMP_DIR/ip4.json) &&
  WAN4=$(awk -F '"' '/"ip"/{print $4}' <<< "$IP4_JSON") &&
  COUNTRY4=$(awk -F '"' '/"country"/{print $4}' <<< "$IP4_JSON") &&
  EMOJI4=$(awk -F '"' '/"emoji"/{print $4}' <<< "$IP4_JSON") &&
  ASNORG4=$(awk -F '"' '/"isp"/{print $4}' <<< "$IP4_JSON") &&
  rm -f $TEMP_DIR/ip4.json

  [ -s $TEMP_DIR/ip6.json ] &&
  local IP6_JSON=$(cat $TEMP_DIR/ip6.json) &&
  WAN6=$(awk -F '"' '/"ip"/{print $4}' <<< "$IP6_JSON") &&
  COUNTRY6=$(awk -F '"' '/"country"/{print $4}' <<< "$IP6_JSON") &&
  EMOJI6=$(awk -F '"' '/"emoji"/{print $4}' <<< "$IP6_JSON") &&
  ASNORG6=$(awk -F '"' '/"isp"/{print $4}' <<< "$IP6_JSON") &&
  rm -f $TEMP_DIR/ip6.json

  # 公网 IPv6 探测失败时，回退到网卡上的静态 IPv6 地址（供主菜单显示，排除 ULA 内网 fc00::/7）
  [ -z "$WAN6" ] && { detect_all_ips; STATIC_IPV6=$(printf '%s\n' "${DETECTED_IPS[@]}" | grep ':' | grep -vE '^f[cd]' | tr '\n' ' '); }
}

# 检测本机网卡上所有静态 IPv4 / IPv6 地址（含内网），供用户确认后作为连接目标
detect_all_ips() {
  DETECTED_IPS=()
  # 所有网卡 IPv4 global 地址（含内网 10/8、172.16/12、192.168/16），排除 loopback / link-local
  while IFS= read -r addr; do
    [[ "$addr" =~ ^127\. ]] && continue
    [[ "$addr" =~ ^169\.254\. ]] && continue
    DETECTED_IPS+=("$addr")
  done < <(ip -4 -o addr show scope global 2>/dev/null | awk '{print $4}' | sed 's#/.*##')

  # 所有网卡 IPv6 global 地址（含 ULA fc00::/7），排除 loopback / link-local / multicast / 动态临时地址(dynamic mngtmpaddr)
  while IFS= read -r addr; do
    [[ "$addr" =~ ^::1$ ]] && continue
    [[ "$addr" =~ ^fe80: ]] && continue
    [[ "$addr" =~ ^ff ]] && continue
    DETECTED_IPS+=("$addr")
  done < <(ip -6 -o addr show scope global 2>/dev/null | grep -v 'dynamic' | awk '{print $4}' | sed 's#/.*##')
}

# 交互确认：列出检测到的 IP，用户输入要去掉的编号，结果写入 SERVER_IPS 数组
confirm_server_ips() {
  hint "\n $(text 187) "
  for i in "${!DETECTED_IPS[@]}"; do
    hint " $((i+1)). ${DETECTED_IPS[i]}"
  done
  reading " $(text 188) " REMOVE_IDX
  if [ -z "$REMOVE_IDX" ]; then
    SERVER_IPS=("${DETECTED_IPS[@]}")
    return
  fi
  local -a DROP=($REMOVE_IDX)
  SERVER_IPS=()
  for i in "${!DETECTED_IPS[@]}"; do
    local keep=1
    for d in "${DROP[@]}"; do [ "$((i+1))" = "$d" ] && keep=0; done
    [ "$keep" = 1 ] && SERVER_IPS+=("${DETECTED_IPS[i]}")
  done
  if [ "${#SERVER_IPS[@]}" -eq 0 ]; then
    warning " $(text 189) "
    SERVER_IPS=("${DETECTED_IPS[@]}")
  fi
}

# 输入起始 port 函数
input_start_port() {
  local NUM=$1
  local PORT_ERROR_TIME=6
  while true; do
    [ "$PORT_ERROR_TIME" -lt 6 ] && unset IN_USED START_PORT
    (( PORT_ERROR_TIME-- )) || true
    if [ "$PORT_ERROR_TIME" = 0 ]; then
      error "\n $(text 3) \n"
    else
      [ -z "$START_PORT" ] && reading "\n ${TOTAL_STEPS:+(${STEP_NUM}/${TOTAL_STEPS}) }$(text 11) " START_PORT
    fi
    START_PORT=${START_PORT:-"$START_PORT_DEFAULT"}
    if [[ "$START_PORT" =~ ^[1-9][0-9]{2,4}$ && "$START_PORT" -ge "$MIN_PORT" && "$START_PORT" -le "$MAX_PORT" ]]; then
      for port in $(eval echo {$START_PORT..$[START_PORT+NUM-1]}); do
        is_port_in_use "$port" && IN_USED+=("$port")
      done
      [ "${#IN_USED[*]}" -eq 0 ] && break || warning "\n $(text 44) \n"
    fi
  done
}

# 段数 >4 时只显示前 4 段，末尾追加 "等 N 个"（N = 未显示的端口总数）
format_ports_display() {
  local -a PORTS=("$@") SEGS=()
  local -i TOTAL=0 i a b
  local PREV='' SEG_START='' OUT=''
  [ "${#PORTS[@]}" -eq 0 ] && { echo; return; }
  PORTS=($(printf '%s\n' "${PORTS[@]}" | sort -n | uniq))
  TOTAL=${#PORTS[@]}
  SEG_START=${PORTS[0]}
  PREV=${PORTS[0]}
  for ((i=1; i<TOTAL; i++)); do
    if [ $((PREV + 1)) -eq ${PORTS[i]} ]; then
      PREV=${PORTS[i]}
    else
      SEGS+=("$SEG_START $PREV")
      SEG_START=${PORTS[i]}
      PREV=${PORTS[i]}
    fi
  done
  SEGS+=("$SEG_START $PREV")
  if [ "${#SEGS[@]}" -eq 1 ]; then
    read -r a b <<< "${SEGS[0]}"
    [ "$a" -eq "$b" ] && OUT="$a" || OUT="${a} - ${b}"
    if [ "$TOTAL" -gt 6 ]; then
      [ "$L" = 'C' ] && OUT="${OUT}，共 ${TOTAL} 个" || OUT="${OUT}, ${TOTAL} in total"
    fi
  elif [ "${#SEGS[@]}" -le 4 ]; then
    local -a PARTS=()
    for s in "${SEGS[@]}"; do
      read -r a b <<< "$s"
      [ "$a" -eq "$b" ] && PARTS+=("$a") || PARTS+=("${a} - ${b}")
    done
    OUT="${PARTS[0]}"
    for s in "${PARTS[@]:1}"; do OUT="${OUT}, ${s}"; done
  else
    local -a PARTS=()
    local -i SHOWN=0
    for ((i=0; i<4; i++)); do
      read -r a b <<< "${SEGS[i]}"
      SHOWN=$(( SHOWN + b - a + 1 ))
      [ "$a" -eq "$b" ] && PARTS+=("$a") || PARTS+=("${a} - ${b}")
    done
    OUT="${PARTS[0]}"
    for s in "${PARTS[@]:1}"; do OUT="${OUT}, ${s}"; done
    if [ "$L" = 'C' ]; then
      OUT="${OUT} ... 等 $(( TOTAL - SHOWN )) 个"
    else
      OUT="${OUT} ... $(( TOTAL - SHOWN )) more"
    fi
  fi
  echo "$OUT"
}

# -d 菜单：监听端口 → 方式选择（1. 修改开始端口，默认 / 2. 各协议独立端口）
change_port_mode() {
  local PORTS_MODE='' MODE_ERROR=6
  while true; do
    hint "\n $(text 161) "
    reading "\n $(text 24) " PORTS_MODE
    case "${PORTS_MODE:-1}" in
      1 ) change_start_port; return ;;
      2 ) change_independent_port; return ;;
      * ) (( MODE_ERROR-- )) || true
          [ "$MODE_ERROR" = 0 ] && error "\n $(text 3) \n"
          warning " $(text 143) " ;;
    esac
  done
}

# 读取 hysteria2 当前监听端口（未安装时输出为空）
get_hy2_port() {
  ls ${WORK_DIR}/conf/*${NODE_TAG[1]}_inbounds.json >/dev/null 2>&1 || return
  awk -F '[:,]' '/"listen_port"/{gsub(/[[:space:]]/,"",$2); print $2; exit}' ${WORK_DIR}/conf/*${NODE_TAG[1]}_inbounds.json 2>/dev/null
}

# 端口应用后的通用后处理（方式 1 / 2 共用）：联动刷新 + 热加载 + hy2 端口跳跃目标重建
apply_ports_post() {
  local HY2_OLD="$1" HY2_NEW="$2"
  fetch_nodes_value
  # nginx 反代端口同步：nginx.conf 存在则重建并热加载（proxy_pass 必须跟随 WS 端口变化，
  # 不依赖 PORT_NGINX 是否已被 IS_SUB/IS_ARGO 分支读入）
  if [ -s "${WORK_DIR}/nginx.conf" ]; then
    [ -z "$PORT_NGINX" ] && PORT_NGINX=$(awk '/listen/{print $2; exit}' ${WORK_DIR}/nginx.conf | tr -d ';')
    # 现有 nginx.conf 已含本地 WS 反代时强制按 is_argo 重建，
    # 避免 IS_ARGO 标志缺失/失效时导出配置丢失 WS 反代（端口变化后必须跟随）
    local _ARGO_BAK="${IS_ARGO-}"
    grep -q 'proxy_pass.*127.0.0.1' "${WORK_DIR}/nginx.conf" 2>/dev/null && IS_ARGO=is_argo
    export_nginx_conf_file
    IS_ARGO="$_ARGO_BAK"
  fi
  nginx_sync
  cmd_systemctl reload sing-box
  [ -n "$ARGO_DOMAIN" ] && export_argo_json_file
  # Hysteria2 端口跳跃目标同步（hy2 端口变化且跳跃已启用时，显式重建 dnat 目标）
  if [ -n "$HY2_OLD" ] && [ -n "$HY2_NEW" ] && [ "$HY2_OLD" != "$HY2_NEW" ]; then
    check_port_hopping_nat
    if [ -n "$PORT_HOPPING_START" ] && [ -n "$PORT_HOPPING_END" ]; then
      del_port_hopping_nat
      (add_port_hopping_nat "$PORT_HOPPING_START" "$PORT_HOPPING_END" "$HY2_NEW") >/dev/null 2>&1
    fi
  fi
  sync_firewall_rules
  sleep 2
  export_list
  # 显示新端口列表
  local PORTS=$(format_ports_display $(awk -F ':|,' '/"listen_port"/{print $2}' ${WORK_DIR}/conf/*_inbounds.json 2>/dev/null))
  [ -n "$PORTS" ] && hint " $(text 164) "
  info " $(text 170) "
}

# 方式 1：修改开始端口（各协议按顺序占用，现有逻辑 + 预览确认 + hy2 跳跃联动）
change_start_port() {
  local OLD_PORTS OLD_START_PORT OLD_CONSECUTIVE_PORTS
  local _STEP_NUM_BAK="${STEP_NUM-}" _TOTAL_STEPS_BAK="${TOTAL_STEPS-}"
  OLD_PORTS=$(awk -F ':|,' '/listen_port/{print $2}' ${WORK_DIR}/conf/*)
  OLD_START_PORT=$(awk 'NR == 1 { min = $0 } { if ($0 < min) min = $0; count++ } END {print min}' <<< "$OLD_PORTS")
  OLD_CONSECUTIVE_PORTS=$(awk 'END { print NR }' <<< "$OLD_PORTS")
  local HY2_OLD=$(get_hy2_port)
  unset STEP_NUM TOTAL_STEPS
  input_start_port $OLD_CONSECUTIVE_PORTS
  STEP_NUM="$_STEP_NUM_BAK"
  TOTAL_STEPS="$_TOTAL_STEPS_BAK"
  [ "$START_PORT" = "$OLD_START_PORT" ] && { info " $(text 135) "; return; }
  # 预览确认（方式 1 / 方式 2 同一套确认交互）
  local NUM="$OLD_CONSECUTIVE_PORTS" OLD_START="$OLD_START_PORT" NEW_START="$START_PORT" NEW_END=$((START_PORT + OLD_CONSECUTIVE_PORTS - 1))
  hint "\n $(text 173) "
  reading "\n $(text 168) " PORTS_CONFIRM
  [ "${PORTS_CONFIRM,,}" != 'y' ] && { info " $(text 135) "; return; }
  for ((a=0; a<$OLD_CONSECUTIVE_PORTS; a++)) do
    [ -s ${WORK_DIR}/conf/${CONF_FILES[a]} ] && sed -i "s/\(.*listen_port.*:\)$((OLD_START_PORT+a))/\1$((START_PORT+a))/" ${WORK_DIR}/conf/*
  done
  apply_ports_post "$HY2_OLD" "$(get_hy2_port)"
}

# 方式 2：各协议独立端口（多选协议 → 逐项询问端口 → 校验 → 预览确认 → 应用）
change_independent_port() {
  local -a LETTERS=() PROTOS=() PORTS=() PROTO_IDX=()
  local -A OWNER=()
  local -i i j
  local letter proto port
  for ((i=0; i<${#PROTOCOL_LIST[@]}; i++)); do
    local -a FILES=(${WORK_DIR}/conf/*${NODE_TAG[i]}_inbounds.json)
    [ -s "${FILES[0]}" ] || continue
    port=$(awk -F '[:,]' '/"listen_port"/{gsub(/[[:space:]]/,"",$2); print $2; exit}' "${FILES[0]}")
    [ -n "$port" ] || continue
    letter=$(asc $((i+98)))
    LETTERS+=("$letter"); PROTOS+=("${PROTOCOL_LIST[i]}"); PORTS+=("$port"); PROTO_IDX+=("$i")
    OWNER[$port]="${PROTOCOL_LIST[i]}"
  done
  [ "${#LETTERS[@]}" -eq 0 ] && { info " $(text 135) "; return; }

  # 多选需要修改端口的协议（a = 全部，b.. = 逐协议，留空 = 不修改，顺序 = 输入顺序）
  local MAX_LETTER=$(asc $(( ${#PROTOCOL_LIST[@]} + 97 )))
  local CHOOSE='' SELECTED=()
  hint "\n $(text 162) "
  for ((i=0; i<${#LETTERS[@]}; i++)); do
    local LETTER="${LETTERS[i]}" PROTO="${PROTOS[i]}" PORT="${PORTS[i]}"
    hint " $(text 172) "
  done
  reading "\n $(text 24) " CHOOSE
  if [ -z "$CHOOSE" ]; then
    info " $(text 135) "
    return
  fi
  if [[ "${CHOOSE,,}" =~ ^[aA]$ ]]; then
    SELECTED=("${LETTERS[@]}")
  else
    local FILTERED=$(grep -o . <<< "${CHOOSE,,}" | sed "/[^b-$MAX_LETTER]/d" | awk '!seen[$0]++' | tr -d '\n')
    local TMP=() ch
    while IFS= read -r -n1 ch; do
      [ -n "$ch" ] && [[ " ${LETTERS[*]} " =~ " $ch " ]] && TMP+=("$ch")
    done <<< "$FILTERED"
    SELECTED=("${TMP[@]}")
  fi
  [ "${#SELECTED[@]}" -eq 0 ] && { info " $(text 135) "; return; }

  # 逐协议询问新端口（留空 = 不变；校验：数字范围 / 与他协议重复 / 系统占用，错误即时提示，上限 6 次）
  local -a CHG_LETTERS=() CHG_OLDS=() CHG_NEWS=()
  local chg_letter proto oldport newport conflict new_port err_time
  for ((j=0; j<${#SELECTED[@]}; j++)); do
    chg_letter="${SELECTED[j]}"
    for ((i=0; i<${#LETTERS[@]}; i++)); do
      [ "${LETTERS[i]}" = "$chg_letter" ] && break
    done
    proto="${PROTOS[i]}"; oldport="${PORTS[i]}"
    new_port=''
    err_time=6
    while true; do
      local PROTO="$proto" PORT="$oldport"
      reading " $(text 163) " new_port
      if [ -z "$new_port" ]; then
        newport="$oldport"; break
      fi
      if [[ "$new_port" =~ ^[1-9][0-9]{2,4}$ && "$new_port" -ge "$MIN_PORT" && "$new_port" -le "$MAX_PORT" ]]; then
        conflict="${OWNER[$new_port]-}"
        if [ -n "$conflict" ] && [ "$conflict" != "$proto" ]; then
          local PORT="$new_port" PROTO="$conflict"
          warning " $(text 171) "
          (( err_time-- )) || true
          [ "$err_time" = 0 ] && error "\n $(text 3) \n"
          continue
        fi
        if [ "$new_port" != "$oldport" ] && is_port_in_use "$new_port"; then
          local PORT="$new_port"
          warning " $(text 166) "
          (( err_time-- )) || true
          [ "$err_time" = 0 ] && error "\n $(text 3) \n"
          continue
        fi
        newport="$new_port"; break
      else
        local PORT="$new_port"
        warning " $(text 166) "
        (( err_time-- )) || true
        [ "$err_time" = 0 ] && error "\n $(text 3) \n"
      fi
    done
    [ "$newport" != "$oldport" ] && { unset "OWNER[$oldport]"; OWNER[$newport]="$proto"; }
    [ "$newport" != "$oldport" ] && { CHG_LETTERS+=("$chg_letter"); CHG_OLDS+=("$oldport"); CHG_NEWS+=("$newport"); }
  done

  [ "${#CHG_LETTERS[@]}" -eq 0 ] && { info " $(text 165) "; return; }

  # 变更预览（只列变更项）与确认
  hint "\n $(text 167) "
  for ((j=0; j<${#CHG_LETTERS[@]}; j++)); do
    for ((i=0; i<${#LETTERS[@]}; i++)); do
      [ "${LETTERS[i]}" = "${CHG_LETTERS[j]}" ] && break
    done
    local PROTO="${PROTOS[i]}" OLD="${CHG_OLDS[j]}" NEW="${CHG_NEWS[j]}"
    hint " $(text 169) "
  done
  reading " $(text 168) " PORTS_CONFIRM
  [ "${PORTS_CONFIRM,,}" != 'y' ] && { info " $(text 135) "; return; }

  # 应用（按协议文件替换，避免端口号在其他字段重复出现时误伤）
  local HY2_OLD=$(get_hy2_port)
  for ((j=0; j<${#CHG_LETTERS[@]}; j++)); do
    for ((i=0; i<${#LETTERS[@]}; i++)); do
      [ "${LETTERS[i]}" = "${CHG_LETTERS[j]}" ] && break
    done
    sed -i "/\"listen_port\"/s/[0-9]\+/${CHG_NEWS[j]}/" ${WORK_DIR}/conf/*${NODE_TAG[PROTO_IDX[i]]}_inbounds.json
  done
  apply_ports_post "$HY2_OLD" "$(get_hy2_port)"
}

# 定义 Sing-box 变量
sing-box_variables() {
  STEP_NUM=0
  # 预先用全选协议计算最大总步骤数，用于协议选择提示时显示 (1/?)
  local SAVED_PROTOCOLS=("${INSTALL_PROTOCOLS[@]}")
  INSTALL_PROTOCOLS=(b c d e f g h i j k l m)
  calc_install_steps
  INSTALL_PROTOCOLS=("${SAVED_PROTOCOLS[@]}")

  if grep -qi 'cloudflare' <<< "$ASNORG4$ASNORG6"; then
    if grep -qi 'cloudflare' <<< "$ASNORG6" && [ -n "$WAN4" ] && ! grep -qi 'cloudflare' <<< "$ASNORG4"; then
      SERVER_IP_DEFAULT=$WAN4
    elif grep -qi 'cloudflare' <<< "$ASNORG4" && [ -n "$WAN6" ] && ! grep -qi 'cloudflare' <<< "$ASNORG6"; then
      SERVER_IP_DEFAULT=$WAN6
    else
      local a=6
      until [ -n "$SERVER_IP" ] && is_valid_server_addr "$SERVER_IP"; do
        ((a--)) || true
        [ "$a" = 0 ] && error "\n $(text 3) \n"
        reading "\n $(text 46) " SERVER_IP
      done
    fi
  elif [ -n "$WAN4" ]; then
    SERVER_IP_DEFAULT=$WAN4
  elif [ -n "$WAN6" ]; then
    SERVER_IP_DEFAULT=$WAN6
  fi

  # 选择安装的协议，由于选项 a 为全部协议，所以选项数不是从 a 开始，而是从 b 开始，处理输入：把大写全部变为小写，把不符合的选项去掉，把重复的选项合并
  MAX_CHOOSE_PROTOCOLS=$(asc $(( CONSECUTIVE_PORTS+96+1 )))
  (( STEP_NUM++ )) || true
  if [ -z "$CHOOSE_PROTOCOLS" ]; then
    hint "\n (${STEP_NUM}/${TOTAL_STEPS:-?}) $(text 49) "
    for e in "${!PROTOCOL_LIST[@]}"; do
      hint " $(asc $(( e+98 ))). ${PROTOCOL_LIST[e]} "
    done
    reading "\n $(text 24) " CHOOSE_PROTOCOLS
  fi

  # 对选择协议的输入处理逻辑：先把所有的大写转为小写，并把所有没有去选项剔除掉，最后按输入的次序排序。如果选项为 a(all) 和其他选项并存，将会忽略 a，如 abc 则会处理为 bc
  [[ ! "${CHOOSE_PROTOCOLS,,}" =~ [b-$MAX_CHOOSE_PROTOCOLS] ]] && INSTALL_PROTOCOLS=($(eval echo {b..$MAX_CHOOSE_PROTOCOLS})) || INSTALL_PROTOCOLS=($(grep -o . <<< "$CHOOSE_PROTOCOLS" | sed "/[^b-$MAX_CHOOSE_PROTOCOLS]/d" | awk '!seen[$0]++'))

  # 协议已确定，按实际选择重新计算总步骤数
  calc_install_steps

  # 显示选择协议及其次序，输入开始端口号
  if [ -z "$START_PORT" ]; then
    (( STEP_NUM++ )) || true
    hint "\n $(text 60) "
    for w in "${!INSTALL_PROTOCOLS[@]}"; do
      [ "$w" -ge 9 ] && hint " $(( w+1 )). ${PROTOCOL_LIST[$(($(asc ${INSTALL_PROTOCOLS[w]}) - 98))]} " || hint " $(( w+1 )) . ${PROTOCOL_LIST[$(($(asc ${INSTALL_PROTOCOLS[w]}) - 98))]} "
    done
    input_start_port ${#INSTALL_PROTOCOLS[@]}
  fi

  # 输出模式选择，输入用于订阅的 Nginx 服务端口号， 后台根据选择安装依赖
  if [[ "$IS_SUB" = 'is_sub' || "$IS_ARGO" = 'is_argo' ]]; then
    (( STEP_NUM++ )) || true
    input_nginx_port
  fi

  # 检测本机所有静态 IP 并确认，得到 SERVER_IPS 数组；SERVER_IP 取第一个作为主 IP
  if [ -n "$SERVER_IP" ]; then
    # 已通过 --SERVER_IP / -F 配置文件预设（支持逗号分隔多 IP）
    SERVER_IPS=(${SERVER_IP//,/ })
  else
    detect_all_ips
    # 网卡检测不到 IP 时，退回公网出口 IP
    [ "${#DETECTED_IPS[@]}" -eq 0 ] && [ -n "$WAN4" ] && DETECTED_IPS+=("$WAN4")
    [ "${#DETECTED_IPS[@]}" -eq 0 ] && [ -n "$WAN6" ] && DETECTED_IPS+=("$WAN6")
    if [[ "$NONINTERACTIVE_INSTALL" = 'noninteractive_install' || "$IS_FAST_INSTALL" = 'is_fast_install' ]]; then
      SERVER_IPS=("${DETECTED_IPS[@]}")
    else
      (( STEP_NUM++ )) || true
      confirm_server_ips
    fi
  fi
  [ "${#SERVER_IPS[@]}" -eq 0 ] && error " $(text 47) "
  SERVER_IP=${SERVER_IPS[0]} && WS_SERVER_IP_SHOW=$SERVER_IP

  # 根据 IPv4 和 IPv6 的网络状态，使不同的 DNS 策略
  command -v ping >/dev/null 2>&1 && for i in {1..3}; do
    ping -c 1 -W 1 "151.101.1.91" &>/dev/null && local IS_IPV4=is_ipv4 && break
  done

  if command -v ping6 >/dev/null 2>&1; then
    for i in {1..3}; do
      ping6 -c 1 -W 1 "2a04:4e42:200::347" &>/dev/null && local IS_IPV6=is_ipv6 && break
    done
  elif command -v ping >/dev/null 2>&1; then
    for i in {1..3}; do
      ping -c 1 -W 1 "2a04:4e42:200::347" &>/dev/null && local IS_IPV6=is_ipv6 && break
    done
  fi

  case "${IS_IPV4}@${IS_IPV6}" in
    is_ipv4@is_ipv6)
      STRATEGY=prefer_ipv4
      ;;
    is_ipv4@)
      STRATEGY=ipv4_only
      ;;
    @is_ipv6)
      STRATEGY=ipv6_only
      ;;
    *)
      STRATEGY=prefer_ipv4
      ;;
  esac

  # 检测是否解锁 chatGPT：按服务器地址类型决定检测栈；域名（NAT 动态地址）交由 wget 按系统默认解析，避免域名被误判为 IPv6 栈
  CHATGPT_OUT=warp-ep
  if [[ "$SERVER_IP" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
    local CHATGPT_STACK='-4'
  elif [[ "$SERVER_IP" =~ ^[0-9a-fA-F:]+$ && "$SERVER_IP" =~ : ]]; then
    local CHATGPT_STACK='-6'
  else
    local CHATGPT_STACK=''
  fi
  [ "$(check_chatgpt $CHATGPT_STACK)" = 'unlock' ] && CHATGPT_OUT=direct

  # 如果选择有 b j k 这些 reality 协议，自定义 reality 公私钥，如果没有则自动生成
  if [ "$NONINTERACTIVE_INSTALL" != 'noninteractive_install' ] && [[ "${INSTALL_PROTOCOLS[@]}" =~ 'b'|'j'|'k' ]]; then
    (( STEP_NUM++ )) || true
    input_reality_key
  fi

  # 如选择有 c. hysteria2 时，先选择 Realm / WARP，再选择是否使用端口跳跃。
  # 这三项属于 Hysteria2 子选项，不计入安装总步骤，也不显示步骤编号。
  if [[ "${INSTALL_PROTOCOLS[@]}" =~ 'c' ]]; then
    # Realm 与端口跳跃互斥：先提示；开启 Realm 后跳过端口跳跃交互
    hint "\n $(text 186) \n"
    input_hy2_realm
    local _SAVED_TOTAL_STEPS="$TOTAL_STEPS"
    TOTAL_STEPS=''
    [ "$IS_HY2_REALM" != 'is_hy2_realm' ] && input_hopping_port
    TOTAL_STEPS="$_SAVED_TOTAL_STEPS"
  fi

  # 如选择有 h. vmess + ws 或 i. vless + ws 时，先检测是否有支持的 http 端口可用，如有则要求输入域名和 cdn
  if [[ "${INSTALL_PROTOCOLS[@]}" =~ 'h' ]]; then
    if [ "$IS_ARGO" = 'is_argo' ]; then
      if [ "$ARGO_READY" != 'argo_ready' ]; then
        (( STEP_NUM++ )) || true
        input_argo_auth is_install
      fi
      local ARGO_READY=argo_ready
    else
      local DOMAIN_ERROR_TIME=5
      until [ -n "$VMESS_HOST_DOMAIN" ]; do
        (( DOMAIN_ERROR_TIME-- )) || true
        [ "$DOMAIN_ERROR_TIME" != 0 ] && TYPE=VMESS && reading "\n $(text 50) " VMESS_HOST_DOMAIN || error "\n $(text 3) \n"
      done
    fi
  fi

  if [[ "${INSTALL_PROTOCOLS[@]}" =~ 'i' ]]; then
    if [ "$IS_ARGO" = 'is_argo' ]; then
      if [ "$ARGO_READY" != 'argo_ready' ]; then
        (( STEP_NUM++ )) || true
        input_argo_auth is_install
      fi
      local ARGO_READY=argo_ready
    else
      local DOMAIN_ERROR_TIME=5
      until [ -n "$VLESS_HOST_DOMAIN" ]; do
        (( DOMAIN_ERROR_TIME-- )) || true
        [ "$DOMAIN_ERROR_TIME" != 0 ] && TYPE=VLESS && reading "\n $(text 50) " VLESS_HOST_DOMAIN || error "\n $(text 3) \n"
      done
    fi
  fi

  # 选择或者输入 cdn
  if [[ -z "$CDN" && -n "${VMESS_HOST_DOMAIN}${VLESS_HOST_DOMAIN}${ARGO_READY}" ]]; then
    (( STEP_NUM++ )) || true
    input_cdn
  fi

  # 确认 UUID
  input_uuid

  # 输入节点名，以系统的 hostname 作为默认
  input_node_name
}

check_dependencies() {
  local DEPS=() DEPS_CHECK=() DEPS_INSTALL=()

  # 1. Alpine 特有处理：检查 BusyBox wget，设置 IS_PREFER_GO
  if [ "$SYSTEM" = 'Alpine' ]; then
    IS_PREFER_GO=true
    local CHECK_WGET=$(wget 2>&1 | sed -n 1p)
    grep -qi 'busybox' <<< "$CHECK_WGET" && DEPS+=("wget")

    DEPS_CHECK+=("bash" "rc-update")
    DEPS_INSTALL+=("bash" "openrc")
  else
    # 非 Alpine 系统，检查 systemd-resolved 状态，用于 DNS 配置里的 prefer_go 字段
    command -v systemctl >/dev/null 2>&1 && systemctl is-active --quiet systemd-resolved && IS_PREFER_GO=false || IS_PREFER_GO=true
  fi

  # 2. 基础通用依赖（不含防火墙，防火墙仅端口跳跃时按需安装）
  DEPS_CHECK+=("wget" "tar" "ss"  "ip"        "bash" "openssl" "ping")
  DEPS_INSTALL+=("wget" "tar" "iproute2" "iproute2" "bash" "openssl" "iputils-ping")

  [ "$SYSTEM" != 'Alpine' ] && DEPS_CHECK+=("systemctl") && DEPS_INSTALL+=("systemctl")

  # CentOS7 需要 epel-release
  [ "$SYSTEM" = 'CentOS' ] && [ "$IS_CENTOS" = 'CentOS7' ] && \
    yum repolist 2>/dev/null | grep -q epel || { [ "$SYSTEM" = 'CentOS' ] && [ "$IS_CENTOS" = 'CentOS7' ] && DEPS+=("epel-release"); }

  for g in "${!DEPS_CHECK[@]}"; do
    ! command -v "${DEPS_CHECK[g]}" >/dev/null 2>&1 && DEPS+=("${DEPS_INSTALL[g]}")
  done

  # 3. 去重并安装
  DEPS=($(printf "%s\n" "${DEPS[@]}" | sort -u))
  if [ "${#DEPS[@]}" -gt 0 ]; then
    info "\n $(text 7) $(sed "s/ /,&/g" <<< "${DEPS[*]}") \n"
    [[ ! "$SYSTEM" =~ Alpine|CentOS ]] && ${PACKAGE_UPDATE[int]} >/dev/null 2>&1
    ${PACKAGE_INSTALL[int]} "${DEPS[@]}" >/dev/null 2>&1
  else
    info "\n $(text 8) \n"
  fi

  # 4. 对于 Alpine 系统，确保 OpenRC 服务已启动
  if [ "$SYSTEM" = 'Alpine' ]; then
    if ! rc-service --list | grep -q "^openrc"; then
      rc-update add openrc boot >/dev/null 2>&1
      rc-service openrc start >/dev/null 2>&1
    fi
  fi
}

# 生成 UFW PortHopping 备注
add_port_hopping_ufw_rules() {
  local PORT_HOPPING_START=$1
  local PORT_HOPPING_END=$2
  local PORT_HOPPING_TARGET=$3
  local TARGET_PORT="$3"
  local COMMENT="Sing-box Family Bucket UFW NAT ${PORT_HOPPING_START}:${PORT_HOPPING_END} -> ${TARGET_PORT}"

  [ -z "$PORT_HOPPING_START" ] && return 1
  [ -z "$PORT_HOPPING_END" ] && return 1
  [ -z "$TARGET_PORT" ] && return 1

  local UFW_BEFORE_RULES='/etc/ufw/before.rules'
  local UFW_BEFORE6_RULES='/etc/ufw/before6.rules'
  local UFW_IPV4_BLOCK_BEGIN="# ${COMMENT} IPv4 BEGIN"
  local UFW_IPV4_BLOCK_END="# ${COMMENT} IPv4 END"
  local UFW_IPV6_BLOCK_BEGIN="# ${COMMENT} IPv6 BEGIN"
  local UFW_IPV6_BLOCK_END="# ${COMMENT} IPv6 END"

  # 先清理所有历史残留规则，确保文件和 numbered 规则都干净
  del_port_hopping_ufw_rules >/dev/null 2>&1

  # 注意：这里必须用 TARGET_PORT，不能再用可能被下游函数改掉的 PORT_HOPPING_TARGET
  add_port_hopping_ufw_block "$UFW_BEFORE_RULES"  "$UFW_IPV4_BLOCK_BEGIN" "$UFW_IPV4_BLOCK_END" "$PORT_HOPPING_START" "$PORT_HOPPING_END" "$TARGET_PORT" "$COMMENT" || return 1
  add_port_hopping_ufw_block "$UFW_BEFORE6_RULES" "$UFW_IPV6_BLOCK_BEGIN" "$UFW_IPV6_BLOCK_END" "$PORT_HOPPING_START" "$PORT_HOPPING_END" "$TARGET_PORT" "$COMMENT" || return 1

  ufw delete allow ${PORT_HOPPING_START}:${PORT_HOPPING_END}/udp >/dev/null 2>&1 || true
  ufw allow ${PORT_HOPPING_START}:${PORT_HOPPING_END}/udp comment "$COMMENT" >/dev/null 2>&1 || return 1
  ufw reload >/dev/null 2>&1 || return 1

  [ "$(ufw status 2>/dev/null | awk '/^Status/{print $NF; exit}')" != 'active' ] && warning "\n $(text 145) \n"

  return 0
}

# 向指定的 UFW 规则文件写入 PortHopping NAT 规则块
add_port_hopping_ufw_block() {
  local RULES_FILE=$1
  local BLOCK_BEGIN=$2
  local BLOCK_END=$3
  local PORT_HOPPING_START=$4
  local PORT_HOPPING_END=$5
  local PORT_HOPPING_TARGET=$6
  local COMMENT=$7

  [ ! -e "$RULES_FILE" ] && return 0
  [ -z "$PORT_HOPPING_START" ] && return 1
  [ -z "$PORT_HOPPING_END" ] && return 1
  [ -z "$PORT_HOPPING_TARGET" ] && return 1
  [ -z "$COMMENT" ] && return 1

  awk \
    -v begin="$BLOCK_BEGIN" \
    -v end="$BLOCK_END" \
    -v start="$PORT_HOPPING_START" \
    -v finish="$PORT_HOPPING_END" \
    -v target="$PORT_HOPPING_TARGET" \
    -v comment="$COMMENT" '
    BEGIN { inserted=0 }
    {
      if ($0 ~ /^\*filter/ && inserted==0) {
        print begin
        print "*nat"
        print ":PREROUTING ACCEPT [0:0]"
        print "-A PREROUTING -p udp --dport " start ":" finish " -m comment --comment \"" comment "\" -j DNAT --to-destination :" target
        print "COMMIT"
        print end
        inserted=1
      }
      print
    }
    END {
      if (inserted==0) {
        print begin
        print "*nat"
        print ":PREROUTING ACCEPT [0:0]"
        print "-A PREROUTING -p udp --dport " start ":" finish " -m comment --comment \"" comment "\" -j DNAT --to-destination :" target
        print "COMMIT"
        print end
      }
    }
  ' "$RULES_FILE" > "${TEMP_DIR}/$(basename "$RULES_FILE")" && mv "${TEMP_DIR}/$(basename "$RULES_FILE")" "$RULES_FILE"
}

# 删除指定 UFW 规则文件中的 PortHopping NAT 规则块
del_port_hopping_ufw_block() {
  local RULES_FILE=$1
  local IP_VERSION=$2
  local TEMP_RULES_FILE

  [ ! -e "$RULES_FILE" ] && return 0

  TEMP_RULES_FILE="${TEMP_DIR}/$(basename "$RULES_FILE")"

  awk -v ip_version="$IP_VERSION" '
    BEGIN { in_block=0 }
    {
      if ($0 ~ "^# Sing-box Family Bucket UFW NAT .* " ip_version " BEGIN$") {
        in_block=1
        next
      }
      if (in_block==1 && $0 ~ "^# Sing-box Family Bucket UFW NAT .* " ip_version " END$") {
        in_block=0
        next
      }
      if (in_block==0) print
    }
  ' "$RULES_FILE" > "$TEMP_RULES_FILE" && mv "$TEMP_RULES_FILE" "$RULES_FILE"
}

# 删除 UFW PortHopping NAT 规则
del_port_hopping_ufw_rules() {
  local UFW_BEFORE_RULES='/etc/ufw/before.rules'
  local UFW_BEFORE6_RULES='/etc/ufw/before6.rules'
  local COMMENT_PREFIX='Sing-box Family Bucket UFW NAT'
  local RULE_NUM
  local OLD_START OLD_END

  check_port_hopping_ufw_rules
  OLD_START="$PORT_HOPPING_START"
  OLD_END="$PORT_HOPPING_END"

  del_port_hopping_ufw_block "$UFW_BEFORE_RULES" "IPv4" >/dev/null 2>&1
  del_port_hopping_ufw_block "$UFW_BEFORE6_RULES" "IPv6" >/dev/null 2>&1

  if [ -n "$OLD_START" ] && [ -n "$OLD_END" ]; then
    ufw delete allow ${OLD_START}:${OLD_END}/udp >/dev/null 2>&1 || true
  fi

  while read -r RULE_NUM; do
    [ -n "$RULE_NUM" ] && ufw --force delete "$RULE_NUM" >/dev/null 2>&1 || true
  done < <(
    ufw status numbered 2>/dev/null | \
    grep "$COMMENT_PREFIX" | \
    awk -F'[][]' '{print $2}' | sort -rn
  )

  ufw reload >/dev/null 2>&1 || return 1

  unset PORT_HOPPING_START PORT_HOPPING_END HY2_PORT_HOPPING_RANGE
  return 0
}

# 检查 UFW PortHopping NAT 规则
check_port_hopping_ufw_rules() {
  unset PORT_HOPPING_START PORT_HOPPING_END HY2_PORT_HOPPING_RANGE
  local DETECTED_TARGET
  local UFW_BEFORE_RULES='/etc/ufw/before.rules'
  local UFW_BEFORE6_RULES='/etc/ufw/before6.rules'
  local UFW_RULE

  DETECTED_TARGET=$(awk -F '[:,]' '/"listen_port"/{gsub(/[[:space:]]/, "", $2); print $2; exit}' ${WORK_DIR}/conf/*${NODE_TAG[1]}_inbounds.json 2>/dev/null)

  if [ -s "$UFW_BEFORE_RULES" ]; then
    UFW_RULE=$(awk '
      /Sing-box Family Bucket UFW NAT .* IPv4 BEGIN/ { in_block=1; next }
      /Sing-box Family Bucket UFW NAT .* IPv4 END/   { in_block=0 }
      in_block && /-A PREROUTING -p udp/ { print; exit }
    ' "$UFW_BEFORE_RULES")
  fi

  if [ -z "$UFW_RULE" ] && [ -s "$UFW_BEFORE6_RULES" ]; then
    UFW_RULE=$(awk '
      /Sing-box Family Bucket UFW NAT .* IPv6 BEGIN/ { in_block=1; next }
      /Sing-box Family Bucket UFW NAT .* IPv6 END/   { in_block=0 }
      in_block && /-A PREROUTING -p udp/ { print; exit }
    ' "$UFW_BEFORE6_RULES")
  fi

  [ -z "$UFW_RULE" ] && {
    PORT_HOPPING_TARGET="$DETECTED_TARGET"
    return 0
  }

  if [[ "$UFW_RULE" =~ --dport[[:space:]]+([0-9]+):([0-9]+) ]]; then
    PORT_HOPPING_START="${BASH_REMATCH[1]}"
    PORT_HOPPING_END="${BASH_REMATCH[2]}"
    HY2_PORT_HOPPING_RANGE="${PORT_HOPPING_START}:${PORT_HOPPING_END}"
  fi

  if [[ "$UFW_RULE" =~ --to-destination[[:space:]]+:([0-9]+) ]]; then
    PORT_HOPPING_TARGET="${BASH_REMATCH[1]}"
  else
    PORT_HOPPING_TARGET="$DETECTED_TARGET"
  fi
}

# 检测防火墙后端
check_firewall_backend() {
  local UFW_STATUS

  if command -v ufw >/dev/null 2>&1; then
    UFW_STATUS=$(ufw status 2>/dev/null | awk '/^Status/{print $NF; exit}')
    [ "$UFW_STATUS" = 'active' ] && {
      echo 'ufw'
      return
    }
  fi

  if [ "$SYSTEM" = 'Alpine' ]; then
    echo 'alpine-iptables'
  elif command -v firewall-cmd >/dev/null 2>&1 || [ "$SYSTEM" = 'CentOS' ]; then
    echo 'firewalld'
  else
    echo 'iptables'
  fi
}

# 兼容旧调用
check_port_hopping_firewall() {
  check_firewall_backend
}

# 初始化防火墙状态目录
init_firewall_state_dir() {
  [ ! -d "$FIREWALL_STATE_DIR" ] && mkdir -p "$FIREWALL_STATE_DIR"
}

# 读取上一次由脚本管理的普通端口规则
append_unique_port() {
  local ARRAY_NAME=$1
  local PORT=$2
  local -n ARRAY_REF="$ARRAY_NAME"

  [ -z "$PORT" ] && return 0
  [[ ! "$PORT" =~ ^[0-9]+$ ]] && return 0

  local ITEM
  for ITEM in "${ARRAY_REF[@]}"; do
    [ "$ITEM" = "$PORT" ] && return 0
  done

  ARRAY_REF+=("$PORT")
}

# UFW 普通端口规则备注
service_port_ufw_comment() {
  local PROTO=$1
  local PORT=$2
  echo "Sing-box Family Bucket UFW PORT ${PROTO} ${PORT}"
}

# 添加 UFW 普通端口规则
add_service_port_rule_ufw() {
  local PROTO=$1
  local PORT=$2
  local COMMENT
  COMMENT=$(service_port_ufw_comment "$PROTO" "$PORT")

  [ -z "$PROTO" ] || [ -z "$PORT" ] && return 1
  ufw allow ${PORT}/${PROTO} comment "$COMMENT" >/dev/null 2>&1
}

# 清理所有由脚本管理的 UFW 普通端口规则
purge_service_port_rules_ufw() {
  local RULE_NUM
  local COMMENT_PREFIX='Sing-box Family Bucket UFW PORT'

  while read -r RULE_NUM; do
    [ -n "$RULE_NUM" ] && ufw --force delete "$RULE_NUM" >/dev/null 2>&1 || true
  done < <(
    ufw status numbered 2>/dev/null | \
    grep "$COMMENT_PREFIX" | \
    awk -F'[][]' '{print $2}' | sort -rn
  )

  ufw reload >/dev/null 2>&1 || true
}

# 添加 firewalld 普通端口规则
add_service_port_rule_firewalld() {
  local PROTO=$1
  local PORT=$2
  [ -z "$PROTO" ] || [ -z "$PORT" ] && return 1
  firewall-cmd --zone=public --add-port=${PORT}/${PROTO} --permanent >/dev/null 2>&1
}

# 删除 firewalld 普通端口规则
del_service_port_rule_firewalld() {
  local PROTO=$1
  local PORT=$2
  [ -z "$PROTO" ] || [ -z "$PORT" ] && return 0
  firewall-cmd --zone=public --remove-port=${PORT}/${PROTO} --permanent >/dev/null 2>&1
}

# iptables 普通端口规则备注
add_service_port_rule_iptables() {
  local PROTO=$1
  local PORT=$2
  local COMMENT="Sing-box Family Bucket PORT ${PROTO} ${PORT}"

  [ -z "$PROTO" ] || [ -z "$PORT" ] && return 1

  iptables -C INPUT -p ${PROTO} --dport ${PORT} -m comment --comment "$COMMENT" -j ACCEPT >/dev/null 2>&1 || \
  iptables -A INPUT -p ${PROTO} --dport ${PORT} -m comment --comment "$COMMENT" -j ACCEPT >/dev/null 2>&1

  ip6tables -C INPUT -p ${PROTO} --dport ${PORT} -m comment --comment "$COMMENT" -j ACCEPT >/dev/null 2>&1 || \
  ip6tables -A INPUT -p ${PROTO} --dport ${PORT} -m comment --comment "$COMMENT" -j ACCEPT >/dev/null 2>&1
}

# 删除 iptables 普通端口规则
del_service_port_rule_iptables() {
  local PROTO=$1
  local PORT=$2
  local COMMENT="Sing-box Family Bucket PORT ${PROTO} ${PORT}"

  [ -z "$PROTO" ] || [ -z "$PORT" ] && return 0

  iptables -D INPUT -p ${PROTO} --dport ${PORT} -m comment --comment "$COMMENT" -j ACCEPT >/dev/null 2>&1 || true
  ip6tables -D INPUT -p ${PROTO} --dport ${PORT} -m comment --comment "$COMMENT" -j ACCEPT >/dev/null 2>&1 || true
}

# 按后端保存 / 重载防火墙规则
reload_or_save_firewall_rules() {
  local FW_BACKEND
  FW_BACKEND=$(check_firewall_backend)

  case "$FW_BACKEND" in
    ufw )
      ufw reload >/dev/null 2>&1 || true
      ;;
    firewalld )
      firewall-cmd --reload >/dev/null 2>&1 || true
      ;;
    alpine-iptables )
      rc-service iptables save >/dev/null 2>&1 || true
      rc-service ip6tables save >/dev/null 2>&1 || true
      ;;
    * )
      [ "$(systemctl is-active netfilter-persistent 2>/dev/null)" = 'active' ] && netfilter-persistent save >/dev/null 2>&1 || true
      ;;
  esac
}

# 清理上一次由脚本管理的普通端口规则
purge_service_firewall_rules() {
  local FW_BACKEND
  FW_BACKEND=$(check_firewall_backend)

  init_firewall_state_dir
  MANAGED_TCP_PORTS=()
  MANAGED_UDP_PORTS=()

  [ ! -s "$SERVICE_FIREWALL_STATE_FILE" ] || while read -r PROTO PORT; do
    case "$PROTO" in
      tcp ) MANAGED_TCP_PORTS+=("$PORT") ;;
      udp ) MANAGED_UDP_PORTS+=("$PORT") ;;
    esac
  done < "$SERVICE_FIREWALL_STATE_FILE"

  case "$FW_BACKEND" in
    ufw )
      purge_service_port_rules_ufw
      ;;
    firewalld )
      local PORT
      for PORT in "${MANAGED_TCP_PORTS[@]}"; do
        del_service_port_rule_firewalld tcp "$PORT"
      done
      for PORT in "${MANAGED_UDP_PORTS[@]}"; do
        del_service_port_rule_firewalld udp "$PORT"
      done
      ;;
    alpine-iptables|iptables )
      local PORT
      for PORT in "${MANAGED_TCP_PORTS[@]}"; do
        del_service_port_rule_iptables tcp "$PORT"
      done
      for PORT in "${MANAGED_UDP_PORTS[@]}"; do
        del_service_port_rule_iptables udp "$PORT"
      done
      ;;
  esac

  : > "$SERVICE_FIREWALL_STATE_FILE"
  reload_or_save_firewall_rules
}

# 同步普通服务端口规则
# 同步所有防火墙规则
sync_firewall_rules() {
  local FW_BACKEND
  local PORT
  local HY2_FILE="${WORK_DIR}/conf/*${NODE_TAG[1]}_inbounds.json"
  local HY2_TARGET DESIRED_START DESIRED_END
  local EXISTING_START EXISTING_END EXISTING_TARGET
  local FILE BASENAME NGINX_PORT HAS_NGINX=false

  EXPOSED_TCP_PORTS=()
  EXPOSED_UDP_PORTS=()

  if [ -s "${WORK_DIR}/nginx.conf" ]; then
    HAS_NGINX=true
    NGINX_PORT=$(awk '
      /listen[[:space:]]+[0-9]+[[:space:]]*;/ && $2 !~ /^\[/ {
        gsub(/;/, "", $2)
        print $2
        exit
      }
    ' "${WORK_DIR}/nginx.conf")
    append_unique_port EXPOSED_TCP_PORTS "$NGINX_PORT"
  fi

  for FILE in ${WORK_DIR}/conf/*_inbounds.json; do
    [ ! -s "$FILE" ] && continue
    BASENAME=$(basename "$FILE")
    PORT=$(awk -F '[:,]' '/"listen_port"/{gsub(/[[:space:]]/, "", $2); print $2; exit}' "$FILE")
    [ -z "$PORT" ] && continue

    case "$BASENAME" in
      *hysteria2_inbounds.json|*tuic_inbounds.json )
        append_unique_port EXPOSED_UDP_PORTS "$PORT"
        ;;
      *naive_inbounds.json )
        append_unique_port EXPOSED_TCP_PORTS "$PORT"
        append_unique_port EXPOSED_UDP_PORTS "$PORT"
        ;;
      *vmess-ws_inbounds.json|*vless-ws-tls_inbounds.json )
        [ "$HAS_NGINX" = false ] && append_unique_port EXPOSED_TCP_PORTS "$PORT"
        ;;
      * )
        append_unique_port EXPOSED_TCP_PORTS "$PORT"
        ;;
    esac
  done

  FW_BACKEND=$(check_firewall_backend)

  init_firewall_state_dir
  MANAGED_TCP_PORTS=()
  MANAGED_UDP_PORTS=()
  if [ -s "$SERVICE_FIREWALL_STATE_FILE" ]; then
    while read -r PROTO PORT; do
      case "$PROTO" in
        tcp ) MANAGED_TCP_PORTS+=("$PORT") ;;
        udp ) MANAGED_UDP_PORTS+=("$PORT") ;;
      esac
    done < "$SERVICE_FIREWALL_STATE_FILE"
  fi

  case "$FW_BACKEND" in
    ufw )
      purge_service_port_rules_ufw
      ;;
    firewalld )
      for PORT in "${MANAGED_TCP_PORTS[@]}"; do
        del_service_port_rule_firewalld tcp "$PORT"
      done
      for PORT in "${MANAGED_UDP_PORTS[@]}"; do
        del_service_port_rule_firewalld udp "$PORT"
      done
      ;;
    alpine-iptables|iptables )
      for PORT in "${MANAGED_TCP_PORTS[@]}"; do
        del_service_port_rule_iptables tcp "$PORT"
      done
      for PORT in "${MANAGED_UDP_PORTS[@]}"; do
        del_service_port_rule_iptables udp "$PORT"
      done
      ;;
  esac

  : > "$SERVICE_FIREWALL_STATE_FILE"
  reload_or_save_firewall_rules

  case "$FW_BACKEND" in
    ufw )
      for PORT in "${EXPOSED_TCP_PORTS[@]}"; do
        add_service_port_rule_ufw tcp "$PORT"
      done
      for PORT in "${EXPOSED_UDP_PORTS[@]}"; do
        add_service_port_rule_ufw udp "$PORT"
      done
      ;;
    firewalld )
      for PORT in "${EXPOSED_TCP_PORTS[@]}"; do
        add_service_port_rule_firewalld tcp "$PORT"
      done
      for PORT in "${EXPOSED_UDP_PORTS[@]}"; do
        add_service_port_rule_firewalld udp "$PORT"
      done
      ;;
    alpine-iptables|iptables )
      for PORT in "${EXPOSED_TCP_PORTS[@]}"; do
        add_service_port_rule_iptables tcp "$PORT"
      done
      for PORT in "${EXPOSED_UDP_PORTS[@]}"; do
        add_service_port_rule_iptables udp "$PORT"
      done
      ;;
  esac

  : > "$SERVICE_FIREWALL_STATE_FILE"
  for PORT in "${EXPOSED_TCP_PORTS[@]}"; do
    [ -n "$PORT" ] && echo "tcp $PORT" >> "$SERVICE_FIREWALL_STATE_FILE"
  done
  for PORT in "${EXPOSED_UDP_PORTS[@]}"; do
    [ -n "$PORT" ] && echo "udp $PORT" >> "$SERVICE_FIREWALL_STATE_FILE"
  done
  reload_or_save_firewall_rules

  HY2_TARGET=$(awk -F '[:,]' '/"listen_port"/{gsub(/[[:space:]]/, "", $2); print $2; exit}' ${HY2_FILE} 2>/dev/null)

  check_port_hopping_nat
  EXISTING_START="$PORT_HOPPING_START"
  EXISTING_END="$PORT_HOPPING_END"
  EXISTING_TARGET="$PORT_HOPPING_TARGET"

  DESIRED_START="${PORT_HOPPING_START:-$EXISTING_START}"
  DESIRED_END="${PORT_HOPPING_END:-$EXISTING_END}"

  if [ -z "$HY2_TARGET" ]; then
    [ -n "$EXISTING_START" ] && [ -n "$EXISTING_END" ] && del_port_hopping_nat
    unset PORT_HOPPING_START PORT_HOPPING_END HY2_PORT_HOPPING_RANGE PORT_HOPPING_TARGET
    return 0
  fi

  if [ -z "$DESIRED_START" ] || [ -z "$DESIRED_END" ]; then
    [ -n "$EXISTING_START" ] && [ -n "$EXISTING_END" ] && del_port_hopping_nat
    unset PORT_HOPPING_START PORT_HOPPING_END HY2_PORT_HOPPING_RANGE
    PORT_HOPPING_TARGET="$HY2_TARGET"
    return 0
  fi

  if [ "$EXISTING_START" != "$DESIRED_START" ] ||      [ "$EXISTING_END" != "$DESIRED_END" ] ||      [ "$EXISTING_TARGET" != "$HY2_TARGET" ]; then
    [ -n "$EXISTING_START" ] && [ -n "$EXISTING_END" ] && del_port_hopping_nat
    PORT_HOPPING_START="$DESIRED_START"
    PORT_HOPPING_END="$DESIRED_END"
    HY2_PORT_HOPPING_RANGE="${DESIRED_START}:${DESIRED_END}"
    PORT_HOPPING_TARGET="$HY2_TARGET"
    add_port_hopping_nat "$PORT_HOPPING_START" "$PORT_HOPPING_END" "$PORT_HOPPING_TARGET"
  fi
}
export_argo_json_file() {
  local FILE_PATH=$1
  [[ -z "$PORT_NGINX" && -s ${WORK_DIR}/nginx.conf ]] && local PORT_NGINX=$(awk '/listen/{print $2; exit}' ${WORK_DIR}/nginx.conf)
  [ ! -s $FILE_PATH/tunnel.json ] && echo $ARGO_JSON > $FILE_PATH/tunnel.json
  [ ! -s $FILE_PATH/tunnel.yml ] && cat > $FILE_PATH/tunnel.yml << EOF
tunnel: $(awk -F '"' '{print $12}' <<< "$ARGO_JSON")
credentials-file: ${WORK_DIR}/tunnel.json

ingress:
  - hostname: ${ARGO_DOMAIN}
    service: http://localhost:${PORT_NGINX}
  - service: http_status:404
EOF
}

# 生成自签证书，区分使用 IPv4 / IPv6 / 域名
# 默认同时更新 cert.pem(36500天) 和 cert_200.pem(200天)
# 传参 naive_only 时，仅检测 cert_200.pem 是否缺失 / 过期 / SNI 不一致，符合条件才更新
ssl_certificate() {
  local TLS_SERVER="$1"
  local CERT_MODE="$2"
  local CERT_200_FILE="${WORK_DIR}/cert/cert_200.pem"
  local CERT_200_SNI

  [ ! -d ${WORK_DIR}/cert ] && mkdir -p ${WORK_DIR}/cert

  if [ "$CERT_MODE" != 'naive_only' ]; then
    openssl ecparam -genkey -name prime256v1 -out ${WORK_DIR}/cert/private.key
  elif [ ! -s ${WORK_DIR}/cert/private.key ] || [ ! -s ${WORK_DIR}/cert/cert.pem ]; then
    CERT_MODE=''
    openssl ecparam -genkey -name prime256v1 -out ${WORK_DIR}/cert/private.key
  fi

  cat > ${WORK_DIR}/cert/cert.conf << EOF
[req]
distinguished_name = req_distinguished_name
x509_extensions = v3_req
prompt = no

[req_distinguished_name]
CN = $(awk -F . '{print $(NF-1)"."$NF}' <<< "$TLS_SERVER")

[v3_req]
subjectAltName = @alt_names

[alt_names]
DNS = ${TLS_SERVER}
EOF

  if [ "$CERT_MODE" != 'naive_only' ]; then
    openssl req -new -x509 -days 36500 -key ${WORK_DIR}/cert/private.key -out ${WORK_DIR}/cert/cert.pem -config ${WORK_DIR}/cert/cert.conf -extensions v3_req
    openssl req -new -x509 -days 200 -key ${WORK_DIR}/cert/private.key -out ${WORK_DIR}/cert/cert_200.pem -config ${WORK_DIR}/cert/cert.conf -extensions v3_req
  else
    CERT_200_SNI=$(openssl x509 -noout -ext subjectAltName -in "$CERT_200_FILE" 2>/dev/null | awk -F 'DNS:' '/DNS:/{gsub(/,.*/, "", $2); print $2}')
    if [ ! -s "$CERT_200_FILE" ] || ! openssl x509 -checkend 0 -noout -in "$CERT_200_FILE" >/dev/null 2>&1 || [ "$CERT_200_SNI" != "$TLS_SERVER" ]; then
      openssl req -new -x509 -days 200 -key ${WORK_DIR}/cert/private.key -out ${WORK_DIR}/cert/cert_200.pem -config ${WORK_DIR}/cert/cert.conf -extensions v3_req
    fi
  fi

  rm -f ${WORK_DIR}/cert/cert.conf
}

# Nginx 配置文件
export_nginx_conf_file() {
  [ "$IS_SUB" = 'is_sub' ] && ensure_subscribe_token
  # 在添加协议，需要用到 nginx 的时候，先检测是否已经安装
  if ! command -v nginx >/dev/null 2>&1; then
    info "\n $(text 7) nginx"
    ${PACKAGE_INSTALL[int]} nginx >/dev/null 2>&1
  fi

  NGINX_CONF="user  root;
worker_processes  auto;

error_log  /dev/null;
pid        /var/run/nginx.pid;

events {
    worker_connections  1024;
}

http {
"
  [ "$IS_SUB" = 'is_sub' ] && ! is_strict_multi_user_mode && NGINX_CONF+="
  map \$http_user_agent \$path1 {
    default                    /;               # 默认路径
    ~*v2rayN                   /v2rayn;         # 匹配 V2rayN 客户端
    ~*clash                    /clash;          # 匹配 Clash 客户端
    ~*Throne|Neko              /throne;         # 匹配 Throne / Neko 客户端
    ~*ShadowRocket             /shadowrocket;   # 匹配 ShadowRocket 客户端
    ~*SFM|SFI|SFA              /sing-box;       # 匹配 Sing-box 官方客户端
#   ~*Chrome|Firefox|Mozilla   /;               # 添加更多的分流规则
  }
  map \$http_user_agent \$path2 {
    default                    /;               # 默认路径
    ~*v2rayN                   /v2rayn;         # 匹配 V2rayN 客户端
    ~*clash                    /clash2;         # 匹配 Clash 客户端
    ~*Throne|Neko              /throne;         # 匹配 Throne / Neko 客户端
    ~*ShadowRocket             /shadowrocket;   # 匹配 ShadowRocket 客户端
    ~*SFM|SFI|SFA              /sing-box;       # 匹配 Sing-box 官方客户端
#   ~*Chrome|Firefox|Mozilla   /;               # 添加更多的分流规则
  }"

  [ "$IS_SUB" = 'is_sub' ] && NGINX_CONF+="
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    log_format  main  '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                      '\$status \$body_bytes_sent "\$http_referer" '
                      '"\$http_user_agent" "\$http_x_forwarded_for"';
"

  NGINX_CONF+="
    access_log  /dev/null;

    sendfile        on;
    #tcp_nopush     on;

    keepalive_timeout  65;

    #gzip  on;

    #include /etc/nginx/conf.d/*.conf;

  server {
    listen $PORT_NGINX ;  # ipv4
    listen [::]:$PORT_NGINX ;  # ipv6
    server_name localhost;
"

  [[ -n "$PORT_VMESS_WS" && "$IS_ARGO" = 'is_argo' ]] && NGINX_CONF+="
    # 反代 sing-box vmess websocket
    location /${UUID_CONFIRM}-vmess {
      if (\$http_upgrade != "websocket") {
         return 404;
      }
      proxy_pass                          http://127.0.0.1:${PORT_VMESS_WS};
      proxy_http_version                  1.1;
      proxy_set_header Upgrade            \$http_upgrade;
      proxy_set_header Connection         "upgrade";
      proxy_set_header X-Real-IP          \$remote_addr;
      proxy_set_header X-Forwarded-For    \$proxy_add_x_forwarded_for;
      proxy_set_header Host               \$host;
      proxy_redirect                      off;
    }
"

  [[ -n "$PORT_VLESS_WS" && "$IS_ARGO" = 'is_argo' ]] && NGINX_CONF+="
    # 反代 sing-box vless websocket
    location /${UUID_CONFIRM}-vless {
      if (\$http_upgrade != "websocket") {
         return 404;
      }
      proxy_http_version                  1.1;
      proxy_pass                          https://127.0.0.1:${PORT_VLESS_WS};
      proxy_ssl_protocols                 TLSv1.3;
      proxy_set_header Upgrade            \$http_upgrade;
      proxy_set_header Connection         "upgrade";
      proxy_set_header X-Real-IP          \$remote_addr;
      proxy_set_header X-Forwarded-For    \$proxy_add_x_forwarded_for;
      proxy_set_header Host               \$host;
      proxy_redirect                      off;
    }
"

  if [ "$IS_SUB" = 'is_sub' ] && ! is_strict_multi_user_mode; then
    NGINX_CONF+="
    # 来自 /auto2 的分流
    location ~ ^/${SUBSCRIBE_TOKEN}/auto2 {
      default_type 'text/plain; charset=utf-8';
      alias ${WORK_DIR}/subscribe/\$path2;
    }

    # 来自 /auto 的分流
    location ~ ^/${SUBSCRIBE_TOKEN}/auto {
      default_type 'text/plain; charset=utf-8';
      alias ${WORK_DIR}/subscribe/\$path1;
    }

    location ~ ^/${SUBSCRIBE_TOKEN}/(.*) {
      autoindex on;
      proxy_set_header X-Real-IP \$proxy_protocol_addr;
      default_type 'text/plain; charset=utf-8';
      alias ${WORK_DIR}/subscribe/\$1;
    }"
  fi

  if is_strict_multi_user_mode; then
    NGINX_CONF+="
    # 严格多用户订阅、管理员网页和 API 全部由本机 sb-user 后端处理。
    # 订阅响应会动态附加 Subscription-Userinfo，让 Clash 显示已用/总量进度条；
    # 后端同时验证用户令牌，page/api 仍只允许管理员访问。
    # 花括号量词必须置于引号内，否则 Nginx 会把 } 误解析为 location 结束符。
    location ~ \"^/user/[a-f0-9]{64}/(clash-campus-free|proxies|page|api(?:/.*)?)$\" {
      access_log off;
      client_max_body_size 8k;
      proxy_pass http://127.0.0.1:18081;
      proxy_http_version 1.1;
      proxy_set_header Host \$host;
      proxy_set_header X-Real-IP \$remote_addr;
      proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
      proxy_set_header X-Forwarded-Proto \$scheme;
      proxy_redirect off;
    }"
  fi

  NGINX_CONF+="  }
}"

  echo "$NGINX_CONF" > ${WORK_DIR}/nginx.conf
}

# ==================== 流量统计 ====================
# 流量与单位换算：四舍五入保留 1 位小数
format_traffic() {
  local BYTES=$1
  [ "$BYTES" -lt 1024 ] && { echo "${BYTES} B"; return; }
  local DIV UNIT
  if [ "$BYTES" -lt $((1024 * 1024)) ]; then
    DIV=1024; UNIT=KB
  elif [ "$BYTES" -lt $((1024 * 1024 * 1024)) ]; then
    DIV=$((1024 * 1024)); UNIT=MB
  elif [ "$BYTES" -lt $((1024 * 1024 * 1024 * 1024)) ]; then
    DIV=$((1024 * 1024 * 1024)); UNIT=GB
  else
    DIV=$((1024 * 1024 * 1024 * 1024)); UNIT=TB
  fi
  local IDX=$((BYTES / DIV))
  local REM=$(( ((BYTES % DIV) * 10 + DIV / 2) / DIV ))
  [ "$REM" -ge 10 ] && { IDX=$((IDX + 1)); REM=0; }
  echo "${IDX}.${REM} ${UNIT}"
}

# 检测端口是否被系统占用（严格匹配端口号，避免 1111 误命中 11111）
is_port_in_use() {
  local _PORT="$1"
  ss -nltup 2>/dev/null | grep -qE "([[:space:]]|^)[^[:space:]]*:${_PORT}([[:space:]]|$)"
}

# 校验服务器地址：IPv4 / IPv6 / 域名（域名须含至少一个点，NAT 场景可用 DDNS 域名）
is_valid_server_addr() {
  local _ADDR="$1"
  [[ "$_ADDR" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] && return 0
  [[ "$_ADDR" =~ ^[0-9a-fA-F:]+$ && "$_ADDR" =~ : ]] && return 0
  [[ "$_ADDR" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+$ ]] && return 0
  return 1
}

# 在脚本限制的端口范围内（MIN_PORT-MAX_PORT）随机找一个未被系统占用的端口。
# 逻辑统一为数组承载候选端口：一次性随机生成 16 个端口装入数组，
# 逐个用 ss -nltp 探测占用情况，返回第一个空闲端口；全部占用则返回 1。
# 用两次 RANDOM 组合成 0-65535 的随机值再取模，避免单次 RANDOM(0-32767) 无法覆盖完整范围。
# 供 nginx 默认端口（input_nginx_port）与 clash_api 端口（find_free_api_port）共用。
find_free_port() {
  local CAND=() SPAN=$((MAX_PORT - MIN_PORT + 1)) IDX PORT
  for IDX in $(seq 1 16); do
    CAND+=("$((MIN_PORT + ((RANDOM * 2) + (RANDOM % 2)) % SPAN))")
  done
  for PORT in "${CAND[@]}"; do
    if ! is_port_in_use "$PORT"; then
      echo "$PORT"; return 0
    fi
  done
  return 1
}

# 在脚本限制的端口范围内随机找一个未被占用的空闲端口，供 clash_api 监听（复用 find_free_port）。
find_free_api_port() {
  local PORT
  PORT=$(find_free_port) || PORT=10000   # 探测失败则回退默认值
  echo "$PORT"
}

# 获取 /connections 流量数据并缓存到全局变量 STATS_JSON（静默降级：任一前置不满足即返回 1）
# clash_api 由官方二进制默认编译（with_clash_api），无需版本门控；
# /connections 返回 { downloadTotal, uploadTotal, connections: [...] }，
# downloadTotal / uploadTotal 为进程生命周期累计值
ensure_stats_data() {
  [ -n "$STATS_JSON" ] && return 0
  [ "${STATUS[0]}" != "$(text 28)" ] && return 1   # Sing-box 未运行
  [ ! -x "$WORK_DIR/sing-box" ] && return 1

  local API_PORT
  # 从 04_experimental.json 解析 clash_api 监听端口（external_controller 形如 127.0.0.1:<port>）。
  # 单条 sed 正则提取（排除 // 注释行），不依赖 jq / 多段管道。
  API_PORT=$(sed -n '/^[[:space:]]*\/\//!s/.*"external_controller"[[:space:]]*:[[:space:]]*"127\.0\.0\.1:\([0-9][0-9]*\)".*/\1/p' "$WORK_DIR/conf/04_experimental.json" 2>/dev/null | head -1)
  [ -z "$API_PORT" ] && return 1

  # curl 优先，wget 兜底（脚本安装时已依赖 wget，必存在）
  if command -v curl >/dev/null 2>&1; then
    STATS_JSON=$(curl -fsS --max-time 3 "http://127.0.0.1:${API_PORT}/connections" 2>/dev/null) || return 1
  else
    STATS_JSON=$(wget -qO- --timeout=3 "http://127.0.0.1:${API_PORT}/connections" 2>/dev/null) || return 1
  fi
  [ -n "$STATS_JSON" ] || return 1
}

# 生成 sing-box 基础配置
generate_sing_box_base_conf() {
  # 生成 log 配置
  cat > ${WORK_DIR}/conf/00_log.json << EOF
{
    "log":{
        "disabled":false,
        "level":"error",
        "output":"${WORK_DIR}/logs/box.log",
        "timestamp":true
    }
}
EOF

  # 生成 outbound 配置
  cat > ${WORK_DIR}/conf/01_outbounds.json << EOF
{
    "outbounds":[
        {
            "type":"direct",
            "tag":"direct"${BIND_INTERFACE:+,
            "bind_interface":"${BIND_INTERFACE}"}
        }
    ]
}
EOF

  # 生成 endpoint 配置
  if [ -s $TEMP_DIR/warp_account.json ] && grep -q '"id"' $TEMP_DIR/warp_account.json; then
    local WARP_ACCOUNT=$(< "$TEMP_DIR/warp_account.json")
    rm -f "$TEMP_DIR/warp_account.json"
  else
    local WARP_ACCOUNT=$(wget -qO- --tries=10 --waitretry=1 --timeout=2 "https://warp.cloudflare.nyc.mn/?run=register")
  fi

  if grep -q '"id"' <<< "$WARP_ACCOUNT"; then
    local ADDRESS6=$(awk -F'"' '/"v6":/ && $4 !~ /^\[/ {print $4}' <<< "$WARP_ACCOUNT")
    local PRIVATE_KEY=$(awk -F'"' '/"private_key"/{print $4}' <<< "$WARP_ACCOUNT")
    local RESERVED[1]=$(awk '/"reserved":/ {getline; gsub(/[^0-9]/, ""); print}' <<< "$WARP_ACCOUNT")
    local RESERVED[2]=$(awk '/"reserved":/ {getline; getline; gsub(/[^0-9]/, ""); print}' <<< "$WARP_ACCOUNT")
    local RESERVED[3]=$(awk '/"reserved":/ {getline; getline; getline; gsub(/[^0-9]/, ""); print}' <<< "$WARP_ACCOUNT")
  else
    local ADDRESS6="2606:4700:110:8a36:df92:102a:9602:fa18"
    local PRIVATE_KEY="YFYOAdbw1bKTHlNNi+aEjBM3BO7unuFC5rOkMRAz9XY="
    local RESERVED[1]=78
    local RESERVED[2]=135
    local RESERVED[3]=76
  fi

  cat > ${WORK_DIR}/conf/02_endpoints.json << EOF
{
    "endpoints":[
        {
            "type":"wireguard",
            "tag":"warp-ep",
            "mtu":1400,
            "address":[
                "172.16.0.2/32",
                "${ADDRESS6}/128"
            ],
            "private_key":"${PRIVATE_KEY}",
            "peers": [
              {
                "address": "engage.cloudflareclient.com",
                "port":2408,
                "public_key":"bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo=",
                "allowed_ips": [
                  "0.0.0.0/0",
                  "::/0"
                ],
                "reserved":[
                    ${RESERVED[1]},
                    ${RESERVED[2]},
                    ${RESERVED[3]}
                ]
              }
            ]
        }
    ]
}
EOF

  # 生成 route 配置
  cat > ${WORK_DIR}/conf/03_route.json << EOF
{
    "route":{
        "default_http_client": "http-client-direct",
        "rule_set":[
            {
                "tag":"geosite-openai",
                "type":"remote",
                "format":"binary",
                "url":"https://raw.githubusercontent.com/SagerNet/sing-geosite/rule-set/geosite-openai.srs"
            }
        ],
        "rules":[
            {
                "action": "sniff"
            },
            {
                "action": "resolve",
                "domain":[
                    "api.openai.com"
                ],
                "strategy": "prefer_ipv4"
            },
            {
                "action": "resolve",
                "rule_set":[
                    "geosite-openai"
                ],
                "strategy": "prefer_ipv6"
            },
            {
                "domain":[
                    "api.openai.com"
                ],
                "rule_set":[
                    "geosite-openai"
                ],
                "outbound":"${CHATGPT_OUT:-direct}"
            }
        ]
    }
}
EOF

  # 生成缓存文件 + clash_api 流量统计。clash_api 是官方二进制默认编译功能
  # （with_clash_api 在 DEFAULT_BUILD_TAGS 中），无版本门控；无需枚举
  # inbound/outbound tag（clash_api 默认统计所有流量）。
  # 新装场景（generate_sing_box_base_conf 由 sing-box_json 首次调用）inbound 尚未生成
  # 也不影响 clash_api 注入，此处统一直接写入。
  CLASH_API_PORT=$(find_free_api_port)
  cat > ${WORK_DIR}/conf/04_experimental.json << EOF
{
    "experimental": {
        "cache_file": {
            "enabled": true,
            "path": "${WORK_DIR}/cache.db"
        },
        "clash_api": {
            "external_controller": "127.0.0.1:${CLASH_API_PORT}"
        }
    }
}
EOF

  # 生成 dns 配置文件
  cat > ${WORK_DIR}/conf/05_dns.json << EOF
{
    "dns":{
        "servers":[
            {
                "type":"local",
                "prefer_go": ${IS_PREFER_GO}
            }
        ],
        "strategy": "${STRATEGY}"
    }
}
EOF

  # 内建的 NTP 客户端服务配置文件，这对于无法进行时间同步的环境很有用
  cat > ${WORK_DIR}/conf/06_ntp.json << EOF
{
    "ntp": {
        "enabled": true,
        "server": "time.apple.com",
        "server_port": 123,
        "interval": "60m"
    }
}
EOF

  # 专门给 sing-box 内部组件发 HTTP 请求用，比如这些场景会用到它：下载远程 rule_set：.srs 规则文件，ACME 申请证书，Cloudflare Origin CA 证书提供器，DERP / Tailscale 相关 HTTP 请求
  cat > ${WORK_DIR}/conf/07_http_clients.json << EOF
{
    "http_clients": [
        {
            "tag": "http-client-direct"
        }
    ]
}
EOF
}

# 生成 sing-box 配置文件
sing-box_json() {
  local IS_CHANGE=$1
  mkdir -p ${WORK_DIR}/conf ${WORK_DIR}/logs ${WORK_DIR}/subscribe

  # 判断是否为新安装，不为 change 就是新安装
  if [ "$IS_CHANGE" = 'change' ]; then
    # 判断 sing-box 主程序所在路径
    DIR=${WORK_DIR}
  else
    DIR=$TEMP_DIR
    generate_sing_box_base_conf
  fi

  # 生成 Reality 公私钥，第一次安装的时候，如有指定的私钥，则使用该私钥及生成对应的公钥；如没有指定私钥则使用新生成的；添加协议的时，使用相应数组里的第一个非空值，如全空则像第一次安装那样使用新生成的
  generate_reality_keypair() {
    [ "$1" = 'convert_error' ] && hint " $(text 116) "
    REALITY_KEYPAIR=$($DIR/sing-box generate reality-keypair) && REALITY_PRIVATE=$(awk '/PrivateKey/{print $NF}' <<< "$REALITY_KEYPAIR") && REALITY_PUBLIC=$(awk '/PublicKey/{print $NF}' <<< "$REALITY_KEYPAIR")
  }

  if [[ "${#REALITY_PRIVATE}" = 43 && "${#REALITY_PUBLIC}" = 0 ]]; then
    if command -v xxd >/dev/null 2>&1; then
      until [ -n "$REALITY_PUBLIC" ]; do
        # convert base64url -> base64 (standard), add padding
        local B64=$(printf '%s' "$REALITY_PRIVATE" | tr '_-' '/+')
        local MOD=$(( ${#B64} % 4 ))
        if [ $MOD -eq 2 ]; then
          B64="${B64}=="
        elif [ $MOD -eq 3 ]; then
          B64="${B64}="
        elif [ $MOD -eq 1 ]; then
          generate_reality_keypair convert_error
          continue
        fi

        # decode to raw 32 bytes
        echo "$B64" | base64 -d > $TEMP_DIR/_X25519_PRIV_RAW || { generate_reality_keypair convert_error; continue; }

        local PRIV_LEN=$(stat -c%s $TEMP_DIR/_X25519_PRIV_RAW 2>/dev/null || stat -f%z $TEMP_DIR/_X25519_PRIV_RAW)
        [ "$PRIV_LEN" -ne 32 ] && { generate_reality_keypair convert_error; continue; }

        # DER prefix for PKCS#8 private key with OID 1.3.101.110 (X25519)
        # Hex: 30 2e 02 01 00 30 05 06 03 2b 65 6e 04 22 04 20
        local PREFIX_HEX="302e020100300506032b656e04220420"

        # append raw private key hex and create DER
        local PRIV_HEX=$(xxd -p -c 256 $TEMP_DIR/_X25519_PRIV_RAW | tr -d '\n')
        printf "%s%s" "$PREFIX_HEX" "$PRIV_HEX" | xxd -r -p > $TEMP_DIR/_X25519_PRIV_DER

        # convert DER PKCS8 -> PEM private key
        openssl pkcs8 -inform DER -in $TEMP_DIR/_X25519_PRIV_DER -nocrypt -out $TEMP_DIR/_X25519_PRIV_PEM 2>/dev/null

        # extract public key in DER
        openssl pkey -in $TEMP_DIR/_X25519_PRIV_PEM -pubout -outform DER > $TEMP_DIR/_X25519_PUB_DER 2>/dev/null

        # last 32 bytes are the raw public key
        tail -c 32 $TEMP_DIR/_X25519_PUB_DER > $TEMP_DIR/_X25519_PUB_RAW

        # encode to base64url (no padding)
        REALITY_PUBLIC=$(base64 -w0 $TEMP_DIR/_X25519_PUB_RAW | tr '+/' '-_' | sed -E 's/=+$//')
      done
    else
      REALITY_PUBLIC=$(wget --no-check-certificate -qO- --tries=3 --timeout=2 https://realitykey.cloudflare.now.cc/?privateKey=$REALITY_PRIVATE | awk -F '"' '/publicKey/{print $4}')
    fi
  elif [[ "${#REALITY_PRIVATE[@]}" = 0 && "${#REALITY_PUBLIC[@]}" = 0 ]]; then
    generate_reality_keypair new_keypair
  else
    REALITY_PRIVATE=$(awk '{print $1}' <<< "${REALITY_PRIVATE[@]}") && REALITY_PUBLIC=$(awk '{print $1}' <<< "${REALITY_PUBLIC[@]}")
  fi

  # 获取自签名证书的域名
  TLS_SERVER=$(openssl x509 -noout -ext subjectAltName -in ${WORK_DIR}/cert/cert.pem 2>/dev/null | awk -F 'DNS:' '/DNS:/{gsub(/,.*/, "", $2); print $2}')

  # naive 在 -r 新增协议时，如 cert_200.pem 过期 / 缺失 / SNI 不一致则自动更新
  [[ "${INSTALL_PROTOCOLS[@]}" =~ 'm' ]] && ssl_certificate "$TLS_SERVER" naive_only

  # 生成 2022-blake3-aes-128-gcm 的 password
  local SIP022_PASSWORD=${SIP022_PASSWORD:-"$(openssl rand -base64 16)"}

  # 第1个协议为 b  (a为全部)，生成 XTLS + Reality 配置
  CHECK_PROTOCOLS=b
  if [[ "${INSTALL_PROTOCOLS[@]}" =~ "$CHECK_PROTOCOLS" ]]; then
    [ -z "$PORT_XTLS_REALITY" ] && PORT_XTLS_REALITY=$(( START_PORT+$(awk -v target=$CHECK_PROTOCOLS '{ for(i=1; i<=NF; i++) if($i == target) { print i-1; break } }' <<< "${INSTALL_PROTOCOLS[*]}") ))
    NODE_NAME[11]=${NODE_NAME[11]:-"$NODE_NAME_CONFIRM"} && UUID[11]=${UUID[11]:-"$UUID_CONFIRM"} && REALITY_PRIVATE[11]=${REALITY_PRIVATE[11]:-"$REALITY_PRIVATE"} && REALITY_PUBLIC[11]=${REALITY_PUBLIC[11]:-"$REALITY_PUBLIC"} &&
    cat > ${WORK_DIR}/conf/11_${NODE_TAG[0]}_inbounds.json << EOF
//  "public_key":"${REALITY_PUBLIC[11]}"
{
    "inbounds":[
        {
            "type":"vless",
            "tag":"${NODE_NAME[11]} ${NODE_TAG[0]}",
            "listen":"::",
            "listen_port":$PORT_XTLS_REALITY,
            "users":[
                {
                    "uuid":"${UUID[11]}",
                    "flow":"xtls-rprx-vision"
                }
            ],
            "tls":{
                "enabled":true,
                "server_name":"${TLS_SERVER}",
                "reality":{
                    "enabled":true,
                    "handshake":{
                        "server":"${TLS_SERVER}",
                        "server_port":443
                    },
                    "private_key":"${REALITY_PRIVATE[11]}",
                    "short_id":[
                        ""
                    ]
                }
            },
            "multiplex":{
                "enabled":false,
                "padding":false,
                "brutal":{
                    "enabled":false,
                    "up_mbps":1000,
                    "down_mbps":1000
                }
            }
        }
    ]
}
EOF
  fi

  # 生成 Hysteria2 配置
  CHECK_PROTOCOLS=$(asc "$CHECK_PROTOCOLS" ++)
  if [[ "${INSTALL_PROTOCOLS[@]}" =~ "$CHECK_PROTOCOLS" ]]; then
    [ -z "$PORT_HYSTERIA2" ] && PORT_HYSTERIA2=$[START_PORT+$(awk -v target=$CHECK_PROTOCOLS '{ for(i=1; i<=NF; i++) if($i == target) { print i-1; break } }' <<< "${INSTALL_PROTOCOLS[*]}")]
    [ "$IS_HOPPING" = 'is_hopping' ] && add_port_hopping_nat $PORT_HOPPING_START $PORT_HOPPING_END $PORT_HYSTERIA2
    NODE_NAME[12]=${NODE_NAME[12]:-"$NODE_NAME_CONFIRM"} && UUID[12]=${UUID[12]:-"$UUID_CONFIRM"}
    HY2_REALM_ID="${HY2_REALM_ID:-${UUID[12]}}"
    local HY2_REALM_CONFIG=""
    if [ "$IS_HY2_REALM" = 'is_hy2_realm' ]; then
      HY2_REALM_CONFIG=$(cat <<EOF_REALM
,
            "realm":{
                "server_url":"https://realm.hy2.io",
                "token":"public",
                "realm_id":"${HY2_REALM_ID}",
                "stun_servers":[
                    "turn.cloudflare.com:3478",
                    "stun.nextcloud.com:3478",
                    "stun.sip.us:3478",
                    "global.stun.twilio.com:3478"
                ]
            }
EOF_REALM
)
    fi
    cat > ${WORK_DIR}/conf/12_${NODE_TAG[1]}_inbounds.json << EOF
{
    "inbounds":[
        {
            "type":"hysteria2",
            "tag":"${NODE_NAME[12]} ${NODE_TAG[1]}",
            "listen":"::",
            "listen_port":$PORT_HYSTERIA2,
            "users":[
                {
                    "password":"${UUID[12]}"
                }
            ],
            "ignore_client_bandwidth":false${HY2_REALM_CONFIG},
            "tls":{
                "enabled":true,
                "alpn":[
                    "h3"
                ],
                "min_version":"1.3",
                "max_version":"1.3",
                "certificate_path":"${WORK_DIR}/cert/cert.pem",
                "key_path":"${WORK_DIR}/cert/private.key"
            }
        }
    ]
}
EOF
    [ "$IS_HY2_WARP" = 'is_hy2_warp' ] && sync_hy2_warp_route enable || sync_hy2_warp_route disable
  fi

  # 生成 Tuic V5 配置
  CHECK_PROTOCOLS=$(asc "$CHECK_PROTOCOLS" ++)
  if [[ "${INSTALL_PROTOCOLS[@]}" =~ "$CHECK_PROTOCOLS" ]]; then
    [ -z "$PORT_TUIC" ] && PORT_TUIC=$[START_PORT+$(awk -v target=$CHECK_PROTOCOLS '{ for(i=1; i<=NF; i++) if($i == target) { print i-1; break } }' <<< "${INSTALL_PROTOCOLS[*]}")]
    NODE_NAME[13]=${NODE_NAME[13]:-"$NODE_NAME_CONFIRM"} && UUID[13]=${UUID[13]:-"$UUID_CONFIRM"} && TUIC_PASSWORD=${TUIC_PASSWORD:-"$UUID_CONFIRM"} && TUIC_CONGESTION_CONTROL=${TUIC_CONGESTION_CONTROL:-"bbr"}
    cat > ${WORK_DIR}/conf/13_${NODE_TAG[2]}_inbounds.json << EOF
{
    "inbounds":[
        {
            "type":"tuic",
            "tag":"${NODE_NAME[13]} ${NODE_TAG[2]}",
            "listen":"::",
            "listen_port":$PORT_TUIC,
            "users":[
                {
                    "uuid":"${UUID[13]}",
                    "password":"$TUIC_PASSWORD"
                }
            ],
            "congestion_control": "$TUIC_CONGESTION_CONTROL",
            "zero_rtt_handshake": false,
            "tls":{
                "enabled":true,
                "alpn":[
                    "h3"
                ],
                "certificate_path":"${WORK_DIR}/cert/cert.pem",
                "key_path":"${WORK_DIR}/cert/private.key"
            }
        }
    ]
}
EOF
  fi

  # 生成 ShadowTLS V5 配置
  CHECK_PROTOCOLS=$(asc "$CHECK_PROTOCOLS" ++)
  if [[ "${INSTALL_PROTOCOLS[@]}" =~ "$CHECK_PROTOCOLS" ]]; then
    [ -z "$PORT_SHADOWTLS" ] && PORT_SHADOWTLS=$[START_PORT+$(awk -v target=$CHECK_PROTOCOLS '{ for(i=1; i<=NF; i++) if($i == target) { print i-1; break } }' <<< "${INSTALL_PROTOCOLS[*]}")]
    NODE_NAME[14]=${NODE_NAME[14]:-"$NODE_NAME_CONFIRM"} && UUID[14]=${UUID[14]:-"$UUID_CONFIRM"} && SHADOWTLS_PASSWORD=${SHADOWTLS_PASSWORD:-"$SIP022_PASSWORD"} && SHADOWTLS_METHOD=${SHADOWTLS_METHOD:-"2022-blake3-aes-128-gcm"}

    cat > ${WORK_DIR}/conf/14_${NODE_TAG[3]}_inbounds.json << EOF
{
    "inbounds":[
        {
            "type":"shadowtls",
            "tag":"${NODE_NAME[14]} ${NODE_TAG[3]}",
            "listen":"::",
            "listen_port":$PORT_SHADOWTLS,
            "detour":"shadowtls-in",
            "version":3,
            "users":[
                {
                    "password":"${UUID[14]}"
                }
            ],
            "handshake":{
                "server":"${TLS_SERVER}",
                "server_port":443
            },
            "strict_mode":true
        },
        {
            "type":"shadowsocks",
            "tag":"shadowtls-in",
            "listen":"127.0.0.1",
            "network":"tcp",
            "method":"$SHADOWTLS_METHOD",
            "password":"$SHADOWTLS_PASSWORD",
            "multiplex":{
                "enabled":true,
                "padding":true,
                "brutal":{
                    "enabled":${IS_BRUTAL},
                    "up_mbps":1000,
                    "down_mbps":1000
                }
            }
        }
    ]
}
EOF
  fi

  # 生成 Shadowsocks 配置
  CHECK_PROTOCOLS=$(asc "$CHECK_PROTOCOLS" ++)
  if [[ "${INSTALL_PROTOCOLS[@]}" =~ "$CHECK_PROTOCOLS" ]]; then
    [ -z "$PORT_SHADOWSOCKS" ] && PORT_SHADOWSOCKS=$[START_PORT+$(awk -v target=$CHECK_PROTOCOLS '{ for(i=1; i<=NF; i++) if($i == target) { print i-1; break } }' <<< "${INSTALL_PROTOCOLS[*]}")]
    NODE_NAME[15]=${NODE_NAME[15]:-"$NODE_NAME_CONFIRM"} && SHADOWSOCKS_PASSWORD=${SHADOWSOCKS_PASSWORD:-"$SIP022_PASSWORD"} && SHADOWSOCKS_METHOD=${SHADOWSOCKS_METHOD:-"2022-blake3-aes-128-gcm"}
    cat > ${WORK_DIR}/conf/15_${NODE_TAG[4]}_inbounds.json << EOF
{
    "inbounds":[
        {
            "type":"shadowsocks",
            "tag":"${NODE_NAME[15]} ${NODE_TAG[4]}",
            "listen":"::",
            "listen_port":$PORT_SHADOWSOCKS,
            "method":"${SHADOWSOCKS_METHOD}",
            "password":"${SHADOWSOCKS_PASSWORD}",
            "multiplex":{
                "enabled":true,
                "padding":true,
                "brutal":{
                    "enabled":${IS_BRUTAL},
                    "up_mbps":1000,
                    "down_mbps":1000
                }
            }
        }
    ]
}
EOF
  fi

  # 生成 Trojan 配置
  CHECK_PROTOCOLS=$(asc "$CHECK_PROTOCOLS" ++)
  if [[ "${INSTALL_PROTOCOLS[@]}" =~ "$CHECK_PROTOCOLS" ]]; then
    [ -z "$PORT_TROJAN" ] && PORT_TROJAN=$[START_PORT+$(awk -v target=$CHECK_PROTOCOLS '{ for(i=1; i<=NF; i++) if($i == target) { print i-1; break } }' <<< "${INSTALL_PROTOCOLS[*]}")]
    NODE_NAME[16]=${NODE_NAME[16]:-"$NODE_NAME_CONFIRM"} && TROJAN_PASSWORD=${TROJAN_PASSWORD:-"$UUID_CONFIRM"}
    cat > ${WORK_DIR}/conf/16_${NODE_TAG[5]}_inbounds.json << EOF
{
    "inbounds":[
        {
            "type":"trojan",
            "tag":"${NODE_NAME[16]} ${NODE_TAG[5]}",
            "listen":"::",
            "listen_port":$PORT_TROJAN,
            "users":[
                {
                    "password":"$TROJAN_PASSWORD"
                }
            ],
            "tls":{
                "enabled":true,
                "certificate_path":"${WORK_DIR}/cert/cert.pem",
                "key_path":"${WORK_DIR}/cert/private.key"
            },
            "multiplex":{
                "enabled":true,
                "padding":true,
                "brutal":{
                    "enabled":${IS_BRUTAL},
                    "up_mbps":1000,
                    "down_mbps":1000
                }
            }
        }
    ]
}
EOF
  fi

  # 生成 vmess + ws 配置
  CHECK_PROTOCOLS=$(asc "$CHECK_PROTOCOLS" ++)
  if [[ "${INSTALL_PROTOCOLS[@]}" =~ "$CHECK_PROTOCOLS" ]]; then
    [ -z "$PORT_VMESS_WS" ] && PORT_VMESS_WS=$[START_PORT+$(awk -v target=$CHECK_PROTOCOLS '{ for(i=1; i<=NF; i++) if($i == target) { print i-1; break } }' <<< "${INSTALL_PROTOCOLS[*]}")]
    NODE_NAME[17]=${NODE_NAME[17]:-"$NODE_NAME_CONFIRM"} && UUID[17]=${UUID[17]:-"$UUID_CONFIRM"} && WS_SERVER_IP[17]=${WS_SERVER_IP[17]:-"$SERVER_IP"} && CDN[17]=${CDN[17]:-"$CDN"} && CDN_PORT[17]=${CDN_PORT[17]:-${CDN_PORT:-80}} && VMESS_WS_PATH=${VMESS_WS_PATH:-"${UUID[17]}-vmess"}
    cat > ${WORK_DIR}/conf/17_${NODE_TAG[6]}_inbounds.json << EOF
//  "WS_SERVER_IP_SHOW": "${WS_SERVER_IP[17]}"
//  "VMESS_HOST_DOMAIN": "${VMESS_HOST_DOMAIN}${ARGO_DOMAIN}"
//  "CDN": "${CDN[17]}"
//  "CDN_PORT": "${CDN_PORT[17]}"
{
    "inbounds":[
        {
            "type":"vmess",
            "tag":"${NODE_NAME[17]} ${NODE_TAG[6]}",
            "listen":"::",
            "listen_port":$PORT_VMESS_WS,
            "tcp_fast_open":false,
            "proxy_protocol":false,
            "users":[
                {
                    "uuid":"${UUID[17]}",
                    "alterId":0
                }
            ],
            "transport":{
                "type":"ws",
                "path":"/$VMESS_WS_PATH",
                "max_early_data":2560,
                "early_data_header_name":"Sec-WebSocket-Protocol"
            },
            "multiplex":{
                "enabled":true,
                "padding":true,
                "brutal":{
                    "enabled":${IS_BRUTAL},
                    "up_mbps":1000,
                    "down_mbps":1000
                }
            }
        }
    ]
}
EOF
  fi

  # 生成 vless + ws + tls 配置
  CHECK_PROTOCOLS=$(asc "$CHECK_PROTOCOLS" ++)
  if [[ "${INSTALL_PROTOCOLS[@]}" =~ "$CHECK_PROTOCOLS" ]]; then
    [ -z "$PORT_VLESS_WS" ] && PORT_VLESS_WS=$[START_PORT+$(awk -v target=$CHECK_PROTOCOLS '{ for(i=1; i<=NF; i++) if($i == target) { print i-1; break } }' <<< "${INSTALL_PROTOCOLS[*]}")]
    NODE_NAME[18]=${NODE_NAME[18]:-"$NODE_NAME_CONFIRM"} && UUID[18]=${UUID[18]:-"$UUID_CONFIRM"} && WS_SERVER_IP[18]=${WS_SERVER_IP[18]:-"$SERVER_IP"} && CDN[18]=${CDN[18]:-"$CDN"} && CDN_PORT[18]=${CDN_PORT[18]:-${CDN_PORT:-443}} && VLESS_WS_PATH=${VLESS_WS_PATH:-"${UUID[18]}-vless"}
    cat > ${WORK_DIR}/conf/18_${NODE_TAG[7]}_inbounds.json << EOF
//  "WS_SERVER_IP_SHOW": "${WS_SERVER_IP[18]}"
//  "CDN": "${CDN[18]}"
//  "CDN_PORT": "${CDN_PORT[18]}"
{
    "inbounds":[
        {
            "type":"vless",
            "tag":"${NODE_NAME[18]} ${NODE_TAG[7]}",
            "listen":"::",
            "listen_port":$PORT_VLESS_WS,
            "tcp_fast_open":false,
            "proxy_protocol":false,
            "users":[
                {
                    "name":"sing-box",
                    "uuid":"${UUID[18]}"
                }
            ],
            "transport":{
                "type":"ws",
                "path":"/$VLESS_WS_PATH",
                "max_early_data":2560,
                "early_data_header_name":"Sec-WebSocket-Protocol"
            },
            "tls":{
                "enabled":true,
                "server_name":"${VLESS_HOST_DOMAIN}${ARGO_DOMAIN}",
                "min_version":"1.3",
                "max_version":"1.3",
                "certificate_path":"${WORK_DIR}/cert/cert.pem",
                "key_path":"${WORK_DIR}/cert/private.key"
            },
            "multiplex":{
                "enabled":true,
                "padding":true,
                "brutal":{
                    "enabled":${IS_BRUTAL},
                    "up_mbps":1000,
                    "down_mbps":1000
                }
            }
        }
    ]
}
EOF
  fi

  # 生成 H2 + Reality 配置
  CHECK_PROTOCOLS=$(asc "$CHECK_PROTOCOLS" ++)
  if [[ "${INSTALL_PROTOCOLS[@]}" =~ "$CHECK_PROTOCOLS" ]]; then
    [ -z "$PORT_H2_REALITY" ] && PORT_H2_REALITY=$[START_PORT+$(awk -v target=$CHECK_PROTOCOLS '{ for(i=1; i<=NF; i++) if($i == target) { print i-1; break } }' <<< "${INSTALL_PROTOCOLS[*]}")]
    NODE_NAME[19]=${NODE_NAME[19]:-"$NODE_NAME_CONFIRM"} && UUID[19]=${UUID[19]:-"$UUID_CONFIRM"} && REALITY_PRIVATE[19]=${REALITY_PRIVATE[19]:-"$REALITY_PRIVATE"} && REALITY_PUBLIC[19]=${REALITY_PUBLIC[19]:-"$REALITY_PUBLIC"}
    cat > ${WORK_DIR}/conf/19_${NODE_TAG[8]}_inbounds.json << EOF
//  "public_key":"${REALITY_PUBLIC[19]}"
{
    "inbounds":[
        {
            "type":"vless",
            "tag":"${NODE_NAME[19]} ${NODE_TAG[8]}",
            "listen":"::",
            "listen_port":$PORT_H2_REALITY,
            "users":[
                {
                    "uuid":"${UUID[19]}"
                }
            ],
            "tls":{
                "enabled":true,
                "server_name":"${TLS_SERVER}",
                "reality":{
                    "enabled":true,
                    "handshake":{
                        "server":"${TLS_SERVER}",
                        "server_port":443
                    },
                    "private_key":"${REALITY_PRIVATE[19]}",
                    "short_id":[
                        ""
                    ]
                }
            },
            "transport":{
                "type": "http"
            },
            "multiplex":{
                "enabled":true,
                "padding":true,
                "brutal":{
                    "enabled":${IS_BRUTAL},
                    "up_mbps":1000,
                    "down_mbps":1000
                }
            }
        }
    ]
}
EOF
  fi

  # 生成 gRPC + Reality 配置
  CHECK_PROTOCOLS=$(asc "$CHECK_PROTOCOLS" ++)
  if [[ "${INSTALL_PROTOCOLS[@]}" =~ "$CHECK_PROTOCOLS" ]]; then
    [ -z "$PORT_GRPC_REALITY" ] && PORT_GRPC_REALITY=$[START_PORT+$(awk -v target=$CHECK_PROTOCOLS '{ for(i=1; i<=NF; i++) if($i == target) { print i-1; break } }' <<< "${INSTALL_PROTOCOLS[*]}")]
    NODE_NAME[20]=${NODE_NAME[20]:-"$NODE_NAME_CONFIRM"} && UUID[20]=${UUID[20]:-"$UUID_CONFIRM"} && REALITY_PRIVATE[20]=${REALITY_PRIVATE[20]:-"$REALITY_PRIVATE"} && REALITY_PUBLIC[20]=${REALITY_PUBLIC[20]:-"$REALITY_PUBLIC"}
    cat > ${WORK_DIR}/conf/20_${NODE_TAG[9]}_inbounds.json << EOF
//  "public_key":"${REALITY_PUBLIC[20]}"
{
    "inbounds":[
        {
            "type":"vless",
            "tag":"${NODE_NAME[20]} ${NODE_TAG[9]}",
            "listen":"::",
            "listen_port":$PORT_GRPC_REALITY,
            "users":[
                {
                    "uuid":"${UUID[20]}"
                }
            ],
            "tls":{
                "enabled":true,
                "server_name":"${TLS_SERVER}",
                "reality":{
                    "enabled":true,
                    "handshake":{
                        "server":"${TLS_SERVER}",
                        "server_port":443
                    },
                    "private_key":"${REALITY_PRIVATE[20]}",
                    "short_id":[
                        ""
                    ]
                }
            },
            "transport":{
                "type": "grpc",
                "service_name": "grpc"
            },
            "multiplex":{
                "enabled":true,
                "padding":true,
                "brutal":{
                    "enabled":${IS_BRUTAL},
                    "up_mbps":1000,
                    "down_mbps":1000
                }
            }
        }
    ]
}
EOF
  fi

  # 生成 anytls 配置
  CHECK_PROTOCOLS=$(asc "$CHECK_PROTOCOLS" ++)
  if [[ "${INSTALL_PROTOCOLS[@]}" =~ "$CHECK_PROTOCOLS" ]]; then
    [ -z "$PORT_ANYTLS" ] && PORT_ANYTLS=$[START_PORT+$(awk -v target=$CHECK_PROTOCOLS '{ for(i=1; i<=NF; i++) if($i == target) { print i-1; break } }' <<< "${INSTALL_PROTOCOLS[*]}")]
    NODE_NAME[21]=${NODE_NAME[21]:-"$NODE_NAME_CONFIRM"} && UUID[21]=${UUID[21]:-"$UUID_CONFIRM"}

    cat > ${WORK_DIR}/conf/21_${NODE_TAG[10]}_inbounds.json << EOF
{
    "inbounds":[
        {
            "type":"anytls",
            "tag":"${NODE_NAME[21]} ${NODE_TAG[10]}",
            "listen":"::",
            "listen_port":$PORT_ANYTLS,
            "users":[
                {
                    "password":"${UUID[21]}"
                }
            ],
            "padding_scheme":[],
            "tls":{
                "enabled":true,
                "certificate_path":"${WORK_DIR}/cert/cert.pem",
                "key_path":"${WORK_DIR}/cert/private.key"
            }
        }
    ]
}
EOF
  fi

  # 生成 naive 配置
  CHECK_PROTOCOLS=$(asc "$CHECK_PROTOCOLS" ++)
  if [[ "${INSTALL_PROTOCOLS[@]}" =~ "$CHECK_PROTOCOLS" ]]; then
    [ -z "$PORT_NAIVE" ] && PORT_NAIVE=$[START_PORT+$(awk -v target=$CHECK_PROTOCOLS '{ for(i=1; i<=NF; i++) if($i == target) { print i-1; break } }' <<< "${INSTALL_PROTOCOLS[*]}")]
    NODE_NAME[22]=${NODE_NAME[22]:-"$NODE_NAME_CONFIRM"} && UUID[22]=${UUID[22]:-"$UUID_CONFIRM"}

    cat > ${WORK_DIR}/conf/22_${NODE_TAG[11]}_inbounds.json << EOF
{
    "inbounds":[
        {
            "type":"naive",
            "tag":"${NODE_NAME[22]} ${NODE_TAG[11]}",
            "listen":"::",
            "listen_port":$PORT_NAIVE,
            "users":[
                {
                    "username":"${UUID[22]}",
                    "password":"${UUID[22]}"
                }
            ],
            "tls":{
                "enabled":true,
                "certificate_path":"${WORK_DIR}/cert/cert_200.pem",
                "key_path":"${WORK_DIR}/cert/private.key"
            }
        }
    ]
}
EOF
  fi
}

# Sing-box 生成守护进程文件
sing-box_systemd() {
  if [ "$SYSTEM" = 'Alpine' ]; then
    local OPENRC_SERVICE="#!/sbin/openrc-run

name=\"sing-box\"
description=\"sing-box service\"
command=\"${WORK_DIR}/sing-box\"
command_args=\"run -C ${WORK_DIR}/conf\"
pidfile=\"/var/run/\${RC_SVCNAME}.pid\"
command_background=\"yes\"
output_log=\"${WORK_DIR}/logs/sing-box.log\"
error_log=\"${WORK_DIR}/logs/sing-box.log\"

depend() {
    need net
    after net"

    # 添加 reload 函数，支持 SIGHUP 热更
    OPENRC_SERVICE+="
}

reload() {
    ebegin \"Reloading \${RC_SVCNAME}\"
    start-stop-daemon --signal HUP --pidfile \$pidfile
    eend \$? \"Failed to reload \${RC_SVCNAME}\"
}

start_pre() {
    # 确保日志目录和PID目录存在并有正确权限
    mkdir -p ${WORK_DIR}/logs
    mkdir -p /var/run
    chmod 755 /var/run"

    # 存在 nginx.conf 时自管 nginx（与 xray 守护一致）：已运行则跳过，未运行才启动，失败不阻塞服务启动
    [ -s ${WORK_DIR}/nginx.conf ] && OPENRC_SERVICE+="
    if command -v /usr/sbin/nginx >/dev/null 2>&1 && ! pgrep -f \"nginx.*${WORK_DIR}/nginx.conf\" >/dev/null 2>&1; then
        /usr/sbin/nginx -c ${WORK_DIR}/nginx.conf
    fi"

    OPENRC_SERVICE+="
    # 确保 PID 文件不存在，避免启动失败
    rm -f \$pidfile
}"

    # 添加 stop_post 函数，用于在服务停止后清理 nginx 进程
    [ -s ${WORK_DIR}/nginx.conf ] && OPENRC_SERVICE+="

stop_post() {
    # 停止 nginx：优先用内置命令
    if command -v /usr/sbin/nginx >/dev/null 2>&1; then
        /usr/sbin/nginx -s quit -c ${WORK_DIR}/nginx.conf 2>/dev/null
        sleep 1 # 等待优雅关闭
        # 如果仍运行，用 SIGKILL
        local NGINX_MASTER=\$(pgrep -f \"nginx: master process /usr/sbin/nginx -c ${WORK_DIR}/nginx.conf\")
        if [ -n \"\$NGINX_MASTER\" ]; then
            kill -KILL \$NGINX_MASTER 2>/dev/null
        fi
    fi
}

stop() {
    ebegin \"Stopping \${RC_SVCNAME}\"
    # 先停止主进程（OpenRC 会调用）
    start-stop-daemon --stop --pidfile \$pidfile --retry 5
    eend \$? \"Failed to stop \${RC_SVCNAME}\"

    # 然后运行 post 清理
    stop_post
}"

    echo "$OPENRC_SERVICE" > ${SINGBOX_DAEMON_FILE}
    chmod +x ${SINGBOX_DAEMON_FILE}
  else
    # 原有的 systemd 服务创建代码
    SING_BOX_SERVICE="[Unit]
Description=sing-box service
Documentation=https://sing-box.sagernet.org
After=network.target nss-lookup.target

[Service]
User=root
Type=simple
NoNewPrivileges=yes
TimeoutStartSec=0
WorkingDirectory=${WORK_DIR}
"
    # 存在 nginx.conf 时用 ExecStartPre 管理 nginx（含 CentOS7）：已在运行则 reload 最新配置，未运行则启动
    [[ -s "${WORK_DIR}/nginx.conf" ]] && SING_BOX_SERVICE+="ExecStartPre=/bin/bash -c 'nginx -c ${WORK_DIR}/nginx.conf -s reload 2>/dev/null || nginx -c ${WORK_DIR}/nginx.conf'
"
    SING_BOX_SERVICE+="ExecStart=${WORK_DIR}/sing-box run -C ${WORK_DIR}/conf
ExecReload=/bin/kill -HUP \$MAINPID
Restart=on-failure
RestartSec=10
LimitNOFILE=infinity

[Install]
WantedBy=multi-user.target"

    echo "$SING_BOX_SERVICE" > ${SINGBOX_DAEMON_FILE}
    systemctl daemon-reload
  fi
}

# Argo 生成守护进程文件
argo_systemd() {
  if [ "$SYSTEM" = 'Alpine' ]; then
    # 分离命令和参数
    local COMMAND="${ARGO_RUNS%% --*}"   # 提取命令部分（包括 cloudflared tunnel）
    local ARGS="${ARGO_RUNS#$COMMAND }"  # 提取参数部分

    cat > ${ARGO_DAEMON_FILE} << EOF
#!/sbin/openrc-run

name="argo"
description="Cloudflare Tunnel service"
command="${COMMAND}"
command_args="${ARGS}"
pidfile="/var/run/\${RC_SVCNAME}.pid"
command_background="yes"
output_log="${WORK_DIR}/logs/argo.log"
error_log="${WORK_DIR}/logs/argo.log"

depend() {
    need net
    after net
}

start_pre() {
    # 确保日志目录和PID目录存在并有正确权限
    mkdir -p ${WORK_DIR}/logs
    mkdir -p /var/run
    chmod 755 /var/run

    # 确保 PID 文件不存在，避免启动失败
    rm -f \$pidfile
}
EOF
    chmod +x ${ARGO_DAEMON_FILE}
  else
    # 原有的 systemd 服务创建代码
    cat > ${ARGO_DAEMON_FILE} << EOF
[Unit]
Description=Cloudflare Tunnel
After=network.target

[Service]
Type=simple
WorkingDirectory=$WORK_DIR
NoNewPrivileges=yes
TimeoutStartSec=0
ExecStart=${ARGO_RUNS}
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
  fi
}

# 获取原有各协议的参数，先清空所有的 key-value
fetch_nodes_value() {
  unset NODE_NAME PORT_XTLS_REALITY UUID TLS_SERVER REALITY_PRIVATE REALITY_PUBLIC PORT_HYSTERIA2 HY2_REALM_ID IS_HY2_REALM IS_HY2_WARP PORT_TUIC TUIC_PASSWORD TUIC_CONGESTION_CONTROL PORT_SHADOWTLS SHADOWTLS_PASSWORD SHADOWSOCKS_METHOD PORT_SHADOWSOCKS PORT_TROJAN TROJAN_PASSWORD PORT_VMESS_WS VMESS_WS_PATH WS_SERVER_IP WS_SERVER_IP_SHOW VMESS_HOST_DOMAIN CDN CDN_PORT PORT_VLESS_WS VLESS_WS_PATH VLESS_HOST_DOMAIN PORT_H2_REALITY PORT_GRPC_REALITY ARGO_DOMAIN PORT_ANYTLS PORT_NAIVE SELF_SIGNED_FINGERPRINT_SHA256 SELF_SIGNED_FINGERPRINT_BASE64

  # 获取公共数据
  ls ${WORK_DIR}/conf/*-ws*inbounds.json >/dev/null 2>&1 && SERVER_IP=$(awk -F '"' '/"WS_SERVER_IP_SHOW"/{print $4; exit}' ${WORK_DIR}/conf/*-ws*inbounds.json) || SERVER_IP=$([ -s ${WORK_DIR}/list ] && grep -A1 '"tag"' ${WORK_DIR}/list | sed -E '/-ws(-tls)*",$/{N;d}' | awk -F '"' '/"server"/{count++; if (count == 1) {print $4; exit}}')

  # 还原所有直连 IP 到 SERVER_IPS（多 IP 场景）；若已在内存中预设（如 sb -d 修改 IP）则跳过
  if [ "${#SERVER_IPS[@]}" -eq 0 ]; then
    if [ -s ${WORK_DIR}/list ]; then
      while IFS= read -r srv; do
        [[ "$srv" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ || "$srv" =~ ^[0-9a-fA-F:]+$ ]] && SERVER_IPS+=("$srv")
      done < <(awk -F '"' '/"server":/{print $4}' ${WORK_DIR}/list | awk '!seen[$0]++')
    fi
    [ "${#SERVER_IPS[@]}" -eq 0 ] && SERVER_IPS=("$SERVER_IP")
  fi
  EXISTED_PORTS=$(awk -F ':|,' '/listen_port/{print $2}' ${WORK_DIR}/conf/*_inbounds.json 2>/dev/null)
  START_PORT=$(awk 'NR == 1 { min = $0 } { if ($0 < min) min = $0; count++ } END {print min}' <<< "$EXISTED_PORTS")
  [[ -z "$NODE_NAME_CONFIRM" && -s ${WORK_DIR}/subscribe/clash ]] && NODE_NAME_CONFIRM=$(awk -F "'" '/u: &u/{print $2; exit}' ${WORK_DIR}/subscribe/clash)

  # 如有 Argo，获取 Argo Tunnel
  [[ ${STATUS[1]} =~ $(text 27)|$(text 28) ]] && grep -q '\--url' ${ARGO_DAEMON_FILE} && { cmd_systemctl enable argo; sleep 2 && cmd_systemctl status argo &>/dev/null && fetch_quicktunnel_domain; }

  # 获取 UUID_CONFIRM（从 JSON 配置文件读取，不依赖 nginx）
  # 如 UUID_CONFIRM 已有值（例如上层已交互输入），跳过 JSON 读取，避免重复弹窗
  [ -z "$UUID_CONFIRM" ] && UUID_CONFIRM=$(awk 'match($0, /[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/) { print substr($0, RSTART, RLENGTH); exit }' ${WORK_DIR}/conf/1*.json 2>/dev/null)
  # JSON 中提取不到时，尝试从 nginx.conf 提取（订阅开启 / 关闭时 nginx.conf 一定含有 UUID）
  [ -z "$UUID_CONFIRM" ] && [ -s "${WORK_DIR}/nginx.conf" ] && \
    UUID_CONFIRM=$(awk 'match($0, /[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/) { print substr($0, RSTART, RLENGTH); exit }' ${WORK_DIR}/nginx.conf 2>/dev/null)
  # 提取不到时，走交互式输入（与新安装一致：默认随机 UUID，回车使用默认值）
  [ -z "$UUID_CONFIRM" ] && input_uuid
  # 新版订阅路径为 64 位随机令牌；旧版路径仍使用 UUID，保留它以免升级后客户端失效。
  [ -z "$SUBSCRIBE_TOKEN" ] && [ -s "${WORK_DIR}/nginx.conf" ] && \
    SUBSCRIBE_TOKEN=$(grep -oE 'location ~ \^/[a-f0-9]{64}/' "${WORK_DIR}/nginx.conf" 2>/dev/null | sed -E 's#.*\^/([a-f0-9]{64})/#\1#' | head -n 1)
  [ -z "$SUBSCRIBE_TOKEN" ] && [ -s "${WORK_DIR}/nginx.conf" ] && SUBSCRIBE_TOKEN="$UUID_CONFIRM"
  # 获取 Nginx 端口（首次开启订阅时 nginx.conf 尚未创建，静默跳过）
  [[ "${IS_SUB}" = 'is_sub' || "${IS_ARGO}" = 'is_argo' ]] && [ -s "${WORK_DIR}/nginx.conf" ] &&
  PORT_NGINX=$(awk '/listen/{print $2; exit}' ${WORK_DIR}/nginx.conf)

  # 获取 XTLS + Reality key-value
  [ -s ${WORK_DIR}/conf/*_${NODE_TAG[0]}_inbounds.json ] && local JSON=$(cat ${WORK_DIR}/conf/*_${NODE_TAG[0]}_inbounds.json) && NODE_NAME[11]=$(sed -n "s/.*\"tag\":\"\(.*\) ${NODE_TAG[0]}.*/\1/p" <<< "$JSON") && PORT_XTLS_REALITY=$(sed -n 's/.*"listen_port":\([0-9]\+\),/\1/gp' <<< "$JSON") && UUID[11]=$(awk -F '"' '/"uuid"/{print $4}' <<< "$JSON") && REALITY_PRIVATE[11]=$(awk -F '"' '/"private_key"/{print $4}' <<< "$JSON") && REALITY_PUBLIC[11]=$(awk -F '"' '/"public_key"/{print $4}' <<< "$JSON")

  # 获取 Hysteria2 key-value
  # 严格多用户模式会额外生成 30_sbuser_* 入站。只能读取基础入站，
  # 不能让通配符同时展开为多个文件，否则 [ -s ... ] 会报 binary operator expected。
  local HYSTERIA2_INBOUND_FILE
  HYSTERIA2_INBOUND_FILE=$(find "${WORK_DIR}/conf" -maxdepth 1 -type f -name "*_${NODE_TAG[1]}_inbounds.json" ! -name '30_sbuser_*' -print -quit 2>/dev/null)
  if [ -n "$HYSTERIA2_INBOUND_FILE" ] && [ -s "$HYSTERIA2_INBOUND_FILE" ]; then
    local JSON=$(cat "$HYSTERIA2_INBOUND_FILE")
    NODE_NAME[12]=$(awk -F '"' -v suffix=" ${NODE_TAG[1]}" '/"tag"[[:space:]]*:/ {v=$4; sub(suffix"$", "", v); print v; exit}' <<< "$JSON")
    PORT_HYSTERIA2=$(awk -F ':' '/"listen_port"[[:space:]]*:/ {gsub(/[[:space:],]/, "", $2); print $2; exit}' <<< "$JSON")
    UUID[12]=$(awk -F '"' '/"password"[[:space:]]*:/ {count++; if (count == 1) {print $4; exit}}' <<< "$JSON")
    HY2_UP=${HY2_UP:-"$([ -s $WORK_DIR/list ] && sed -n '/type: hysteria2/ s/.*,[ ]*up:[ ]*"\([0-9]\+\)[ ]*Mbps.*/\1/gp' $WORK_DIR/list)"}
    HY2_DOWN=${HY2_DOWN:-"$([ -s $WORK_DIR/list ] && sed -n '/type: hysteria2/ s/.*,[ ]*down:[ ]*"\([0-9]\+\)[ ]*Mbps.*/\1/gp' $WORK_DIR/list)"}
    if grep -q '"realm"[[:space:]]*:' <<< "$JSON"; then
      IS_HY2_REALM=is_hy2_realm
      HY2_REALM_ID=$(awk -F '"' '/"realm_id"[[:space:]]*:/{print $4; exit}' <<< "$JSON")
      HY2_REALM_ID=${HY2_REALM_ID:-${UUID[12]}}
    fi
    if [ -s ${WORK_DIR}/conf/03_route.json ] && [ -n "${NODE_NAME[12]}" ] && grep -q '"outbound"[[:space:]]*:[[:space:]]*"warp-ep"' ${WORK_DIR}/conf/03_route.json && grep -q "${NODE_NAME[12]} ${NODE_TAG[1]}" ${WORK_DIR}/conf/03_route.json; then
      IS_HY2_WARP=is_hy2_warp
    fi
    check_port_hopping_nat
  fi
  # 严格多用户模式没有公共订阅令牌；不要把旧 UUID 回退值带入后续校验。
  is_strict_multi_user_mode && SUBSCRIBE_TOKEN=''

  # 获取 Tuic V5 key-value；必须排除 sb-user 生成的用户入站，否则多文件会被拼成无效 JSON。
  local TUIC_INBOUND_FILE
  TUIC_INBOUND_FILE=$(find "${WORK_DIR}/conf" -maxdepth 1 -type f -name "*_${NODE_TAG[2]}_inbounds.json" ! -name '31_sbuser_*' -print -quit 2>/dev/null)
  if [ -n "$TUIC_INBOUND_FILE" ] && [ -s "$TUIC_INBOUND_FILE" ]; then
    local JSON=$(cat "$TUIC_INBOUND_FILE")
    NODE_NAME[13]=$(awk -F '"' '/"tag"[[:space:]]*:/ {print $4; exit}' <<< "$JSON" | sed "s/ ${NODE_TAG[2]}$//")
    PORT_TUIC=$(awk -F ':' '/"listen_port"[[:space:]]*:/ {gsub(/[[:space:],]/, "", $2); print $2; exit}' <<< "$JSON")
    UUID[13]=$(awk -F '"' '/"uuid"/{print $4; exit}' <<< "$JSON")
    TUIC_PASSWORD=$(awk -F '"' '/"password"/{print $4; exit}' <<< "$JSON")
    TUIC_CONGESTION_CONTROL=$(awk -F '"' '/"congestion_control"/{print $4; exit}' <<< "$JSON")
  fi

  # 获取 ShadowTLS key-value
  [ -s ${WORK_DIR}/conf/*_${NODE_TAG[3]}_inbounds.json ] && local JSON=$(cat ${WORK_DIR}/conf/*_${NODE_TAG[3]}_inbounds.json) && NODE_NAME[14]=$(sed -n "s/.*\"tag\":\"\(.*\) ${NODE_TAG[3]}.*/\1/p" <<< "$JSON") && PORT_SHADOWTLS=$(sed -n 's/.*"listen_port":\([0-9]\+\),/\1/gp' <<< "$JSON") && UUID[14]=$(awk -F '"' '/"password"/{count++; if (count == 1) {print $4; exit}}' <<< "$JSON") && SHADOWTLS_PASSWORD=$(awk -F '"' '/"password"/{count++; if (count == 2) {print $4; exit}}' <<< "$JSON") && SHADOWTLS_METHOD=$(awk -F '"' '/"method"/{print $4}' <<< "$JSON")

  # 获取 Shadowsocks key-value
  [ -s ${WORK_DIR}/conf/*_${NODE_TAG[4]}_inbounds.json ] && local JSON=$(cat ${WORK_DIR}/conf/*_${NODE_TAG[4]}_inbounds.json) && NODE_NAME[15]=$(sed -n "s/.*\"tag\":\"\(.*\) ${NODE_TAG[4]}.*/\1/p" <<< "$JSON") && PORT_SHADOWSOCKS=$(sed -n 's/.*"listen_port":\([0-9]\+\),/\1/gp' <<< "$JSON") && SHADOWSOCKS_PASSWORD=$(awk -F '"' '/"password"/{print $4}' <<< "$JSON") && SHADOWSOCKS_METHOD=$(awk -F '"' '/"method"/{print $4}' <<< "$JSON")

  # 获取 Trojan key-value
  [ -s ${WORK_DIR}/conf/*_${NODE_TAG[5]}_inbounds.json ] && local JSON=$(cat ${WORK_DIR}/conf/*_${NODE_TAG[5]}_inbounds.json) && NODE_NAME[16]=$(sed -n "s/.*\"tag\":\"\(.*\) ${NODE_TAG[5]}.*/\1/p" <<< "$JSON") && PORT_TROJAN=$(sed -n 's/.*"listen_port":\([0-9]\+\),/\1/gp' <<< "$JSON") && TROJAN_PASSWORD=$(awk -F '"' '/"password"/{print $4}' <<< "$JSON")

  # 获取 vmess + ws key-value
  [ -s ${WORK_DIR}/conf/*_${NODE_TAG[6]}_inbounds.json ] && local JSON=$(cat ${WORK_DIR}/conf/*_${NODE_TAG[6]}_inbounds.json) && NODE_NAME[17]=$(sed -n "s/.*\"tag\":\"\(.*\) ${NODE_TAG[6]}.*/\1/p" <<< "$JSON") && PORT_VMESS_WS=$(sed -n 's/.*"listen_port":\([0-9]\+\),/\1/gp' <<< "$JSON") && UUID[17]=$(awk -F '"' '/"uuid"/{print $4}' <<< "$JSON") && VMESS_WS_PATH=$(sed -n 's#.*"path":"/\(.*\)",#\1#p' <<< "$JSON") && WS_SERVER_IP[17]=$(awk  -F '"' '/"WS_SERVER_IP_SHOW"/{print $4}' <<< "$JSON") && CDN[17]=$(awk  -F '"' '/"CDN"/{print $4}' <<< "$JSON") && CDN_PORT[17]=$(awk  -F '"' '/"CDN_PORT"/{print $4}' <<< "$JSON") && [[ "${STATUS[1]}" =~ $(text 27)|$(text 28) ]] && ARGO_DOMAIN=$(awk  -F '"' '/"VMESS_HOST_DOMAIN"/{print $4}' <<< "$JSON") || VMESS_HOST_DOMAIN=$(awk  -F '"' '/"VMESS_HOST_DOMAIN"/{print $4}' <<< "$JSON")

  # 获取 vless + ws + tls key-value
  [ -s ${WORK_DIR}/conf/*_${NODE_TAG[7]}_inbounds.json ] && local JSON=$(cat ${WORK_DIR}/conf/*_${NODE_TAG[7]}_inbounds.json) && NODE_NAME[18]=$(sed -n "s/.*\"tag\":\"\(.*\) ${NODE_TAG[7]}.*/\1/p" <<< "$JSON") && PORT_VLESS_WS=$(sed -n 's/.*"listen_port":\([0-9]\+\),/\1/gp' <<< "$JSON") && UUID[18]=$(awk -F '"' '/"uuid"/{print $4}' <<< "$JSON") && VLESS_WS_PATH=$(sed -n 's#.*"path":"/\(.*\)",#\1#p' <<< "$JSON") && WS_SERVER_IP[18]=$(awk  -F '"' '/"WS_SERVER_IP_SHOW"/{print $4}' <<< "$JSON") && CDN[18]=$(awk  -F '"' '/"CDN"/{print $4}' <<< "$JSON") && [[ "${STATUS[1]}" =~ $(text 27)|$(text 28) ]] && CDN_PORT[18]=$(awk  -F '"' '/"CDN_PORT"/{print $4}' <<< "$JSON") && ARGO_DOMAIN=$(awk -F '"' '/"server_name"/{print $4}' <<< "$JSON") || VLESS_HOST_DOMAIN=$(awk -F '"' '/"server_name"/{print $4}' <<< "$JSON")

  # 获取 H2 + Reality key-value
  [ -s ${WORK_DIR}/conf/*_${NODE_TAG[8]}_inbounds.json ] && local JSON=$(cat ${WORK_DIR}/conf/*_${NODE_TAG[8]}_inbounds.json) && NODE_NAME[19]=$(sed -n "s/.*\"tag\":\"\(.*\) ${NODE_TAG[8]}.*/\1/p" <<< "$JSON") && PORT_H2_REALITY=$(sed -n 's/.*"listen_port":\([0-9]\+\),/\1/gp' <<< "$JSON") && UUID[19]=$(awk -F '"' '/"uuid"/{print $4}' <<< "$JSON") && REALITY_PRIVATE[19]=$(awk -F '"' '/"private_key"/{print $4}' <<< "$JSON") && REALITY_PUBLIC[19]=$(awk -F '"' '/"public_key"/{print $4}' <<< "$JSON")

  # 获取 gRPC + Reality key-value
  [ -s ${WORK_DIR}/conf/*_${NODE_TAG[9]}_inbounds.json ] && local JSON=$(cat ${WORK_DIR}/conf/*_${NODE_TAG[9]}_inbounds.json) && NODE_NAME[20]=$(sed -n "s/.*\"tag\":\"\(.*\) ${NODE_TAG[9]}.*/\1/p" <<< "$JSON") && PORT_GRPC_REALITY=$(sed -n 's/.*"listen_port":\([0-9]\+\),/\1/gp' <<< "$JSON") && UUID[20]=$(awk -F '"' '/"uuid"/{print $4}' <<< "$JSON") && REALITY_PRIVATE[20]=$(awk -F '"' '/"private_key"/{print $4}' <<< "$JSON") && REALITY_PUBLIC[20]=$(awk -F '"' '/"public_key"/{print $4}' <<< "$JSON")

  # 获取 anytls key-value
  [ -s ${WORK_DIR}/conf/*_${NODE_TAG[10]}_inbounds.json ] && local JSON=$(cat ${WORK_DIR}/conf/*_${NODE_TAG[10]}_inbounds.json) && NODE_NAME[21]=$(sed -n "s/.*\"tag\":\"\(.*\) ${NODE_TAG[10]}.*/\1/p" <<< "$JSON") && PORT_ANYTLS=$(sed -n 's/.*"listen_port":\([0-9]\+\),/\1/gp' <<< "$JSON") && UUID[21]=$(awk -F '"' '/"password"/{print $4}' <<< "$JSON")

  # 获取 naive key-value
  [ -s ${WORK_DIR}/conf/*_${NODE_TAG[11]}_inbounds.json ] && local JSON=$(cat ${WORK_DIR}/conf/*_${NODE_TAG[11]}_inbounds.json) && NODE_NAME[22]=$(sed -n "s/.*\"tag\":\"\(.*\) ${NODE_TAG[11]}.*/\1/p" <<< "$JSON") && PORT_NAIVE=$(sed -n 's/.*"listen_port":\([0-9]\+\),/\1/gp' <<< "$JSON") && UUID[22]=$(awk -F '"' '/"username"/{print $4; exit}' <<< "$JSON")

  # 兜底：极早期版本 04_experimental.json 无 clash_api（cache_file-only），补全注入。
  # 同时剥离可能残留的 v2ray_api（官方 release 二进制默认不编译该功能，
  # 若旧版脚本已注入会在启动时报 "v2ray api is not included in this build"）。
  # 升级/change 场景 generate_sing_box_base_conf 已统一写入 clash_api，这里无需重复。
  if ! grep -q 'clash_api' ${WORK_DIR}/conf/04_experimental.json 2>/dev/null; then
    CLASH_API_PORT=$(find_free_api_port)
    local EXP_JSON=$(cat ${WORK_DIR}/conf/04_experimental.json)
    printf '%s\n' "$EXP_JSON" | "$DIR/jq" 'del(.experimental.v2ray_api) | .experimental += {
      "clash_api": {
        "external_controller": "127.0.0.1:'"$CLASH_API_PORT"'"
      }
    }' > ${WORK_DIR}/conf/04_experimental.json
    # 补全后立即热加载（SIGHUP）使 clash_api 监听马上生效；
    # 前台同步执行确保信号送达（SIGHUP reload 不断连 SSH）；仅当 sing-box 运行中才 reload
    if pgrep -x sing-box >/dev/null 2>&1; then
      cmd_systemctl reload sing-box
    fi
  fi
}

# 获取 Argo 临时隧道域名
fetch_quicktunnel_domain() {
  unset CLOUDFLARED_PID METRICS_ADDRESS ARGO_DOMAIN
  local QUICKTUNNEL_ERROR_TIME=20
  until [ -n "$ARGO_DOMAIN" ]; do
    local CLOUDFLARED_PID=$(ps -eo pid,args | awk -v work_dir="$WORK_DIR" '$0~(work_dir"/cloudflared"){print $1;exit}')
    [[ -z "$METRICS_ADDRESS" && "$CLOUDFLARED_PID" =~ ^[0-9]+$ ]] && local METRICS_ADDRESS=$(ss -nltp | grep "pid=$CLOUDFLARED_PID" | awk '{print $4}')
    [ -n "$METRICS_ADDRESS" ] && ARGO_DOMAIN=$(wget -qO- http://$METRICS_ADDRESS/quicktunnel | awk -F '"' '{print $4}')
    if [[ ! "$ARGO_DOMAIN" =~ trycloudflare\.com$ ]]; then
      (( QUICKTUNNEL_ERROR_TIME-- )) || true
      [ "$QUICKTUNNEL_ERROR_TIME" = '0' ] && error " $(text 93) "
      sleep 2
    else
      break
    fi
  done

  # 把临时隧道写到 Sing-box 相应的 ws inbounds 文件
  [ -s ${WORK_DIR}/conf/17_${NODE_TAG[6]}_inbounds.json ] && sed -i "s/VMESS_HOST_DOMAIN.*/VMESS_HOST_DOMAIN\": \"$ARGO_DOMAIN\"/" ${WORK_DIR}/conf/17_${NODE_TAG[6]}_inbounds.json
  [ -s ${WORK_DIR}/conf/18_${NODE_TAG[7]}_inbounds.json ] && sed -i "s/\"server_name\":.*/\"server_name\": \"$ARGO_DOMAIN\",/" ${WORK_DIR}/conf/18_${NODE_TAG[7]}_inbounds.json
}

# 安装 sing-box 全家桶
install_sing-box() {
  sing-box_variables
  if [ -n "$PORT_NGINX" ] && ! command -v nginx >/dev/null 2>&1; then
    info "\n $(text 7) nginx \n"
    ${PACKAGE_UPDATE[int]} >/dev/null 2>&1
    ${PACKAGE_INSTALL[int]} nginx >/dev/null 2>&1
    cmd_systemctl disable nginx
  fi
  [ ! -d ${WORK_DIR}/logs ] && mkdir -p ${WORK_DIR}/logs
  [ ! -d ${TEMP_DIR} ] && mkdir -p $TEMP_DIR
  ssl_certificate $TLS_SERVER_DEFAULT
  hint "\n $(text 2) " && wait
  [ -x "$TEMP_DIR/sing-box" ] || error "\n $(text 42) \n"
  sing-box_json
  echo "${L^^}" > ${WORK_DIR}/language
  cp $TEMP_DIR/sing-box $TEMP_DIR/jq ${WORK_DIR}
  [ -x $TEMP_DIR/qrencode ] && cp $TEMP_DIR/qrencode ${WORK_DIR}

  # 只有确实选择 Argo 时才下载、复制并配置 cloudflared。Hysteria2/TUIC
  # 快装明确为 no_argo，不能因为缺少 cloudflared 输出无关错误。
  if [ "$IS_ARGO" = 'is_argo' ]; then
    if [ ! -x "${WORK_DIR}/cloudflared" ]; then
      if [ ! -x "$TEMP_DIR/cloudflared" ]; then
        wget --no-check-certificate --tries=3 --timeout=15 -qO "$TEMP_DIR/cloudflared" \
          "${GH_PROXY}https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-$ARGO_ARCH" 2>/dev/null \
          && chmod +x "$TEMP_DIR/cloudflared"
      fi
      [ -x "$TEMP_DIR/cloudflared" ] || error "\n Cloudflared download failed. Please check the server network and try again. \n"
      cp "$TEMP_DIR/cloudflared" "${WORK_DIR}/cloudflared"
    fi
    [ -n "$ARGO_RUNS" ] && argo_systemd
  fi

  # 如果是 Json Argo，把配置文件复制到工作目录
  [ -n "$ARGO_JSON" ] && cp $TEMP_DIR/tunnel.* ${WORK_DIR}

  # 生成 Nginx 配置文件（先于守护文件，确保 ExecStartPre / start_pre 与最终状态一致）
  [ -n "$PORT_NGINX" ] && export_nginx_conf_file

  # 生成 sing-box systemd 配置文件
  sing-box_systemd

  # 系统启动 sing-box 服务
  cmd_systemctl enable sing-box

  # 等待服务启动
  sleep 2

  # 处理防火墙相关端口
  sync_firewall_rules

  # 检查服务是否成功启动
  if cmd_systemctl status sing-box &>/dev/null; then
    STATUS[0]=$(text 28)
    info "\n Sing-box $(text 28) $(text 37) \n"
  else
    STATUS[0]=$(text 27)
    error "\n Sing-box $(text 27) $(text 38) \n"
    # 如果启动失败，再尝试重启
    cmd_systemctl restart sing-box
  fi

  # 如果配置了 Argo，也启动 Argo 服务；双协议快装则关闭遗留的 Argo 服务。
  [ "$IS_ARGO" = 'no_argo' ] && [ -s ${ARGO_DAEMON_FILE} ] && cmd_systemctl disable argo
  if [ "$IS_ARGO" = 'is_argo' ] && [ -s ${ARGO_DAEMON_FILE} ]; then
    cmd_systemctl enable argo

    sleep 2

    # 检查 Argo 服务是否成功启动
    if cmd_systemctl status argo &>/dev/null; then
      STATUS[1]=$(text 28)
      info "\n Argo $(text 28) $(text 37) \n"
    else
      STATUS[1]=$(text 27)
      error "\n Argo $(text 27) $(text 38) \n"
      # 如果启动失败，再尝试重启
      cmd_systemctl restart argo
    fi
  fi
}

export_list() {
  IS_INSTALL=$1

  check_install status_only

  # 白名单是安装配置的一部分；升级或执行 -N 重新生成订阅时必须保留，
  # 否则未再次传参会意外清空用户已设置的直连域名。
  local CAMPUS_DIRECT_DOMAINS_FILE="${WORK_DIR}/users/campus-direct-domains"
  if [ "$CAMPUS_DIRECT_DOMAINS_EXPLICIT" = true ]; then
    mkdir -p "${WORK_DIR}/users"
    printf '%s\n' "$CAMPUS_DIRECT_DOMAINS" > "$CAMPUS_DIRECT_DOMAINS_FILE"
    chmod 600 "$CAMPUS_DIRECT_DOMAINS_FILE"
  elif [ -s "$CAMPUS_DIRECT_DOMAINS_FILE" ]; then
    IFS= read -r CAMPUS_DIRECT_DOMAINS < "$CAMPUS_DIRECT_DOMAINS_FILE"
  fi

  [ "$IS_INSTALL" != 'install' ] && fetch_nodes_value
  [ "$IS_SUB" = 'is_sub' ] && ensure_subscribe_token
  # 升级已有 Hysteria2 安装时，-N 同样要撤销旧的公共 Nginx 路由；
  # 否则旧令牌在下一次修改协议前仍会短暂可用。
  if [ "$IS_INSTALL" != 'install' ] && is_strict_multi_user_mode && [ -n "$PORT_NGINX" ]; then
    export_nginx_conf_file
    nginx_sync
  fi

  # IPv6 时的 IP 处理
  if [[ "$SERVER_IP" =~ : ]]; then
    SERVER_IP_1="[$SERVER_IP]"
    SERVER_IP_2="[[$SERVER_IP]]"
  else
    SERVER_IP_1="$SERVER_IP"
    SERVER_IP_2="$SERVER_IP"
  fi

  # 使用 Argo 时，获取临时隧道域名
  ls ${WORK_DIR}/conf/*-ws*inbounds.json >/dev/null 2>&1 && [ "$IS_ARGO" = 'is_argo' ] && [ -z "$ARGO_DOMAIN" ] && [[ "${STATUS[1]}" = "$(text 28)" || "$NONINTERACTIVE_INSTALL" = 'noninteractive_install' ]] && fetch_quicktunnel_domain

  # 严格模式的 list 不会保存公共节点地址。升级时若无法重新发现 IP，保留先前已验证的基地址，
  # 绝不能把它覆盖成 http://:PORT。
  local SAVED_SUBSCRIBE_ADDRESS=''
  [ -s "${WORK_DIR}/users/subscription-base-url" ] && IFS= read -r SAVED_SUBSCRIBE_ADDRESS < "${WORK_DIR}/users/subscription-base-url"
  if is_strict_multi_user_mode && [ -z "$SERVER_IP" ] && is_valid_subscription_base_url "$SAVED_SUBSCRIBE_ADDRESS"; then
    SUBSCRIBE_ADDRESS="${SAVED_SUBSCRIBE_ADDRESS%/}"
  elif [[ "$ARGO_TYPE" = 'is_token_argo' || "$ARGO_TYPE" = 'is_json_argo' ]]; then
    SUBSCRIBE_ADDRESS="https://$ARGO_DOMAIN"
  else
    SUBSCRIBE_ADDRESS="http://${SERVER_IP_1}:${PORT_NGINX}"
  fi
  if is_strict_multi_user_mode && ! is_valid_subscription_base_url "${SUBSCRIBE_ADDRESS%/}"; then
    warning " Cannot determine the subscription server address. Restore ${WORK_DIR}/users/subscription-base-url before running -N."
    return 1
  fi
  # 只作为 sb-user 渲染专属订阅时的内部占位地址，绝不由 Nginx 对外提供。
  local PROXY_PROVIDERS_URL="${SUBSCRIBE_ADDRESS}/${SUBSCRIBE_TOKEN}/proxies"
  is_strict_multi_user_mode && PROXY_PROVIDERS_URL='http://127.0.0.1/strict-internal/proxies'

  # v1.3.0 (2025.11.10)及之后 reality 使用 xtls-rprx-vision 流控替代多路复用 multiplex，但为了兼容旧版本已安装的客户端 URI，在这里作判断
  if [ -n "$PORT_XTLS_REALITY" ]; then
    local FLOW="$(awk -F '"' '/"flow"/{print $4}' ${WORK_DIR}/conf/*_${NODE_TAG[0]}_inbounds.json)"

    if [ "${FLOW}" = 'xtls-rprx-vision' ]; then
      local VISION_OR_MUX_SHADOWROCKET='xtls=2' && local VISION_FLOW='&flow=xtls-rprx-vision' && local VISION_OR_MUX_CLASH=', flow: xtls-rprx-vision' && local MULTIPLEX_PADDING_ENABLED='false' && local VISION_BRUTAL_ENABLED='false'
    else
      local VISION_OR_MUX_SHADOWROCKET='mux=1' && local MULTIPLEX_PADDING_ENABLED='true' && local VISION_BRUTAL_ENABLED="${IS_BRUTAL}"
    fi
  fi

  # 获取自签证书指纹。origin rules 或者 argo 回源的是由 Google Trust Services（谷歌信任服务）作为中间 CA（CN=WE1）签发，受信任的证书（非自签名）
  local SELF_SIGNED_FINGERPRINT_SHA256=$(openssl x509 -fingerprint -noout -sha256 -in ${WORK_DIR}/cert/cert.pem | awk -F '=' '{print $NF}')
  local SELF_SIGNED_FINGERPRINT_BASE64=$(openssl x509 -in ${WORK_DIR}/cert/cert.pem -pubkey -noout | openssl pkey -pubin -outform der | openssl dgst -sha256 -binary | openssl enc -base64)

  local CERT_URL_1=$(awk '{printf "%s,", $0}' ${WORK_DIR}/cert/cert.pem | sed 's/ /%20/g; s/,$//') &&
  local CERT_URL_2=$(awk '{printf "%s\\r\\n", $0}' ${WORK_DIR}/cert/cert.pem)
  [ -s ${WORK_DIR}/cert/cert_200.pem ] &&
  local CERT_200_URL_1=$(awk '{printf "%s,", $0}' ${WORK_DIR}/cert/cert_200.pem | sed 's/,$//') &&
  local CERT_200_URL_2=$(awk '{printf "%s\\r\\n", $0}' ${WORK_DIR}/cert/cert_200.pem)

  # 从自签证书的 SAN 中读取当前使用的 SNI，优先取 SAN，退回到 CN
  local TLS_SERVER=$(openssl x509 -noout -ext subjectAltName -in ${WORK_DIR}/cert/cert.pem 2>/dev/null | awk -F 'DNS:' '/DNS:/{gsub(/,.*/, "", $2); print $2}')

  # naive 协议的特殊处理
  if [ -n "$PORT_NAIVE" ]; then
    # 在 -n 查看节点时，如 cert_200.pem 过期 / 缺失 / SNI 不一致则自动更新
    ssl_certificate "$TLS_SERVER" naive_only

    # 读取 naive 自签证书并格式化为 JSON 字符串数组内容；多行/单行位置共用这一个变量
    local CERT200_JSON=$(awk 'BEGIN{sep=""} {gsub(/\\/,"\\\\"); gsub(/"/,"\\\""); printf "%s\"%s\"", sep, $0; sep=",\n"}' "${WORK_DIR}/cert/cert_200.pem")

    # 获取 naive 自签名证书的指纹
    local SELF_SIGNED_200_FINGERPRINT_SHA256=$(openssl x509 -fingerprint -noout -sha256 -in ${WORK_DIR}/cert/cert_200.pem | awk -F '=' '{print $NF}')
  fi

  # 生成各订阅文件
  # 生成 Clash proxy providers 订阅文件
  local CLASH_SUBSCRIBE='proxies:'

  if [ -n "$PORT_XTLS_REALITY" ]; then
    for ip in "${SERVER_IPS[@]}"; do
      local CLASH_SUF=""; [ "${#SERVER_IPS[@]}" -gt 1 ] && CLASH_SUF=" [${ip}]"
      local CLASH_XTLS_REALITY="- {name: \"${NODE_NAME[11]} ${NODE_TAG[0]}${CLASH_SUF}\", type: vless, server: ${ip}, port: ${PORT_XTLS_REALITY}, uuid: ${UUID[11]}, network: tcp, udp: true, tls: true${VISION_OR_MUX_CLASH}, servername: ${TLS_SERVER}, client-fingerprint: ${FINGER_PRINT}, reality-opts: {public-key: ${REALITY_PUBLIC[11]}, short-id: \"\"}, smux: { enabled: ${MULTIPLEX_PADDING_ENABLED}, protocol: 'h2mux', padding: ${MULTIPLEX_PADDING_ENABLED}, max-connections: '8', min-streams: '16', statistic: true, only-tcp: false }, brutal-opts: { enabled: ${VISION_BRUTAL_ENABLED}, up: '1000 Mbps', down: '1000 Mbps' } }"
      local CLASH_SUBSCRIBE+="
  $CLASH_XTLS_REALITY
"
    done
  fi
  if [ -n "$PORT_HYSTERIA2" ]; then
    [[ -n "$PORT_HOPPING_START" && -n "$PORT_HOPPING_END" ]] && local CLASH_HOPPING=" ports: ${PORT_HOPPING_START}-${PORT_HOPPING_END}, hop-interval: 30,"
    local HY2_UP=${HY2_UP:-200}
    local HY2_DOWN=${HY2_DOWN:-1000}
    local CLASH_REALM_OPTS=""
    if [ "$IS_HY2_REALM" = 'is_hy2_realm' ]; then
      HY2_REALM_ID="${HY2_REALM_ID:-${UUID[12]}}"
      CLASH_REALM_OPTS=", realm-opts: {enable: true, server-url: \"https://realm.hy2.io\", token: public, realm-id: \"${HY2_REALM_ID}\", stun-servers: [turn.cloudflare.com:3478, stun.nextcloud.com:3478, stun.sip.us:3478, global.stun.twilio.com:3478]}"
    fi
    for ip in "${SERVER_IPS[@]}"; do
      local CLASH_SUF=""; [ "${#SERVER_IPS[@]}" -gt 1 ] && CLASH_SUF=" [${ip}]"
      local CLASH_HYSTERIA2="- {name: \"${NODE_NAME[12]} ${NODE_TAG[1]}${CLASH_SUF}\", type: hysteria2, server: ${ip}, port: ${PORT_HYSTERIA2},${CLASH_HOPPING} up: \"${HY2_UP} Mbps\", down: \"${HY2_DOWN} Mbps\", password: ${UUID[12]}, sni: ${TLS_SERVER}, skip-cert-verify: false, fingerprint: ${SELF_SIGNED_FINGERPRINT_SHA256}${CLASH_REALM_OPTS}}"
      local CLASH_SUBSCRIBE+="
  $CLASH_HYSTERIA2
"
    done
  fi

  if [ -n "$PORT_TUIC" ]; then
    for ip in "${SERVER_IPS[@]}"; do
      local CLASH_SUF=""; [ "${#SERVER_IPS[@]}" -gt 1 ] && CLASH_SUF=" [${ip}]"
      local CLASH_TUIC="- {name: \"${NODE_NAME[13]} ${NODE_TAG[2]}${CLASH_SUF}\", type: tuic, server: ${ip}, port: ${PORT_TUIC}, uuid: ${UUID[13]}, password: ${TUIC_PASSWORD}, alpn: [h3], reduce-rtt: true, request-timeout: 8000, udp-relay-mode: native, congestion-controller: $TUIC_CONGESTION_CONTROL, sni: ${TLS_SERVER}, skip-cert-verify: false, fingerprint: ${SELF_SIGNED_FINGERPRINT_SHA256}}"
      local CLASH_SUBSCRIBE+="
  $CLASH_TUIC
"
    done
  fi
  if [ -n "$PORT_SHADOWTLS" ]; then
    for ip in "${SERVER_IPS[@]}"; do
      local CLASH_SUF=""; [ "${#SERVER_IPS[@]}" -gt 1 ] && CLASH_SUF=" [${ip}]"
      local CLASH_SHADOWTLS="- {name: \"${NODE_NAME[14]} ${NODE_TAG[3]}${CLASH_SUF}\", type: ss, server: ${ip}, port: ${PORT_SHADOWTLS}, cipher: $SHADOWTLS_METHOD, password: $SHADOWTLS_PASSWORD, plugin: shadow-tls, client-fingerprint: ${FINGER_PRINT}, plugin-opts: {host: ${TLS_SERVER}, password: \"${UUID[14]}\", version: 3}, smux: { enabled: true, protocol: 'h2mux', padding: true, max-connections: '8', min-streams: '16', statistic: true, only-tcp: false }, brutal-opts: { enabled: ${IS_BRUTAL}, up: '1000 Mbps', down: '1000 Mbps' } }"
      local CLASH_SUBSCRIBE+="
  $CLASH_SHADOWTLS
"
    done
  fi

  if [ -n "$PORT_SHADOWSOCKS" ]; then
    for ip in "${SERVER_IPS[@]}"; do
      local CLASH_SUF=""; [ "${#SERVER_IPS[@]}" -gt 1 ] && CLASH_SUF=" [${ip}]"
      local CLASH_SHADOWSOCKS="- {name: \"${NODE_NAME[15]} ${NODE_TAG[4]}${CLASH_SUF}\", type: ss, server: ${ip}, port: $PORT_SHADOWSOCKS, cipher: ${SHADOWSOCKS_METHOD}, password: ${SHADOWSOCKS_PASSWORD}, smux: { enabled: true, protocol: 'h2mux', padding: true, max-connections: '8', min-streams: '16', statistic: true, only-tcp: false }, brutal-opts: { enabled: ${IS_BRUTAL}, up: '1000 Mbps', down: '1000 Mbps' } }"
      local CLASH_SUBSCRIBE+="
  $CLASH_SHADOWSOCKS
"
    done
  fi
  if [ -n "$PORT_TROJAN" ]; then
    for ip in "${SERVER_IPS[@]}"; do
      local CLASH_SUF=""; [ "${#SERVER_IPS[@]}" -gt 1 ] && CLASH_SUF=" [${ip}]"
      local CLASH_TROJAN="- {name: \"${NODE_NAME[16]} ${NODE_TAG[5]}${CLASH_SUF}\", type: trojan, server: ${ip}, port: $PORT_TROJAN, password: $TROJAN_PASSWORD, client-fingerprint: ${FINGER_PRINT}, sni: ${TLS_SERVER}, skip-cert-verify: false, fingerprint: ${SELF_SIGNED_FINGERPRINT_SHA256}, smux: { enabled: true, protocol: 'h2mux', padding: true, max-connections: '8', min-streams: '16', statistic: true, only-tcp: false }, brutal-opts: { enabled: ${IS_BRUTAL}, up: '1000 Mbps', down: '1000 Mbps' } }"
      local CLASH_SUBSCRIBE+="
  $CLASH_TROJAN
"
    done
  fi
  if [ -n "$PORT_VMESS_WS" ]; then
    local VMESS_CDN_PORT=${CDN_PORT[17]:-80}
    local VMESS_CDN_SERVER=$(format_uri_host "${CDN[17]}")
    if [[ "${STATUS[1]}" =~ $(text 27)|$(text 28) ]] || [[ "$IS_ARGO" = 'is_argo' && "$NONINTERACTIVE_INSTALL" = 'noninteractive_install' ]]; then
      local CLASH_VMESS_WS="- {name: \"${NODE_NAME[17]} ${NODE_TAG[6]}\", type: vmess, server: ${VMESS_CDN_SERVER}, port: ${VMESS_CDN_PORT}, uuid: ${UUID[17]}, udp: true, tls: false, alterId: 0, cipher: auto, network: ws, ws-opts: { path: \"/$VMESS_WS_PATH\", headers: {Host: $ARGO_DOMAIN} }, smux: { enabled: true, protocol: 'h2mux', padding: true, max-connections: '8', min-streams: '16', statistic: true, only-tcp: false }, brutal-opts: { enabled: ${IS_BRUTAL}, up: '1000 Mbps', down: '1000 Mbps' } }" &&
      local CLASH_SUBSCRIBE+="
  $CLASH_VMESS_WS
"
      [ "$ARGO_TYPE" = 'is_token_argo' ] && CLASH_SUBSCRIBE+="
  # $(text 94)
"
    else
      local CLASH_VMESS_WS="- {name: \"${NODE_NAME[17]} ${NODE_TAG[6]}\", type: vmess, server: ${VMESS_CDN_SERVER}, port: ${VMESS_CDN_PORT}, uuid: ${UUID[17]}, udp: true, tls: false, alterId: 0, cipher: auto, network: ws, ws-opts: { path: \"/$VMESS_WS_PATH\", headers: {Host: $VMESS_HOST_DOMAIN} }, smux: { enabled: true, protocol: 'h2mux', padding: true, max-connections: '8', min-streams: '16', statistic: true, only-tcp: false }, brutal-opts: { enabled: ${IS_BRUTAL}, up: '1000 Mbps', down: '1000 Mbps' } }" &&
      local WS_SERVER_IP_SHOW=${WS_SERVER_IP[17]} && local TYPE_HOST_DOMAIN=$VMESS_HOST_DOMAIN && local TYPE_PORT_WS=$PORT_VMESS_WS &&
      local CLASH_SUBSCRIBE+="
  $CLASH_VMESS_WS

  # $(text 52)
"
    fi
  fi

  if [ -n "$PORT_VLESS_WS" ]; then
    local VLESS_CDN_PORT=${CDN_PORT[18]:-443}
    local VLESS_CDN_SERVER=$(format_uri_host "${CDN[18]}")
     if [[ "${STATUS[1]}" =~ $(text 27)|$(text 28) ]] || [[ "$IS_ARGO" = 'is_argo' && "$NONINTERACTIVE_INSTALL" = 'noninteractive_install' ]]; then
      local CLASH_VLESS_WS="- {name: \"${NODE_NAME[18]} ${NODE_TAG[7]}\", type: vless, server: ${VLESS_CDN_SERVER}, port: ${VLESS_CDN_PORT}, uuid: ${UUID[18]}, udp: true, tls: true, servername: $ARGO_DOMAIN, network: ws, skip-cert-verify: false, ws-opts: { path: \"/$VLESS_WS_PATH\", headers: {Host: $ARGO_DOMAIN}, max-early-data: 2560, early-data-header-name: Sec-WebSocket-Protocol }, smux: { enabled: true, protocol: 'h2mux', padding: true, max-connections: '8', min-streams: '16', statistic: true, only-tcp: false }, brutal-opts: { enabled: ${IS_BRUTAL}, up: '1000 Mbps', down: '1000 Mbps' } }" &&
      local CLASH_SUBSCRIBE+="
  $CLASH_VLESS_WS
"
      [ "$ARGO_TYPE" = 'is_token_argo' ] && CLASH_SUBSCRIBE+="
  # $(text 94)
"
    else
      local CLASH_VLESS_WS="- {name: \"${NODE_NAME[18]} ${NODE_TAG[7]}\", type: vless, server: ${VLESS_CDN_SERVER}, port: ${VLESS_CDN_PORT}, uuid: ${UUID[18]}, udp: true, tls: true, servername: $VLESS_HOST_DOMAIN, network: ws, skip-cert-verify: false, ws-opts: { path: \"/$VLESS_WS_PATH\", headers: {Host: $VLESS_HOST_DOMAIN}, max-early-data: 2560, early-data-header-name: Sec-WebSocket-Protocol }, smux: { enabled: true, protocol: 'h2mux', padding: true, max-connections: '8', min-streams: '16', statistic: true, only-tcp: false }, brutal-opts: { enabled: ${IS_BRUTAL}, up: '1000 Mbps', down: '1000 Mbps' } }" &&
      local WS_SERVER_IP_SHOW=${WS_SERVER_IP[18]} && local TYPE_HOST_DOMAIN=$VLESS_HOST_DOMAIN && local TYPE_PORT_WS=$PORT_VLESS_WS &&
      local CLASH_SUBSCRIBE+="
  $CLASH_VLESS_WS

  # $(text 52)
"
    fi
  fi

  if [ -n "$PORT_H2_REALITY" ]; then
    for ip in "${SERVER_IPS[@]}"; do
      local CLASH_SUF=""; [ "${#SERVER_IPS[@]}" -gt 1 ] && CLASH_SUF=" [${ip}]"
      local CLASH_H2_REALITY="- {name: \"${NODE_NAME[19]} ${NODE_TAG[8]}${CLASH_SUF}\", type: vless, server: ${ip}, port: ${PORT_H2_REALITY}, uuid: ${UUID[19]}, network: http, tls: true, servername: ${TLS_SERVER}, client-fingerprint: ${FINGER_PRINT}, reality-opts: { public-key: ${REALITY_PUBLIC[19]}, short-id: \"\" }, smux: { enabled: true, protocol: 'h2mux', padding: true, max-connections: '8', min-streams: '16', statistic: true, only-tcp: false }, brutal-opts: { enabled: ${IS_BRUTAL}, up: '1000 Mbps', down: '1000 Mbps' } }"
      local CLASH_SUBSCRIBE+="
  $CLASH_H2_REALITY
"
    done
  fi

  if [ -n "$PORT_GRPC_REALITY" ]; then
    for ip in "${SERVER_IPS[@]}"; do
      local CLASH_SUF=""; [ "${#SERVER_IPS[@]}" -gt 1 ] && CLASH_SUF=" [${ip}]"
      local CLASH_GRPC_REALITY="- {name: \"${NODE_NAME[20]} ${NODE_TAG[9]}${CLASH_SUF}\", type: vless, server: ${ip}, port: ${PORT_GRPC_REALITY}, uuid: ${UUID[20]}, network: grpc, tls: true, udp: true, flow: , client-fingerprint: ${FINGER_PRINT}, servername: ${TLS_SERVER}, grpc-opts: {  grpc-service-name: \"grpc\" }, reality-opts: { public-key: ${REALITY_PUBLIC[20]}, short-id: \"\" }, smux: { enabled: true, protocol: 'h2mux', padding: true, max-connections: '8', min-streams: '16', statistic: true, only-tcp: false }, brutal-opts: { enabled: ${IS_BRUTAL}, up: '1000 Mbps', down: '1000 Mbps' } }"
      local CLASH_SUBSCRIBE+="
  $CLASH_GRPC_REALITY
"
    done
  fi

  if [ -n "$PORT_ANYTLS" ]; then
    for ip in "${SERVER_IPS[@]}"; do
      local CLASH_SUF=""; [ "${#SERVER_IPS[@]}" -gt 1 ] && CLASH_SUF=" [${ip}]"
      local CLASH_ANYTLS="- {name: \"${NODE_NAME[21]} ${NODE_TAG[10]}${CLASH_SUF}\", type: anytls, server: ${ip}, port: $PORT_ANYTLS, password: ${UUID[21]}, client-fingerprint: ${FINGER_PRINT}, udp: true, idle-session-check-interval: 30, idle-session-timeout: 30, sni: ${TLS_SERVER}, skip-cert-verify: false, fingerprint: ${SELF_SIGNED_FINGERPRINT_SHA256} }"
      local CLASH_SUBSCRIBE+="
  $CLASH_ANYTLS
"
    done
  fi

  echo -n "${CLASH_SUBSCRIBE}" | sed -E '/^[ ]*#|^--/d' | sed '/^$/d' > ${WORK_DIR}/subscribe/proxies

  # 后台生成 clash 订阅配置文件
  {
    # 模板1: 使用 proxy providers
    cat ${TEMP_DIR}/clash | sed "s#NODE_NAME#${NODE_NAME_CONFIRM}#g; s#PROXY_PROVIDERS_URL#$PROXY_PROVIDERS_URL#" > ${WORK_DIR}/subscribe/clash

    # 模板2: 不使用 proxy providers
    # 从已生成的多 IP Clash 订阅中抽取节点行（排除 h2-reality，与旧版 Clash2 行为一致）
    mapfile -t CLASH2_PROXY_INSERT < <(printf '%s\n' "$CLASH_SUBSCRIBE" | sed '1d' | sed -E '/^[ ]*#|^--/d' | sed '/^$/d' | grep -v 'network: http')
    mapfile -t CLASH2_PROXY_GROUPS_INSERT < <(printf '%s\n' "${CLASH2_PROXY_INSERT[@]}" | sed -E 's/.*name: "([^"]+)".*/- \1/')

    CLASH2_YAML=$(cat ${TEMP_DIR}/clash2)
    for x in ${!CLASH2_PROXY_INSERT[@]}; do
      CLASH2_YAML=$(sed "/proxy-groups:/i\${CLASH2_PROXY_INSERT[x]}" <<< "$CLASH2_YAML"); CLASH2_YAML=$(sed -E "/- name: (♻️ 自动选择|📲 电报消息|💬 OpenAi|📹 油管视频|🎥 奈飞视频|📺 巴哈姆特|📺 哔哩哔哩|🌍 国外媒体|🌏 国内媒体|📢 谷歌FCM|Ⓜ️ 微软Bing|Ⓜ️ 微软云盘|Ⓜ️ 微软服务|🍎 苹果服务|🎮 游戏平台|🎶 网易音乐|🎯 全球直连)|^rules:$/i\      ${CLASH2_PROXY_GROUPS_INSERT[x]}" <<< "$CLASH2_YAML")
    done
    echo "$CLASH2_YAML" > ${WORK_DIR}/subscribe/clash2

    rm -f ${TEMP_DIR}/clash{,2}
  } &>/dev/null

  # 生成校园网免流 Clash 订阅。
  # 公网地址不再按 DNS 返回的 A/AAAA 记录分流：除直连网段和域名白名单外，一律走免流节点。
  if [ "$IS_SUB" = 'is_sub' ]; then
    local CAMPUS_RULES="" CAMPUS_DOMAIN_RULES="" _cidr _domain
    for _cidr in ${CAMPUS_DIRECT_CIDR//,/ }; do
      CAMPUS_RULES+="  - IP-CIDR,${_cidr},DIRECT"$'\n'
    done
    # 仅接受域名，避免把用户传入的内容直接写进 YAML 规则。DOMAIN-SUFFIX 会匹配该域名及其全部子域名。
    for _domain in ${CAMPUS_DIRECT_DOMAINS//,/ }; do
      _domain=${_domain,,}
      # 允许用户传入域名，也允许误填完整 URL；路径和端口不参与 Clash 的域名匹配。
      _domain=${_domain#http://}
      _domain=${_domain#https://}
      _domain=${_domain%%/*}
      _domain=${_domain%%:*}
      _domain=${_domain#.}
      if [[ "$_domain" =~ ^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?(\.[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?)+$ ]]; then
        CAMPUS_DOMAIN_RULES+="  - DOMAIN-SUFFIX,${_domain},DIRECT"$'\n'
      else
        warning "忽略无效的校园网直连域名：${_domain}（请填写域名或 http(s) URL，例如 neu.edu.cn）"
      fi
    done
    cat > ${WORK_DIR}/subscribe/clash-campus-free << EOF
mixed-port: 7890
allow-lan: true
bind-address: '*'
mode: rule
log-level: info
ipv6: true
external-controller: 127.0.0.1:10000
experimental:
  ignore-resolve-fail: true
sniffer:
  enable: true
  override-destination: true
  force-dns-mapping: true
  parse-pure-ip: true
  sniff:
    HTTP:
      ports: [80, 8080-8880]
      override-destination: true
    TLS:
      ports: [443, 8443]
      override-destination: true
    QUIC:
      ports: [443, 8443]
      override-destination: true

# 校园网免流：保留域名以命中白名单；公网 IPv4/IPv6 不再依赖 DNS 结果分流。
dns:
  enable: true
  ipv6: true
  enhanced-mode: redir-host
  use-hosts: true
  default-nameserver:
    - 223.5.5.5
    - 1.12.12.12
  nameserver:
    - 223.5.5.5
    - 1.12.12.12
  fallback:
    - https://dns.google/dns-query
    - https://1.1.1.1/dns-query
  fallback-filter:
    geoip: true
    geoip-code: CN

proxy-providers:
  所有节点:
    type: http
    url: ${PROXY_PROVIDERS_URL}
    interval: 3600
    health-check:
      enable: true
      url: https://www.gstatic.com/generate_204
      interval: 300

  仅IPv6节点:
    type: http
    url: ${PROXY_PROVIDERS_URL}
    interval: 3600
    # 节点名后缀是 [IP]，IPv6 地址含冒号，IPv4 不含 → 只留 IPv6
    filter: ".*:.*"
    health-check:
      enable: true
      url: https://www.gstatic.com/generate_204
      interval: 300

rule-providers:
  # 广告屏蔽规则集：Loyalsoldier 维护的广告/追踪域名列表。
  # RULE-SET 只能引用 rule-providers，不能放在 proxy-providers 中。
  reject:
    type: http
    behavior: domain
    url: "https://cdn.jsdelivr.net/gh/Loyalsoldier/clash-rules@release/reject.txt"
    path: ./ruleset/reject.yaml
    interval: 86400

proxies:

# 三个代理组
proxy-groups:
  # 1. 节点选择：直接手动选择真实节点，不再嵌套“自动选择”子组
  - name: 🚀 节点选择
    type: select
    use: ['所有节点']

  # 2. 自动选择：只测 IPv6 节点，自动选延迟最低的 IPv6
  - name: ♻️ 自动选择
    type: url-test
    url: http://www.gstatic.com/generate_204
    interval: 300
    tolerance: 50
    use: ['仅IPv6节点']

  # 3. 免流节点：自动选择优先，其次节点选择，再列出 IPv6/IPv4 真实节点
  - name: 🆓 免流节点
    type: select
    proxies: ['♻️ 自动选择', '🚀 节点选择']
    use: ['所有节点']

  # 4. 广告屏蔽：命中广告规则集的请求直接拒绝，默认 REJECT，可切 DIRECT 放行
  - name: 🛑 全球拦截
    type: select
    proxies: [REJECT, DIRECT]

# 规则：广告屏蔽 + 校园网/内网 IPv4、域名白名单直连 + 其余所有公网地址走免流节点。
# 不能在此处增加 IP-CIDR6,::/0；否则双栈网站被 DNS 解析为 IPv6 时会绕过免流节点。
rules:
  - RULE-SET,reject,🛑 全球拦截
${CAMPUS_DOMAIN_RULES}${CAMPUS_RULES}  - IP-CIDR,172.16.0.0/12,DIRECT
  - IP-CIDR,100.64.0.0/10,DIRECT
  - IP-CIDR,192.168.0.0/16,DIRECT
  - IP-CIDR,10.0.0.0/8,DIRECT
  - IP-CIDR,127.0.0.0/8,DIRECT
  - IP-CIDR,169.254.0.0/16,DIRECT
  - IP-CIDR,224.0.0.0/4,DIRECT
  # 其余所有公网地址（包括 IPv4 与 IPv6）→ 免流节点
  - MATCH,🆓 免流节点
EOF
  fi

  # 生成 ShadowRocket 订阅配置文件
  if [ -n "$PORT_XTLS_REALITY" ]; then
    for ip in "${SERVER_IPS[@]}"; do
      if [[ "$ip" =~ : ]]; then local ip2="[[$ip]]"; else local ip2="$ip"; fi
      local suf=""; [ "${#SERVER_IPS[@]}" -gt 1 ] && suf="%20[${ip}]"
      local SHADOWROCKET_SUBSCRIBE+="
vless://$(echo -n "auto:${UUID[11]}@${ip2}:${PORT_XTLS_REALITY}" | base64 -w0)?remarks=${NODE_NAME[11]// /%20}%20${NODE_TAG[0]}${suf}&tls=1&peer=${TLS_SERVER}&${VISION_OR_MUX_SHADOWROCKET}&pbk=${REALITY_PUBLIC[11]}
"
    done
  fi
  if [ -n "$PORT_HYSTERIA2" ]; then
    local SHADOWROCKET_PARAMS="peer=${TLS_SERVER}&hpkp=${SELF_SIGNED_FINGERPRINT_SHA256}&obfs=none&upmbps=${HY2_UP}&downmbps=${HY2_DOWN}"
    [[ -n "$PORT_HOPPING_START" && -n "$PORT_HOPPING_END" ]] && SHADOWROCKET_PARAMS+="&keepalive=30&mport=${PORT_HYSTERIA2},${PORT_HOPPING_START}-${PORT_HOPPING_END}"
    for ip in "${SERVER_IPS[@]}"; do
      if [[ "$ip" =~ : ]]; then local ip1="[$ip]"; else local ip1="$ip"; fi
      local suf=""; [ "${#SERVER_IPS[@]}" -gt 1 ] && suf="%20[${ip}]"
      local SHADOWROCKET_SUBSCRIBE+="
hysteria2://${UUID[12]}@${ip1}:${PORT_HYSTERIA2}?${SHADOWROCKET_PARAMS}#${NODE_NAME[12]// /%20}%20${NODE_TAG[1]}${suf}
"
    done
  fi
  if [ -n "$PORT_TUIC" ]; then
    for ip in "${SERVER_IPS[@]}"; do
      if [[ "$ip" =~ : ]]; then local ip2="[[$ip]]"; else local ip2="$ip"; fi
      local suf=""; [ "${#SERVER_IPS[@]}" -gt 1 ] && suf="%20[${ip}]"
      local SHADOWROCKET_SUBSCRIBE+="
tuic://${TUIC_PASSWORD}:${UUID[13]}@${ip2}:${PORT_TUIC}?peer=${TLS_SERVER}&congestion_control=$TUIC_CONGESTION_CONTROL&udp_relay_mode=native&alpn=h3&hpkp=${SELF_SIGNED_FINGERPRINT_SHA256}#${NODE_NAME[13]// /%20}%20${NODE_TAG[2]}${suf}
"
    done
  fi
  if [ -n "$PORT_SHADOWTLS" ]; then
    for ip in "${SERVER_IPS[@]}"; do
      if [[ "$ip" =~ : ]]; then local ip2="[[$ip]]"; else local ip2="$ip"; fi
      local suf=""; [ "${#SERVER_IPS[@]}" -gt 1 ] && suf="%20[${ip}]"
      local SHADOWROCKET_SUBSCRIBE+="
ss://$(echo -n "$SHADOWTLS_METHOD:$SHADOWTLS_PASSWORD@${ip2}:${PORT_SHADOWTLS}" | base64 -w0)?shadow-tls=$(echo -n "{\"version\":\"3\",\"host\":\"${TLS_SERVER}\",\"password\":\"${UUID[14]}\"}" | base64 -w0)#${NODE_NAME[14]// /%20}%20${NODE_TAG[3]}${suf}
"
    done
  fi
  if [ -n "$PORT_SHADOWSOCKS" ]; then
    for ip in "${SERVER_IPS[@]}"; do
      if [[ "$ip" =~ : ]]; then local ip2="[[$ip]]"; else local ip2="$ip"; fi
      local suf=""; [ "${#SERVER_IPS[@]}" -gt 1 ] && suf="%20[${ip}]"
      local SHADOWROCKET_SUBSCRIBE+="
ss://$(echo -n "${SHADOWSOCKS_METHOD}:${SHADOWSOCKS_PASSWORD}@${ip2}:$PORT_SHADOWSOCKS" | base64 -w0)#${NODE_NAME[15]// /%20}%20${NODE_TAG[4]}${suf}
"
    done
  fi
  if [ -n "$PORT_TROJAN" ]; then
    for ip in "${SERVER_IPS[@]}"; do
      if [[ "$ip" =~ : ]]; then local ip1="[$ip]"; else local ip1="$ip"; fi
      local suf=""; [ "${#SERVER_IPS[@]}" -gt 1 ] && suf="%20[${ip}]"
      local SHADOWROCKET_SUBSCRIBE+="
trojan://${TROJAN_PASSWORD}@${ip1}:$PORT_TROJAN?peer=${TLS_SERVER}&hpkp=${SELF_SIGNED_FINGERPRINT_SHA256}#${NODE_NAME[16]// /%20}%20${NODE_TAG[5]}${suf}
"
    done
  fi
  if [ -n "$PORT_VMESS_WS" ]; then
    local VMESS_CDN_PORT=${CDN_PORT[17]:-80}
    local VMESS_CDN_HOST=$(format_uri_host "${CDN[17]}")
     if [[ "${STATUS[1]}" =~ $(text 27)|$(text 28) ]] || [[ "$IS_ARGO" = 'is_argo' && "$NONINTERACTIVE_INSTALL" = 'noninteractive_install' ]]; then
      local SHADOWROCKET_SUBSCRIBE+="
----------------------------
vmess://$(echo -n "auto:${UUID[17]}@${VMESS_CDN_HOST}:${VMESS_CDN_PORT}" | base64 -w0)?remarks=${NODE_NAME[17]// /%20}%20${NODE_TAG[6]}&obfsParam=$ARGO_DOMAIN&path=/$VMESS_WS_PATH&obfs=websocket&alterId=0
"
      [ "$ARGO_TYPE" = 'is_token_argo' ] && SHADOWROCKET_SUBSCRIBE+="
  # $(text 94)
"
    else
      WS_SERVER_IP_SHOW=${WS_SERVER_IP[17]} && TYPE_HOST_DOMAIN=$VMESS_HOST_DOMAIN && TYPE_PORT_WS=$PORT_VMESS_WS && local SHADOWROCKET_SUBSCRIBE+="
----------------------------
vmess://$(echo -n "auto:${UUID[17]}@${VMESS_CDN_HOST}:${VMESS_CDN_PORT}" | base64 -w0)?remarks=${NODE_NAME[17]// /%20}%20${NODE_TAG[6]}&obfsParam=$VMESS_HOST_DOMAIN&path=/$VMESS_WS_PATH&obfs=websocket&alterId=0

# $(text 52)
"
    fi
  fi

  if [ -n "$PORT_VLESS_WS" ]; then
    local VLESS_CDN_PORT=${CDN_PORT[18]:-443}
    local VLESS_CDN_HOST=$(format_uri_host "${CDN[18]}")
     if [[ "${STATUS[1]}" =~ $(text 27)|$(text 28) ]] || [[ "$IS_ARGO" = 'is_argo' && "$NONINTERACTIVE_INSTALL" = 'noninteractive_install' ]]; then
      local SHADOWROCKET_SUBSCRIBE+="
----------------------------
vless://$(echo -n "auto:${UUID[18]}@${VLESS_CDN_HOST}:${VLESS_CDN_PORT}" | base64 -w0)?remarks=${NODE_NAME[18]// /%20}%20${NODE_TAG[7]}&obfsParam=$ARGO_DOMAIN&path=/$VLESS_WS_PATH?ed=2560&obfs=websocket&tls=1&peer=$ARGO_DOMAIN
"
      [ "$ARGO_TYPE" = 'is_token_argo' ] && SHADOWROCKET_SUBSCRIBE+="
  # $(text 94)
"
    else
      WS_SERVER_IP_SHOW=${WS_SERVER_IP[18]} && TYPE_HOST_DOMAIN=$VLESS_HOST_DOMAIN && TYPE_PORT_WS=$PORT_VLESS_WS && local SHADOWROCKET_SUBSCRIBE+="
----------------------------
vless://$(echo -n "auto:${UUID[18]}@${VLESS_CDN_HOST}:${VLESS_CDN_PORT}" | base64 -w0)?remarks=${NODE_NAME[18]// /%20}%20${NODE_TAG[7]}&obfsParam=$VLESS_HOST_DOMAIN&path=/$VLESS_WS_PATH?ed=2560&obfs=websocket&tls=1&peer=$VLESS_HOST_DOMAIN

# $(text 52)
"
    fi
  fi

  if [ -n "$PORT_H2_REALITY" ]; then
    local SHADOWROCKET_SUBSCRIBE+="
----------------------------"
    for ip in "${SERVER_IPS[@]}"; do
      if [[ "$ip" =~ : ]]; then local ip2="[[$ip]]"; else local ip2="$ip"; fi
      local suf=""; [ "${#SERVER_IPS[@]}" -gt 1 ] && suf="%20[${ip}]"
      local SHADOWROCKET_SUBSCRIBE+="
vless://$(echo -n auto:${UUID[19]}@${ip2}:${PORT_H2_REALITY} | base64 -w0)?remarks=${NODE_NAME[19]// /%20}%20${NODE_TAG[8]}${suf}&path=/&obfs=h2&tls=1&peer=${TLS_SERVER}&alpn=h2&mux=1&pbk=${REALITY_PUBLIC[19]}
"
    done
  fi
  if [ -n "$PORT_GRPC_REALITY" ]; then
    for ip in "${SERVER_IPS[@]}"; do
      if [[ "$ip" =~ : ]]; then local ip2="[[$ip]]"; else local ip2="$ip"; fi
      local suf=""; [ "${#SERVER_IPS[@]}" -gt 1 ] && suf="%20[${ip}]"
      local SHADOWROCKET_SUBSCRIBE+="
vless://$(echo -n "auto:${UUID[20]}@${ip2}:${PORT_GRPC_REALITY}" | base64 -w0)?remarks=${NODE_NAME[20]// /%20}%20${NODE_TAG[9]}${suf}&path=grpc&obfs=grpc&tls=1&peer=${TLS_SERVER}&pbk=${REALITY_PUBLIC[20]}
"
    done
  fi
  if [ -n "$PORT_ANYTLS" ]; then
    for ip in "${SERVER_IPS[@]}"; do
      if [[ "$ip" =~ : ]]; then local ip1="[$ip]"; else local ip1="$ip"; fi
      local suf=""; [ "${#SERVER_IPS[@]}" -gt 1 ] && suf="%20[${ip}]"
      local SHADOWROCKET_SUBSCRIBE+="
anytls://${UUID[21]}@${ip1}:${PORT_ANYTLS}?peer=${TLS_SERVER}&udp=1&hpkp=${SELF_SIGNED_FINGERPRINT_SHA256}#${NODE_NAME[21]// /%20}%20${NODE_TAG[10]}${suf}
"
    done
  fi
  if [ -n "$PORT_NAIVE" ]; then
    for ip in "${SERVER_IPS[@]}"; do
      if [[ "$ip" =~ : ]]; then local ip2="[[$ip]]"; else local ip2="$ip"; fi
      local suf=""; [ "${#SERVER_IPS[@]}" -gt 1 ] && suf="%20[${ip}]"
      local SHADOWROCKET_SUBSCRIBE+="
http2://$(echo -n "${UUID[22]}:${UUID[22]}@${ip2}:${PORT_NAIVE}" | base64 -w0)?peer=${TLS_SERVER}&alpn=h2,http/1.1&padding=1&uot=2&hpkp=${SELF_SIGNED_200_FINGERPRINT_SHA256}#${NODE_NAME[22]// /%20}%20${NODE_TAG[11]}%20http2${suf}

http3://$(echo -n "${UUID[22]}:${UUID[22]}@${ip2}:${PORT_NAIVE}" | base64 -w0)?peer=${TLS_SERVER}&alpn=h3&padding=1&hpkp=${SELF_SIGNED_200_FINGERPRINT_SHA256}#${NODE_NAME[22]// /%20}%20${NODE_TAG[11]}%20http3${suf}
"
    done
  fi
  echo -n "$SHADOWROCKET_SUBSCRIBE" | sed -E '/^[ ]*#|^--/d' | sed '/^$/d' | base64 -w0 > ${WORK_DIR}/subscribe/shadowrocket

  # 生成 V2rayN 订阅文件
  if [ -n "$PORT_XTLS_REALITY" ]; then
    for ip in "${SERVER_IPS[@]}"; do
      if [[ "$ip" =~ : ]]; then local ip1="[$ip]"; else local ip1="$ip"; fi
      local suf=""; [ "${#SERVER_IPS[@]}" -gt 1 ] && suf="%20[${ip}]"
      local V2RAYN_SUBSCRIBE+="
----------------------------
vless://${UUID[11]}@${ip1}:${PORT_XTLS_REALITY}?encryption=none${VISION_FLOW}&security=reality&sni=${TLS_SERVER}&fp=${FINGER_PRINT}&pbk=${REALITY_PUBLIC[11]}&type=tcp&headerType=none#${NODE_NAME[11]// /%20}%20${NODE_TAG[0]}${suf}"
    done
  fi

  if [ -n "$PORT_HYSTERIA2" ]; then
    [[ -n "$PORT_HOPPING_START" && -n "$PORT_HOPPING_END" ]] && local V2RAYN_PARAMS=",\"Ports\":\"${PORT_HOPPING_START}-${PORT_HOPPING_END}\",\"HopInterval\":\"30s\""
    local REALM_PARAMS=""
    [ "$IS_HY2_REALM" = 'is_hy2_realm' ] && REALM_PARAMS="\"Hy2RealmUrl\":\"realm://public@realm.hy2.io:443/${UUID[12]}?stun=stun.nextcloud.com:3478&stun=stun.sip.us:3478&stun=turn.cloudflare.com:3478&stun=global.stun.twilio.com:3478\","
    for ip in "${SERVER_IPS[@]}"; do
      local suf=""; [ "${#SERVER_IPS[@]}" -gt 1 ] && suf=" [${ip}]"
      local V2RAYN_SUBSCRIBE+="
----------------------------
v2rayn://hysteria2/$(echo -n "{\"ConfigType\":7,\"ConfigVersion\":4,\"Remarks\":\"${NODE_NAME[12]} ${NODE_TAG[1]}${suf}\",\"Address\":\"${ip}\",\"Port\":${PORT_HYSTERIA2},\"Password\":\"${UUID[12]}\",\"StreamSecurity\":\"tls\",\"AllowInsecure\":\"false\",\"Sni\":\"${TLS_SERVER}\",\"Cert\":\"${CERT_URL_2}\",\"ProtoExtraObj\":{"${REALM_PARAMS}"\"UpMbps\":${HY2_UP:-200},\"DownMbps\":${HY2_DOWN:-1000}}}" | base64 -w0 | tr '+/' '-_' | tr -d '=')"
    done
  fi

  if [ -n "$PORT_TUIC" ]; then
    for ip in "${SERVER_IPS[@]}"; do
      local suf=""; [ "${#SERVER_IPS[@]}" -gt 1 ] && suf=" [${ip}]"
      local V2RAYN_SUBSCRIBE+="
----------------------------
v2rayn://tuic/$(echo -n "{\"ConfigType\":8,\"CoreType\":24,\"ConfigVersion\":4,\"Remarks\":\"${NODE_NAME[13]} ${NODE_TAG[2]}${suf}\",\"Address\":\"${ip}\",\"Port\":${PORT_TUIC},\"Password\":\"${TUIC_PASSWORD}\",\"Username\":\"${UUID[13]}\",\"StreamSecurity\":\"tls\",\"AllowInsecure\":\"false\",\"Sni\":\"${TLS_SERVER}\",\"Alpn\":\"h3\",\"Cert\":\"${CERT_URL_2}\",\"ProtoExtraObj\":{\"CongestionControl\":\"bbr\"}}" | base64 -w0 | tr '+/' '-_' | tr -d '=')"
    done
  fi

  if [ -n "$PORT_SHADOWTLS" ]; then
    for ip in "${SERVER_IPS[@]}"; do
      local V2RAYN_SUBSCRIBE+="
----------------------------
{
    \"log\": {
        \"level\": \"warn\"
    },
    \"inbounds\": [
        {
            \"listen\": \"127.0.0.1\",
            \"listen_port\": ${PORT_SHADOWTLS},
            \"tag\": \"${PROTOCOL_LIST[3]}\",
            \"type\": \"mixed\"
        }
    ],
    \"outbounds\": [
        {
            \"detour\": \"shadowtls-out\",
            \"method\": \"$SHADOWTLS_METHOD\",
            \"password\": \"$SHADOWTLS_PASSWORD\",
            \"type\": \"shadowsocks\",
            \"udp_over_tcp\": false,
            \"multiplex\": {
              \"enabled\": true,
              \"protocol\": \"h2mux\",
              \"max_connections\": 8,
              \"min_streams\": 16,
              \"padding\": true
            }
        },
        {
            \"password\": \"${UUID[14]}\",
            \"server\": \"${ip}\",
            \"server_port\": ${PORT_SHADOWTLS},
            \"tag\": \"shadowtls-out\",
            \"tls\": {
                \"enabled\": true,
                \"server_name\": \"${TLS_SERVER}\",
                \"utls\": {
                  \"enabled\": true,
                  \"fingerprint\": \"${FINGER_PRINT}\"
                }
            },
            \"type\": \"shadowtls\",
            \"version\": 3
        }
    ]
}"
    done
  fi
  if [ -n "$PORT_SHADOWSOCKS" ]; then
    for ip in "${SERVER_IPS[@]}"; do
      if [[ "$ip" =~ : ]]; then local ip1="[$ip]"; else local ip1="$ip"; fi
      local suf=""; [ "${#SERVER_IPS[@]}" -gt 1 ] && suf="%20[${ip}]"
      local V2RAYN_SUBSCRIBE+="
----------------------------
ss://$(echo -n "${SHADOWSOCKS_METHOD}:${SHADOWSOCKS_PASSWORD}@${ip1}:$PORT_SHADOWSOCKS" | base64 -w0)#${NODE_NAME[15]// /%20}%20${NODE_TAG[4]}${suf}"
    done
  fi

  if [ -n "$PORT_TROJAN" ]; then
    for ip in "${SERVER_IPS[@]}"; do
      local suf=""; [ "${#SERVER_IPS[@]}" -gt 1 ] && suf=" [${ip}]"
      local V2RAYN_SUBSCRIBE+="
----------------------------
v2rayn://trojan/$(echo -n "{\"ConfigType\":6,\"ConfigVersion\":4,\"Remarks\":\"${NODE_NAME[16]} ${NODE_TAG[5]}${suf}\",\"Address\":\"${ip}\",\"Port\":${PORT_TROJAN},\"Password\":\"${TROJAN_PASSWORD}\",\"Network\":\"raw\",\"StreamSecurity\":\"tls\",\"AllowInsecure\":\"false\",\"Sni\":\"${TLS_SERVER}\",\"Cert\":\"${CERT_URL_2}\"}" | base64 -w0 | tr '+/' '-_' | tr -d '=')"
    done
  fi

 if [ -n "$PORT_VMESS_WS" ]; then
    local VMESS_CDN_PORT=${CDN_PORT[17]:-80}
    local VMESS_CDN_HOST=$(format_uri_host "${CDN[17]}")
     if [[ "${STATUS[1]}" =~ $(text 27)|$(text 28) ]] || [[ "$IS_ARGO" = 'is_argo' && "$NONINTERACTIVE_INSTALL" = 'noninteractive_install' ]]; then
      local V2RAYN_SUBSCRIBE+="
----------------------------
vmess://$(echo -n "{ \"v\": \"2\", \"ps\": \"${NODE_NAME[17]} ${NODE_TAG[6]}\", \"add\": \"${VMESS_CDN_HOST}\", \"port\": \"${VMESS_CDN_PORT}\", \"id\": \"${UUID[17]}\", \"aid\": \"0\", \"scy\": \"none\", \"net\": \"ws\", \"type\": \"auto\", \"host\": \"$ARGO_DOMAIN\", \"path\": \"/$VMESS_WS_PATH\", \"tls\": \"\", \"sni\": \"\", \"alpn\": \"\" }" | base64 -w0)"
      [ "$ARGO_TYPE" = 'is_token_argo' ] && V2RAYN_SUBSCRIBE+="

  # $(text 94)
"
    else
      WS_SERVER_IP_SHOW=${WS_SERVER_IP[17]} && TYPE_HOST_DOMAIN=$VMESS_HOST_DOMAIN && TYPE_PORT_WS=$PORT_VMESS_WS && local V2RAYN_SUBSCRIBE+="
----------------------------
vmess://$(echo -n "{ \"v\": \"2\", \"ps\": \"${NODE_NAME[17]} ${NODE_TAG[6]}\", \"add\": \"${VMESS_CDN_HOST}\", \"port\": \"${VMESS_CDN_PORT}\", \"id\": \"${UUID[17]}\", \"aid\": \"0\", \"scy\": \"none\", \"net\": \"ws\", \"type\": \"auto\", \"host\": \"$VMESS_HOST_DOMAIN\", \"path\": \"/$VMESS_WS_PATH\", \"tls\": \"\", \"sni\": \"\", \"alpn\": \"\" }" | base64 -w0)

# $(text 52)"
    fi
  fi

  if [ -n "$PORT_VLESS_WS" ]; then
    local VLESS_CDN_PORT=${CDN_PORT[18]:-443}
    local VLESS_CDN_HOST=$(format_uri_host "${CDN[18]}")
     if [[ "${STATUS[1]}" =~ $(text 27)|$(text 28) ]] || [[ "$IS_ARGO" = 'is_argo' && "$NONINTERACTIVE_INSTALL" = 'noninteractive_install' ]]; then
      local V2RAYN_SUBSCRIBE+="
----------------------------
vless://${UUID[18]}@${VLESS_CDN_HOST}:${VLESS_CDN_PORT}?encryption=none&security=tls&sni=$ARGO_DOMAIN&type=ws&host=$ARGO_DOMAIN&path=%2F$VLESS_WS_PATH%3Fed%3D2560#${NODE_NAME[18]// /%20}%20${NODE_TAG[7]}"
      [ "$ARGO_TYPE" = 'is_token_argo' ] && V2RAYN_SUBSCRIBE+="

  # $(text 94)
"
    else
      WS_SERVER_IP_SHOW=${WS_SERVER_IP[18]} && TYPE_HOST_DOMAIN=$VLESS_HOST_DOMAIN && TYPE_PORT_WS=$PORT_VLESS_WS && local V2RAYN_SUBSCRIBE+="
----------------------------
vless://${UUID[18]}@${VLESS_CDN_HOST}:${VLESS_CDN_PORT}?encryption=none&security=tls&sni=$VLESS_HOST_DOMAIN&type=ws&host=$VLESS_HOST_DOMAIN&path=%2F$VLESS_WS_PATH%3Fed%3D2560#${NODE_NAME[18]// /%20}%20${NODE_TAG[7]}

# $(text 52)"
    fi
  fi

  if [ -n "$PORT_H2_REALITY" ]; then
    for ip in "${SERVER_IPS[@]}"; do
      local suf=""; [ "${#SERVER_IPS[@]}" -gt 1 ] && suf=" [${ip}]"
      local V2RAYN_SUBSCRIBE+="
----------------------------
v2rayn://vless/$(echo -n "{\"ConfigType\":5,\"CoreType\":24,\"ConfigVersion\":4,\"Remarks\":\"${NODE_NAME[19]} ${NODE_TAG[8]}${suf}\",\"Address\":\"${ip}\",\"Port\":${PORT_H2_REALITY},\"Password\":\"${UUID[19]}\",\"Network\":\"raw\",\"StreamSecurity\":\"reality\",\"AllowInsecure\":\"false\",\"Sni\":\"${TLS_SERVER}\",\"Fingerprint\":\"${FINGER_PRINT}\",\"PublicKey\":\"${REALITY_PUBLIC[19]}\"}" | base64 -w0 | tr '+/' '-_' | tr -d '=')"
    done
  fi

  if [ -n "$PORT_GRPC_REALITY" ]; then
    for ip in "${SERVER_IPS[@]}"; do
      if [[ "$ip" =~ : ]]; then local ip1="[$ip]"; else local ip1="$ip"; fi
      local suf=""; [ "${#SERVER_IPS[@]}" -gt 1 ] && suf="%20[${ip}]"
      local V2RAYN_SUBSCRIBE+="
----------------------------
vless://${UUID[20]}@${ip1}:${PORT_GRPC_REALITY}?encryption=none&security=reality&sni=${TLS_SERVER}&fp=${FINGER_PRINT}&pbk=${REALITY_PUBLIC[20]}&type=grpc&serviceName=grpc&mode=gun#${NODE_NAME[20]// /%20}%20${NODE_TAG[9]}${suf}"
    done
  fi

  if [ -n "$PORT_ANYTLS" ]; then
    for ip in "${SERVER_IPS[@]}"; do
      local suf=""; [ "${#SERVER_IPS[@]}" -gt 1 ] && suf=" [${ip}]"
      local V2RAYN_SUBSCRIBE+="
----------------------------
v2rayn://anytls/$(echo -n "{\"ConfigType\":11,\"CoreType\":24,\"ConfigVersion\":4,\"Remarks\":\"${NODE_NAME[21]} ${NODE_TAG[10]}${suf}\",\"Address\":\"${ip}\",\"Port\":${PORT_ANYTLS},\"Password\":\"${UUID[21]}\",\"StreamSecurity\":\"tls\",\"AllowInsecure\":\"false\",\"Sni\":\"${TLS_SERVER}\",\"Fingerprint\":\"${FINGER_PRINT}\",\"Cert\":\"${CERT_URL_2}\"}" | base64 -w0 | tr '+/' '-_' | tr -d '=')"
    done
  fi

  if [ -n "$PORT_NAIVE" ]; then
    for ip in "${SERVER_IPS[@]}"; do
      local suf=""; [ "${#SERVER_IPS[@]}" -gt 1 ] && suf=" [${ip}]"
      local V2RAYN_SUBSCRIBE+="
----------------------------
v2rayn://naive/$(echo -n "{\"ConfigType\":12,\"CoreType\":24,\"ConfigVersion\":4,\"Remarks\":\"${NODE_NAME[22]} ${NODE_TAG[11]} http2${suf}\",\"Address\":\"${ip}\",\"Port\":${PORT_NAIVE},\"Password\":\"${UUID[22]}\",\"Username\":\"${UUID[22]}\",\"StreamSecurity\":\"tls\",\"AllowInsecure\":\"false\",\"Sni\":\"${TLS_SERVER}\",\"Cert\":\"${CERT_200_URL_2}\"}" | base64 -w0 | tr '+/' '-_' | tr -d '=')
----------------------------
v2rayn://naive/$(echo -n "{\"ConfigType\":12,\"CoreType\":24,\"ConfigVersion\":4,\"Remarks\":\"${NODE_NAME[22]} ${NODE_TAG[11]} quic${suf}\",\"Address\":\"${ip}\",\"Port\":${PORT_NAIVE},\"Password\":\"${UUID[22]}\",\"Username\":\"${UUID[22]}\",\"StreamSecurity\":\"tls\",\"AllowInsecure\":\"false\",\"Sni\":\"${TLS_SERVER}\",\"Cert\":\"${CERT_200_URL_2}\",\"ProtoExtraObj\":{\"CongestionControl\":\"bbr\",\"NaiveQuic\":true}}" | base64 -w0 | tr '+/' '-_' | tr -d '=')"
    done
  fi

  echo -n "$V2RAYN_SUBSCRIBE" | sed '/-----BEGIN CERTIFICATE-----/,/-----END CERTIFICATE-----/d' | sed -E '/^[ ]*#|^[ ]+|^\{|^\}/d' | sed '/^$/d' | base64 -w0 > ${WORK_DIR}/subscribe/v2rayn

  # 生成 Throne 订阅文件
  if [ -n "$PORT_XTLS_REALITY" ]; then
    for ip in "${SERVER_IPS[@]}"; do
      if [[ "$ip" =~ : ]]; then local ip1="[$ip]"; else local ip1="$ip"; fi
      local suf=""; [ "${#SERVER_IPS[@]}" -gt 1 ] && suf="%20[${ip}]"
      local THRONE_SUBSCRIBE+="
----------------------------
vless://${UUID[11]}@${ip1}:${PORT_XTLS_REALITY}?security=reality&sni=${TLS_SERVER}&fp=${FINGER_PRINT}&pbk=${REALITY_PUBLIC[11]}&type=tcp${VISION_FLOW}&encryption=none#${NODE_NAME[11]// /%20}%20${NODE_TAG[0]}${suf}"
    done
  fi

  if [ -n "$PORT_HYSTERIA2" ]; then
    local THRONE_PARAMS="allowInsecure=false&alpn&security=tls&sni=${TLS_SERVER}&upmbps=${HY2_UP}&downmbps=${HY2_DOWN}&security=tls&tls_certificate=${CERT_URL_1}"
    if [[ -n "$PORT_HOPPING_START" && -n "$PORT_HOPPING_END" ]]; then
      THRONE_PARAMS+="&mport=${PORT_HOPPING_START}-${PORT_HOPPING_END}&hop_interval=30s"
    fi
    for ip in "${SERVER_IPS[@]}"; do
      if [[ "$ip" =~ : ]]; then local ip1="[$ip]"; else local ip1="$ip"; fi
      local suf=""; [ "${#SERVER_IPS[@]}" -gt 1 ] && suf="%20[${ip}]"
      local THRONE_SUBSCRIBE+="
----------------------------
hysteria2://${UUID[12]}@${ip1}:${PORT_HYSTERIA2}?${THRONE_PARAMS}#${NODE_NAME[12]// /%20}%20${NODE_TAG[1]}${suf}"
    done
  fi

  if [ -n "$PORT_TUIC" ]; then
    for ip in "${SERVER_IPS[@]}"; do
      if [[ "$ip" =~ : ]]; then local ip1="[$ip]"; else local ip1="$ip"; fi
      local suf=""; [ "${#SERVER_IPS[@]}" -gt 1 ] && suf="%20[${ip}]"
      local THRONE_SUBSCRIBE+="
----------------------------
tuic://${TUIC_PASSWORD}:${UUID[13]}@${ip1}:${PORT_TUIC}?congestion_control=$TUIC_CONGESTION_CONTROL&alpn=h3&sni=${TLS_SERVER}&udp_relay_mode=native&allow_insecure=0&security=tls&tls_certificate=${CERT_URL_1}#${NODE_NAME[13]// /%20}%20${NODE_TAG[2]}${suf}"
    done
  fi

  if [ -n "$PORT_SHADOWTLS" ]; then
    for ip in "${SERVER_IPS[@]}"; do
      if [[ "$ip" =~ : ]]; then local ip1="[$ip]"; else local ip1="$ip"; fi
      local suf=""; [ "${#SERVER_IPS[@]}" -gt 1 ] && suf="%20[${ip}]"
      local THRONE_SUBSCRIBE+="
----------------------------
shadowtls://:${UUID[14]}@${ip1}:${PORT_SHADOWTLS}?version=3&security=tls&sni=${TLS_SERVER}&fp=chrome#1-tls-not-use${suf}

ss://${SHADOWTLS_METHOD}:${SHADOWTLS_PASSWORD}@127.0.0.1:0#2-ss-not-use"
    done
  fi

  if [ -n "$PORT_SHADOWSOCKS" ]; then
    for ip in "${SERVER_IPS[@]}"; do
      if [[ "$ip" =~ : ]]; then local ip1="[$ip]"; else local ip1="$ip"; fi
      local suf=""; [ "${#SERVER_IPS[@]}" -gt 1 ] && suf="%20[${ip}]"
      local THRONE_SUBSCRIBE+="
----------------------------
ss://$(echo -n "${SHADOWSOCKS_METHOD}:${SHADOWSOCKS_PASSWORD}" | base64 -w0)@${ip1}:$PORT_SHADOWSOCKS#${NODE_NAME[15]// /%20}%20${NODE_TAG[4]}${suf}"
    done
  fi

  if [ -n "$PORT_TROJAN" ]; then
    for ip in "${SERVER_IPS[@]}"; do
      if [[ "$ip" =~ : ]]; then local ip1="[$ip]"; else local ip1="$ip"; fi
      local suf=""; [ "${#SERVER_IPS[@]}" -gt 1 ] && suf="%20[${ip}]"
      local THRONE_SUBSCRIBE+="
----------------------------
trojan://${TROJAN_PASSWORD}@${ip1}:$PORT_TROJAN?security=tls&sni=${TLS_SERVER}&allowInsecure=0&tls_certificate=${CERT_URL_1}&fp=${FINGER_PRINT}&type=tcp#${NODE_NAME[16]// /%20}%20${NODE_TAG[5]}${suf}"
    done
  fi

  if [ -n "$PORT_VMESS_WS" ]; then
     if [[ "${STATUS[1]}" =~ $(text 27)|$(text 28) ]] || [[ "$IS_ARGO" = 'is_argo' && "$NONINTERACTIVE_INSTALL" = 'noninteractive_install' ]]; then
      THRONE_SUBSCRIBE+="
----------------------------
vmess://$(echo -n "{\"add\":\"${CDN[17]}\",\"aid\":\"0\",\"host\":\"$ARGO_DOMAIN\",\"id\":\"${UUID[17]}\",\"net\":\"ws\",\"path\":\"/$VMESS_WS_PATH\",\"port\":\"80\",\"ps\":\"${NODE_NAME[17]} ${NODE_TAG[6]}\",\"scy\":\"auto\",\"sni\":\"\",\"tls\":\"\",\"type\":\"\",\"v\":\"2\"}" | base64 -w0)"
      [ "$ARGO_TYPE" = 'is_token_argo' ] && THRONE_SUBSCRIBE+="

  # $(text 94)
"
    else
      WS_SERVER_IP_SHOW=${WS_SERVER_IP[17]} && TYPE_HOST_DOMAIN=$VMESS_HOST_DOMAIN && TYPE_PORT_WS=$PORT_VMESS_WS && local THRONE_SUBSCRIBE+="
----------------------------
vmess://$(echo -n "{\"add\":\"${CDN[17]}\",\"aid\":\"0\",\"host\":\"$VMESS_HOST_DOMAIN\",\"id\":\"${UUID[17]}\",\"net\":\"ws\",\"path\":\"/$VMESS_WS_PATH\",\"port\":\"80\",\"ps\":\"${NODE_NAME[17]} ${NODE_TAG[6]}\",\"scy\":\"auto\",\"sni\":\"\",\"tls\":\"\",\"type\":\"\",\"v\":\"2\"}" | base64 -w0)

# $(text 52)"
    fi
  fi

  if [ -n "$PORT_VLESS_WS" ]; then
    local VLESS_CDN_PORT=${CDN_PORT[18]:-443}
    local VLESS_CDN_HOST=$(format_uri_host "${CDN[18]}")
     if [[ "${STATUS[1]}" =~ $(text 27)|$(text 28) ]] || [[ "$IS_ARGO" = 'is_argo' && "$NONINTERACTIVE_INSTALL" = 'noninteractive_install' ]]; then
      local THRONE_SUBSCRIBE+="
----------------------------
vless://${UUID[18]}@${VLESS_CDN_HOST}:${VLESS_CDN_PORT}?security=tls&sni=$ARGO_DOMAIN&type=ws&path=/$VLESS_WS_PATH?ed%3D2560&host=$ARGO_DOMAIN&encryption=none#${NODE_NAME[18]// /%20}%20${NODE_TAG[7]}"
      [ "$ARGO_TYPE" = 'is_token_argo' ] && THRONE_SUBSCRIBE+="

  # $(text 94)
"
    else
      WS_SERVER_IP_SHOW=${WS_SERVER_IP[18]} && TYPE_HOST_DOMAIN=$VLESS_HOST_DOMAIN && TYPE_PORT_WS=$PORT_VLESS_WS && local THRONE_SUBSCRIBE+="
----------------------------
vless://${UUID[18]}@${VLESS_CDN_HOST}:${VLESS_CDN_PORT}?security=tls&sni=$VLESS_HOST_DOMAIN&type=ws&path=/$VLESS_WS_PATH?ed%3D2560&host=$VLESS_HOST_DOMAIN&encryption=none#${NODE_NAME[18]// /%20}%20${NODE_TAG[7]}

# $(text 52)"
    fi
  fi

  if [ -n "$PORT_H2_REALITY" ]; then
    for ip in "${SERVER_IPS[@]}"; do
      if [[ "$ip" =~ : ]]; then local ip1="[$ip]"; else local ip1="$ip"; fi
      local suf=""; [ "${#SERVER_IPS[@]}" -gt 1 ] && suf="%20[${ip}]"
      local THRONE_SUBSCRIBE+="
----------------------------
vless://${UUID[19]}@${ip1}:${PORT_H2_REALITY}?security=reality&sni=${TLS_SERVER}&alpn=h2&fp=${FINGER_PRINT}&pbk=${REALITY_PUBLIC[19]// /%20}&type=http&encryption=none#${NODE_NAME[19]// /%20}%20${NODE_TAG[8]}${suf}"
    done
  fi

  if [ -n "$PORT_GRPC_REALITY" ]; then
    for ip in "${SERVER_IPS[@]}"; do
      if [[ "$ip" =~ : ]]; then local ip1="[$ip]"; else local ip1="$ip"; fi
      local suf=""; [ "${#SERVER_IPS[@]}" -gt 1 ] && suf="%20[${ip}]"
      local THRONE_SUBSCRIBE+="
----------------------------
vless://${UUID[20]}@${ip1}:${PORT_GRPC_REALITY}?security=reality&sni=${TLS_SERVER}&fp=${FINGER_PRINT}&pbk=${REALITY_PUBLIC[20]// /%20}&type=grpc&serviceName=grpc&encryption=none#${NODE_NAME[20]// /%20}%20${NODE_TAG[9]}${suf}"
    done
  fi

  if [ -n "$PORT_ANYTLS" ]; then
    for ip in "${SERVER_IPS[@]}"; do
      if [[ "$ip" =~ : ]]; then local ip1="[$ip]"; else local ip1="$ip"; fi
      local suf=""; [ "${#SERVER_IPS[@]}" -gt 1 ] && suf="%20[${ip}]"
      local THRONE_SUBSCRIBE+="
----------------------------
anytls://${UUID[21]}@${ip1}:${PORT_ANYTLS}?idle_session_check_interval=30s&idle_session_timeout=30s&min_idle_session=5&insecure=0&security=tls&sni=${TLS_SERVER}&tls_certificate=${CERT_URL_1}&fp=${FINGER_PRINT}#${NODE_NAME[21]// /%20}%20${NODE_TAG[10]}${suf}"
    done
  fi

  if [ -n "$PORT_NAIVE" ]; then
    for ip in "${SERVER_IPS[@]}"; do
      if [[ "$ip" =~ : ]]; then local ip1="[$ip]"; else local ip1="$ip"; fi
      local suf=""; [ "${#SERVER_IPS[@]}" -gt 1 ] && suf="%20[${ip}]"
      local THRONE_SUBSCRIBE+="
----------------------------
naive+https://${UUID[22]}:${UUID[22]}@${ip1}:${PORT_NAIVE}?uot=1&security=tls&sni=${TLS_SERVER}&tls_certificate=${CERT_200_URL_1}#${NODE_NAME[22]// /%20}%20${NODE_TAG[11]}%20http2${suf}
----------------------------
naive+quic://${UUID[22]}:${UUID[22]}@${ip1}:${PORT_NAIVE}?congestion_control=bbr&security=tls&sni=${TLS_SERVER}&tls_certificate=${CERT_200_URL_1}#${NODE_NAME[22]// /%20}%20${NODE_TAG[11]}%20quic${suf}"
    done
  fi

  echo -n "$THRONE_SUBSCRIBE" | sed -E '/^[ ]*#|^--/d' | sed '/^$/d' | base64 -w0 > ${WORK_DIR}/subscribe/throne

  # 生成 Sing-box 订阅文件
  if [ -n "$PORT_XTLS_REALITY" ]; then
    for ip in "${SERVER_IPS[@]}"; do
      local SB_SUF=""; [ "${#SERVER_IPS[@]}" -gt 1 ] && SB_SUF=" [${ip}]"
      local OUTBOUND_REPLACE+=" { \"type\": \"vless\", \"tag\": \"${NODE_NAME[11]} ${NODE_TAG[0]}${SB_SUF}\", \"server\":\"${ip}\", \"server_port\":${PORT_XTLS_REALITY}, \"uuid\":\"${UUID[11]}\", \"flow\":\"${FLOW}\", \"tls\":{ \"enabled\":true, \"server_name\":\"${TLS_SERVER}\", \"utls\":{ \"enabled\":true, \"fingerprint\":\"${FINGER_PRINT}\" }, \"reality\":{ \"enabled\":true, \"public_key\":\"${REALITY_PUBLIC[11]}\", \"short_id\":\"\" } }, \"multiplex\": { \"enabled\": ${MULTIPLEX_PADDING_ENABLED}, \"protocol\": \"h2mux\", \"max_connections\": 8, \"min_streams\": 16, \"padding\": ${MULTIPLEX_PADDING_ENABLED}, \"brutal\":{ \"enabled\":${VISION_BRUTAL_ENABLED}, \"up_mbps\":1000, \"down_mbps\":1000 } } },"
      local NODE_REPLACE+="\"${NODE_NAME[11]} ${NODE_TAG[0]}${SB_SUF}\","
    done
  fi

  if [ -n "$PORT_HYSTERIA2" ]; then
    for ip in "${SERVER_IPS[@]}"; do
      local SB_SUF=""; [ "${#SERVER_IPS[@]}" -gt 1 ] && SB_SUF=" [${ip}]"
      local HYSTERIA2_CONFIG=" { \"type\": \"hysteria2\", \"tag\": \"${NODE_NAME[12]} ${NODE_TAG[1]}${SB_SUF}\", \"server\": \"${ip}\", \"server_port\": ${PORT_HYSTERIA2}, \"up_mbps\": ${HY2_UP}, \"down_mbps\": ${HY2_DOWN}, \"password\": \"${UUID[12]}\", \"tls\": { \"enabled\": true, \"server_name\": \"${TLS_SERVER}\", \"certificate_public_key_sha256\": [\"$SELF_SIGNED_FINGERPRINT_BASE64\"], \"alpn\": [ \"h3\" ] }"
      if [ "$IS_HY2_REALM" = 'is_hy2_realm' ]; then
        HY2_REALM_ID="${HY2_REALM_ID:-${UUID[12]}}"
        HYSTERIA2_CONFIG+=", \"realm\": { \"server_url\": \"https://realm.hy2.io\", \"token\": \"public\", \"realm_id\": \"${HY2_REALM_ID}\", \"stun_servers\": [ \"turn.cloudflare.com:3478\", \"stun.nextcloud.com:3478\", \"stun.sip.us:3478\", \"global.stun.twilio.com:3478\" ] }"
      fi
      HYSTERIA2_CONFIG+=" },"
      if [[ -n "${PORT_HOPPING_START}" && -n "${PORT_HOPPING_END}" ]]; then
        HYSTERIA2_CONFIG="${HYSTERIA2_CONFIG/\"server_port\": ${PORT_HYSTERIA2},/\"server_port\": ${PORT_HYSTERIA2}, \"server_ports\": [ \"${PORT_HOPPING_START}:${PORT_HOPPING_END}\" ], \"hop_interval\": \"30s\", \"hop_interval_max\": \"60s\",}"
      fi
      local OUTBOUND_REPLACE+="${HYSTERIA2_CONFIG}"
      local NODE_REPLACE+="\"${NODE_NAME[12]} ${NODE_TAG[1]}${SB_SUF}\","
    done
  fi

  if [ -n "$PORT_TUIC" ]; then
    for ip in "${SERVER_IPS[@]}"; do
      local SB_SUF=""; [ "${#SERVER_IPS[@]}" -gt 1 ] && SB_SUF=" [${ip}]"
      local OUTBOUND_REPLACE+=" { \"type\": \"tuic\", \"tag\": \"${NODE_NAME[13]} ${NODE_TAG[2]}${SB_SUF}\", \"server\": \"${ip}\", \"server_port\": ${PORT_TUIC}, \"uuid\": \"${UUID[13]}\", \"password\": \"${TUIC_PASSWORD}\", \"congestion_control\": \"$TUIC_CONGESTION_CONTROL\", \"udp_relay_mode\": \"native\", \"zero_rtt_handshake\": false, \"heartbeat\": \"10s\", \"tls\": { \"enabled\": true, \"server_name\": \"${TLS_SERVER}\", \"certificate_public_key_sha256\": [\"$SELF_SIGNED_FINGERPRINT_BASE64\"], \"alpn\": [ \"h3\" ] } },"
      local NODE_REPLACE+="\"${NODE_NAME[13]} ${NODE_TAG[2]}${SB_SUF}\","
    done
  fi

  if [ -n "$PORT_SHADOWTLS" ]; then
    local ST_IDX=0
    for ip in "${SERVER_IPS[@]}"; do
      ST_IDX=$((ST_IDX+1))
      local SB_SUF=""; [ "${#SERVER_IPS[@]}" -gt 1 ] && SB_SUF=" [${ip}]"
      local ST_TAG="shadowtls-out"; [ "${#SERVER_IPS[@]}" -gt 1 ] && ST_TAG="shadowtls-out-${ST_IDX}"
      local OUTBOUND_REPLACE+=" { \"type\": \"shadowsocks\", \"tag\": \"${NODE_NAME[14]} ${NODE_TAG[3]}${SB_SUF}\", \"method\": \"$SHADOWTLS_METHOD\", \"password\": \"$SHADOWTLS_PASSWORD\", \"detour\": \"${ST_TAG}\", \"udp_over_tcp\": false, \"multiplex\": { \"enabled\": true, \"protocol\": \"h2mux\", \"max_connections\": 8, \"min_streams\": 16, \"padding\": true, \"brutal\":{ \"enabled\":${IS_BRUTAL}, \"up_mbps\":1000, \"down_mbps\":1000 } } }, { \"type\": \"shadowtls\", \"tag\": \"${ST_TAG}\", \"server\": \"${ip}\", \"server_port\": ${PORT_SHADOWTLS}, \"version\": 3, \"password\": \"${UUID[14]}\", \"tls\": { \"enabled\": true, \"server_name\": \"${TLS_SERVER}\", \"utls\": { \"enabled\": true, \"fingerprint\": \"${FINGER_PRINT}\" } } },"
      local NODE_REPLACE+="\"${NODE_NAME[14]} ${NODE_TAG[3]}${SB_SUF}\","
    done
  fi

  if [ -n "$PORT_SHADOWSOCKS" ]; then
    for ip in "${SERVER_IPS[@]}"; do
      local SB_SUF=""; [ "${#SERVER_IPS[@]}" -gt 1 ] && SB_SUF=" [${ip}]"
      local OUTBOUND_REPLACE+=" { \"type\": \"shadowsocks\", \"tag\": \"${NODE_NAME[15]} ${NODE_TAG[4]}${SB_SUF}\", \"server\": \"${ip}\", \"server_port\": $PORT_SHADOWSOCKS, \"method\": \"${SHADOWSOCKS_METHOD}\", \"password\": \"${SHADOWSOCKS_PASSWORD}\", \"multiplex\": { \"enabled\": true, \"protocol\": \"h2mux\", \"max_connections\": 8, \"min_streams\": 16, \"padding\": true, \"brutal\":{ \"enabled\":${IS_BRUTAL}, \"up_mbps\":1000, \"down_mbps\":1000 } } },"
      local NODE_REPLACE+="\"${NODE_NAME[15]} ${NODE_TAG[4]}${SB_SUF}\","
    done
  fi

  if [ -n "$PORT_TROJAN" ]; then
    for ip in "${SERVER_IPS[@]}"; do
      local SB_SUF=""; [ "${#SERVER_IPS[@]}" -gt 1 ] && SB_SUF=" [${ip}]"
      local OUTBOUND_REPLACE+=" { \"type\": \"trojan\", \"tag\": \"${NODE_NAME[16]} ${NODE_TAG[5]}${SB_SUF}\", \"server\": \"${ip}\", \"server_port\": $PORT_TROJAN, \"password\": \"$TROJAN_PASSWORD\", \"tls\": { \"enabled\": true, \"certificate_public_key_sha256\": [\"$SELF_SIGNED_FINGERPRINT_BASE64\"], \"server_name\":\"${TLS_SERVER}\", \"utls\": { \"enabled\":true, \"fingerprint\":\"${FINGER_PRINT}\" } }, \"multiplex\": { \"enabled\":true, \"protocol\":\"h2mux\", \"max_connections\": 8, \"min_streams\": 16, \"padding\": true, \"brutal\":{ \"enabled\":${IS_BRUTAL}, \"up_mbps\":1000, \"down_mbps\":1000 } } },"
      local NODE_REPLACE+="\"${NODE_NAME[16]} ${NODE_TAG[5]}${SB_SUF}\","
    done
  fi

  if [ -n "$PORT_VMESS_WS" ]; then
    local VMESS_CDN_PORT=${CDN_PORT[17]:-80}
    local VMESS_CDN_HOST=$(format_uri_host "${CDN[17]}")
     if [[ "${STATUS[1]}" =~ $(text 27)|$(text 28) ]] || [[ "$IS_ARGO" = 'is_argo' && "$NONINTERACTIVE_INSTALL" = 'noninteractive_install' ]]; then
      local OUTBOUND_REPLACE+=" { \"type\": \"vmess\", \"tag\": \"${NODE_NAME[17]} ${NODE_TAG[6]}\", \"server\":\"${VMESS_CDN_HOST}\", \"server_port\":${VMESS_CDN_PORT}, \"uuid\": \"${UUID[17]}\", \"security\": \"auto\", \"transport\": { \"type\":\"ws\", \"path\":\"/$VMESS_WS_PATH\", \"headers\": { \"Host\": \"$ARGO_DOMAIN\" } }, \"multiplex\": { \"enabled\":true, \"protocol\":\"h2mux\", \"max_streams\":16, \"padding\": true, \"brutal\":{ \"enabled\":${IS_BRUTAL}, \"up_mbps\":1000, \"down_mbps\":1000 } } },"
      [ "$ARGO_TYPE" = 'is_token_argo' ] && [ -z "$PROMPT" ] && local PROMPT="
  # $(text 94)"
    else
      local WS_SERVER_IP_SHOW=${WS_SERVER_IP[17]} &&
      local TYPE_HOST_DOMAIN=$VMESS_HOST_DOMAIN &&
      local TYPE_PORT_WS=$PORT_VMESS_WS &&
      local PROMPT+="
      # $(text 52)" &&
      local OUTBOUND_REPLACE+=" { \"type\": \"vmess\", \"tag\": \"${NODE_NAME[17]} ${NODE_TAG[6]}\", \"server\":\"${VMESS_CDN_HOST}\", \"server_port\":${VMESS_CDN_PORT}, \"uuid\":\"${UUID[17]}\", \"security\": \"auto\", \"transport\": { \"type\":\"ws\", \"path\":\"/$VMESS_WS_PATH\", \"headers\": { \"Host\": \"$VMESS_HOST_DOMAIN\" } }, \"multiplex\": { \"enabled\":true, \"protocol\":\"h2mux\", \"max_streams\":16, \"padding\": true, \"brutal\":{ \"enabled\":${IS_BRUTAL}, \"up_mbps\":1000, \"down_mbps\":1000 } } },"
    fi
    local NODE_REPLACE+="\"${NODE_NAME[17]} ${NODE_TAG[6]}\","
  fi

  if [ -n "$PORT_VLESS_WS" ]; then
    local VLESS_CDN_PORT=${CDN_PORT[18]:-443}
    local VLESS_CDN_HOST=$(format_uri_host "${CDN[18]}")
    if [[ "${STATUS[1]}" =~ $(text 27)|$(text 28) ]] || [[ "$IS_ARGO" = 'is_argo' && "$NONINTERACTIVE_INSTALL" = 'noninteractive_install' ]]; then
      local OUTBOUND_REPLACE+=" { \"type\": \"vless\", \"tag\": \"${NODE_NAME[18]} ${NODE_TAG[7]}\", \"server\":\"${VLESS_CDN_HOST}\", \"server_port\":${VLESS_CDN_PORT}, \"uuid\": \"${UUID[18]}\", \"tls\": { \"enabled\":true, \"server_name\":\"$ARGO_DOMAIN\", \"insecure\": false, \"utls\": { \"enabled\":true, \"fingerprint\":\"${FINGER_PRINT}\" } }, \"transport\": { \"type\":\"ws\", \"path\":\"/$VLESS_WS_PATH\", \"headers\": { \"Host\": \"$ARGO_DOMAIN\" }, \"max_early_data\":2560, \"early_data_header_name\":\"Sec-WebSocket-Protocol\" }, \"multiplex\": { \"enabled\":true, \"protocol\":\"h2mux\", \"max_streams\":16, \"padding\": true, \"brutal\":{ \"enabled\":${IS_BRUTAL}, \"up_mbps\":1000, \"down_mbps\":1000 } } },"
      [ "$ARGO_TYPE" = 'is_token_argo' ] && [ -z "$PROMPT" ] && local PROMPT="
  # $(text 94)"
    else
      local WS_SERVER_IP_SHOW=${WS_SERVER_IP[18]} &&
      local TYPE_HOST_DOMAIN=$VLESS_HOST_DOMAIN &&
      local TYPE_PORT_WS=$PORT_VLESS_WS &&
      local PROMPT+="
      # $(text 52)" &&
      local OUTBOUND_REPLACE+=" { \"type\": \"vless\", \"tag\": \"${NODE_NAME[18]} ${NODE_TAG[7]}\", \"server\":\"${VLESS_CDN_HOST}\", \"server_port\":${VLESS_CDN_PORT}, \"uuid\": \"${UUID[18]}\",\"tls\": { \"enabled\":true, \"server_name\":\"$VLESS_HOST_DOMAIN\", \"insecure\": false, \"utls\": { \"enabled\":true, \"fingerprint\":\"${FINGER_PRINT}\" } }, \"transport\": { \"type\":\"ws\", \"path\":\"/$VLESS_WS_PATH\", \"headers\": { \"Host\": \"$VLESS_HOST_DOMAIN\" }, \"max_early_data\":2560, \"early_data_header_name\":\"Sec-WebSocket-Protocol\" }, \"multiplex\": { \"enabled\":true, \"protocol\":\"h2mux\", \"max_streams\":16, \"padding\": true, \"brutal\":{ \"enabled\":${IS_BRUTAL}, \"up_mbps\":1000, \"down_mbps\":1000 } } },"
    fi
    local NODE_REPLACE+="\"${NODE_NAME[18]} ${NODE_TAG[7]}\","
  fi

  if [ -n "$PORT_H2_REALITY" ]; then
    for ip in "${SERVER_IPS[@]}"; do
      local SB_SUF=""; [ "${#SERVER_IPS[@]}" -gt 1 ] && SB_SUF=" [${ip}]"
      local OUTBOUND_REPLACE+=" { \"type\": \"vless\", \"tag\": \"${NODE_NAME[19]} ${NODE_TAG[8]}${SB_SUF}\", \"server\": \"${ip}\", \"server_port\": ${PORT_H2_REALITY}, \"uuid\":\"${UUID[19]}\", \"tls\": { \"enabled\":true, \"server_name\":\"${TLS_SERVER}\", \"utls\": { \"enabled\":true, \"fingerprint\":\"${FINGER_PRINT}\" }, \"reality\":{ \"enabled\":true, \"public_key\":\"${REALITY_PUBLIC[19]}\", \"short_id\":\"\" } }, \"transport\": { \"type\": \"http\" } },"
      local NODE_REPLACE+="\"${NODE_NAME[19]} ${NODE_TAG[8]}${SB_SUF}\","
    done
  fi

  if [ -n "$PORT_GRPC_REALITY" ]; then
    for ip in "${SERVER_IPS[@]}"; do
      local SB_SUF=""; [ "${#SERVER_IPS[@]}" -gt 1 ] && SB_SUF=" [${ip}]"
      local OUTBOUND_REPLACE+=" { \"type\": \"vless\", \"tag\": \"${NODE_NAME[20]} ${NODE_TAG[9]}${SB_SUF}\", \"server\": \"${ip}\", \"server_port\": ${PORT_GRPC_REALITY}, \"uuid\":\"${UUID[20]}\", \"tls\": { \"enabled\":true, \"server_name\":\"${TLS_SERVER}\", \"utls\": { \"enabled\":true, \"fingerprint\":\"${FINGER_PRINT}\" }, \"reality\":{ \"enabled\":true, \"public_key\":\"${REALITY_PUBLIC[20]}\", \"short_id\":\"\" } }, \"transport\": { \"type\": \"grpc\", \"service_name\": \"grpc\" } },"
      local NODE_REPLACE+="\"${NODE_NAME[20]} ${NODE_TAG[9]}${SB_SUF}\","
    done
  fi

  if [ -n "$PORT_ANYTLS" ]; then
    for ip in "${SERVER_IPS[@]}"; do
      local SB_SUF=""; [ "${#SERVER_IPS[@]}" -gt 1 ] && SB_SUF=" [${ip}]"
      local OUTBOUND_REPLACE+=" { \"type\": \"anytls\", \"tag\": \"${NODE_NAME[21]} ${NODE_TAG[10]}${SB_SUF}\", \"server\": \"${ip}\", \"server_port\": ${PORT_ANYTLS}, \"password\": \"${UUID[21]}\", \"idle_session_check_interval\": \"30s\", \"idle_session_timeout\": \"30s\", \"min_idle_session\": 5, \"tls\": { \"enabled\": true, \"certificate_public_key_sha256\": [\"$SELF_SIGNED_FINGERPRINT_BASE64\"], \"server_name\": \"${TLS_SERVER}\", \"utls\": { \"enabled\": true, \"fingerprint\": \"${FINGER_PRINT}\" } } },"
      local NODE_REPLACE+="\"${NODE_NAME[21]} ${NODE_TAG[10]}${SB_SUF}\","
    done
  fi

  if [ -n "$PORT_NAIVE" ]; then
    for ip in "${SERVER_IPS[@]}"; do
      local SB_SUF=""; [ "${#SERVER_IPS[@]}" -gt 1 ] && SB_SUF=" [${ip}]"
      local OUTBOUND_REPLACE+=" { \"type\": \"naive\", \"tag\": \"${NODE_NAME[22]} ${NODE_TAG[11]} http2${SB_SUF}\", \"server\": \"${ip}\", \"server_port\": ${PORT_NAIVE}, \"username\": \"${UUID[22]}\", \"password\": \"${UUID[22]}\", \"udp_over_tcp\": true, \"quic\": false, \"tls\": { \"enabled\": true, \"certificate\": [$(tr -d '\n' <<< "$CERT200_JSON")], \"server_name\": \"${TLS_SERVER}\" } }, { \"type\": \"naive\", \"tag\": \"${NODE_NAME[22]} ${NODE_TAG[11]} quic${SB_SUF}\", \"server\": \"${ip}\", \"server_port\": ${PORT_NAIVE}, \"username\": \"${UUID[22]}\", \"password\": \"${UUID[22]}\", \"udp_over_tcp\": false, \"quic\": true, \"quic_congestion_control\": \"bbr\", \"tls\": { \"enabled\": true, \"certificate\": [$(tr -d '\n' <<< "$CERT200_JSON")], \"server_name\": \"${TLS_SERVER}\" } },"
      local NODE_REPLACE+="\"${NODE_NAME[22]} ${NODE_TAG[11]} http2${SB_SUF}\",\"${NODE_NAME[22]} ${NODE_TAG[11]} quic${SB_SUF}\","
    done
  fi

  # 严格多用户入口只向 Clash 提供 clash-campus-free/proxies，不需要旧的
  # SFM/SFA/SFI 公共模板。跳过这项远程下载可避免 GitHub 不可达时无限等待。
  if ! is_strict_multi_user_mode; then
    {
      # 生成 sing-box SFM SFA SFI 订阅文件；兜底下载也必须有重试和超时。
      [ -s "$TEMP_DIR/sing-box-template" ] || wget --no-check-certificate --tries=3 --timeout=15 \
        -qO "$TEMP_DIR/sing-box-template" "${GH_PROXY}${SUBSCRIBE_TEMPLATE}/sing-box" 2>/dev/null
      if [ -s "$TEMP_DIR/sing-box-template" ]; then
        sed "s#\"<OUTBOUND_REPLACE>\",#$OUTBOUND_REPLACE#; s#\"<NODE_REPLACE>\"#${NODE_REPLACE%,}#g" \
          "$TEMP_DIR/sing-box-template" | ${WORK_DIR}/jq > ${WORK_DIR}/subscribe/sing-box
      fi
      rm -f "$TEMP_DIR/sing-box-template"
    } &>/dev/null
  else
    rm -f "${WORK_DIR}/subscribe/sing-box" "$TEMP_DIR/sing-box-template"
  fi

  # 生成二维码 url 文件。严格多用户模式没有公共订阅，因此清理旧的公共二维码文件。
  if [ "$IS_SUB" = 'is_sub' ] && ! is_strict_multi_user_mode; then
    cat > ${WORK_DIR}/subscribe/qr << EOF
$(text 81):
$(text 82) 1:
$SUBSCRIBE_ADDRESS/${SUBSCRIBE_TOKEN}/auto

$(text 82) 2:
$SUBSCRIBE_ADDRESS/${SUBSCRIBE_TOKEN}/auto2

$(text 80) QRcode:
$(text 82) 1:
# 本地生成，避免将含令牌的订阅 URL 发送给第三方二维码服务
$(${WORK_DIR}/qrencode "$SUBSCRIBE_ADDRESS/${SUBSCRIBE_TOKEN}/auto")

$(text 82) 2:
$(${WORK_DIR}/qrencode "$SUBSCRIBE_ADDRESS/${SUBSCRIBE_TOKEN}/auto2")
EOF
  elif is_strict_multi_user_mode; then
    rm -f "${WORK_DIR}/subscribe/qr"
  fi

  # 先完成关键管理组件，再处理展示用流量统计和终端输出。即使后面的
  # 非关键步骤异常，管理员命令也不会再处于 command not found 状态。
  if [ "$IS_SUB" = 'is_sub' ] && [ -n "$PORT_HYSTERIA2" ]; then
    info "\n $(text 198) "
    install_multi_user_manager || error "\n Failed to install the Hysteria2/TUIC multi-user manager. \n"
    info " $(text 199) \n"
  fi

  # 生成配置文件
  EXPORT_LIST_FILE="*******************************************
┌────────────────┐
│                │
│     $(warning "V2rayN")     │
│                │
└────────────────┘
$(info "${V2RAYN_SUBSCRIBE}")

*******************************************
┌────────────────┐
│                │
│  $(warning "ShadowRocket")  │
│                │
└────────────────┘
----------------------------
$(hint "${SHADOWROCKET_SUBSCRIBE}")

*******************************************
┌────────────────┐
│                │
│   $(warning "Clash Verge")  │
│                │
└────────────────┘
----------------------------

$(info "$(sed '1d' <<< "${CLASH_SUBSCRIBE}")")

*******************************************
┌────────────────┐
│                │
│     $(warning "Throne")     │
│                │
└────────────────┘
$(hint "${THRONE_SUBSCRIBE}")

*******************************************
┌────────────────┐
│                │
│    $(warning "Sing-box")    │
│                │
└────────────────┘
----------------------------

$(info "$(echo "{ \"outbounds\":[ ${OUTBOUND_REPLACE%,} ] }" | ${WORK_DIR}/jq)

${PROMPT}

 $(text 72)")
"

  [ "$IS_SUB" = 'is_sub' ] && ! is_strict_multi_user_mode && EXPORT_LIST_FILE+="

*******************************************

$(hint "Index:
$SUBSCRIBE_ADDRESS/${SUBSCRIBE_TOKEN}/

QR code:
$SUBSCRIBE_ADDRESS/${SUBSCRIBE_TOKEN}/qr

V2rayN $(text 80):
$SUBSCRIBE_ADDRESS/${SUBSCRIBE_TOKEN}/v2rayn")

$(hint "Throne $(text 80):
$SUBSCRIBE_ADDRESS/${SUBSCRIBE_TOKEN}/throne")

$(hint "Clash $(text 80):
$SUBSCRIBE_ADDRESS/${SUBSCRIBE_TOKEN}/clash
$SUBSCRIBE_ADDRESS/${SUBSCRIBE_TOKEN}/clash2
$SUBSCRIBE_ADDRESS/${SUBSCRIBE_TOKEN}/clash-campus-free

SFI / SFA / SFM $(text 80):
$SUBSCRIBE_ADDRESS/${SUBSCRIBE_TOKEN}/sing-box

ShadowRocket $(text 80):
$SUBSCRIBE_ADDRESS/${SUBSCRIBE_TOKEN}/shadowrocket")

*******************************************

$(info " $(text 81):
$(text 82) 1:
$SUBSCRIBE_ADDRESS/${SUBSCRIBE_TOKEN}/auto

$(text 82) 2:
$SUBSCRIBE_ADDRESS/${SUBSCRIBE_TOKEN}/auto2

 $(text 80) QRcode:")

$(hint "$(text 82) 1:")
$(${WORK_DIR}/qrencode $SUBSCRIBE_ADDRESS/${SUBSCRIBE_TOKEN}/auto)

$(hint "$(text 82) 2:")
$(${WORK_DIR}/qrencode $SUBSCRIBE_ADDRESS/${SUBSCRIBE_TOKEN}/auto2)
"

  if is_strict_multi_user_mode; then
    EXPORT_LIST_FILE="*******************************************
Hysteria2${PORT_TUIC:+/TUIC} 严格多用户模式已启用。

未创建、未显示公共订阅 URL；基础协议入站只作为本机模板，不能从互联网访问。
若尚未创建用户，请创建第一个用户（其自动成为管理员）：

  sb-user add admin 0

创建成功后，终端会只显示该管理员自己的订阅 URL。可用以下命令查看全部用户与流量：

  sb-user list
  sb-user show admin
*******************************************"
  fi

  # === 流量统计块（仅 clash_api 可用时显示；流量为 0 时显示 0 B） ===
  # downloadTotal / uploadTotal 为 clash_api 提供的进程生命周期累计值
  STATS_JSON=''   # 每次调用 export_list 都是独立的用户请求，强制刷新获取实时数据
  if ensure_stats_data; then
    local IN_SUM OUT_SUM
    IN_SUM=$(echo "$STATS_JSON" | $WORK_DIR/jq '.downloadTotal // 0' 2>/dev/null)
    OUT_SUM=$(echo "$STATS_JSON" | $WORK_DIR/jq '.uploadTotal // 0' 2>/dev/null)
    EXPORT_LIST_FILE="${EXPORT_LIST_FILE}

*******************************************
┌────────────────┐
│                │
│  $(warning "Traffic Stats") │
│                │
└────────────────┘
---------------------------

$(info "⬇ Inbound  (total):  $(format_traffic $IN_SUM)")
$(hint "⬆ Outbound (total):  $(format_traffic $OUT_SUM)")
"
  fi
  # === 结束 ===

  # 生成并显示节点信息
  echo "$EXPORT_LIST_FILE" > ${WORK_DIR}/list
  if is_strict_multi_user_mode; then
    # 模板仅供 root 的 sb-user 使用，Nginx 也不会再公开 /subscribe 路径。
    chmod 700 "${WORK_DIR}/subscribe"
    chmod 600 "${WORK_DIR}/subscribe/proxies" "${WORK_DIR}/subscribe/clash-campus-free" 2>/dev/null || true
  fi
  cat ${WORK_DIR}/list

  # 显示脚本使用情况数据
  statistics_of_run_times get
}

# 创建快捷方式
create_shortcut() {
  cat > ${WORK_DIR}/sb.sh << EOF
#!/usr/bin/env bash

bash <(wget --no-check-certificate -qO- ${SCRIPT_UPDATE_URL}) \$@
EOF
  chmod +x ${WORK_DIR}/sb.sh
  ln -sf ${WORK_DIR}/sb.sh /usr/bin/sb
  [ -s /usr/bin/sb ] && info "\n $(text 71) "
}

# 增加或删除协议
change_protocols() {
  check_install
  [ "${STATUS[0]}" = "$(text 26)" ] && error "\n Sing-box $(text 26) "

  # 检查服务器 IP
  check_system_ip

  # 查找已安装的协议，并遍历其在所有协议列表中的名称，获取协议名后存放在 EXISTED_PROTOCOLS; 没有的协议存放在 NOT_EXISTED_PROTOCOLS
  INSTALLED_PROTOCOLS_LIST=$(awk -F '"' '/"tag":/{print $4}' ${WORK_DIR}/conf/*_inbounds.json 2>/dev/null | grep -v 'shadowtls-in' | awk '{print $NF}')
  for f in ${!NODE_TAG[@]}; do [[ $INSTALLED_PROTOCOLS_LIST =~ "${NODE_TAG[f]}" ]] && EXISTED_PROTOCOLS+=("${PROTOCOL_LIST[f]}") || NOT_EXISTED_PROTOCOLS+=("${PROTOCOL_LIST[f]}"); done

  # 已安装协议为空时不交互删除，直接进入添加
  if [ "${#EXISTED_PROTOCOLS[@]}" -gt 0 ]; then
    # 列出已安装协议（保持原有样式，仅显示协议名；F2 流量显示已移除，见需求文档 3.3 节）
    hint "\n $(text 136) (${#EXISTED_PROTOCOLS[@]})"
    for h in "${!EXISTED_PROTOCOLS[@]}"; do
      hint " $(asc $(( h+97 ))). ${EXISTED_PROTOCOLS[h]} "
    done

    # 从已安装的协议中选择需要删除的协议名，并存放在 REMOVE_PROTOCOLS，把保存的协议的协议存放在 KEEP_PROTOCOLS
    reading "\n $(text 64) " REMOVE_SELECT
    # 统一为小写，去掉重复选项，处理不在可选列表里的选项，把特殊符号处理
    REMOVE_SELECT=$(sed "s/[^a-$(asc $(( ${#EXISTED_PROTOCOLS[@]} + 96 )))]//g" <<< "${REMOVE_SELECT,,}" | awk 'BEGIN{RS=""; FS=""}{delete seen; output=""; for(i=1; i<=NF; i++){ if(!seen[$i]++){ output=output $i } } print output}')

    for ((j=0; j<${#REMOVE_SELECT}; j++)); do
      REMOVE_PROTOCOLS+=("${EXISTED_PROTOCOLS[$(( $(asc "$(awk "NR==$[j+1] {print}" <<< "$(grep -o . <<< "$REMOVE_SELECT")")") - 97 ))]}")
    done

    for k in "${EXISTED_PROTOCOLS[@]}"; do
      [[ ! "${REMOVE_PROTOCOLS[@]}" =~ "$k" ]] && KEEP_PROTOCOLS+=("$k")
    done
  fi

  # 如有未安装的协议，列表显示并选择安装，把增加的协议存在放在 ADD_PROTOCOLS
  if [ "${#NOT_EXISTED_PROTOCOLS[@]}" -gt 0 ]; then
    hint "\n $(text 137) (${#NOT_EXISTED_PROTOCOLS[@]}) "
    for i in "${!NOT_EXISTED_PROTOCOLS[@]}"; do
      hint " $(asc $(( i+97 ))). ${NOT_EXISTED_PROTOCOLS[i]} "
    done
    reading "\n $(text 66) " ADD_SELECT
    # 统一为小写，去掉重复选项，处理不在可选列表里的选项，把特殊符号处理
    ADD_SELECT=$(sed "s/[^a-$(asc $(( ${#NOT_EXISTED_PROTOCOLS[@]} + 96 )))]//g" <<< "${ADD_SELECT,,}" | awk 'BEGIN{RS=""; FS=""}{delete seen; output=""; for(i=1; i<=NF; i++){ if(!seen[$i]++){ output=output $i } } print output}')

    for ((l=0; l<${#ADD_SELECT}; l++)); do
      ADD_PROTOCOLS+=("${NOT_EXISTED_PROTOCOLS[$(( $(asc "$(awk "NR==$[l+1] {print}" <<< "$(grep -o . <<< "$ADD_SELECT")")") - 97 ))]}")
    done
  fi

  # 重新安装 = 保留 + 新增；数量可为 0（协议全删后仅保留基础配置）
  REINSTALL_PROTOCOLS=("${KEEP_PROTOCOLS[@]}" "${ADD_PROTOCOLS[@]}")

  # 显示重新安装的协议列表，并确认是否正确
  hint "\n $(text 138) (${#REINSTALL_PROTOCOLS[@]}) "
  [ "${#KEEP_PROTOCOLS[@]}" -gt 0 ] && hint "\n $(text 74) (${#KEEP_PROTOCOLS[@]}) "
  for r in "${!KEEP_PROTOCOLS[@]}"; do
    hint " $[r+1]. ${KEEP_PROTOCOLS[r]} "
  done

  [ "${#ADD_PROTOCOLS[@]}" -gt 0 ] && hint "\n $(text 75) (${#ADD_PROTOCOLS[@]}) "
  for r in "${!ADD_PROTOCOLS[@]}"; do
    hint " $[r+1]. ${ADD_PROTOCOLS[r]} "
  done

  reading "\n $(text 68) " CONFIRM
  [ "${CONFIRM,,}" = 'n' ] && exit 0

  # 把确认安装的协议遍历所有协议列表的数组，找出其下标并变为英文小写的形式
  for m in "${!REINSTALL_PROTOCOLS[@]}"; do
    for n in "${!PROTOCOL_LIST[@]}"; do
      if [ "${REINSTALL_PROTOCOLS[m]}" = "${PROTOCOL_LIST[n]}" ]; then
        INSTALL_PROTOCOLS+=($(asc $[n+98]))
      fi
    done
  done

  # 获取各节点信息
  fetch_nodes_value

  for v in "${NODE_NAME[@]}"; do
    [ -n "$v" ] && NODE_NAME_CONFIRM="$v" && break
  done

  # 无既有协议（0 协议或全部删除后重新添加）时，像新安装一样询问节点名称；已有节点名称则沿用
  if [ "${#REINSTALL_PROTOCOLS[@]}" -gt 0 ] && [ "${#KEEP_PROTOCOLS[@]}" -eq 0 ]; then
    unset NODE_NAME_CONFIRM
    input_node_name
  fi

  [ "${#WS_SERVER_IP[@]}" -gt 0 ] && WS_SERVER_IP_SHOW=$(awk '{print $1}' <<< "${WS_SERVER_IP[@]}") && CDN=$(awk '{print $1}' <<< "${CDN[@]}")

  # 寻找待删除协议的 inbound 文件名
  for o in "${REMOVE_PROTOCOLS[@]}"; do
    for s in ${!PROTOCOL_LIST[@]}; do
      [ "$o" = "${PROTOCOL_LIST[s]}" ] && REMOVE_FILE+=("${NODE_TAG[s]}_inbounds.json")
    done
  done

  # 如有需要，删除 hysteria2 跳跃端口，待后面添加回来
  [ "$IS_HOPPING" = 'is_hopping' ] && del_port_hopping_nat

  # 删除不需要的协议配置文件
  [ "${#REMOVE_FILE[@]}" -gt 0 ] && for t in "${REMOVE_FILE[@]}"; do
    rm -f ${WORK_DIR}/conf/*${t}
  done

  # 寻找已存在协议中原有的端口号
  for p in "${KEEP_PROTOCOLS[@]}"; do
    for u in "${!PROTOCOL_LIST[@]}"; do
      if [ "$p" = "${PROTOCOL_LIST[u]}" ]; then
        local KEEP_INBOUND_FILE
        KEEP_INBOUND_FILE=$(find "${WORK_DIR}/conf" -maxdepth 1 -type f -name "*${NODE_TAG[u]}_inbounds.json" ! -name '30_sbuser_*' ! -name '31_sbuser_*' -print -quit 2>/dev/null)
        [ -n "$KEEP_INBOUND_FILE" ] && KEEP_PORTS+=("$(awk -F '[:,]' '/listen_port/{gsub(/[[:space:]]/, "", $2); print $2; exit}' "$KEEP_INBOUND_FILE")")
      fi
    done
  done

  # 根据全部协议，找到空余的端口号
  for q in "${!REINSTALL_PROTOCOLS[@]}"; do
    [[ ! ${KEEP_PORTS[@]} =~ $[START_PORT + q] ]] && ADD_PORTS+=($[START_PORT + q])
  done

  # 所有协议的端口号
  REINSTALL_PORTS=(${KEEP_PORTS[@]} ${ADD_PORTS[@]})

  CHECK_PROTOCOLS=b
  # 获取 Reality 端口
  if [[ "${INSTALL_PROTOCOLS[@]}" =~ "$CHECK_PROTOCOLS" ]]; then
    POSITION=$(awk -v target=$CHECK_PROTOCOLS '{ for(i=1; i<=NF; i++) if($i == target) { print i-1; break } }' <<< "${INSTALL_PROTOCOLS[*]}")
    PORT_XTLS_REALITY=${REINSTALL_PORTS[POSITION]}
    NEED_PRIVATE_KEY='need_private_key'
  else
    unset PORT_XTLS_REALITY
  fi

  # 获取 Hysteria2 端口
  CHECK_PROTOCOLS=$(asc "$CHECK_PROTOCOLS" ++)
  if [[ "${INSTALL_PROTOCOLS[@]}" =~ "$CHECK_PROTOCOLS" ]]; then
    POSITION=$(awk -v target=$CHECK_PROTOCOLS '{ for(i=1; i<=NF; i++) if($i == target) { print i-1; break } }' <<< "${INSTALL_PROTOCOLS[*]}")
    PORT_HYSTERIA2=${REINSTALL_PORTS[POSITION]}
    if [[ " ${ADD_PROTOCOLS[*]} " =~ " ${PROTOCOL_LIST[1]} " ]] && [ -z "$IS_HY2_REALM" ]; then
      input_hy2_realm
    fi
    [ -z "${PORT_HOPPING_START}${PORT_HOPPING_END}" ] && [ "$IS_HY2_REALM" != 'is_hy2_realm' ] && input_hopping_port
  else
    unset PORT_HYSTERIA2 IS_HY2_REALM IS_HY2_WARP HY2_REALM_ID
  fi

  # 获取 Tuic V5 端口
  CHECK_PROTOCOLS=$(asc "$CHECK_PROTOCOLS" ++)
  if [[ "${INSTALL_PROTOCOLS[@]}" =~ "$CHECK_PROTOCOLS" ]]; then
    POSITION=$(awk -v target=$CHECK_PROTOCOLS '{ for(i=1; i<=NF; i++) if($i == target) { print i-1; break } }' <<< "${INSTALL_PROTOCOLS[*]}")
    PORT_TUIC=${REINSTALL_PORTS[POSITION]}
  else
    unset PORT_TUIC
  fi

  # 获取 ShadowTLS 端口
  CHECK_PROTOCOLS=$(asc "$CHECK_PROTOCOLS" ++)
  if [[ "${INSTALL_PROTOCOLS[@]}" =~ "$CHECK_PROTOCOLS" ]]; then
    POSITION=$(awk -v target=$CHECK_PROTOCOLS '{ for(i=1; i<=NF; i++) if($i == target) { print i-1; break } }' <<< "${INSTALL_PROTOCOLS[*]}")
    PORT_SHADOWTLS=${REINSTALL_PORTS[POSITION]}
  fi

  # 获取 Shadowsocks 端口
  CHECK_PROTOCOLS=$(asc "$CHECK_PROTOCOLS" ++)
  if [[ "${INSTALL_PROTOCOLS[@]}" =~ "$CHECK_PROTOCOLS" ]]; then
    POSITION=$(awk -v target=$CHECK_PROTOCOLS '{ for(i=1; i<=NF; i++) if($i == target) { print i-1; break } }' <<< "${INSTALL_PROTOCOLS[*]}")
    PORT_SHADOWSOCKS=${REINSTALL_PORTS[POSITION]}
  else
    unset PORT_SHADOWSOCKS
  fi

  # 获取 Trojan 端口
  CHECK_PROTOCOLS=$(asc "$CHECK_PROTOCOLS" ++)
  if [[ "${INSTALL_PROTOCOLS[@]}" =~ "$CHECK_PROTOCOLS" ]]; then
    POSITION=$(awk -v target=$CHECK_PROTOCOLS '{ for(i=1; i<=NF; i++) if($i == target) { print i-1; break } }' <<< "${INSTALL_PROTOCOLS[*]}")
    PORT_TROJAN=${REINSTALL_PORTS[POSITION]}
  else
    unset PORT_TROJAN
  fi

  # 获取 ws 的 argo 或者 origin 状态
  if [ -s ${ARGO_DAEMON_FILE} ]; then
    local ARGO_ORIGIN_RULES_STATUS=is_argo
    [ "$SYSTEM" = 'Alpine' ] && ARGO_RUNS="$(sed -n 's/command="\(.*\)"/\1/gp' $ARGO_DAEMON_FILE) $(sed -n 's/command_args="\(.*\)"/\1/gp' $ARGO_DAEMON_FILE)" || ARGO_RUNS=$(sed -n "s/^ExecStart=\(.*\)/\1/gp" ${ARGO_DAEMON_FILE})
  elif ls ${WORK_DIR}/conf/*-ws*inbounds.json >/dev/null 2>&1; then
    local ARGO_ORIGIN_RULES_STATUS=is_origin
  else
    local ARGO_ORIGIN_RULES_STATUS=no_argo_no_origin
  fi

  # 获取 vmess + ws 配置信息
  CHECK_PROTOCOLS=$(asc "$CHECK_PROTOCOLS" ++)
  if [[ "${INSTALL_PROTOCOLS[@]}" =~ "$CHECK_PROTOCOLS" ]]; then
    local DOMAIN_ERROR_TIME=5
    if [[ "$ARGO_READY" != 'argo_ready' || "$ORIGIN_READY" != 'origin_ready' ]]; then
      if [ "$ARGO_ORIGIN_RULES_STATUS" = 'is_origin' ]; then
        until [ -n "$VMESS_HOST_DOMAIN" ]; do
          (( DOMAIN_ERROR_TIME-- )) || true
          [ "$DOMAIN_ERROR_TIME" != 0 ] && TYPE=VMESS && reading "\n $(text 50) " VMESS_HOST_DOMAIN || error "\n $(text 3) \n"
        done
      elif [ "$ARGO_ORIGIN_RULES_STATUS" = 'no_argo_no_origin' ]; then
        [ -z "$ARGO_OR_ORIGIN_RULES" ] && hint "\n $(text 57) " && reading "\n $(text 24) " ARGO_OR_ORIGIN_RULES
        [ "$ARGO_OR_ORIGIN_RULES" != '2' ] && ARGO_OR_ORIGIN_RULES=1 && IS_ARGO=is_argo || IS_ARGO=no_argo
        if [ "$IS_ARGO" = 'is_argo' ]; then
          # 如果原来没有 nginx 配置，需要获取 nginx 端口信息
          [ -z "$PORT_NGINX"  ] && input_nginx_port
          until [ -n "$ARGO_RUNS" ]; do
            input_argo_auth is_add_protocols
            [ -n "$ARGO_RUNS" ] && local ARGO_READY=argo_ready && break
          done
        else
          until [ -n "$VMESS_HOST_DOMAIN" ]; do
            (( DOMAIN_ERROR_TIME-- )) || true
            [ "$DOMAIN_ERROR_TIME" != 0 ] && TYPE=VMESS && reading "\n $(text 50) " VMESS_HOST_DOMAIN || error "\n $(text 3) \n"
          done
          local ORIGIN_READY=origin_ready
        fi
      fi
    fi
    POSITION=$(awk -v target=$CHECK_PROTOCOLS '{ for(i=1; i<=NF; i++) if($i == target) { print i-1; break } }' <<< "${INSTALL_PROTOCOLS[*]}")
    PORT_VMESS_WS=${REINSTALL_PORTS[POSITION]}
  else
    unset PORT_VMESS_WS
  fi

  # 获取 vless + ws + tls 配置信息
  CHECK_PROTOCOLS=$(asc "$CHECK_PROTOCOLS" ++)
  if [[ "${INSTALL_PROTOCOLS[@]}" =~ "$CHECK_PROTOCOLS" ]]; then
    local DOMAIN_ERROR_TIME=5
    if [[ "$ARGO_READY" != 'argo_ready' || "$ORIGIN_READY" != 'origin_ready' ]]; then
      if [ "$ARGO_ORIGIN_RULES_STATUS" = 'is_origin' ]; then
        until [ -n "$VLESS_HOST_DOMAIN" ]; do
          (( DOMAIN_ERROR_TIME-- )) || true
          [ "$DOMAIN_ERROR_TIME" != 0 ] && TYPE=VLESS && reading "\n $(text 50) " VLESS_HOST_DOMAIN || error "\n $(text   3) \n"
        done
      elif [ "$ARGO_ORIGIN_RULES_STATUS" = 'no_argo_no_origin' ]; then
        [ -z "$ARGO_OR_ORIGIN_RULES" ] && hint "\n $(text 57) " && reading "\n $(text 24) " ARGO_OR_ORIGIN_RULES
        [ "$ARGO_OR_ORIGIN_RULES" != '2' ] && ARGO_OR_ORIGIN_RULES=1 && IS_ARGO=is_argo || IS_ARGO=no_argo
        if [ "$IS_ARGO" = 'is_argo' ]; then
           # 如果原来没有 nginx 配置，需要获取 nginx 端口信息
          [ -z "$PORT_NGINX"  ] && input_nginx_port
          until [ -n "$ARGO_RUNS" ]; do
            [ "$ARGO_READY" != 'argo_ready' ] && input_argo_auth is_add_protocols
            [ -n "$ARGO_RUNS" ] && local ARGO_READY=argo_ready && break
          done
        else
          until [ -n "$VLESS_HOST_DOMAIN" ]; do
            (( DOMAIN_ERROR_TIME-- )) || true
            [ "$DOMAIN_ERROR_TIME" != 0 ] && TYPE=VLESS && reading "\n $(text 50) " VLESS_HOST_DOMAIN || error "\n $(text   3) \n"
          done
          local ORIGIN_READY=origin_ready
        fi
      fi
    fi
    POSITION=$(awk -v target=$CHECK_PROTOCOLS '{ for(i=1; i<=NF; i++) if($i == target) { print i-1; break } }' <<< "${INSTALL_PROTOCOLS[*]}")
    PORT_VLESS_WS=${REINSTALL_PORTS[POSITION]}
  else
    unset PORT_VLESS_WS
  fi

  # 如之前没有 ws，现新增的 ws，则确认服务器 IP 和输入 cdn
  if [[ "${#CDN[@]}" = '0' && ( "$ARGO_READY" = 'argo_ready' || "$ORIGIN_READY" = 'origin_ready' ) ]]; then
    if grep -qi 'cloudflare' <<< "$ASNORG4$ASNORG6"; then
      if grep -qi 'cloudflare' <<< "$ASNORG6" && [ -n "$WAN4" ] && ! grep -qi 'cloudflare' <<< "$ASNORG4"; then
        SERVER_IP_DEFAULT=$WAN4
      elif grep -qi 'cloudflare' <<< "$ASNORG4" && [ -n "$WAN6" ] && ! grep -qi 'cloudflare' <<< "$ASNORG6"; then
        SERVER_IP_DEFAULT=$WAN6
      else
        local a=6
        until [ -n "$SERVER_IP" ]; do
          ((a--)) || true
          [ "$a" = 0 ] && error "\n $(text 3) \n"
          reading "\n $(text 46) " SERVER_IP
        done
      fi
    elif [ -n "$WAN4" ]; then
      SERVER_IP_DEFAULT=$WAN4
    elif [ -n "$WAN6" ]; then
      SERVER_IP_DEFAULT=$WAN6
    fi

    # 输入服务器 IP,默认为检测到的服务器 IP，如果全部为空，则提示并退出脚本
    [ -z "$SERVER_IP" ] && reading "\n $(text 10) " SERVER_IP
    SERVER_IP=${SERVER_IP:-"$SERVER_IP_DEFAULT"} && WS_SERVER_IP_SHOW=$SERVER_IP
    [ -z "$SERVER_IP" ] && error " $(text 47) "

    input_cdn
  fi

  # 获取 H2 + Reality 端口
  CHECK_PROTOCOLS=$(asc "$CHECK_PROTOCOLS" ++)
  if [[ "${INSTALL_PROTOCOLS[@]}" =~ "$CHECK_PROTOCOLS" ]]; then
    POSITION=$(awk -v target=$CHECK_PROTOCOLS '{ for(i=1; i<=NF; i++) if($i == target) { print i-1; break } }' <<< "${INSTALL_PROTOCOLS[*]}")
    PORT_H2_REALITY=${REINSTALL_PORTS[POSITION]}
    NEED_PRIVATE_KEY='need_private_key'
  else
    unset PORT_H2_REALITY
  fi

  # 获取 gRPC + Reality 端口
  CHECK_PROTOCOLS=$(asc "$CHECK_PROTOCOLS" ++)
  if [[ "${INSTALL_PROTOCOLS[@]}" =~ "$CHECK_PROTOCOLS" ]]; then
    POSITION=$(awk -v target=$CHECK_PROTOCOLS '{ for(i=1; i<=NF; i++) if($i == target) { print i-1; break } }' <<< "${INSTALL_PROTOCOLS[*]}")
    PORT_GRPC_REALITY=${REINSTALL_PORTS[POSITION]}
    NEED_PRIVATE_KEY='need_private_key'
  else
    unset PORT_GRPC_REALITY
  fi

  # 如之前没有 Reality，现新增的 reality，则确认 privateKey
  [[ "${#REALITY_PRIVATE[@]}" = 0 && "${NEED_PRIVATE_KEY}" = 'need_private_key' ]] && input_reality_key

  # 让 ShadowTLS 和 shadowsocks 密码相同
  if [[ -n "$SHADOWTLS_PASSWORD" && -z "$SHADOWSOCKS_PASSWORD" ]]; then
    SIP022_PASSWORD=$SHADOWTLS_PASSWORD
  elif [[ -z "$SHADOWTLS_PASSWORD" && -n "$SHADOWSOCKS_PASSWORD" ]]; then
    SIP022_PASSWORD=$SHADOWSOCKS_PASSWORD
  fi

  # 获取 anytls 端口
  CHECK_PROTOCOLS=$(asc "$CHECK_PROTOCOLS" ++)
  if [[ "${INSTALL_PROTOCOLS[@]}" =~ "$CHECK_PROTOCOLS" ]]; then
    POSITION=$(awk -v target=$CHECK_PROTOCOLS '{ for(i=1; i<=NF; i++) if($i == target) { print i-1; break } }' <<< "${INSTALL_PROTOCOLS[*]}")
    PORT_ANYTLS=${REINSTALL_PORTS[POSITION]}
  else
    unset PORT_ANYTLS
  fi

  # 获取 naive 端口
  CHECK_PROTOCOLS=$(asc "$CHECK_PROTOCOLS" ++)
  if [[ "${INSTALL_PROTOCOLS[@]}" =~ "$CHECK_PROTOCOLS" ]]; then
    POSITION=$(awk -v target=$CHECK_PROTOCOLS '{ for(i=1; i<=NF; i++) if($i == target) { print i-1; break } }' <<< "${INSTALL_PROTOCOLS[*]}")
    PORT_NAIVE=${REINSTALL_PORTS[POSITION]}
  else
    unset PORT_NAIVE
  fi

  # 生成各协议的 json 文件
  sing-box_json change

  # 无 ws 协议且无订阅时清理 nginx：先于守护文件生成，确保 ExecStartPre / start_pre 与最终状态一致
  if ! ls ${WORK_DIR}/conf/*-ws*inbounds.json >/dev/null 2>&1 && [[ -s ${WORK_DIR}/nginx.conf && "$IS_SUB" = 'no_sub' ]]; then
    nginx_stop
    rm -f ${WORK_DIR}/nginx.conf
    unset PORT_NGINX
  fi

  # 生成 Nginx 配置文件（按最终状态）
  [ -n "$PORT_NGINX" ] && export_nginx_conf_file

  # 重新生成 Sing-box 守护进程文件
  sing-box_systemd

  # 如有需要，安装和删除 Argo 服务
  if ls ${WORK_DIR}/conf/*-ws*inbounds.json >/dev/null 2>&1; then
    if [[ "$ARGO_OR_ORIGIN_RULES" != '2' && "$ARGO_ORIGIN_RULES_STATUS" != 'is_origin' && ! -s ${ARGO_DAEMON_FILE} ]]; then
      argo_systemd
      cmd_systemctl enable argo >/dev/null 2>&1
    fi
  elif [ -s ${ARGO_DAEMON_FILE} ]; then
    # 无 ws 协议：固定隧道（token/json）保留 argo；临时隧道删除
    if [[ "$ARGO_TYPE" != 'is_token_argo' && "$ARGO_TYPE" != 'is_json_argo' ]]; then
      cmd_systemctl disable argo >/dev/null 2>&1
      rm -f ${ARGO_DAEMON_FILE}
      [ -s ${WORK_DIR}/tunnel.json ] && rm -f ${WORK_DIR}/tunnel.*
    fi
  fi

  # 热更 sing-box（SIGHUP 重新加载配置，PID 不变）
  cmd_systemctl reload sing-box

  # 同步 nginx 进程：需要则启动/热重载，不需要则停止
  nginx_sync

  # 打开防火墙相关端口
  sync_firewall_rules

  # 等待服务启动
  sleep 3

  # 再次检测状态，运行 sing-box
  check_install

  # 导出节点和订阅服务信息
  export_list
}

# 卸载 sing-box 全家桶
uninstall() {
  if [ -d ${WORK_DIR} ]; then
    if command -v systemctl >/dev/null 2>&1; then
      systemctl disable --now sb-user-collect.timer >/dev/null 2>&1 || true
      systemctl disable --now sb-user-web.service >/dev/null 2>&1 || true
    fi
    [ -x /usr/bin/sb-user ] && /usr/bin/sb-user cleanup >/dev/null 2>&1 || true
    rm -f /etc/systemd/system/sb-user-collect.service /etc/systemd/system/sb-user-collect.timer /etc/systemd/system/sb-user-web.service /usr/bin/sb-user
    command -v systemctl >/dev/null 2>&1 && systemctl daemon-reload >/dev/null 2>&1 || true
    [ -s ${ARGO_DAEMON_FILE} ] && cmd_systemctl disable argo &>/dev/null
    [ -s ${SINGBOX_DAEMON_FILE} ] && cmd_systemctl disable sing-box &>/dev/null
    nginx_stop
    sleep 1
    [[ -s ${WORK_DIR}/nginx.conf && "$(ps -ef | grep -c '[n]ginx')" = 0 ]] && reading "\n $(text 83) " REMOVE_NGINX
    [ "${REMOVE_NGINX,,}" = 'y' ] && ${PACKAGE_UNINSTALL[int]} nginx >/dev/null 2>&1
    purge_service_firewall_rules
    del_port_hopping_nat >/dev/null 2>&1 || true
    rm -rf ${WORK_DIR} ${TEMP_DIR} ${ARGO_DAEMON_FILE} ${SINGBOX_DAEMON_FILE} /usr/bin/sb
    info "\n $(text 16) \n"
  else
    error "\n $(text 15) \n"
  fi
}


# Sing-box 的最新版本
version() {
  # 获取需要下载的 sing-box 版本
  local ONLINE=$(get_sing_box_version)

  grep -q '.' <<< "$ONLINE" || error " $(text 100) \n"
  local LOCAL=$(${WORK_DIR}/sing-box version | awk '/version/{print $NF}')
  info "\n $(text 40) "
  [[ -n "$ONLINE" && "$ONLINE" != "$LOCAL" ]] && reading "\n $(text 9) " UPDATE || info " $(text 41) "

  if [ "${UPDATE,,}" = 'y' ]; then
    check_system_info
    wget --no-check-certificate --continue ${GH_PROXY}https://github.com/SagerNet/sing-box/releases/download/v$ONLINE/sing-box-$ONLINE-linux-$SING_BOX_ARCH.tar.gz -qO- | tar xz -C $TEMP_DIR sing-box-$ONLINE-linux-$SING_BOX_ARCH/sing-box

    [ -s $TEMP_DIR/sing-box-$ONLINE-linux-$SING_BOX_ARCH/sing-box ] || error "\n $(text 42) \n"
    if ! $TEMP_DIR/sing-box-$ONLINE-linux-$SING_BOX_ARCH/sing-box check -C ${WORK_DIR}/conf >/dev/null; then
      warning "\n $(text 54) " && reading "\n $(text 111) " UPDATE_CONFIG
      [ "${UPDATE_CONFIG,,}" = 'n' ] && exit 1

      # 设置基础配置参数 dns.servers.prefer_go 和 dns.strategy
      local STRATEGY=$(grep -E --exclude="03_route.json" 'ipv4_only|ipv6_only|prefer_ipv4|prefer_ipv6' ${WORK_DIR}/conf/0*.json | awk -F '"' '{print $(NF-1); exit}')
      STRATEGY=${STRATEGY:-prefer_ipv4}
      command -v systemctl >/dev/null 2>&1 && systemctl is-active --quiet systemd-resolved && local IS_PREFER_GO=false || local IS_PREFER_GO=true

      # 备份旧基础配置
      for i in $(ls ${WORK_DIR}/conf/0*); do
        cp $i ${i}.bak
      done
      generate_sing_box_base_conf

      if ! $TEMP_DIR/sing-box-$ONLINE-linux-$SING_BOX_ARCH/sing-box check -C ${WORK_DIR}/conf >/dev/null; then
        for i in $(ls ${WORK_DIR}/conf/0*.bak); do
          mv $i ${i%%.bak}
        done
        error "\n $(text 101) \n"
      fi
    fi

    cmd_systemctl disable sing-box

    # 备份旧版本
    cp ${WORK_DIR}/sing-box ${WORK_DIR}/sing-box.bak
    hint "\n $(text 102) \n"

    # 安装新版本
    chmod +x $TEMP_DIR/sing-box-$ONLINE-linux-$SING_BOX_ARCH/sing-box && mv $TEMP_DIR/sing-box-$ONLINE-linux-$SING_BOX_ARCH/sing-box ${WORK_DIR}/sing-box
    cmd_systemctl enable sing-box
    sleep 2

    # 检查新版本是否成功运行
    if cmd_systemctl status sing-box &>/dev/null; then
      # 新版本运行成功，删除备份
      rm -f ${WORK_DIR}/sing-box.bak ${WORK_DIR}/conf/*.bak
      info "\n $(text 103) \n"
    else
      # 新版本运行失败，恢复旧版本
      warning "\n $(text 104) \n"
      mv ${WORK_DIR}/sing-box.bak ${WORK_DIR}/sing-box
      rm -f ${WORK_DIR}/conf/*.bak
      cmd_systemctl enable sing-box
      sleep 2

      cmd_systemctl status sing-box &>/dev/null && info "\n $(text 105) \n" || error "\n $(text 106) \n"
    fi
  fi
}

# 判断当前 Sing-box 的运行状态，并对应的给菜单和动作赋值
# 双协议专用极速安装：只启用 Hysteria2 + TUIC 和严格多用户订阅。
# 为避免共享入站、端口冲突和额外依赖，快装模式不启用 Argo、Realm、WARP 打洞或端口跳跃。
quick_install_hy2_tuic() {
  IS_FAST_INSTALL='is_fast_install'
  CHOOSE_PROTOCOLS='cd'
  START_PORT=${START_PORT:-"$START_PORT_DEFAULT"}
  CDN=${CDN:-"${CDN_DOMAIN[0]}"}
  IS_SUB='is_sub'
  IS_ARGO='no_argo'
  IS_HOPPING='no_hopping'
  unset HY2_PORT_HOPPING_RANGE PORT_HOPPING_START PORT_HOPPING_END
  unset IS_HY2_REALM IS_HY2_WARP HY2_REALM_ID

  # 快装只用于全新部署。若调用路径绕过了入口检查，也必须先备份并移除旧安装，
  # 绝不在旧目录上局部覆盖配置，避免旧节点、旧服务和端口规则互相冲突。
  has_existing_singbox_installation && prepare_clean_reinstall

  install_sing-box
  export_list install
  create_shortcut
}


menu_setting() {
  if [[ "${STATUS[0]}" =~ $(text 27)|$(text 28) ]]; then
    OPTION[1]="1 .  $(text 29)"
    [ "${STATUS[0]}" = "$(text 28)" ] && OPTION[2]="2 .  $(text 27) Sing-box (sb -s)" || OPTION[2]="2 .  $(text 28) Sing-box (sb -s)"
    [ "${STATUS[1]}" = "$(text 28)" ] && OPTION[3]="3 .  $(text 27) Argo (sb -a)" || OPTION[3]="3 .  $(text 28) Argo (sb -a)"
    OPTION[4]="4 .  $(text 92)"
    OPTION[5]="5 .  $(text 121)"
    OPTION[6]="6 .  $(text 31)"
    OPTION[7]="7 .  $(text 32)"
    OPTION[8]="8 .  $(text 62)"
    OPTION[9]="9 .  $(text 33)"
    OPTION[10]="10.  $(text 59)"
    OPTION[11]="11.  $(text 69)"
    OPTION[12]="12.  $(text 76)"

    ACTION[1]() { export_list; exit 0; }

    [ "${STATUS[0]}" = "$(text 28)" ] &&
    ACTION[2]() {
      cmd_systemctl disable sing-box
      cmd_systemctl status sing-box &>/dev/null && error " Sing-box $(text 27) $(text 38) " || info " Sing-box $(text 27) $(text 37)"
    } ||
    ACTION[2]() {
      cmd_systemctl enable sing-box
      sleep 2
      cmd_systemctl status sing-box &>/dev/null && info " Sing-box $(text 28) $(text 37)" || error " Sing-box $(text 28) $(text 38) "
    }

    [ "${STATUS[1]}" = "$(text 28)" ] &&
    ACTION[3]() {
      cmd_systemctl disable argo
      cmd_systemctl status argo &>/dev/null && error " Argo $(text 27) $(text 38) " || info " Argo $(text 27) $(text 37)"
    } ||
    ACTION[3]() {
      cmd_systemctl enable argo
      sleep 2
      cmd_systemctl status argo &>/dev/null &&  info " Argo $(text 28) $(text 37)" || error " Argo $(text 28) $(text 38) "
      grep -qs '\--url' ${ARGO_DAEMON_FILE} && fetch_quicktunnel_domain && export_list
    }

    ACTION[4]() { change_argo; exit; }
    ACTION[5]() { change_config; exit; }
    ACTION[6]() { version; exit; }
    ACTION[7]() { bash <(wget --no-check-certificate -qO- ${GH_PROXY}https://raw.githubusercontent.com/ylx2016/Linux-NetSpeed/master/tcp.sh); exit; }
    ACTION[8]() { change_protocols; exit; }
    ACTION[9]() { uninstall; exit; }
    ACTION[10]() { bash <(wget --no-check-certificate -qO- ${GH_PROXY}https://raw.githubusercontent.com/fscarmen/argox/main/argox.sh) -$L; exit; }
    ACTION[11]() { bash <(wget --no-check-certificate -qO- ${GH_PROXY}https://raw.githubusercontent.com/fscarmen/sba/main/sba.sh) -$L; exit; }
    ACTION[12]() { bash <(wget --no-check-certificate -qO- https://tcp.hy2.sh/); exit; }
  else
    OPTION[1]="1.  $(text 115)"
    OPTION[2]="2.  $(text 34) + Argo + $(text 80) $(text 89)"
    OPTION[3]="3.  $(text 34) + Argo $(text 89)"
    OPTION[4]="4.  $(text 34) + $(text 80) $(text 89)"
    OPTION[5]="5.  $(text 34)"
    OPTION[6]="6.  $(text 32)"
    OPTION[7]="7.  $(text 59)"
    OPTION[8]="8.  $(text 69)"
    OPTION[9]="9.  $(text 76)"

    ACTION[1]() { quick_install_hy2_tuic; exit; }
    ACTION[2]() { IS_SUB=is_sub; IS_ARGO=is_argo; install_sing-box; export_list install; create_shortcut; exit; }
    ACTION[3]() { IS_SUB=no_sub; IS_ARGO=is_argo; install_sing-box; export_list install; create_shortcut; exit; }
    ACTION[4]() { IS_SUB=is_sub; IS_ARGO=no_argo; install_sing-box; export_list install; create_shortcut; exit; }
    ACTION[5]() { install_sing-box; export_list install; create_shortcut; exit; }
    ACTION[6]() { bash <(wget --no-check-certificate -qO- ${GH_PROXY}https://raw.githubusercontent.com/ylx2016/Linux-NetSpeed/master/tcp.sh); exit; }
    ACTION[7]() { bash <(wget --no-check-certificate -qO- ${GH_PROXY}https://raw.githubusercontent.com/fscarmen/argox/main/argox.sh) -$L; exit; }
    ACTION[8]() { bash <(wget --no-check-certificate -qO- ${GH_PROXY}https://raw.githubusercontent.com/fscarmen/sba/main/sba.sh) -$L; exit; }
    ACTION[9]() { bash <(wget --no-check-certificate -qO- ${GH_PROXY}https://tcp.hy2.sh/); exit; }
  fi

  [ "${#OPTION[@]}" -ge '10' ] && OPTION[0]="0 .  $(text 35)" || OPTION[0]="0.  $(text 35)"
  ACTION[0]() { exit; }
}

menu() {
  clear
  echo -e "======================================================================================================================\n"
  info " $(text 17): $VERSION\n $(text 18): $(text 1)\n $(text 19):\n\t $(text 20): $SYS\n\t $(text 21): $(uname -r)\n\t $(text 22): $SING_BOX_ARCH\n\t $(text 23): $VIRT "
  info "\t IPv4: $WAN4 $WARPSTATUS4 $COUNTRY4  $ASNORG4 "
  if [ -n "$WAN6" ]; then
    info "\t IPv6: $WAN6 $WARPSTATUS6 $COUNTRY6  $ASNORG6 "
  elif [ -n "$STATIC_IPV6" ]; then
    info "\t $(text 190) $STATIC_IPV6 "
  fi
  # 对齐显示：中文双宽字符按字符数补空格，英文按最长状态词 "Not install"(11字符) 定宽
  _sv() {
    local s="$1"
    if [ "$L" = 'C' ]; then
      [ "${#s}" -le 2 ] && printf '%s  ' "$s" || printf '%s' "$s"
    else
      printf '%-11s' "$s"
    fi
  }
  local SBV; printf -v SBV '%-26s' "$SING_BOX_VERSION"
  local AV;  printf -v AV  '%-26s' "$ARGO_VERSION"
  local NV;  printf -v NV  '%-26s' "$NGINX_VERSION"
  # === 计算 Sing-box 行流量（仅数据可用时显示；流量为 0 时显示 0 B） ===
  # downloadTotal / uploadTotal 为 clash_api 提供的进程生命周期累计值
  local SB_TRAFFIC=""
  if ensure_stats_data 2>/dev/null; then
    local IN_SUM OUT_SUM
    IN_SUM=$(echo "$STATS_JSON" | $WORK_DIR/jq '.downloadTotal // 0' 2>/dev/null)
    OUT_SUM=$(echo "$STATS_JSON" | $WORK_DIR/jq '.uploadTotal // 0' 2>/dev/null)
    SB_TRAFFIC="  ⬇$(format_traffic $IN_SUM) ⬆$(format_traffic $OUT_SUM)"
  fi
  # === 结束 ===
  info "\t Sing-box: $(_sv "${STATUS[0]}")  ${SBV}${SING_BOX_MEMORY_USAGE}${SB_TRAFFIC}"
  info "\t Argo:     $(_sv "${STATUS[1]}")  ${AV}${ARGO_MEMORY_USAGE}"
  info "\t Nginx:    $(_sv "${STATUS[2]}")  ${NV}${NGINX_MEMORY_USAGE}"
  echo -e "\n======================================================================================================================\n"
  for ((b=1;b<=${#OPTION[*]};b++)); do [ "$b" = "${#OPTION[*]}" ] && hint " ${OPTION[0]} " || hint " ${OPTION[b]} "; done
  reading "\n $(text 24) " CHOOSE

  # 输入必须是数字且少于等于最大可选项
  if grep -qE "^[0-9]{1,2}$" <<< "$CHOOSE" && [ "$CHOOSE" -lt "${#OPTION[*]}" ]; then
    ACTION[$CHOOSE]
  else
    warning " $(text 36) [0-$((${#OPTION[*]}-1))] " && sleep 1 && menu
  fi
}

check_cdn
statistics_of_run_times update sing-box.sh 2>/dev/null

###### 为了给旧版本 04_experimental.json 补全 clash_api 配置并剥离 v2ray_api，将于 2026年12月31日移除
if [ -x "$WORK_DIR/jq" ] && [ -s "$WORK_DIR/conf/04_experimental.json" ] && [ -x "$WORK_DIR/sing-box" ] && [[ "$(date +%Y%m%d)" < "20261231" ]]; then
  # 旧版本 04_experimental.json 可能缺 clash_api、或含 v2ray_api（旧版脚本注入的）。
  # clash_api 是官方 release 二进制默认编译功能（with_clash_api），直接补全；
  # v2ray_api 官方 release 二进制默认不编译，残留会导致启动失败，必须剥离。
  if ! grep -q 'clash_api' "$WORK_DIR/conf/04_experimental.json" || grep -q 'v2ray_api' "$WORK_DIR/conf/04_experimental.json"; then
    API_PORT=$(find_free_api_port)
    if grep -q 'clash_api' "$WORK_DIR/conf/04_experimental.json"; then
      # 已有 clash_api（可能由新版脚本生成），仅剥离残留的 v2ray_api
      grep -v '^//' "$WORK_DIR/conf/04_experimental.json" | $WORK_DIR/jq 'del(.experimental.v2ray_api)' > "$TEMP_DIR/exp_clash_api_tmp.json" 2>/dev/null
    else
      # 缺失 clash_api，剥离 v2ray_api 并补全 clash_api
      grep -v '^//' "$WORK_DIR/conf/04_experimental.json" | $WORK_DIR/jq --arg ec "127.0.0.1:${API_PORT}" '
        del(.experimental.v2ray_api) | .experimental += {
          "clash_api": { "external_controller": $ec }
        }
      ' > "$TEMP_DIR/exp_clash_api_tmp.json" 2>/dev/null
    fi
    [ -s "$TEMP_DIR/exp_clash_api_tmp.json" ] && mv "$TEMP_DIR/exp_clash_api_tmp.json" "$WORK_DIR/conf/04_experimental.json" && {
      # 修改了 experimental 配置，用 SIGHUP 热加载使 API 监听生效（PID 不变，SSH 连接不断）。
      # 此处在 check_system_info() 之前（SYSTEM 未设置）且 select_language() 之前（L 未设置），
      # 注意：不能调用 cmd_systemctl reload——其成功分支会调用 info/text（nameref 依赖 L），
      # 与 Alpine 分支直接 kill -HUP 对称。前台同步执行确保信号送达（SIGHUP 不断连 SSH）。
      if [ -d /run/openrc ] || command -v rc-service >/dev/null 2>&1; then
        # Alpine：kill -HUP 主进程（与 cmd_systemctl reload 的 Alpine 分支一致）；PID 不存在时降级 restart。
        SB_PID=$(cat /var/run/sing-box.pid 2>/dev/null)
        if [ -n "$SB_PID" ] && kill -0 "$SB_PID" 2>/dev/null; then
          kill -HUP "$SB_PID" 2>/dev/null
        else
          rc-service sing-box restart >/dev/null 2>&1
        fi
      else
        # systemd 等：复刻 cmd_systemctl reload 的 systemd 分支（SIGHUP 热加载）；PID 不存在时降级 restart。
        SB_MAINPID=$(systemctl show -p MainPID sing-box 2>/dev/null | awk -F= '{print $2}')
        if [ -n "$SB_MAINPID" ] && [ "$SB_MAINPID" -gt 0 ] 2>/dev/null; then
          systemctl kill -s HUP sing-box >/dev/null 2>&1
        else
          systemctl restart sing-box >/dev/null 2>&1
        fi
        unset SB_MAINPID
      fi
    }
  fi
fi

###### 为了把原来的 nekobox 换成 Throne 做的处理，将于 2026年9月30日移除
if [ -s $WORK_DIR/nginx.conf ] && grep -q 'Neko|Throne' $WORK_DIR/nginx.conf; then
  sed -i 's@~\*Neko|Throne.*@~*Throne|Neko              /throne;         # 匹配 Throne / Neko 客户端@g' "$WORK_DIR/nginx.conf"
  [ -s $WORK_DIR/subscribe/neko ] && rm -f $WORK_DIR/subscribe/neko
  cmd_systemctl restart sing-box
  export_list >/dev/null 2>&1
fi

# 传参
[[ "${*^^}" =~ '-E'|'-K' ]] && L=E
[[ "${*^^}" =~ '-C'|'-B'|'-L' ]] && L=C
# 支持在 select_language 前识别 --LANGUAGE，避免 KV 无交互安装仍弹出语言选择。
for ((PARAM_I=1; PARAM_I<=$#; PARAM_I++)); do
  eval "PARAM_V=\${${PARAM_I}}"
  case "${PARAM_V^^}" in
    --LANGUAGE )
      PARAM_N=$((PARAM_I+1))
      eval "PARAM_LANG=\${${PARAM_N}}"
      [[ "${PARAM_LANG^^}" =~ ^C ]] && L=C || L=E
      ;;
    --LANGUAGE=* )
      PARAM_LANG="${PARAM_V#*=}"
      [[ "${PARAM_LANG^^}" =~ ^C ]] && L=C || L=E
      ;;
  esac
done
unset PARAM_I PARAM_V PARAM_N PARAM_LANG

# 获取 -F 参数的值
CONFIG_FILE=$(awk '-F[ =]' 'tolower($1) ~ /^-f$/{print $2}' <<< "$*")
if [[ -n "$CONFIG_FILE" && -s "$CONFIG_FILE" ]]; then
  NONINTERACTIVE_INSTALL=noninteractive_install
  . $CONFIG_FILE
  L=${LANGUAGE^^}
  [ "$ARGO" = 'true' ] && IS_ARGO=is_argo || IS_ARGO=no_argo
  [ "$SUBSCRIBE" = 'true' ] && IS_SUB=is_sub || IS_SUB=no_sub
fi

check_root
select_language
check_system_info
check_brutal

# 可以是 Key Value 或者 Key=Value 的形式。传参时，
# 传参处理1: 把所有的 = 变为空格，但保留 =" ，因为 Json TunnelSecret 是 =" 结尾的，如 {"AccountTag":"9cc9e3e4d8f29d2a02e297f14f20513a","TunnelSecret":"6AYfKBOoNlPiTAuWg64ZwujsNuERpWLm6pPJ2qpN8PM=","TunnelID":"1ac55430-f4dc-47d5-a850-bdce824c4101"}
# 传参处理2: 去掉 sudo cloudflared service install ，以方便用户输入 Token 并能正确读取真正的以 ey 开头的 Value
ALL_PARAMETER=($(sed -E 's/(-c|-e|-f|-C|-E|-F) //; s/=([^"])/ \1/g; s/sudo cloudflared service install //' <<< $*))
# KV 参数安装：只要指定 --CHOOSE_PROTOCOLS，就认为用户要无交互安装。
# 其余参数允许缺省，脚本会按交互模式默认值自动补齐。
[[ "${ALL_PARAMETER[@]^^}" == *"--CHOOSE_PROTOCOLS"* ]] && NONINTERACTIVE_INSTALL=noninteractive_install

# 传参处理，无交互快速安装参数
for z in ${!ALL_PARAMETER[@]}; do
  case "${ALL_PARAMETER[z]^^}" in
    -K|-L )
      ((z++))
      IS_FAST_INSTALL=is_fast_install
      ;;
    -S )
      check_install
      if [ "${STATUS[0]}" = "$(text 26)" ]; then
        error "\n Sing-box $(text 26) "
      elif [ "${STATUS[0]}" = "$(text 28)" ]; then
        cmd_systemctl disable sing-box
        cmd_systemctl status sing-box &>/dev/null && error " Sing-box $(text 27) $(text 38) " || info "\n Sing-box $(text 27) $(text 37)"
      elif [ "${STATUS[0]}" = "$(text 27)" ]; then
        cmd_systemctl enable sing-box
        sleep 2
        cmd_systemctl status sing-box &>/dev/null && info "\n Sing-box $(text 28) $(text 37)" || error "\n Sing-box $(text 28) $(text 38)"
      fi
      exit 0
      ;;
    -A )
      check_install
      if [ "${STATUS[1]}" = "$(text 26)" ]; then
        error "\n Argo $(text 26) "
      elif [ "${STATUS[1]}" = "$(text 28)" ]; then
        cmd_systemctl disable argo
        cmd_systemctl status argo &>/dev/null && error " Argo $(text 27) $(text 38) " || info "\n Argo $(text 27) $(text 37)"
      elif [ "${STATUS[1]}" = "$(text 27)" ]; then
        cmd_systemctl enable argo
        sleep 2
        cmd_systemctl status argo &>/dev/null && info "\n Argo $(text 28) $(text 37)" || error "\n Argo $(text 28) $(text 38) "
        grep -qs '\--url' ${ARGO_DAEMON_FILE} && fetch_quicktunnel_domain && export_list
      fi
      exit 0
      ;;
    -T )
      change_argo; exit 0
      ;;
    -D )
      change_config; exit 0
      ;;
    -U )
      check_install; uninstall; exit 0
      ;;
    -N )
      [ ! -s ${WORK_DIR}/list ] && error " Sing-box $(text 26) "; export_list; exit 0
      ;;
    -V )
      check_system_info; check_arch; version; exit 0
      ;;
    -B )
      bash <(wget --no-check-certificate -qO- ${GH_PROXY}https://raw.githubusercontent.com/ylx2016/Linux-NetSpeed/master/tcp.sh); exit
      ;;
    -R )
      change_protocols; exit 0
      ;;
    --ROTATE_SUBSCRIBE_TOKEN )
      check_install
      fetch_nodes_value
      [ "$IS_SUB" = 'is_sub' ] || error " Subscription is not enabled."
      if is_strict_multi_user_mode; then
        info " Strict multi-user mode has no public subscription URL. Use: sb-user rotate-token <username>"
        exit 0
      fi
      SUBSCRIBE_TOKEN=$(generate_subscribe_token)
      export_nginx_conf_file
      nginx_sync
      export_list
      info " Subscription URL token rotated. Previous subscription URLs are no longer valid."
      exit 0
      ;;
    --LANGUAGE )
      ((z++)); [[ "${ALL_PARAMETER[z]^^}" =~ ^C ]] && LANGUAGE=C || LANGUAGE=E
      ;;
    --CHOOSE_PROTOCOLS )
      ((z++)); CHOOSE_PROTOCOLS=${ALL_PARAMETER[z]}
      ;;
    --START_PORT )
      ((z++)); START_PORT=${ALL_PARAMETER[z]}
      ;;
    --PORT_NGINX )
      ((z++)); PORT_NGINX=${ALL_PARAMETER[z]}
      ;;
    --SERVER_IP )
      ((z++)); SERVER_IP=${ALL_PARAMETER[z]}
      ;;
    --CAMPUS_DIRECT_CIDR )
      ((z++)); CAMPUS_DIRECT_CIDR=${ALL_PARAMETER[z]}
      ;;
    --CAMPUS_DIRECT_DOMAINS )
      ((z++)); CAMPUS_DIRECT_DOMAINS=${ALL_PARAMETER[z]}; CAMPUS_DIRECT_DOMAINS_EXPLICIT=true
      ;;
    --VMESS_HOST_DOMAIN )
      ((z++)); VMESS_HOST_DOMAIN=${ALL_PARAMETER[z]}
      ;;
    --VLESS_HOST_DOMAIN )
      ((z++)); VLESS_HOST_DOMAIN=${ALL_PARAMETER[z]}
      ;;
    --CDN )
      ((z++)); CDN=${ALL_PARAMETER[z]}
      ;;
    --UUID_CONFIRM )
      ((z++)); UUID_CONFIRM=${ALL_PARAMETER[z]}
      ;;
    --SUBSCRIBE_TOKEN )
      ((z++)); SUBSCRIBE_TOKEN=${ALL_PARAMETER[z]}
      ;;
    --NODE_NAME_CONFIRM )
      ((z++))
      for ((z=$z; z<${#ALL_PARAMETER[@]}; z++)); do
        [[ ! "${ALL_PARAMETER[z]}" =~ ^- ]] && NODE_NAME_ARRAY+=(${ALL_PARAMETER[z]}) || break
      done
      NODE_NAME_CONFIRM=${NODE_NAME_ARRAY[@]}
      ;;
    --SUBSCRIBE )
      ((z++)); [ "${ALL_PARAMETER[z]}" = 'true' ] && IS_SUB=is_sub
      ;;
    --ARGO )
      ((z++)); [ "${ALL_PARAMETER[z]}" = 'true' ] && IS_ARGO=is_argo
      ;;
    --ARGO_DOMAIN )
      ((z++)); ARGO_DOMAIN=${ALL_PARAMETER[z]}
      ;;
    --ARGO_AUTH )
      ((z++)); ARGO_AUTH=${ALL_PARAMETER[z]}
      ;;
    --HY2_PORT_HOPPING_RANGE )
      ((z++)); [[ "${ALL_PARAMETER[z]//:/-}" =~ ^[1-6][0-9]{4}-[1-6][0-9]{4}$ ]] && HY2_PORT_HOPPING_RANGE=${ALL_PARAMETER[z]//-/:} && PORT_HOPPING_START=${ALL_PARAMETER[z]%:*} && PORT_HOPPING_END=${ALL_PARAMETER[z]#*:}
      [[ "$PORT_HOPPING_START" < "$PORT_HOPPING_END" && "$PORT_HOPPING_START" -ge "$MIN_HOPPING_PORT" && "$PORT_HOPPING_END" -le "$MAX_HOPPING_PORT" ]] && IS_HOPPING=is_hopping
      ;;
    --HY2_REALM|--REALM )
      ((z++)); [[ "${ALL_PARAMETER[z],,}" =~ ^(true|1|y|yes)$ ]] && IS_HY2_REALM=is_hy2_realm
      ;;
    --HY2_WARP|--REALM_WARP|--WARP_REALM )
      ((z++)); [[ "${ALL_PARAMETER[z],,}" =~ ^(true|1|y|yes)$ ]] && IS_HY2_WARP=is_hy2_warp && IS_HY2_REALM=is_hy2_realm
      ;;
    --REINSTALL )
      ((z++)); [[ "${ALL_PARAMETER[z],,}" =~ ^(true|1|y|yes)$ ]] && FORCE_REINSTALL=true
      ;;
    --BIND_INTERFACE )
      ((z++)); BIND_INTERFACE=${ALL_PARAMETER[z]}
      [[ "${BIND_INTERFACE,,}" = "default" ]] && unset BIND_INTERFACE
      ;;
    --REALITY_PRIVATE )
      ((z++)); REALITY_PRIVATE=${ALL_PARAMETER[z]}
      ;;
  esac
done

check_arch
check_dependencies
check_system_ip

# -l 是“全新双协议安装”，不能复用任何旧二进制或配置；否则后台下载会被跳过，
# 随后可能出现等待下载、端口冲突或旧节点超时。先让用户确认备份和卸载。
if [ "$IS_FAST_INSTALL" = 'is_fast_install' ]; then
  prepare_clean_reinstall
elif { [ -d "$WORK_DIR" ] && [ ! -x "$WORK_DIR/sing-box" ]; } || pgrep -x sing-box >/dev/null 2>&1; then
  # 残留目录、损坏安装或没有 systemd/OpenRC 托管的旧进程，也要在下载开始前处理。
  prepare_clean_reinstall
fi
check_install

# 第三方脚本的 service 以前会在 check_install 中直接退出，既没有卸载入口也容易留下
# 运行中的旧进程。现在统一给出备份/卸载确认，清理后重新检测并开始下载任务。
if [ "$FOREIGN_SINGBOX_DETECTED" = true ]; then
  prepare_clean_reinstall
  check_install
elif [ "${STATUS[0]}" = "$(text 26)" ] && has_existing_singbox_installation; then
  # 目录或残留进程存在、但 service 已损坏时也必须先清理，避免覆盖残留配置。
  prepare_clean_reinstall
  check_install
fi
if [ "$NONINTERACTIVE_INSTALL" = 'noninteractive_install' ]; then
  # 预设默认值，允许只传 --CHOOSE_PROTOCOLS 进行最小无交互安装。
  CHOOSE_PROTOCOLS=${CHOOSE_PROTOCOLS:-'a'}
  START_PORT=${START_PORT:-"$START_PORT_DEFAULT"}
  CDN=${CDN:-"${CDN_DOMAIN[0]}"}
  IS_SUB=${IS_SUB:-'no_sub'}
  IS_ARGO=${IS_ARGO:-'no_argo'}
  IS_HOPPING=${IS_HOPPING:-'no_hopping'}

  install_sing-box
  export_list install
  create_shortcut
elif [ "$IS_FAST_INSTALL" = 'is_fast_install' ]; then
  quick_install_hy2_tuic
else
  menu_setting
  menu
fi
