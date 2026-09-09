
# 目录
- [disable-ipv6-safe](#disable-ipv6-safe)
- [geodata](#geodata)

<a id="disable-ipv6-safe"></a>
## 禁用 IPV6 disable-ipv6-safe.sh

### 测试总结

在容器里做了完整的实测(不是纸上谈兵),包括:

| 测试项 | 结果 |
|---|---|
| `bash -n` 语法检查 | ✅ 通过 |
| `shellcheck`(error 级别) | ✅ 无报错 |
| netplan YAML 转换逻辑(用实际的配置样本) | ✅ `dhcp6:true→false`,新增 `accept-ra:false`,其余字段(地址/路由/DNS/MAC匹配)完整保留 |
| netplan 转换幂等性 | ✅ 第二次运行 md5 完全一致,不重复触发 apply |
| 接口探测逻辑 | ✅ 正确识别 `set-name` 重命名后的接口名 |
| sysctl 配置生成 | ✅ 只写 `default` + 具体网卡,不碰 `all`/`lo` |
| 清理遗留冲突配置(用之前的脏配置样本) | ✅ 只注释 `all`/`lo` 那两行 |
| GRUB 参数移除(用实际的 grub 配置) | ✅ 精准删除 `ipv6.disable=1`,其余参数原样保留 |
| GRUB 处理幂等性 | ✅ 第二次运行提示"未发现"，不重复操作 |
| 非 root 运行 | ✅ 正确拒绝 |
| `netplan`/`update-grub` 命令缺失时 | ✅ 修复了一个真实发现的 bug——原本会导致脚本崩溃退出，现在改为警告并继续 |
| 完整流程端到端跑通 | ✅ 退出码 0，验证阶段 DNS/HTTP 测试通过 |

**一个诚实的说明**:测试沙箱容器的网络命名空间本身就没有 IPv6(`/proc/sys/net/ipv6` 整个不存在),这和真实 VPS 环境不同,所以**无法在这里验证 `netplan apply`/`sysctl --system` 在真正有 IPv6 协议栈的机器上生效后的最终网络状态**。但这恰好帮忙在测试中发现并修复了两处真实的健壮性问题(netplan/sysctl 部分失败时不该让整个脚本崩溃),所以这个测试环境的局限性反而有价值。

### 使用建议

在重装系统后的**全新 Ubuntu VPS**上:
```bash
curl -L -O https://raw.githubusercontent.com/faintx/public/refs/heads/main/tools/disable-ipv6-safe.sh
```

先看看会做什么改动，不实际执行
```bash
sudo bash disable-ipv6-safe.sh --dry-run
```

确认无误后正式执行（会有一次 y/N 确认）
```bash
sudo bash disable-ipv6-safe.sh
```

如果脚本提示"GRUB 配置已更新，需要重启”，执行 `reboot`；重启后建议再跑一次脚本本身做二次确认（此时应该全部显示"无需修改"/"未发现"，证明状态已经收敛），然后用下面命令做最终验证。

```bash
ip -6 addr show scope global
```
```bash
curl -I https://github.com
```

[⬆ 返回目录](#目录)


<a id="geodata"></a>
## 获取 geo 数据 geodata.sh


[⬆ 返回目录](#目录)
