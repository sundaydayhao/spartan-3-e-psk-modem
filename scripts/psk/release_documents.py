"""Publish usage/evidence after the exact validated image has been programmed."""
from reference import ROOT,PAYLOAD
from modes import MODES,parameters
import re,json
out=ROOT/'build/psk'
validation=json.loads((out/'validation.json').read_text())
hardware=json.loads((out/'hardware-status.json').read_text())
digest=validation['sources_and_bitstream_sha256']['build/psk/psk_rx_top.bit']
assert hardware['fpga_programmed'] and hardware['bitstream_sha256']==digest
assert hardware['done']==1 and hardware['crc_error']==0
mapping=(out/'psk_rx_top_map.mrp').read_text()
timing=(out/'psk_rx_top.twr').read_text()
slices=re.search(r'Number of occupied Slices:\s+([\d,]+)',mapping).group(1)
luts=re.search(r'Total Number of 4 input LUTs:\s+([\d,]+)',mapping).group(1)
brams=re.search(r'Number of RAMB16s:\s+(\d+)',mapping).group(1)
period=re.search(r'Minimum period:\s+([\d.]+)ns',timing).group(1)
doc=ROOT/'docs/PSK-RECEIVER.md'
old=doc.read_text(encoding='utf-8-sig')
wiring=old.split('## 与 HPM6750 联测的接线')[1].split('## 实现与验证')[0]
wiring=wiring.replace('测试新增 8PSK 时，两端都选择例如 **8PSK125**，不要选择带 F 后缀的模式。',
    '两端应选择完全相同的模式，包括载波数量和 F 后缀。多载波的 2000 Hz 表示整组载波的中心频率。\nFEC 和交织需要额外同步时间；切换模式后请持续发送十几秒，BPSK63F 可等待约 20 秒。')
rows=[]
for i,(name,family,rate) in enumerate(MODES):
    p=parameters(name)
    code='无 FEC' if not p['k'] else f"K={p['k']}，"+('打孔 2/3' if p['puncture'] else '1/2')
    rows.append(f"| {i+1} | {name} | {p['baud']:.6g} | {p['carriers']} | {code} | {p['depth']} |")
text=f"""# Spartan-3E PSK 音频文字接收器：27 模式

27 模式版本已通过验证并下载到实际 XC3S500E，DONE=1、CRC error=0。
覆盖当前 HPM6750 工程的全部文字调制模式，按用户要求排除 **2x8PSK1200F**。
输入仍是板载 ADC 的 J7 VINA，LCD 第一行显示模式和信号状态，
第二行滚动显示最近 16 个可打印 ASCII 字符。生产 RTL 不包含测试用 HELLO 文本。

## 操作与模式

顺时针/逆时针转动旋钮预览模式，按下确认。预览期间继续按原模式接收；
确认不同模式后清空第二行并重新同步。长按不重复确认，同模式确认不清空文字。
27 项首尾循环，拨码开关不参与操作，上电默认 BPSK31。

正常显示例如 `BPSK31    2k ---`，预览例如 `>8PSK1200F PUSH `。
`SIG` 仅表示信号能量，不表示 CRC、FEC 锁定或自动识别模式。
CR/LF 清空第二行；屏幕不显示任意中文。同步捕获期间可能暂时出现无效字符。

下表就是旋钮的实际顺序。交织深度以编码位对计。

| 序号 | 模式 | baud | 载波数 | 卷积编码 | 交织深度 |
|---|---|---:|---:|---|---:|
{chr(10).join(rows)}

BPSK 普通模式和 QPSK 使用 PSK31 Varicode；BPSK63F 与全部 8PSK 使用 MFSK Varicode。
QPSK 使用 USB 相位映射。8PSK F 模式使用 HPM 的 Gray 映射，按实际发送顺序解交织；
打孔模式补回擦除位，不把缺失位当作有效 0。

载波中心固定 **2000 Hz**，没有扫频或 AFC。多载波间隔为 1.4 × baud，
按频率从低到高合并数据。8PSK1200F 的实际符号率为 16000/13，约 1230.77 baud。
本工程处理文字 Varicode，不处理 AP580 音频帧、图像包或任意二进制协议。

LED0：LCD 初始化发送完成；LED1：ADC 就绪；LED2：信号能量；LED3：字符活动；
LED4：QPSK/8PSK；LED5：预览模式；LED6：采样处理超时（应熄灭）；LED7：心跳。

## 译码实现与限制

QPSK 的 K=5 和 BPSK63F/8PSK1000F/8PSK1200F 的 K=7 使用完整硬判决 Viterbi。
K=13/16 使用共享的 64 候选状态搜索和 192 位路径历史，并用 GF(2) 状态估计重新捕获。
保留路径数限制了弱信号和突发错误条件下的译码性能；本次通过的测试点不能证明其抗噪性能与 HPM 等效。
两种编码位对对齐同时运行并按路径误差选择，接收器无需从发送第一位开始启动。

最多 12 个载波共享混频、FIR、定时与差分判决运算；各载波历史保存在 RAM 中。
ADC 为 16 kS/s，全部逻辑仍在单一 50 MHz 时钟域内运行。普通速率抽取至每符号 16 点；
800 baud 使用 20 点，8PSK1200F 使用 13 点。首个 ADC 转换及切换模式后的初始化采样被丢弃。

## 与 HPM6750 联测的接线
{wiring}
## 实现与验证

2026-09-13 完成：

- 正常和带干扰两组，共 **54 个模式波形测试**。波形来自重新编译的实际 HPM C 发射代码；
  FPGA 生产 RTL 在 ISim 中从偏移 137 个采样处接收，每种模式验证至少两次完整、连续的测试文本。
- 带干扰组同时施加增益 −0.3、DC +300 ADC 码、Gaussian 噪声标准差 20 码、
  发射中心 2001 Hz、采样时钟 +100 ppm。这些是测试点，不是接收性能极限。
- K=7/13/16 分别加入 5 次独立的码元位翻转，实际 RTL 仍连续恢复完整文本；
  FEC 测试从第 17 个码元开始，覆盖非编码位对边界的起收。
- K=16 另从第 1500 个码元（已进入连续载荷）开始接收，重新捕获后连续解出 196 个正确字符。
- 接收前端每个采样最多 1347 个时钟，小于 ADC 的 3125 个时钟间隔。
  每编码位对处理最多 10000 个时钟的断言通过；各模式最短位对间隔仍足够完成译码。
- 板级仿真检查 ADC 增益、34 个 SPI 时钟、14 位符号及 A/B 顺序、16 kS/s 采样周期、
  共享总线隔离；监测真实 LCD 引脚检查初始化、字符刷新、9 字符模式名、旋钮预览/确认与切换清屏。
- 27 模式循环、方向、机械抖动、非法跳变、长按和同模式确认均通过实际控制 RTL 测试。
- 布局布线：**{slices}/4656 Slice**，总 LUT **{luts}/9312**，
  **10/20 乘法器、{brams}/20 BRAM**；最小时钟周期 **{period} ns**，20 ns 约束下时序错误 0。
- 下载前重新核对 JTAG 链及镜像校验，只配置位置 1 的 XC3S500E（IDCODE 01c22093）。
  仅写 FPGA 的易失性 SRAM，未写 PROM/CPLD。断电后需要重新下载。

**尚未验证：** 新版在实际 HPM → 模拟接线 → 板载 ADC → LCD 路径上的文字接收，
以及新版旋钮菜单的用户观察。此前旧版界面确认不能代替这两项。

当前 bitstream：`build/psk/psk_rx_top.bit`

```text
SHA256 {digest}
```

证据在 `build/psk/nominal`、`build/psk/stress`、`build/fec-error-22`、
`build/fec-error-24`、`build/fec-error-26`、板级/旋钮仿真日志、
`psk_rx_top.twr`、`validation.json`、`program-jtag.log`。
15 模式的原源码与 bitstream 备份：`build/baselines/receiver-15modes-preserved.zip`。

## 编译和重新下载

- `Program-Receiver.cmd`：校验已验证源码、bitstream 和实际 JTAG 链后下载。
- `Build-Receiver.cmd`：生成全部波形和 FEC 错误向量，运行 RTL/板级测试、综合、
  布局布线及验证，再生成下载校验清单。完整回归需要一段时间，控制台逐模式报告进度。
- `Program-Demo.cmd`：恢复原 LED/LCD 示例。

使用现有 ISE 虚拟机、HPM 源码工程、Cygwin 与带 numpy 的 Python。
Python 可通过 `scripts/psk/build_receiver.ps1 -Python ...` 指定。
模式定义集中在 `scripts/psk/modes.py`，生成表由 `generate_tables.py` 管理；
独立 Python 模型用于诊断，下载门禁依据实际 RTL 测试。

硬件依据：[UG230](UG230-Spartan-3E-Starter-Kit.pdf)，尤其第 76 页输入范围、
第 80 页 ADC 时序、第 81 页 SPI 总线隔离要求。
"""
doc.write_text(text,encoding='utf-8',newline='\n')
readme=ROOT/'README.md'
s=readme.read_text(encoding='utf-8-sig')
tail=s.split('下面保留原 LED/LCD 示例说明。',1)[1]
readme.write_text("""# Spartan-3E Starter Kit：27 模式 PSK 接收器与 LED/LCD 示例

**27 模式 PSK 文字接收器已通过验证并烧录。** 覆盖 HPM6750 当前工程中除 2x8PSK1200F
以外的全部文字调制模式，包括多载波 BPSK、BPSK63F 和五种单载波 8PSK F 模式。
用旋钮选择、按下确认，LCD 第二行显示解码文字；音频输入固定为 J7 VINA，中心频率 2000 Hz。

54 组实际 RTL 波形测试、FEC 错误注入、板级测试及 50 MHz 时序检查通过。
K=13/16 使用受候选路径数量限制的译码器；实际模拟连线接收仍待实机确认。

模式顺序、接线、验证和译码限制见 **[PSK 接收器使用说明](docs/PSK-RECEIVER.md)**。
双击 `Program-Receiver.cmd` 重新下载；双击 `Build-Receiver.cmd` 完整构建和验证。

下面保留原 LED/LCD 示例说明。
"""+tail,encoding='utf-8',newline='\n')
print('Published current mode list, wiring, decoder limits and validation evidence')
