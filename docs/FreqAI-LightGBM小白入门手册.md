# FreqAI 小白入门手册（LightGBM ¥预测 BTC 信号）

> 适用：零基础，目标是用 freqtrade 内置 FreqAI + **LightGBM** 自动分析 BTC 行情、给出预测信号，并接上**预警**和**自动下单**。
> 本手册代码全部来自你的本地仓库（版本 `2026.9-dev`）真实文件，可直接对照：
> - 示例策略：`freqtrade/templates/FreqaiExampleStrategy.py`
> - 示例配置：`config_examples/config_freqai.example.json`
> - 内置模型：`freqtrade/freqai/prediction_models/LightGBMRegressor.py`

---

## 目录
- [0. 一页看懂 FreqAI 在干嘛](#0-一页看懂)
- [1. 最重要的一句话（先记住这三个词）](#1-最重要的概念)
- [2. 装依赖 + 准备数据](#2-装依赖--准备数据)
- [3. 一份可直接跑的配置（现货 BTC 版）](#3-配置)
- [4. 策略源码逐段拆解](#4-策略源码拆解)
- [5. 用一条命令跑起来](#5-跑起来)
- [6. 把"预测信号"变成预警和下单](#6-预警与下单)
- [7. 常见坑](#7-常见坑)
- [8. 下一步](#8-下一步)

---

## 0. 一页看懂 FreqAI 在干嘛

```
历史K线(特征 %xxx) + 未来结果(标签 &xxx)
        ↓
LightGBM 训练一个"从特征预测未来"的模型
        ↓
每次来新K线 → 模型预测 → 输出一列 [&-s_close] 预测值 + [do_predict] 可信度
        ↓
你的策略读这两列 → 达标就买/卖 → 触发预警 + 自动下单
```

**核心：FreqAI 核心是用机器学习在上千个指标里找规律，代替你手写"RSI>70 就买"之类的死规则。你喂特征和标签，它负责训练、滚动重训、实时预测。**

---

## 1. 最重要的概念

看代码前，先记这三个"暗号"，全部体现在源码注释里（`interface.py`）：

| 暗号 | 含义 | 例子 |
|---|---|---|
| **`%`** 前缀的列 | 喂给模型的**特征**（输入） | `%-rsi-period`、`%-sma-period` |
| **`&`** 前缀的列 | 让模型学会预测的**标签**（输出目标） | `&-s_close`（未来涨幅） |
| `do_predict` | FreqAI 额外给的**可信度**，1=可信任这次预测 | 0 或 1 |

你在 `populate_indicators` 里必须调 `self.freqai.start(dataframe, metadata, self)`，它才会训练模型、预测、并把上面这些列写回。

---

## 2. 装依赖 + 准备数据

```bash
cd /Users/liu/Documents/go/gopath/src/rust-pro/freqtrade
# 进入虚拟环境（没有就先：python3 -m venv .venv && source .venv/bin/activate）
source .venv/bin/activate

# 装 FreqAI 依赖（LightGBM 就在里面）
pip install -r requirements-freqai.txt

# 下载训练所需数据：你的交易对 + 相关币种（corr）
freqtrade download-data \
  --config config_examples/config_freqai.example.json \
  --pairs BTC/USDT:USDT ETH/USDT:USDT \
  --timeframe 3m 15m 1h \
  --timerange 20240101-
```

> 若你是现货（不是合约），把 `:USDT` 后缀去掉（如 `BTC/USDT`）。FreqAI 需要**多个时间周期**的数据，因为官方模板用了 `3m/15m/1h` 三个周期当特征。

---

## 3. 配置

新建 `user_data/config_freqai_btc.json`（这是给小白的最简现货版，基于官方配置改造）：

```json
{
  "trading_mode": "spot",
  "max_open_trades": 3,
  "stake_currency": "USDT",
  "stake_amount": "unlimited",
  "tradable_balance_ratio": 0.99,
  "dry_run": true,
  "dry_run_wallet": 1000,
  "timeframe": "3m",
  "exchange": {
    "name": "binance",
    "api_key": "你的key",
    "secret": "你的secret",
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
  "bot_name": "btc-ai-bot",
  "internals": {
    "process_throttle_secs": 5
  }
}
```

**小白先别动**：`train_period_days`（每次用多久历史训练）、`label_period_candles`（预测未来多少根K线）、`indicator_periods_candles`（特征周期）。等跑通后再调优。

---

## 4. 策略源码拆解

复制下面的策略到 `user_data/strategies/BtcLgbStrategy.py`。它的主体就是官方模板那套，我只加了注释和一段预警代码：

```python
import logging
from functools import reduce

import talib.abstract as ta
from pandas import DataFrame
from technical import qtpylib

from freqtrade.strategy import IStrategy

logger = logging.getLogger(__name__)

class BtcLgbStrategy(IStrategy):
    # ---------- 风控与交易参数 ----------
    timeframe = '3m'                # K线周期，要和配置里一致
    minimal_roi = {"0": 0.05}       # 盈利5%就考虑止盈
    stoploss = -0.03                # 亏3%止损
    can_short = False               # 先只做多
    startup_candle_count = 40       # 启动预热K线数

    # ---------- ① 特征函数：给模型当"输入"的柱子 ----------
    def feature_engineering_expand_all(self, dataframe, period, metadata, **kwargs):
        # 注意：特征列一律以 % 开头，FreqAI 会自动按周期/多周期自动扩充
        dataframe["%-rsi-period"]    = ta.RSI(dataframe, timeperiod=period)
        dataframe["%-mfi-period"]    = ta.MFI(dataframe, timeperiod=period)
        dataframe["%-sma-period"]    = ta.SMA(dataframe, timeperiod=period)
        dataframe["%-ema-period"]    = ta.EMA(dataframe, timeperiod=period)
        dataframe["%-adx-period"]    = ta.ADX(dataframe, timeperiod=period)
        dataframe["%-roc-period"]    = ta.ROC(dataframe, timeperiod=period)
        return dataframe

    def feature_engineering_standard(self, dataframe, metadata, **kwargs):
        # 不做自动扩充的特征（比如时间信息）
        dataframe["%-hour_of_day"] = dataframe["date"].dt.hour
        return dataframe

    # ---------- ② 标签函数：定义"想让模型预测什么" ----------
    def set_freqai_targets(self, dataframe, metadata, **kwargs):
        # 标签列以 & 开头：预测未来 label_period_candles 根K线内的平均涨幅
        dataframe["&-s_close"] = (
            dataframe["close"]
            .shift(-self.freqai_info["feature_parameters"]["label_period_candles"])
            .rolling(self.freqai_info["feature_parameters"]["label_period_candles"])
            .mean()
            / dataframe["close"]
            - 1
        )
        return dataframe

    # ---------- ③ 让 FreqAI 训练+预测，并写回预测列 ----------
    def populate_indicators(self, dataframe, metadata):
        dataframe = self.freqai.start(dataframe, metadata, self)
        # 现在 dataframe 里有模型预测列：&-s_close 和 do_predict
        return dataframe

    # ---------- ④ 买：模型预测涨 + 预测可信，才买 ----------
    def populate_entry_trend(self, df, metadata):
        conds = [
            df["do_predict"] == 1,       # 预测可信
            df["&-s_close"] > 0.01,      # 模型预测未来能涨超1%
        ]
        df.loc[reduce(lambda x, y: x & y, conds), ["enter_long", "enter_tag"]] = (1, "ai_long")
        return df

    # ---------- ⑤ 卖：模型预测涨不动了就卖 ----------
    def populate_exit_trend(self, df, metadata):
        df.loc[df["&-s_close"] < 0, "exit_long"] = 1
        return df

    # ---------- ⑥ 预警：每次新预测更新时，可把结果推给Telegram/日志 ----------
    def confirm_trade_entry(self, pair, order_type, amount, rate, time_in_force,
                            current_time, entry_tag, side, **kwargs) -> bool:
        df, _ = self.dp.get_analyzed_dataframe(pair, self.timeframe)
        last = df.iloc[-1]
        # 自定义预警：预测值变化大时提醒你
        self.logger.info(f"[预警] {pair} 模型预测={last.get('&-s_close', 0):.4f} "
                         f"可信度={last.get('do_predict','?')}")
        # self.dp.send_msg(f"📊 {pair} AI信号：{last['&-s_close']:.4f}")  # 接Telegram后取消注释
        return True  # 放行下单
```

**核心就 6 个方法**，和之前讲策略的规矩完全一样（`interface.py` 那套），只是把"手写指标判断"换成了"读模型输出"。

---

## 5. 跑起来

```bash
# 先回测看看逻辑是否成立（最安全）
freqtrade backtesting \
  --config user_data/config_freqai_btc.json \
  --strategy BtcLgbStrategy \
  --freqaimodel LightGBMRegressor \
  --timerange 20240101-

# 再实盘模拟（dry-run，假钱真行情）
freqtrade trade \
  --config user_data/config_freqai_btc.json \
  --strategy BtcLgbStrategy \
  --freqaimodel LightGBMRegressor
```

运行后你会看到：自动下载数据 → `LightGBM training` 训练日志 → 然后"边交易边训练"。这说明模型已经跑起来了。

---

## 6. 把"预测信号"变成预警和下单

- **自动下单**：其实第 4 节已经实现了——`enter_long` 为 1 时，freqtrade 的 `process()` 会自动下单（dry-run 假钱）。`confirm_trade_entry` 返回 True/False 可以决定"要不要真下单"，相当于 AI 信号再加一道保险。
- **预警**：两种方式二选一：
  1. **先看日志**（小白推荐）：上面第 ⑥ 步的 `self.logger.info(...)` 已把 AI 预测打到终端/日志。
  2. **接Telegram**：配置里 `"telegram": { "enabled": true, "token": "...", "chat_id": "..." }`，再把第 ⑥ 步里 `self.dp.send_msg(...)` 那行取消注释，每次开仓/异常时就能实时推给你。

> 预警消息在**策略里**用 `self.dp.send_msg(...)`（见 `freqtrade/data/dataprovider.py`），下单通知则由 freqtrade 在 `freqtrade/freqtradebot.py` 成交后自动发。两者互不冲突。

---

## 7. 常见坑

| 现象 | 原因 | 处理 |
|---|---|---|
| 报 `freqai not enabled` | 配置里 `freqai.enabled` 是 false | 确认改成 `true` |
| 特征列报错 `%` 开头才认识 | 手滑写成了普通列名 | 所有特征加 `%`，标签加 `&` |
| 一直不出信号 | `do_predict` 常为 0，或 `&-s_close` 达不到 0.01 | 看日志里模型预测值分布；阈值可调小到 0.005 试 |
| 合约报错/只想要现货 | 配置 `trading_mode` 没配对 | 现货用 `spot`，交易对去掉 `:USDT` |
| 启动慢 | 要下载多周期+相关币数据 | 确认第 2 步数据已下全 |
| 模型一直重训、卡 | 交易对太多/周期太多 | whitelist 只留 `BTC/USDT` 起手 |

---

## 8. 下一步

1. 先把 dry-run 跑满一两天，看日志里 `&-s_close` 预测分布是否合理。
2. 调 `label_period_candles` 和阈值（0.01）改变敏感度。
3. 想换模型就改 `--freqaimodel XGBoostRegressor`（模型列表见 `freqtrade/freqai/prediction_models/` 目录）。
4. 稳定后接 Telegram 预警，再考虑调参上实盘（谨慎！新手强烈建议长期停留在 dry-run 或回测）。

祝你第一步跑通 FreqAI + LightGBM。遇到具体报错，把日志贴出来，我帮你定位。