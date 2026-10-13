# 文件清单与缺失依赖

## 已收录

| 文件 | 用途 |
|---|---|
| `bin/sample_player` | x86-64 Linux 球员程序（ELF） |
| `bin/sample_coach` | x86-64 Linux 教练程序（ELF） |
| `bin/sample_trainer` | x86-64 Linux 训练程序（ELF） |
| `bin/start.sh` | 主启动脚本，包含 GNN 自动训练、现有模型查找和规则回退逻辑 |
| `bin/start-debug.sh` | 调用 `start.sh` 的调试启动脚本 |
| `bin/start-offline.sh` | 调用 `start.sh` 的离线启动脚本 |
| `bin/train.sh` | 传统训练启动脚本 |
| `bin/keepaway.sh` | Keepaway 启动脚本 |
| `bin/player.conf` | 球员配置，默认队名 white，协议版本 18 |
| `bin/coach.conf` | 教练配置，默认队名 white，协议版本 18 |
| `bin/team_logo.xpm` | XPM 队徽（192 × 48，64 色，cpp=1） |
| `bin/unmark_dnn_weights.txt` | 已上传的 DNN 权重文本 |

## 未收录且可能影响运行

- `bin/lib/librcsc.so.19`（`sample_player` 的动态库依赖，当前环境检查为 not found）
- `bin/formations-dt/before-kick-off.conf`、`bin/formations-dt/normal-formation.conf` 等阵型配置
- `bin/gnn_decision_weights.txt`（GNN 决策运行时模型，区别于 `unmark_dnn_weights.txt`）
- `ml/train_gnn_decision.py`、`ml/rcg.py`、CSV/RCG 训练数据（自动训练功能所需）
- `rcssserver`、`rcssmonitor` 等外部工具（不应打包到仓库）

## 其他说明

- 运行文件保留原样，仅去除上传时自动添加的 `(1)` 后缀。
- 所有启动脚本和 ELF 文件设置为可执行。
- 未编译或运行验证，未修改任何启动逻辑。
- 原脚本支持从 `bin.tar.xz` 恢复部分依赖，但本次未上传该归档。
