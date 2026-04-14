# NSFuzz analyze.sh 使用说明

## 概述

`analyze.sh` 是 NSFuzz 模糊测试结果的自动化分析脚本，位于 `NSFuzz/scripts/execution/` 目录下。该脚本从模糊测试产生的 `.tar.gz` 归档文件中提取数据，生成覆盖率和状态的 CSV 数据文件及可视化图表。

脚本设计参照 ChatAFL 项目的 `analyze.sh`，并针对 NSFuzz 的数据格式和目录结构做了完整适配。

---

## 环境要求

### 必需

| 依赖 | 说明 |
|------|------|
| **Bash** | ≥ 4.0 |
| **Perl** | 用于从归档文件名中解析 fuzzer 名称和运行编号 |
| **tar / gzip** | 解压结果归档 |
| **coreutils** | `find`, `grep`, `awk`, `cut`, `sort`, `sed` 等标准工具 |

### 可选（绘图功能）

| 依赖 | 说明 |
|------|------|
| **Python 3** | 绘图引擎 |
| **pandas** | CSV 数据处理 |
| **matplotlib** | 图表绘制 |

安装绘图依赖：
```bash
pip install pandas matplotlib
```

> **注意**：如果系统中找不到带 `pandas` + `matplotlib` 的 Python 3，脚本仍会正常生成所有 CSV 文件，仅跳过绘图步骤。

---

## 命令语法

```
./analyze.sh <subject_names> [time_in_minutes] [results_dir]
```

### 参数说明

| 参数 | 是否必填 | 默认值 | 说明 |
|------|:--------:|:------:|------|
| `subject_names` | **是** | — | 要分析的目标名称，多个目标用逗号 `,` 分隔 |
| `time_in_minutes` | 否 | `1440`（24小时） | 分析的时间截止点，单位为分钟 |
| `results_dir` | 否 | 与 subject_name 同名 | 显式指定结果目录路径（相对于 `scripts/execution/`） |

---

## 使用示例

### 1. 分析单个目标（使用默认 24 小时截止时间）

```bash
cd NSFuzz/scripts/execution
./analyze.sh bftpd-nsfuzz
```

### 2. 指定截止时间

```bash
./analyze.sh bftpd-nsfuzz 720       # 分析 12 小时内的数据
```

### 3. 同时分析多个目标

```bash
./analyze.sh bftpd-nsfuzz,lightftp-nsfuzz,kamailio 1440
```

### 4. 显式指定结果目录

当结果目录名与 subject 名称不一致时使用：

```bash
./analyze.sh kamailio 1440 kamailio
```

### 5. 查看可用目标

不带参数运行时，脚本会列出所有包含结果数据的目录：

```bash
./analyze.sh
```

输出示例：
```
Usage: analyze.sh <subject names> <time in minutes> [results-dir]
  ...
Available result directories:
  bftpd-nsfuzz       (10 archives)
  exim-nsfuzz        (10 archives)
  kamailio           (9 archives)
  lightftp-nsfuzz    (10 archives)
  ...
```

### 6. 权限问题处理

如果结果目录权限不足，可以使用 `sudo` 运行：

```bash
sudo ./analyze.sh bftpd-nsfuzz 1440
```

---

## 目录与文件结构

### 输入数据结构

脚本期望的结果目录位于 `NSFuzz/scripts/execution/` 下，遵循以下命名规范：

```
scripts/execution/
├── bftpd-nsfuzz/                          # 单 fuzzer 目录
│   ├── out-bftpd-nsfuzz_1.tar.gz          # 归档: out-<subject>-<fuzzer>_<N>.tar.gz
│   ├── out-bftpd-nsfuzz_2.tar.gz
│   ├── ...
│   ├── out-bftpd-nsfuzz_10.tar.gz
│   ├── out-bftpd-nsfuzz_sv_range_1.json   # 状态变量范围 JSON
│   └── ...
├── kamailio/                              # 多 fuzzer 目录
│   ├── out-kamailio-aflnet_1.tar.gz
│   ├── out-kamailio-aflnwe_1.tar.gz
│   ├── out-kamailio-nsfuzz_1.tar.gz
│   ├── out-kamailio-nsfuzz-v_1.tar.gz
│   ├── out-kamailio-stateafl_1.tar.gz
│   └── ...
└── ...
```

### 归档文件内部结构

每个 `.tar.gz` 归档包含以下关键文件：

```
out-<subject>-<fuzzer>/
├── cov_over_time.csv    # 覆盖率时间序列 (Time, l_per, l_abs, b_per, b_abs)
├── plot_data            # AFL 统计数据 (11 列: unix_time, cycles_done, ...)
├── fuzzer_stats         # fuzzer 最终运行统计
├── ipsm.dot             # IPSM 状态图 (Graphviz DOT 格式)
├── queue/               # 测试用例队列
├── regions/             # 区域文件
├── replayable-crashes/  # 可重放的崩溃输入
├── cov_html/            # gcov 覆盖率 HTML 报告
└── fuzz_bitmap          # AFL 位图
```

### 支持的 Fuzzer 类型

脚本自动识别以下 fuzzer 名称：

| Fuzzer | 归档命名示例 |
|--------|-------------|
| `nsfuzz` | `out-bftpd-nsfuzz_1.tar.gz` |
| `nsfuzz-v` | `out-live555-nsfuzz-v_1.tar.gz` |
| `aflnet` | `out-kamailio-aflnet_1.tar.gz` |
| `aflnwe` | `out-kamailio-aflnwe_1.tar.gz` |
| `stateafl` | `out-live555-stateafl_1.tar.gz` |

---

## 输出产物

分析完成后，所有产物保存在两个位置：

### 1. 结果目录内（原地生成）

直接写入到被分析的结果目录中，例如 `bftpd-nsfuzz/`：

| 文件 | 说明 |
|------|------|
| `results.csv` | 覆盖率时间序列数据（格式: `time,subject,fuzzer,run,cov_type,cov`） |
| `states.csv` | 状态时间序列数据（格式: `time,subject,fuzzer,run,state_type,state`） |
| `fuzzer_summary.csv` | 各 fuzzer 各次运行的汇总统计 |
| `ipsm_summary.csv` | IPSM 状态模型节点/边数汇总 |
| `sv_range_summary.csv` | 状态变量范围汇总（依赖 `*_sv_range_*.json` 文件） |
| `mean_plot_data.csv` | 状态图表的均值中间数据 |
| `cov_over_time_<subject>_<timestamp>.png` | 覆盖率随时间变化图 |
| `state_over_time_<subject>_<timestamp>.png` | IPSM 状态随时间变化图 |

### 2. 时间戳副本目录

在 `scripts/execution/` 的**上一级目录**（`scripts/`）生成带时间戳的结果副本：

```
scripts/res_<subject>_<Mon-DD_HH-MM-SS>/
├── results.csv
├── states.csv
├── fuzzer_summary.csv
├── ipsm_summary.csv
├── sv_range_summary.csv
├── mean_plot_data.csv
├── cov_over_time_<subject>_<timestamp>.png
├── state_over_time_<subject>_<timestamp>.png
└── <subject-dir>/                          # 原始结果归档的完整拷贝
    ├── out-<subject>-<fuzzer>_1.tar.gz
    └── ...
```

---

## 输出 CSV 格式详解

### results.csv — 覆盖率数据

```csv
time,subject,fuzzer,run,cov_type,cov
1776001084,bftpd,nsfuzz,1,l_per,28.9
1776001084,bftpd,nsfuzz,1,l_abs,647
1776001084,bftpd,nsfuzz,1,b_per,18.5
1776001084,bftpd,nsfuzz,1,b_abs,251
```

| 字段 | 说明 |
|------|------|
| `time` | UNIX 时间戳（秒） |
| `subject` | 目标程序名（不含 fuzzer 后缀，如 `bftpd`） |
| `fuzzer` | fuzzer 名称（如 `nsfuzz`, `aflnet`） |
| `run` | 运行编号（1 ~ N） |
| `cov_type` | 覆盖率类型：`l_per`(行百分比), `l_abs`(行绝对值), `b_per`(分支百分比), `b_abs`(分支绝对值) |
| `cov` | 覆盖率数值 |

### states.csv — 状态数据

```csv
time,subject,fuzzer,run,state_type,state
1776001089,bftpd,nsfuzz,1,nodes,15
1776001089,bftpd,nsfuzz,1,edges,49
```

| 字段 | 说明 |
|------|------|
| `state_type` | `nodes`(IPSM 节点数) 或 `edges`(IPSM 边数) |
| `state` | 状态数值（从 `ipsm.dot` 文件提取） |

### fuzzer_summary.csv — 运行汇总

```csv
fuzzer,run,runtime_min,execs_done,execs_per_sec,paths_total,paths_favored,unique_crashes,unique_hangs,variable_paths,bitmap_cvg
nsfuzz,1,1480,9447876,179.45,460,42,19,82,21,1.49%
```

| 字段 | 说明 |
|------|------|
| `runtime_min` | 实际运行时长（分钟） |
| `execs_done` | 总执行次数 |
| `execs_per_sec` | 每秒执行次数 |
| `paths_total` | 发现的总路径数 |
| `paths_favored` | 被优选的路径数 |
| `unique_crashes` | 唯一崩溃数 |
| `unique_hangs` | 唯一挂起数 |
| `variable_paths` | 状态变量路径数（NSFuzz 特有） |
| `bitmap_cvg` | 位图覆盖率 |

### ipsm_summary.csv — 状态模型汇总

```csv
fuzzer,run,ipsm_nodes,ipsm_edges
nsfuzz,1,15,49
nsfuzz,2,13,42
```

### sv_range_summary.csv — 状态变量范围汇总

```csv
fuzzer,run,sv_range_file,num_variables
nsfuzz,1,out-bftpd-nsfuzz_sv_range_1.json,8
```

---

## 生成的图表说明

### 覆盖率图（Coverage Plot）

生成 2×2 子图，展示随时间变化的覆盖率：

| 子图位置 | 内容 |
|----------|------|
| 左上 | **#edges** — 分支覆盖绝对值 |
| 右上 | **#lines** — 行覆盖绝对值 |
| 左下 | **Edge coverage (%)** — 分支覆盖百分比 |
| 右下 | **Line coverage (%)** — 行覆盖百分比 |

- 每条曲线代表一个 fuzzer，取所有运行的**平均值**
- 不同 fuzzer 使用不同颜色、线型和标记符号以便区分

### 状态图（State Plot）

生成 1×2 子图，展示 IPSM（Inferred Protocol State Machine）状态模型规模：

| 子图位置 | 内容 |
|----------|------|
| 左 | **#IPSM nodes** — 推断的协议状态数 |
| 右 | **#IPSM edges** — 推断的状态转移数 |

---

## 当前可用的结果目录

| 目录名 | 归档数 | 包含 Fuzzer | 说明 |
|--------|:------:|------------|------|
| `bftpd-nsfuzz` | 10 | nsfuzz | Bftpd FTP 服务器 |
| `exim-nsfuzz` | 10 | nsfuzz | Exim SMTP 服务器 |
| `forked-daapd-nsfuzz` | 10 | nsfuzz | forked-daapd DAAP 服务器 |
| `kamailio` | 9 | aflnet, aflnwe, nsfuzz, nsfuzz-v, stateafl | Kamailio SIP 服务器（多 fuzzer 对比） |
| `kamailio-nsfuzz` | 10 | nsfuzz | Kamailio SIP 服务器（仅 nsfuzz） |
| `lightftp-nsfuzz` | 10 | nsfuzz | LightFTP 服务器 |
| `live555` | 2 | nsfuzz-v, stateafl | Live555 RTSP 服务器 |
| `live555-nsfuzz` | 10 | nsfuzz | Live555 RTSP 服务器（仅 nsfuzz） |
| `proftpd-nsfuzz` | 10 | nsfuzz | ProFTPD 服务器 |
| `tinydtls` | 5 | nsfuzz | TinyDTLS 服务器 |

---

## 完整工作流示例

### 示例 1：分析单个 nsfuzz 目标

```bash
cd /home/ckt/Documents/000_2026_test_dev/NSFuzz/scripts/execution

# 分析 bftpd-nsfuzz，24 小时截止
./analyze.sh bftpd-nsfuzz

# 查看输出
ls bftpd-nsfuzz/*.csv
ls bftpd-nsfuzz/*.png
```

### 示例 2：分析多 fuzzer 对比目录

```bash
# kamailio 目录包含 aflnet, aflnwe, nsfuzz, nsfuzz-v, stateafl 五种 fuzzer
./analyze.sh kamailio 1440

# 生成的图表中会自动包含所有 fuzzer 的对比曲线
```

### 示例 3：批量分析所有目标

```bash
./analyze.sh bftpd-nsfuzz,lightftp-nsfuzz,proftpd-nsfuzz,exim-nsfuzz,kamailio-nsfuzz,live555-nsfuzz,forked-daapd-nsfuzz 1440
```

### 示例 4：快速预览（短截止时间）

```bash
# 只分析前 60 分钟的数据，适合快速检查
./analyze.sh bftpd-nsfuzz 60
```

---

## 脚本执行流程

```
1. 参数解析与权限检查
   │
2. 遍历每个指定的 subject
   │
   ├── 3. 定位结果目录，统计 .tar.gz 数量
   │
   ├── 4. 从归档文件名提取 fuzzer 列表和最大运行编号
   │       (支持: nsfuzz, nsfuzz-v, aflnet, aflnwe, stateafl)
   │
   ├── 5. 解析原始 subject 名称 (去除 fuzzer 后缀)
   │
   ├── 6. 逐 fuzzer × 逐 run 解压并转换数据
   │   ├── 提取 cov_over_time.csv → results.csv
   │   ├── 提取 plot_data + ipsm.dot → states.csv
   │   └── 清理临时解压目录
   │
   ├── 7. 从 fuzzer_stats 生成 fuzzer_summary.csv
   │
   ├── 8. 从 ipsm.dot 生成 ipsm_summary.csv
   │
   ├── 9. 从 sv_range JSON 生成 sv_range_summary.csv
   │
   ├── 10. 调用内嵌 Python 生成覆盖率图和状态图
   │
   └── 11. 拷贝所有产物到时间戳副本目录
```

---

## 常见问题排查

### Q: 提示 "No write permission"

```
[!] No write permission in /path/to/scripts/execution
```

**解决方案**：
```bash
sudo chown -R $USER:$USER NSFuzz/scripts/execution
# 或者使用 sudo 运行
sudo ./analyze.sh bftpd-nsfuzz
```

### Q: 提示 "Cannot find python3 with pandas and matplotlib"

CSV 文件仍会正常生成，只是跳过图表。安装依赖后重新运行：
```bash
pip install pandas matplotlib
./analyze.sh bftpd-nsfuzz
```

### Q: 提示 "Cannot extract fuzzer names or replication count"

归档文件命名格式不被识别。请确认文件名遵循 `out-<subject>-<fuzzer>_<N>.tar.gz` 格式，其中 `<fuzzer>` 必须是以下之一：`nsfuzz`, `nsfuzz-v`, `aflnet`, `aflnwe`, `stateafl`。

### Q: 某些运行编号的归档缺失

```
[!] Archive not found: out-kamailio-aflnet_2.tar.gz (run 2), skipping
```

这是正常现象。脚本按检测到的最大运行编号遍历，缺失的归档会被跳过，不影响已有数据的分析。最终结果基于实际可用的运行取均值。

### Q: 分析耗时过长

- 可以缩短截止时间：`./analyze.sh bftpd-nsfuzz 60`
- 处理 10 个归档 × 24 小时截止通常需要数分钟（取决于 `cov_over_time.csv` 的行数）

### Q: 状态图显示为常数线

NSFuzz 的 `plot_data` 不包含时序状态列（不同于 ChatAFL 的 AFLNet 有 `n_nodes`/`n_edges`）。状态数据从运行结束时的 `ipsm.dot` 快照提取，因此各时间点的值相同。如需时序状态变化数据，需修改 NSFuzz 使其在 `plot_data` 中记录状态信息。

---

## 与 ChatAFL analyze.sh 的对应关系

| 功能模块 | ChatAFL | NSFuzz |
|----------|---------|--------|
| 参数解析 (`FILTER`, `TIME`, `EXPLICIT_DIR`) | ✅ | ✅ 完全一致 |
| 彩色日志输出 (`info`, `warn`) | ✅ | ✅ 完全一致 |
| 权限检查与修复 | ✅ | ✅ 完全一致 |
| 结果目录发现 | `results-<subject>_<timestamp>` | 适配为 `<subject-dir>/` |
| fuzzer / run 提取 | 从 tar 文件名 Perl 提取 | ✅ 适配 NSFuzz 命名规范 |
| CSV 生成 (`profuzzbench_generate_csv.sh`) | 外部脚本调用 | 内嵌 `convert_cov()` 函数 |
| 状态 CSV 生成 | 从 `plot_data` 第 12/13 列 | 从 `ipsm.dot` 提取节点/边数 |
| 覆盖率绘图 (`profuzzbench_plot.py`) | 外部 Python 脚本 | 内嵌 Python 代码 |
| 状态绘图 (`profuzzbench_state.py`) | 外部 Python 脚本 | 内嵌 Python 代码 |
| LLM Token 成本分析 | `llm_cost.csv` | 替换为 `fuzzer_summary.csv` + `ipsm_summary.csv` + `sv_range_summary.csv` |
| 输出图片时间戳命名 | ✅ | ✅ 完全一致 |
| 结果拷贝到 `res_<subject>_<timestamp>` | ✅ | ✅ 完全一致 |
