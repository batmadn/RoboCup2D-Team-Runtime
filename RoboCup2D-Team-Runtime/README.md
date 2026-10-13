# RoboCup 2D Team Runtime

这是根据现有上传文件整理的 **RoboCup Soccer Simulation 2D 球队运行包**，并非完整的 C++ 源码仓库。保留了原始启动脚本、Linux 可执行文件、配置、队徽和已有 DNN 权重。

> **状态：文件已整理，尚未完成运行验证。** 目前缺少 `librcsc.so.19`、阵型目录；若要使用启动脚本的赛前 GNN 自动训练功能，还需要相应的 `ml/` 训练代码和数据。

## 目录

```text
RoboCup2D-Team-Runtime/
├── README.md
├── .gitignore
├── docs/
│   └── FILES_AND_REQUIREMENTS.md
└── bin/
    ├── sample_player
    ├── sample_coach
    ├── sample_trainer
    ├── start.sh
    ├── start-debug.sh
    ├── start-offline.sh
    ├── train.sh
    ├── keepaway.sh
    ├── player.conf
    ├── coach.conf
    ├── team_logo.xpm
    └── unmark_dnn_weights.txt
```

## 运行条件

- Ubuntu/Linux x86-64；已安装 RoboCup 2D `rcssserver`（可选 `rcssmonitor`）。
- `bin/lib/librcsc.so.19`（或系统可搜索路径下 ABI 兼容的同名库）。本仓库 **未提供** 该动态库。
- `bin/formations-dt/` 中的 `before-kick-off.conf` 和 `normal-formation.conf` 等阵型配置。本仓库 **未提供**。
- 若启用自动 GNN 训练，还需要 `ml/train_gnn_decision.py`、相关数据和 Python `numpy`、`torch`。这些文件 **未提供**。

## 使用（补齐依赖后）

```bash
# 终端 1
rcssserver

# 终端 2（可选）
rcssmonitor

# 终端 3
cd bin
bash ./start.sh --no-auto-gnn-train --teamname white
```

`start.sh` 默认会尝试赛前 GNN 训练；若无训练代码，自动尝试读取已有的 `gnn_decision_weights.txt`，仍不存在时切换到规则决策。**注意：上传的 `unmark_dnn_weights.txt` 与 `gnn_decision_weights.txt` 是不同文件，不能当作同一模型使用。**

常用参数：

```bash
bash ./start.sh --help
bash ./start-debug.sh --no-auto-gnn-train
bash ./start-offline.sh --no-auto-gnn-train
```

## 发布说明

此包包含第三方项目的衍生可执行文件、脚本和权重。**公开上传 GitHub 前应确认原项目许可证、团队授权和二进制再分发权限**。本次未擅自新增或声明 LICENSE。建议先创建 Private 仓库。

本仓库不是训练源码的替代品，不能据此证明 GNN 的模型结构、训练精度或比赛效果。
