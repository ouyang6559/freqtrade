# FreqAI 使用入门教程（含 freqtrade 部署）

> 定位：从**零开始**，把 freqtrade 部署起来，再开启内置 AI 模块 **FreqAI** 分析行情、产生预测信号。
> 目标读者：小白。读完你能：① 部署 freqtrade；② 装 FreqAI 依赖；③ 下载数据；④ 运行官方示例；⑤ 看懂 FreqAI 的模型/特征/标签概念；⑥ 跑回测和 dry-run。
> 环境：macOS（Linux 同理，Windows 建议用 Docker）。本教程基于你本地仓库（版本 `2026.9-dev`）。

---

## 目录

1. [整体认识：freqtrade 与 FreqAI 是什么关系](#1-整体认识)
2. [准备阶段：检查环境](#2-准备阶段检查环境)
3. [部署 freqtrade（三种方式）](#3-部署-freqtrade三种方式)
4. [安装 FreqAI 额外依赖](#4-安装-freqai-额外依赖)
5. [获取行情数据](#5-获取行情数据)
6. [FreqAI 配置文件逐段讲解](#6-freqai-配置文件逐段讲解)
7. [第一个 FreqAI 策略（官方示例）](#7-第一个-freqai-策略官方示例)
8. [运行：回测 + dry-run 模拟 + live 实盘](#8-运行回测--dry-run-模拟--live-实盘)
9. [理解 FreqAI 核心概念：特征/标签/模型](#9-理解-freqai-核心概念)
10. [模型管理：identifier、重训、清理](#10-模型管理)
11. [把预测接到预警和下单](#11-把预测接到预警和下单)
12. [常见问题排查](#12-常见问题排查)
13. [下一步建议](#13-下一步建议)

---

## 1. 整体认识

**freqtrade** 是一个开源加密货币自动交易框架，负责"体力活"：下载数据、跑策略、下单、风控、发通知。

**FreqAI** 是 freqtrade 内置的一个模块（源码在 `freqtrade/freqai/`），相当于给机器人装一个"会自己学习的大脑"：它用历史行情训练机器学习模型，预测未来价格走势，把预测结果当作一个新"指标"交回给策略使用。

一句话理解 FreqAI 工作流：

```
历史K线 + 未来结果(标签) → 训练模型 → 对最新行情预测 → 预测值写回K线列
→ 策略读取该列 → 达到阈值就开仓/平仓 → 自动下单 + 预警
```

FreqAI 的**最大特点**：模型会**定期自动重新训练**（self-adaptive retraining），市场风格变化时模型跟着更新，不会一套规则用到底。

---

## 2. 准备阶段：检查环境

打开终端，检查：

```bash
# 1. Python 版本（需要 3.10 及以上）
python3 --version

# 2. Git
git --version

# 3. 确认你有本地仓库（本教程用你的仓库路径）
cd /Users/liu/Documents/go/gopath/src/rust-pro/freqtrade
ls
# 应能看到 freqtrade/、docs/、config_examples/、user_data/ 等目录
```

> macOS 注意：如果你是新版 Apple Silicon（M1/M2/M3/M4），有些依赖编译可能费劲，最稳妥的是用 **Docker** 方式部署（见下文 3.3）。本教程以 Linux/macOS 原生方式为主，同时给出 Docker 方式。

---

## 3. 部署 freqtrade（三种方式）

### 方式一（推荐给小白）：官方脚本 `setup.sh`

在你已克隆的仓库根目录执行：

```bash
cd /Users/liu/Documents/go/gopath/src/rust-pro/freqtrade
./setup.sh -i
```

- `-i` = install，脚本会自动创建虚拟环境 `.venv/` 并安装全部依赖。
- 过程中会**交互式提问**，其中有一项：
  `Do you want to install dependencies for freqai [y/N]?`
  → 输入 `y`（这一步直接帮你把 FreqAI 依赖也装了，可以跳过第 4 节）。
- 安装完成后，**每次打开新终端**都要先激活虚拟环境：

```bash
source .venv/bin/activate
freqtrade --version
# 输出类似：2026.9-dev
```

### 方式二：手动创建虚拟环境（更可控）

```bash
cd /Users/liu/Documents/go/gopath/src/rust-pro/freqtrade
python3 -m venv .venv
source .venv/bin/activate
pip install --upgrade pip
pip install -e .
```

> `-e .` 表示以开发模式安装当前仓库。若提示缺依赖，再 `pip install -r requirements.txt`。

### 方式三：Docker（Windows / Apple Silicon 首选）

如果你不想碰 Python 环境，用官方 Docker 镜像：

```bash
cd /Users/liu/Documents/go/gopath/src/rust-pro/freqtrade
docker compose -f docker/docker-compose.yml pull
docker compose -f docker/docker-compose.yml run --rm freqtrade trade --dry-run
```

> 注意：默认 compose 镜像**不含 FreqAI**。要跑 FreqAI 需使用 `stable_freqai` 标签的镜像（见 `docker/` 目录下的 docker-compose-freqai 相关文件）。

### 验证部署成功

```bash
freqtrade --version   # 正常打印版本号
freqtrade trade --help  # 能看到命令行参数说明
```

---

## 4. 安装 FreqAI 额外依赖

如果你用 `setup.sh -i` 时回答了 `y`，可以跳过本步。否则手动装：

```bash
source .venv/bin/activate
pip install -r requirements-freqai.txt
```

该文件包含 FreqAI 所需的机器学习库（LightGBM、scikit-learn 等）。
如果你还要用 PyTorch 系列模型或强化学习，再装：

```bash
pip install -r requirements-freqai-rl.txt
```

验证 FreqAI 依赖可用：

```bash
python3 -c "import lightgbm, sklearn; print('FreqAI 依赖 OK')"
```

---

## 5. 获取行情数据

FreqAI 训练需要**历史行情数据**，且因为它会用到**多个时间周期**和**相关交易对**，数据要下全。

### 5.1 官方配置示例已给出数据需求

先看官方 FreqAI 示例配置 `config_examples/config_freqai.example.json`，其中关键字段：

- `include_timeframes`: `["3m", "15m", "1h"]` → 需要 3 个周期的数据
- `include_corr_pairlist`: `["BTC/USDT:USDT", "ETH/USDT:USDT"]` → 相关币种也要数据

### 5.2 下载数据命令

```bash
source .venv/bin/activate

# 用官方示例配置来下载（它是合约格式，注意交易对带 :USDT 后缀）
freqtrade download-data \
  --config config_examples/config_freqai.example.json \
  --pairs "BTC/USDT:USDT" "ETH/USDT:USDT" \
  --timeframe 3m 15m 1h \
  --timerange 20240101-

# 如果你跑现货（去掉了 :USDT），用你自己的配置
freqtrade download-data \
  --config user_data/config_freqai_btc.json \
  --pairs BTC/USDT ETH/USDT \
  --timeframe 3m 15m 1h \
  --timerange 20240101-
```

> 参数解释：
> - `--timeframe`：K线周期，空格分隔可下多个；
> - `--timerange`：起始日期 `YYYYMMDD-`（`-` 表示到今天）；
> - 数据会保存到 `user_data/data/binance/` 目录下（文件名类似 `BTC_USDT-3m-*.feather`）。

---

## 6. FreqAI 配置文件逐段讲解

下面是一份**现货 BTC** 可用的最小配置。新建文件 `user_data/config_freqai_btc.json`：

```json
{
  "trading_mode": "spot",
  "max_open_trades": 3,
  "stake_currency": "USDT",
  "stake_amount": "unlimited",
  "dry_run": true,
  "dry_run_wallet": 1000,
  "timeframe": "3m",

  "exchange": {
    "name": "binance",
    "key": "你的交易所API_Key",
    "secret": "你的交易所API_Secret",
    "pair_whitelist": ["BTC/USDT"]
  },

  "telegram": {
    "enabled": false
  },

  "freqai": {
    "enabled": true,
    "purge_old_models": 2,
    "train_period_days": 30,
    "backtest_period_days": 7,
    "identifier": "btc-lgb-v1",
    "feature_parameters": {
      "include_timeframes": ["3m", "15m", "1h"],
      "include_corr_pairlist": ["BTC/USDT", "ETH/USDT"],
      "label_period_candles": 20,
      "include_shifted_candles": 2,
      "use_SVM_to_remove_outliers": true,
      "indicator_periods_candles": [10, 20]
    },
    "data_split_parameters": {
      "test_size": 0.33,
      "random_state": 1
    },
    "model_training_parameters": {}
  },

  "internals": {
    "process_throttle_secs": 5
  }
}
```

### 逐段解读

| 字段 | 含义 | 小白建议值 |
|---|---|---|
| `trading_mode: "spot"` | 现货交易（官方示例是 `futures` 合约） | 新手先用 `spot` |
| `dry_run: true` | 模拟盘，假钱真行情 | **永远先保持 true** |
| `stake_amount` | 每单投入金额 | `"unlimited"` = 按余额比例 |
| `timeframe` | 主K线周期 | `3m`（与示例一致） |
| `freqai.enabled` | **FreqAI 总开关** | `true` |
| `train_period_days` | 每次训练用多少天历史数据 | 30 |
| `backtest_period_days` | 回测时每隔多少天重训一次 | 7 |
| `identifier` | **模型身份ID**，改模型/特征后要换新ID | 自己起个名 |
| `include_timeframes` | 参与特征的多周期 | 和下载的数据一致 |
| `include_corr_pairlist` | 相关币种（用于相关性特征） | 与下载数据一致 |
| `label_period_candles` | 预测未来多少根K线 | 20 |
| `indicator_periods_candles` | 指标周期列表（自动扩展特征） | [10, 20] |
| `model_training_parameters` | 传给模型训练器的额外参数 | 留 `{}` 用默认 |

---

## 7. 第一个 FreqAI 策略（官方示例）

官方在仓库里带了一个完整示例：`freqtrade/templates/FreqaiExampleStrategy.py`。先直接运行它，跑通后再改。

### 7.1 快速体验（使用官方示例）

```bash
source .venv/bin/activate

# 回测（用官方合约示例配置 + 官方示例策略 + LightGBM）
freqtrade backtesting \
  --config config_examples/config_freqai.example.json \
  --strategy FreqaiExampleStrategy \
  --strategy-path freqtrade/templates \
  --freqaimodel LightGBMRegressor \
  --timerange 20240101-20240401

# dry-run 模拟运行
freqtrade trade \
  --config config_examples/config_freqai.example.json \
  --strategy FreqaiExampleStrategy \
  --strategy-path freqtrade/templates \
  --freqaimodel LightGBMRegressor
```

> `--freqaimodel` 指定用哪个 AI 模型（下文第 9 节详述）。上面用的是 `LightGBMRegressor`。
> 你会看到日志中出现 `training`、模型训练进度、以及交易开平仓记录——说明 FreqAI 已生效。

### 7.2 官方示例策略结构（重点看这 6 个方法）

```python
class FreqaiExampleStrategy(IStrategy):

    # 1. 特征（输入）：以 % 开头的列，FreqAI 自动按多周期扩展
    def feature_engineering_expand_all(self, dataframe, period, metadata, **kwargs):
        dataframe["%-rsi-period"] = ta.RSI(dataframe, timeperiod=period)
        dataframe["%-sma-period"] = ta.SMA(dataframe, timeperiod=period)
        dataframe["%-ema-period"] = ta.EMA(dataframe, timeperiod=period)
        return dataframe

    def feature_engineering_standard(self, dataframe, metadata, **kwargs):
        # 不自动扩展的特征（如时间）
        dataframe["%-hour_of_day"] = dataframe["date"].dt.hour
        return dataframe

    # 2. 标签（目标/要预测的东西）：以 & 开头的列
    def set_freqai_targets(self, dataframe, metadata, **kwargs):
        # 预测未来 label_period_candles 根K线内的平均涨幅
        dataframe["&-s_close"] = (
            dataframe["close"]
            .shift(-self.freqai_info["feature_parameters"]["label_period_candles"])
            .rolling(self.freqai_info["feature_parameters"]["label_period_candles"])
            .mean()
            / dataframe["close"]
            - 1
        )
        return dataframe

    # 3. 触发 FreqAI 训练 + 预测，并把结果写回 dataframe
    def populate_indicators(self, dataframe, metadata):
        dataframe = self.freqai.start(dataframe, metadata, self)
        return dataframe

    # 4. 买入信号：模型预测可信(do_predict==1) 且 预测涨幅>1%
    def populate_entry_trend(self, df, metadata):
        conds = [df["do_predict"] == 1, df["&-s_close"] > 0.01]
        df.loc[reduce(lambda x, y: x & y, conds), ["enter_long", "enter_tag"]] = (1, "long")
        return df

    # 5. 卖出信号：预测涨幅转负
    def populate_exit_trend(self, df, metadata):
        df.loc[df["&-s_close"] < 0, "exit_long"] = 1
        return df

    # 6. 二次确认下单（可选保险）
    def confirm_trade_entry(self, pair, order_type, amount, rate, time_in_force,
                            current_time, entry_tag, side, **kwargs) -> bool:
        return True
```

### 7.3 关键规则（背下来）

- **特征列必须以 `%` 开头**，才会被 FreqAI 当作模型输入；
- **标签列必须以 `&` 开头**，才会被 FreqAI 当作预测目标；
- `populate_indicators` 里必须调用 `self.freqai.start(dataframe, metadata, self)`；
- 预测完成后，策略里可用的列：
  - `&-s_close`：模型预测的未来涨幅（数值）；
  - `do_predict`：本次预测是否可信（1=可信，0=不可信）；
  - 还有 `&-s_close_mean/std` 等统计辅助列。

---

## 8. 运行：回测 + dry-run 模拟 + live 实盘

### 8.1 回测（最安全，先用它验证）

```bash
freqtrade backtesting \
  --config user_data/config_freqai_btc.json \
  --strategy FreqaiExampleStrategy \
  --strategy-path freqtrade/templates \
  --freqaimodel LightGBMRegressor \
  --timerange 20240101-20240401
```

- 回测会按 `backtest_period_days` 滑动窗口，**定期重训模型**，模拟实盘；
- 结果会输出胜率、收益、最大回撤等统计。

### 8.2 dry-run 模拟盘（接真实行情，假钱）

```bash
freqtrade trade \
  --config user_data/config_freqai_btc.json \
  --strategy FreqaiExampleStrategy \
  --strategy-path freqtrade/templates \
  --freqaimodel LightGBMRegressor
```

- 用真实行情实时预测 + 模拟下单；
- 首次启动会自动补下载训练数据，需要等待；
- 跑起来后你可以通过 `freqtrade trade --show-config`、日志等观察。

### 8.3 live 实盘（**新手强烈不建议现在碰**）

```bash
# 先改配置文件：dry_run 改为 false，填入真实API key/secret
freqtrade trade \
  --config user_data/config_freqai_btc.json \
  --strategy FreqaiExampleStrategy \
  --strategy-path freqtrade/templates \
  --freqaimodel LightGBMRegressor
```

> 实盘前必须：多次回测、至少 dry-run 数周、明确止损参数、用小资金测试。

---

## 9. 理解 FreqAI 核心概念

### 9.1 特征（Features）= 模型的"输入"

你在 `feature_engineering_*` 里定义的、以 `%` 开头的列。FreqAI 会自动把这些特征按照 `include_timeframes`、`indicator_periods_candles`、`include_shifted_candles` 等**自动扩展**出成千上万列。例如一个 `%-sma-period` 会被扩展成 3个周期 × 2个周期参数 × 2个移位 = 12 列。

### 9.2 标签（Labels）= 模型的"标准答案"

你在 `set_freqai_targets` 里定义的、以 `&` 开头的列。它是"未来结果"，模型训练时学的是"看到这组特征 → 未来会怎样"。预测时模型就输出这个值的预测。

### 9.3 模型（Prediction Models）= 用什么算法学习

仓库 `freqtrade/freqai/prediction_models/` 里内置了这些模型，用 `--freqaimodel` 指定：

| 类别 | 模型名 | 说明 |
|---|---|---|
| 回归 | `LightGBMRegressor` | ✅ 新手首选，快且好用 |
| 回归 | `XGBoostRegressor` | 同为梯度提升树 |
| 回归 | `PyTorchMLPRegressor` | 神经网络 |
| 回归 | `PyTorchTransformerRegressor` | Transformer 网络 |
| 分类 | `LightGBMClassifier` | 输出涨/跌概率 |
| 分类 | `XGBoostClassifier` | 概率分类 |
| 分类 | `SKLearnRandomForestClassifier` | 随机森林 |
| 强化学习 | `ReinforcementLearner` | 让模型自己学买卖动作 |

新手**从 `LightGBMRegressor` 开始**，训练快、资源占用低、效果稳定。

### 9.4 数据管线（FreqAI 自动帮你做）

- 特征自动扩展；
- 异常值剔除（SVM / DI）；
- 数据归一化（自动）；
- 训练窗口滑动（滚动重训）。

---

## 10. 模型管理

### 10.1 identifier：模型的"身份证"

- 每次训练出的模型，会保存在 `user_data/models/<identifier>/` 目录；
- 修改了**特征**或**策略逻辑**后，必须换一个新的 `identifier`，否则会复用旧模型导致结果不一致；
- 修改**买卖阈值**（不改特征）可以沿用同一 identifier 加速回测。

### 10.2 重训频率

- 回测：按 `backtest_period_days` 定期重训；
- dry-run/live：默认每次启动/每根K线检查，可设 `live_retrain_hours`（如 0.5 = 每半小时重训一次）。

### 10.3 清理旧模型

```json
"purge_old_models": 2
```

只保留最近 2 个模型，其余自动删除，防止磁盘被占满。

---

## 11. 把预测接到预警和下单

### 11.1 自动下单

你在策略 `populate_entry_trend` 里设置 `enter_long=1`，freqtrade 就会在 `process()` 循环里自动尝试下单。`confirm_trade_entry` 返回 `False` 可拦截这次下单（如"AI 预测信心不足就不买"）。

### 11.2 预警（Telegram / 日志）

**方式 A：先用日志（最简单）**

```python
def confirm_trade_entry(self, pair, order_type, amount, rate, time_in_force,
                        current_time, entry_tag, side, **kwargs) -> bool:
    df, _ = self.dp.get_analyzed_dataframe(pair, self.timeframe)
    last = df.iloc[-1]
    self.logger.info(f"[AI信号] {pair} 预测={last.get('&-s_close', 0):.4f} "
                     f"可信={last.get('do_predict','?')}")
    return True
```

**方式 B：Telegram 实时预警**

1. 在 Telegram 里找 `@BotFather` 创建机器人，拿到 `token` 和你的 `chat_id`；
2. 配置文件中开启：

```json
"telegram": {
  "enabled": true,
  "token": "你的Bot_Token",
  "chat_id": "你的Chat_ID"
},
"notify": {
  "status": true,
  "entry": true,
  "exit": true,
  "fill": true
}
```

3. 策略里用 `self.dp.send_msg("...")` 发自定义消息（接口见 `freqtrade/data/dataprovider.py`）。

---

## 12. 常见问题排查

| 现象 | 原因 | 处理 |
|---|---|---|
| 启动报 `freqai not enabled` | 配置里 `freqai.enabled` 为 false | 改为 `true` |
| 报缺少 `lightgbm` | 没装 FreqAI 依赖 | `pip install -r requirements-freqai.txt` |
| 特征列不被识别 | 列名没以 `%` 开头 | 全部加 `%` 前缀 |
| 标签列不被识别 | 列名没以 `&` 开头 | 全部加 `&` 前缀 |
| 一直不开仓 | 预测达不到阈值 | 看日志 `&-s_close` 分布，降低阈值到 0.005 试 |
| 回测/运行太慢 | 训练窗口大、币种多 | 只留 `BTC/USDT`，减小 `train_period_days` |
| 换了策略但结果没变 | 复用旧 identifier | 换一个新 `identifier` |
| 合约报错 | 官方示例是期货格式 | 用现货：`trading_mode: spot`，交易对去掉 `:USDT` |
| Apple Silicon 装不上依赖 | 编译问题 | 用 Docker `stable_freqai` 镜像 |

---

## 13. 下一步建议

1. **先回测**，看 FreqAI 示例在你的 `BTC/USDT` 数据上能不能出信号、胜率如何；
2. 在官方示例基础上，**改自己的特征和标签**（例如把 `&-s_close` 换成分类标签"涨/跌"）；
3. 体验不同模型：`--freqaimodel XGBoostRegressor`、`--freqaimodel LightGBMClassifier`；
4. 接 Telegram 预警，长期 dry-run 验证；
5. 全部稳定后，再用小资金实盘（谨慎）。

---

*本教程对应的本地源码文件速查：*
- 主引擎：`freqtrade/freqtradebot.py`
- 策略接口：`freqtrade/strategy/interface.py`
- FreqAI 核心：`freqtrade/freqai/freqai_interface.py`、`freqai/data_kitchen.py`
- FreqAI 模型目录：`freqtrade/freqai/prediction_models/`
- 官方示例策略：`freqtrade/templates/FreqaiExampleStrategy.py`
- 官方示例配置：`config_examples/config_freqai.example.json`
- 官方 FreqAI 文档：`docs/freqai*.md`