# Spartan-3E Starter Kit：27 模式 PSK 接收器与 LED/LCD 示例

**27 模式 PSK 文字接收器已通过验证并烧录。** 覆盖 HPM6750 当前工程中除 2x8PSK1200F
以外的全部文字调制模式，包括多载波 BPSK、BPSK63F 和五种单载波 8PSK F 模式。
用旋钮选择、按下确认，LCD 第二行显示解码文字；音频输入固定为 J7 VINA，中心频率 2000 Hz。

54 组实际 RTL 波形测试、FEC 错误注入、板级测试及 50 MHz 时序检查通过。
K=13/16 使用受候选路径数量限制的译码器；实际模拟连线接收仍待实机确认。

模式顺序、接线、验证和译码限制见 **[PSK 接收器使用说明](docs/PSK-RECEIVER.md)**。
双击 `Program-Receiver.cmd` 重新下载；双击 `Build-Receiver.cmd` 完整构建和验证。

下面保留原 LED/LCD 示例说明。


目标板：官方 Xilinx/Digilent Spartan-3E Starter Kit，XC3S500E，FG320 封装。
工程使用 -4 速度等级。参考资料：[UG230](docs/UG230-Spartan-3E-Starter-Kit.pdf)，
LED/时钟见第 19–23 页，LCD 见第 43–54 页，Flash 片选见第 89 页。

## 运行效果

```text
SPARTAN-3E READY
Hello, FPGA!
```

- LED0（最右侧）常亮。
- LED1 在 LCD 初始化和字符发送完成后点亮。这表示发送完成，并非 LCD 读回确认。
- LED7（最左侧）每 0.5 秒翻转一次，即 1 Hz 闪烁。
- LED2–LED6 熄灭。

修改 `rtl/lcd_text.v` 顶部的 `LINE1`、`LINE2` 可更换文字：每行恰好 16 个 ASCII
字符，不足补空格；此字符屏不能直接显示任意中文。然后重新编译、下载。

## 已安装的开发环境

- Oracle VirtualBox 7.2.16。
- AMD 官方 ISE 14.7 Linux 虚拟机：`ISE-14.7-Spartan3E`。
- 虚拟机目录：`C:\Users\zhang\VirtualBox VMs\ISE-14.7-Spartan3E`。
- ISE 安装目录（虚拟机内）：`/opt/Xilinx/14.7/ISE_DS`。
- 本项目共享到虚拟机：`/home/ise/fpga-project`。
- 虚拟机内已提供 Xilinx USB-JTAG 驱动、fxload 和嵌入式电缆固件 `xusb_emb.hex`。
- VM 使用 USB 2.0；只启用 Xilinx（VID `03fd`）的 USB 过滤器。
- VM 原始网卡 MAC 保留为 `08002768C935`，供包内预装许可证识别；网线断开。
  不要重新随机生成 MAC，否则 ISE 许可证会失效。
- 官方虚拟机默认账户是 `ise`，密码 `xilinx`。主机脚本通过 VirtualBox Guest Control
  调用，不需要 SSH 或互联网连接。

## 打开、仿真和编译

双击项目目录的 **`Open-ISE.cmd`** 打开虚拟机中的 `led_demo.xise` 工程。
双击 **`Build-Demo.cmd`** 先运行 LCD 仿真，再综合、布局布线、检查时序、生成 `.bit`。
双击 **`Program-Demo.cmd`** 检查实际 JTAG 链并下载到 FPGA。源文件有更新时须先重新编译。

也可以在本目录的 PowerShell 中运行：

```powershell
.\scripts\ise-vm.ps1 -Action Open
.\scripts\ise-vm.ps1 -Action Simulate
.\scripts\ise-vm.ps1 -Action Build
.\scripts\ise-vm.ps1 -Action Scan
.\scripts\ise-vm.ps1 -Action Program
```

在虚拟机内直接使用：

```bash
source /opt/Xilinx/14.7/ISE_DS/settings64.sh
cd /home/ise/fpga-project
bash scripts/simulate.sh
bash scripts/build.sh
```

输出：`build/led_demo.bit`。时序报告：`build/led_demo.twr`。
仿真日志：`build/simulation.log`。构建脚本遇到时序错误会停止生成 bitstream。
安装原生 Windows 版 ISE 的电脑也可在其命令环境中执行 `scripts/build.ps1`。

## 接线和下载

1. 使用原装 **5 V 直流电源**接 J20，中心正极；打开板上电源开关。
2. USB 数据线连接电脑与板上 USB-B 插座，该接口就是板载 USB-JTAG。
3. JP9 选择 3.3 V。JTAG 启动时 J30 仅短接 M1，M0/M2 留空，即 M2:M1:M0 = 101。
   J12 是 SPI Flash 编程接口。
4. 启动 ISE 虚拟机后，将 Xilinx USB 电缆交给虚拟机。Windows 上未装原生 Xilinx
   驱动并不等于虚拟机不能下载；关键是 Linux 中 `lsusb` 能看到并初始化该设备。
5. 双击 `Program-Demo.cmd` 下载。脚本会重新扫描，并确认链位置 1 为 XC3S500E
   （IDCODE `01c22093`）、位置 2 为 XCF04S、位置 3 为 XC2C64A，只配置位置 1。
   若设备显示 Held，脚本会将 Xilinx USB 设备附加到虚拟机。

本例只配置 FPGA 的易失性 SRAM，断电后需要重新下载。板上的 Platform Flash、
StrataFlash 和 CPLD 不在本例的编程范围内。

LCD 使用 4 位写接口，RW 固定为低；StrataFlash 的 CE0、OE、WE 固定为高，避免
共享数据线冲突。初始化包含 40 ms 等待、3/3/3/2 握手、功能设置、清屏及两行地址设置。

## 本次验证（2026-09-12）

- 官方下载 ZIP 经 7-Zip 全包完整性校验通过。
- ISE/ISim 在虚拟机中实际运行，工程已在 ISE GUI 打开。
- 仿真通过：初始化命令、两行 DDRAM 内容、使能脉宽、命令间隔、Flash 关闭与 LED 翻转。
- 综合、NGDBUILD、MAP、PAR 和 Bitgen 完成；设计规则检查 0 错误、0 警告。
- 布局布线后的时序错误为 0，20 ns 时钟约束最差 setup 裕量 9.593 ns；
  最小时钟周期 10.407 ns（约 96.089 MHz）。本板按 50 MHz 运行。
- 已生成 `build/led_demo.bit`（283851 字节）。
- USB 重插并附加后，虚拟机已识别初始化后的 Xilinx 电缆 `03fd:0008`。
- 实际 JTAG 链已验证：位置 1 XC3S500E（IDCODE `01c22093`）、位置 2 XCF04S、位置 3 XC2C64A。
- **已成功下载到 FPGA**：iMPACT 报告 `Programmed successfully`，DONE=1，INIT_B=1，
  CRC error=0，GWE=1。日志见 `build/program-jtag.log`。
- **用户已确认实机正常**：LCD 两行文字正确，LED0/LED1 常亮，LED7 闪烁。
- 一键下载脚本的前置检查已实跑通过：时序合格、源码未晚于 bitstream、JTAG 型号和位置正确。

官方说明：[ISE VM 用户指南](https://docs.amd.com/r/en-US/ug1227-ise-vm-windows10/Introduction)、
[预装许可证说明](https://docs.amd.com/r/en-US/ug1227-ise-vm-windows10/Licensing-Overview)。
