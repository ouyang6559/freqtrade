# freqtrade 入门与实战：源码阅读 + AI 分析 BTC + 预警 + 自动下单

> 面向：零基础小白
> 场景：用 AI 分析 BTC/行情，得到信号 → 触发预警（发给你） → 自动下单
> 本教程基于你电脑上的 **freqtrade 官方主仓库源码（版本 2026.9-dev）** 编写，所有文件路径都对应 `/Users/liu/Documents/go/gopath/src/rust-pro/freqtrade/` 下的真实文件，边读源码边学会更快。

---

## 目录

- [0. 读完这篇你能得到什么](#0-读完这篇你能得到什么)
- [1. freqtrade 到底是个什么](#1-freqtrade-到底是个什么)
- [2. 整体源码地图（先认路再开车）](#2-整体源码地图)
- [3. 三条核心代码链路（源码阅读主线）](#3-三条核心代码链路)
- [4. 把 freqtrade 跑起来（环境准备）](#4-把-freqtrade-跑起来)
- [5. 写你的第一个策略](#5-写你的第一个策略)
- [6. 预警功能：让信号第一时间告诉你](#6-预警功能)
- [7. AI 接入路径 A：内置 FreqAI](#7-a-内置-freqai)
- [8. AI 接入路径 B：外部 AI + ExternalMessageConsumer](#8-b-外部-ai--external-message-consumer)
- [9. 下单功能：信号自动变成订单](#9-下单功能)
- [10. 完整配置示例（一键整合）](#10-完整配置示例)
- [11. 常见坑与排错](#11-常见坑与排错)
- [12. 下一步学习路线](#12-下一步)

---

## 0. 读完这篇你能得到什么

1. 看懂 freqtrade 源码**从「K线数据进来 → 策略分析 → 决定下单 → 发预警」** 的完整路径。
2. 能自己写一个**策略**，判断 BTC 什么时候该买。
3. 把判断结果**通过 Telegram 发预警**给你。
4. 用 **FreqAI（内置机器学习）** 或 **外部 AI 程序** 来生成预测信号。
5. 让 freqtrade 在收到信号后**自动下单**。

> 核心一句话：**freqtrade 是一个「数据进来 → 策略判断 → 决策下单 → 对外通知」的机器人框架，你只要写好中间的「策略判断」这一环，其余它有现成的。**

---

## 1. freqtrade 到底是个什么

简单说，它是一个**开源的加密货币自动交易框架**（Python 写的）。

它的工作流程是（这就是源码里的真实主干逻辑）：

```
交易所K线数据 (exchange)
      │
      ▼
下载/更新到本地 (DataHandler)
      │
      ▼
喂给你的策略 (strategy.populate_*)  ← 你主要写这里
      │
      ▼
产生买入/卖出信号 (entry/exit signal)
      │
      ▼
freqtradebot 决定是否真的下单 (can_hold / confirm_trade_entry)
      │
      ▼
下真实/模拟订单 (exchange.create_order)  ← 换成真钱就是"下单"
      │
      ▼
发送通知 (RPC → Telegram/Webhook)  ← "预警"在这里
```

你看一眼主入口就能印证这条链：源码 [`freqtrade/freqtradebot.py`](file:///Users/liu/Documents/go/gopath/src/rust-pro/freqtrade/freqtrade/freqtradebot.py) 里有个 `process()` 方法，它是机器人每个周期的"总调度"，里面大致就是逐环调用上面这些步骤。

它支持两种运行模式：

- **Dry-run（模拟交易）**：用真实行情，但是**模拟下单、假钱**。新手开发请永远先在这个模式下跑。
- **Live（实盘）**：用真钱。**新手前期绝对不要开。**

> 新手第一原则：**先在 dry-run 模拟跑，确认预警和下单逻辑都对，再谈实盘。**

---

## 2. 整体源码地图

先在你电脑的这个目录里逛一圈（用编辑器打开）：

```
/Users/liu/Documents/go/gopath/src/rust-pro/freqtrade/
├── freqtrade/                  ← 核心源码（重点看这里）
│   ├── freqtradebot.py         ← 机器人主引擎：驱动整个运行循环
│   ├── strategy/               ← 策略相关
│   │   ├── interface.py        ← IhqStrategy 接口：你写策略的"说明书"
│   │   └── strategy_wrapper.py ← 帮你包装策略方便回测
│   ├── data/                   ← 数据层
│   │   ├── dataprovider.py     ← DataProvider：在策略里取K线/喂数据
│   │   └── history.py          ← 历史K线下载/保存
│   ├── exchange/               ← 交易所适配层（每家的接口封装）
│   ├── freqai/                 ← AI：内置机器学习预测模块 ★本文重点之一
│   ├── rpc/                    ← 通知/告警系统（Telegram等）
│   │   ├── rpc.py              ← 通知核心
│   │   ├── telegram.py         ← Telegram 机器人实现
│   │   └── external_message_consumer.py ← 接外部AI信号 ★本文重点之二
│   ├── configuration/          ← 读取/校验你的配置文件
│   └── commands/               ← 命令行入口（trade/backtesting等）
├── config_examples/            ← 官方配置示例
├── docs/                       ← 官方文档（写得很全，随时查）
├── user_data/                  ← 你自己的工作区（策略就放这里）
│   └── strategies/             ← 【新手策略目录】放你的 .py 策略
├── pyproject.toml              ← 版本/依赖定义（版本 2026.9-dev）
└── README.md                   ← 官方简介
```

**阅读建议（从小白视角）：**

| 顺序 | 文件 | 为什么看 | 难度 |
|------|------|----------|------|
| 1 | `freqtrade/commands/trade.py` | 命令入口，一个指令怎么拉起机器人 | ☆ |
| 2 | `freqtrade/freqtradebot.py` | 主引擎 `process()`，看整体流程 | ☆☆☆ |
| 3 | `freqtrade/strategy/interface.py` | 你写策略必须学的类 | ☆☆☆ |
| 4 | `freqtrade/data/dataprovider.py` | 策略里怎么取K线 | ☆☆ |
| 5 | `freqtrade/rpc/telegram.py` | 预警通知怎么发 | ☆☆ |

> 别急着把每个文件读完，先读 2 和 3，这是你写策略的必修课。

---

## 3. 三条核心代码链路

### 3.1 链路一：策略是怎么分析K线的（最重要）

策略的基类在 [`freqtrade/strategy/interface.py`](file:///Users/liu/Documents/go/gopath/src/rust-pro/freqtrade/freqtrade/strategy/interface.py)，里面有三个抽象方法，就是 freqtrade 给你规定的"写作顺序"：

```python
class IhqStrategy:
    # ① 计算指标：把原始K线变成"有均线、有RSI、有AI预测"的数据表
    def populate_indicators(self, dataframe, metadata) -> DataFrame: ...

    # ② 用指标决定买：标记哪些K线"该买" → 产生买入信号
    def populate_entry_trend(self, dataframe, metadata) -> DataFrame: ...

    # ③ 用指标决定卖：标记哪些K线"该卖" → 产生退出信号
    def populate_exit_trend(self, dataframe, metadata) -> DataFrame: ...
```

- `dataframe`：是一根根 K 线组成的表格（pandas 的 DataFrame），`metadata` 里有当前交易对（如 `BTC/USDT`）。
- 你在表格里新增一列，比如 `dataframe['entry']`，把"该买"的那根K线那一行设为 `1`，其余为 `0`，就产出了一个买入信号。freqtrade 看到 `entry` 列为 1，就会尝试买入。

> **这就是"下单功能"的最原始来源**：`entry` 信号 = 要买，`exit` 信号 = 要卖。
> 注意：源码里 `populate_buy_trend` / `populate_sell_trend` 是**旧名已弃用**，请看上面注释 —— 新版统一用 `entry / exit`。

### 3.2 链路二：机器人怎么"思想斗争"后下单

即使有 `entry=1`，freqtrade 也不会直接梭哈，它会在 [`freqtrade/freqtradebot.py`](file:///Users/liu/Documents/go/gopath/src/rust-pro/freqtrade/freqtrade/freqtradebot.py) 里做一堆检查（有没有可用资金、是否已在同币种持仓、手续费、滑点等），还会回调你的策略方法让你"把关"：

- `confirm_trade_entry(...)`：返回 `True` 才真买。你可以在里面**二次确认**（比如"只有 AI 信心 > 0.8 才买"）。
- `custom_stake_amount(...)`：自定义下多少金额。

### 3.3 链路三：怎么发出预警

机器人决策后，会调 RPC 通知层（`freqtrade/rpc/`）把消息发给 Telegram 等。你在自己的**策略方法里**也能主动发自定义预警，看 [`freqtrade/data/dataprovider.py`](file:///Users/liu/Documents/go/gopath/src/rust-pro/freqtrade/freqtrade/data/dataprovider.py) 的第 614 行左右：

```python
self.dp.send_msg("我是策略里发出来的预警，比如：BTC 突破 12000，注意！")
```

> `self.dp` 就是 `DataProvider`，`send_msg` 会把消息推到所有配置好的通知渠道（Telegram/Webhook）。**这就是你自定义预警的核心调用。**

---

## 4. 把 freqtrade 跑起来

### 4.1 环境准备（macOS）

确认你电脑有 Python 3.10+ 和 Git：

```bash
python3 --version
cd /Users/liu/Documents/go/gopath/src/rust-pro/freqtrade
```

因为这是官方源码仓库，最省心的做法是**用它的自带脚本装进独立环境**（源码里就有）：

```bash
# 用源码仓库自带的安装脚本（会创建虚拟环境并装依赖）
./setup.sh -i
# 或直接创建自己的 Python 虚拟环境
python3 -m venv .venv
source .venv/bin/activate
pip install -e . -r requirements.txt
```

> 如果你本机已经全局可运行 `freqtrade` 命令，直接跳到下一步。

验证安装：

```bash
freqtrade --version
# 可能出现：2026.9-dev
```

### 4.2 下载 BTC 历史数据（先用它练手）

freqtrade 需要本地有行情数据才能回测/开发：

```bash
# 下载 BTC/USDT 从 2023-01-01 至今的 1h K线
freqtrade download-data \
  --config config_examples/config_telegram.example.json \
  --pairs BTC/USDT \
  --timeframe 1h \
  --timerange 20230101-
```

数据会存到 `user_data/data/binance/BTC_USDT-1h-*.feather`。

> 参数含义：`--pairs` 交易对，`--timeframe` 周期（1h=1小时线），`--timerange` 起始时间。
> 对 AI/预警新手，建议同时下小周期来判断更灵敏，例如 `5m`（5分钟线，也下载一份）。

---

## 5. 写你的第一个策略

策略要放到 `user_data/strategies/` 下。这里写一个**最简策略**：价格超过 20 周期均线就觉得该买，跌破就觉得该卖。

新建文件 `user_data/strategies/HelloBtc.py`：

```python
from freqtrade.strategy import IStrategy, DecimalParameter
import talib.abstract as ta
import pandas as pd
from pandas import DataFrame


class HelloBtc(IStrategy):
    """最简示例：均线金叉/死叉简化版"""

    # 用 1 小时线
    timeframe = '1h'

    # ---- 风险/仓位控制 ----
    minimal_roi = {  # 收益到达即考虑止盈
        "60": 0.01,  # 持仓60分钟，盈利1%就倾向卖出
        "0": 0.05,   # 盈利5%直接卖出
    }
    stoploss = -0.02      # 亏损2%强制止损
    trailing_stop = True  # 移动止损

    def populate_indicators(self, dataframe: DataFrame, metadata: dict) -> DataFrame:
        """① 计算指标：20 周期简单均线"""
        dataframe['ma20'] = ta.SMA(dataframe, timeperiod=20)
        return dataframe

    def populate_entry_trend(self, dataframe: DataFrame, metadata: dict) -> DataFrame:
        """② 买卖信号：收盘价突破均线 → 买"""
        dataframe.loc[
            dataframe['close'] > dataframe['ma20'],
            'enter_long'] = 1
        return dataframe

    def populate_exit_trend(self, dataframe: DataFrame, metadata: dict) -> DataFrame:
        """③ 退出信号：收盘价跌破均线 → 卖"""
        dataframe.loc[
            dataframe['close'] < dataframe['ma20'],
            'exit_long'] = 1
        return dataframe
```

> 原理回顾（对应 `interface.py` 的三个方法）：`ma20` 是均线；`enter_long` 列标 1 的地方=买入信号；`exit_long`=卖出信号。你现在就相当于写了一个"AI"的雏形——只不过规则很机械。

### 5.1 跑起来看效果

```bash
# 用官方 telegram 配置模板当作基础配置（先不配 telegram 也能跑）
freqtrade trade \
  --config config_examples/config_telegram.example.json \
  --strategy HelloBtc \
  --pairs BTC/USDT \
  --timerange 20240101-
```

默认是 dry-run 模拟。你会看到日志里出现 `Enter Long / Exit Long` 的记录、`Trade` 创建等。**这说明"最简单的下单"已经跑通了。**

---

## 6. 预警功能：让信号第一时间告诉你

预警就是"把策略里发生的事主动推给你"。freqtrade 支持多种渠道。这里重点讲 **Telegram 自建 bot**（最常用、免费）和 **策略自定义预警**。

### 6.1 注册一个 Telegram 机器人（一次即可）

1. 打开 Telegram，搜索 `@BotFather`，发送 `/newbot`。
2. 按提示命名，BotFather 会给你一个 **token**，形如 `123456:ABC-DEF...`。
3. 用"跟我说话"，找到你的 **chat_id**：
   - 最简单的办法：把你的 bot 拉进一个群，群里发条消息，然后在浏览器访问 `https://api.telegram.org/bot<TOKEN>/getUpdates`，返回 JSON 里的 `chat.id` 就是。
4. 记住两样：**token** 和 **chat_id**。

### 6.2 在配置里开启 telegram

新建你自己的配置 `user_data/config_btc.json`：

```json
{
  "telegram": {
    "enabled": true,
    "token": "你拿到的TOKEN",
    "chat_id": "你的chat_id"
  },
  "notify": {
    "status": true,
    "entry": true,
    "exit": true,
    "fill": true,
    "cancel": true,
    "startup": true
  }
}
```

启动后，freqtrade 默认会在**启动、开仓、平仓、成交、取消**时发 Telegram 消息给你——这就是内置的自动预警。

### 6.3 策略里发"自定义预警"（AI 信号一到就喊你）

在你策略的 `populate_indicators` 里，检测到信号时主动 `send_msg`。看 [`dataprovider.py`](file:///Users/liu/Documents/go/gopath/src/rust-pro/freqtrade/freqtrade/data/dataprovider.py) 第 614 行的用法：

```python
def populate_indicators(self, dataframe: DataFrame, metadata: dict) -> DataFrame:
    pair = metadata['pair']
    # 模拟：AI 预测下一根会涨
    dataframe['ai_predict'] = 1.0  # 这里将来换成真实AI预测值

    # 当 AI 预测接近最高分、且收盘价站上均线时，发一条预警
    last = dataframe.iloc[-1]
    if last['ai_predict'] >= 0.9 and last['close'] > last['ma20']:
        self.dp.send_msg(
            f"⚠️ 预警：{pair} 出现AI看多信号！\n"
            f"预测分={last['ai_predict']:.2f}, 现价={last['close']:.2f}"
        )
    return dataframe
```

> `metadata['pair']` 就是当前币种（如 `BTC/USDT`）。你在策略里调 `self.dp.send_msg(...)`，消息就会进到 Telegram。**这就是"把外部/AI 分析结果变成预警"的标准姿势。**

### 6.4 不想要 Telegram 的其他预警方式

- **日志**：直接 `self.logger.info("预警...")`，看控制台/`user_data/logs`。
- **Webhook**：配置 `"webhook": {...}` 即可推到群机器人/企业微信。适合已经把 AI 放到自己服务器的人。

---

## 7. AI 接入路径 A：内置 FreqAI

如果你**没有**自己的 AI 程序，最省事的是用 freqtrade 内置的 **FreqAI**：它帮你做「用历史数据训练机器学习模型 → 对当前行情预测」，预测结果直接写进你的策略。

> FreqAI 入口在源码 [`freqtrade/freqai/`](file:///Users/liu/Documents/go/gopath/src/rust-pro/freqtrade/freqtrade/freqai)。它从 `freqtrade/strategy/interface.py` 的 `load_freqAI_model()` 被加载启动。

### 7.1 最小开启步骤

**① 装依赖（二选一）：**

```bash
pip install -r requirements-freqai.txt          # sklearn/lightgbm
# 或用强化学习：pip install -r requirements-freqai-rl.txt
```

**② 配置开启 freqai：** 在 `user_data/config_btc.json` 加：

```json
{
  "freqai": {
    "enabled": true,
    "purge_old_models": 2,
    "train_period_days": 30,
    "backtest_period_days": 7,
    "identifier": "btc-predict",
    "feature_parameters": {
      "include_timeframes": ["1h"],
      "include_corr_pairs": ["BTC/USDT"],
      "label_period_candles": 24,
      "include_shifted_candles": 2,
      "indicator_periods_candles": [10, 20]
    },
    "data_split_parameters": { "test_size": 0.2 }
  }
}
```

**③ 策略里用 AI 预测：** 你的策略写法变成"指标里多了一个模型输出列"：

```python
def populate_indicators(self, dataframe: DataFrame, metadata: dict) -> DataFrame:
    # FreqAI 会训练模型，并把预测结果写进 dataframe
    self.freqai.start(dataframe, metadata)

    # 预测列：0~1 之间的"看涨概率"（标签列由 label_period_candles 决定）
    # 你把它当做一个"AI 得分"
    return dataframe

def populate_entry_trend(self, dataframe: DataFrame, metadata: dict) -> DataFrame:
    # 只有 AI 得分高才买
    dataframe.loc[
        (dataframe['&-lookahead'] >= 0.6),
        'enter_long'] = 1
    return dataframe
```

> FreqAI 具体列名（`&-lookahead` 等）取决于你配置的 `label` 与 `indicator`，最稳妥的入门方式是**阅读官方文档 `docs/freqai.md`**，它有一整套示例策略。这里先让你理解"它把机器学习的预测塞进 dataframe，供你当信号用"这个核心理念。

---

## 8. AI 接入路径 B：外部 AI + ExternalMessageConsumer

如果你的 BTC 分析程序（Python/其他语言都行）**已经独立在算**，你不需要 FreqAI 帮你训练模型——你只需要把外部 AI 的信号**喂给 freqtrade**，让它预警并下单。

官方为此设计了**生产者/消费者**机制，见源码 [`freqtrade/rpc/external_message_consumer.py`](file:///Users/liu/Documents/go/gopath/src/rust-pro/freqtrade/freqtrade/rpc/external_message_consumer.py)：你的外面 AI 程序当 **Producer**（用 websocket 往 freqtrade 推送 K 线/信号），freqtrade 当 **Consumer**（在策略里用 `self.dp.get_producer_df(...)` 拿到外部数据）。

### 8.1 整体架构

```
你的AI程序（Producer）         freqtrade（Consumer）
  + 算BTC行情/信号                   + 启动时连接 websocket 端口
  + 定期发送数据                      + 策略里读取外部数据
       │                                    ▲
       └──── websocket (port: 端口号) ──────┘
                你的AI自己定义字段，比如 confidence
```

### 8.2 在 freqtrade 配置文件里开启消费外部数据

```json
{
  "external_message_consumer": {
    "enabled": true,
    "producers": [
      {
        "name": "my_btc_ai",
        "host": "127.0.0.1",
        "port": 18080,
        "ws_token": ""
      }
    ]
  }
}
```

### 8.3 在策略里读取外部 AI 信号

```python
def populate_indicators(self, dataframe: DataFrame, metadata: dict) -> DataFrame:
    pair = metadata['pair']
    # 从外部 Producer 拿它推送过来的、已经算好的K线（含AI字段）
    producer_df, _ = self.dp.get_producer_df(pair, timeframe=self.timeframe,
                                             producer_name="my_btc_ai")
    if len(producer_df) > 0 and 'confidence' in producer_df.columns:
        # 把外部AI给的 confidence 列合并到我们的策略表里
        dataframe['ai_conf'] = producer_df['confidence']
    return dataframe

def populate_entry_trend(self, dataframe: DataFrame, metadata: dict) -> DataFrame:
    # 外部 AI 信心 ≥ 0.8 就买
    if 'ai_conf' in dataframe.columns:
        dataframe.loc[dataframe['ai_conf'] >= 0.8, 'enter_long'] = 1
    return dataframe
```

> 注意：`get_producer_df` 返回的是 Producer 推送的分析K线（`freqtrade/data/dataprovider.py` 第 258 行）。**你的 AI 里自定义的字段（这里叫 `confidence`）它会原样带过来。** 这个"外部 AI 信号 → 预警/下单"就是你要的核心能力。

### 8.4 Producer 端怎么发（给你的 AI 程序参考）

官方提供了 freqtrade 作为 Producer 的现成实现，也提供 `ft_client`（仓库里 `ft_client/` 目录就是一个给外部程序用的客户端封装）。你的 AI 无需重造轮子，只需：建一个 websocket server，定期用 freqtrade 定义的协议把 DataFrame 推过去。**入门阶段，建议先跑通上面的 Consumer 端读取，等理解机制后再写 Producer 端。**

---

## 9. 下单功能：信号自动变成订单

到这一步，你已经有了"ai_conf ≥ 0.8 就发出 `entry` 信号"。freqtrade 会在 `process()` 循环里看到这个信号，然后**下单**。

想让下单更稳，你可以用策略里的「把关方法」二次确认，它们在 [`freqtrade/strategy/interface.py`](file:///Users/liu/Documents/go/gopath/src/rust-pro/freqtrade/freqtrade/strategy/interface.py)：

```python
def confirm_trade_entry(self, pair, order_type, amount, rate,
                        time_in_force, current_time, entry_tag, side,
                        **kwargs) -> bool:
    """AI信心不够就不买 —— 这里等于给下单加一道保险"""
    dataframe, _ = self.dp.get_analyzed_dataframe(pair, self.timeframe)
    if len(dataframe) == 0:
        return False
    last = dataframe.iloc[-1]
    if 'ai_conf' in dataframe.columns:
        if last['ai_conf'] < 0.8:
            self.dp.send_msg(f"🔒 {pair} 信心不足({last['ai_conf']:.2f})，不下单")
            return False
    return True  # 通过检查，才真正下单

def custom_stake_amount(self, pair, current_time, current_rate,
                        proposed_stake, min_stake, max_stake,
                        leverage, entry_tag, side, **kwargs) -> float:
    """根据 AI 信心决定投入多少钱"""
    dataframe, _ = self.dp.get_analyzed_dataframe(pair, self.timeframe)
    if len(dataframe) == 0:
        return 0
    last = dataframe.iloc[-1]
    conf = last['ai_conf'] if 'ai_conf' in dataframe.columns else 0.5
    # 信心越足，仓位越大（0~1000 USDT 之间）
    return float(commandusage.conf2stake(conf))
```

> 上面 `commandusage.conf2stake` 只是个示意写法，实际你直接写 `min(max(conf * 1000, min_stake), 1000)` 即可。重点是明白：**`confirm_trade_entry` 决定"要不要买"，`custom_stake_amount` 决定"买多少"。**

下单的下限校验（金额太小不买）、费率等都是框架自动处理，你不需要关心细节。

---

## 10. 完整配置示例（一键整合）

把你前面所有片段拼成一份可用配置 `user_data/config_btc.json`（**实盘前记得把 `dry_run` 改 false**）：

```json
{
  "max_open_trades": 3,
  "stake_currency": "USDT",
  "stake_amount": "unlimited",
  "tradable_balance_ratio": 0.99,
  "fiat_display_currency": "USD",
  "dry_run": true,
  "dry_run_wallet": 1000,
  "timeframe": "1h",
  "pairs": ["BTC/USDT"],
  "ticker_interval": "1h",
  "exchange": {
    "name": "binance",
    "key": "",
    "secret": "",
    "ccxt_config": {},
    "ccxt_sync_config": {},
    "pair_whitelist": ["BTC/USDT"]
  },
  "telegram": {
    "enabled": true,
    "token": "你的Token",
    "chat_id": "你的chat_id"
  },
  "freqai": {
    "enabled": false,
    "identifier": "btc-predict",
    "train_period_days": 30,
    "backtest_period_days": 7,
    "feature_parameters": {
      "include_timeframes": ["1h"],
      "indicator_periods_candles": [20]
    },
    "data_split_parameters": { "test_size": 0.2 }
  },
  "external_message_consumer": {
    "enabled": false,
    "producers": []
  },
  "entry_pricing": { "price_side": "same", "use_order_book": true },
  "exit_pricing": { "price_side": "same", "use_order_book": true }
}
```

启动命令（dry-run 模拟，最安全）：

```bash
freqtrade trade --config user_data/config_btc.json --strategy HelloBtc
```

你会看到日志流水 + Telegram 收到启动通知。当 `ai_conf` 达标，就会看到开仓（Enter Long）与预警消息。

> 建议先用回测验证策略稳定性，再上 dry-run，最后才考虑实盘：
> ```bash
> freqtrade backtesting --config user_data/config_btc.json --strategy HelloBtc --timerange 20240101-
> ```

---

## 11. 常见坑与排错

| 现象 | 原因 | 解决 |
|------|------|------|
| `OperationalException: freqAI is not enabled` | 策略用了 `self.freqai` 但配置没开 `freqai.enabled` | 参考第7.1节开启 |
| 没收到 Telegram | `notify`/`telegram` 没配对，或 chat_id 错误 | 核对 token/chat_id，开 `"loggers": { "telegram": true }` |
| 一直不开仓 | 信号没算出来/资金小于 `minimal_roi` 最小交易额 | 打印 `dataframe` 检查 `ai_conf` 是否有值、金额是否够 |
| `get_producer_df` 返回空 | Producer 没连上/没推送 | 确认 `external_message_consumer.producers` 端口与 AI 端一致，先只开 consumer 联网测试 |
| 版本报错接口不对 | 旧教程用的 `buy`/`sell`，本仓库已是 `entry`/`exit` | 以本仓库源码 `interface.py` 为准 |

**永远的最稳排错法**：回测跑一遍，看日志里每次信号是否如你所愿，再上模拟盘。

---

## 12. 下一步学习路线

1. 读熟 `freqtrade/strategy/interface.py`（你所有策略能力的说明书）。
2. 看 `freqtrade/freqtradebot.py` 的 `process()`，理解一个周期到底做了什么。
3. 用 dry-run 把你的 `HelloBtc` 跑满整个周末，熟悉日志与 Telegram。
4. 接入真实 AI：路径 A 学 `docs/freqai.md` 的示例策略；路径 B 写 Producer 端，把你自己 AI 的 `confidence` 推给你。
5. 策略稳定后再用 `backtesting` 参数寻优，最后才考虑实盘（谨慎！）。

祝你从"看懂源码"到"AI 信号 → 预警 → 自动下单"一路顺利。遇到问题，先回看对照本文的源码路径，再去 `docs/` 找答案。