# Python 语法入门总结 —— 以 freqtrade 源码为教材

> 这份文档面向零基础读者，所有示例代码都摘自 freqtrade 项目源码（标注了出处文件）。
> freqtrade 是一个用 Python 写的开源加密货币交易机器人，代码风格规范、贴近业界习惯，
> 非常适合当作"真实世界的 Python 教材"来读。
>
> 读完后你不需要能看懂全部业务逻辑，只需要掌握：**Python 语言本身的语法** +
> **这个项目里策略文件怎么写**。

---

## 目录

1. [项目是什么 & 目录导览](#1-项目是什么--目录导览)
2. [读 Python 代码前必须知道的三件事](#2-读-python-代码前必须知道的三件事)
3. [变量与基本类型](#3-变量与基本类型)
4. [字符串与 f-string](#4-字符串与-f-string)
5. [容器：list / dict / tuple](#5-容器list--dict--tuple)
6. [推导式](#6-推导式)
7. [控制流：if / while / 三元表达式](#7-控制流)
8. [函数 def](#8-函数-def)
9. [类与对象（重点）](#9-类与对象重点)
10. [枚举 Enum](#10-枚举-enum)
11. [dataclass 数据类](#11-dataclass-数据类)
12. [类型注解](#12-类型注解)
13. [异常处理](#13-异常处理)
14. [import 与模块](#14-import-与模块)
15. [装饰器 @](#15-装饰器-)
16. [日志 logging](#16-日志-logging)
17. [策略文件专属语法（pandas）](#17-策略文件专属语法pandas)
18. [程序是怎么跑起来的](#18-程序是怎么跑起来的)
19. [学习路线建议](#19-学习路线建议)

---

## 1. 项目是什么 & 目录导览

freqtrade：免费、开源的**加密货币量化交易机器人**。你用 Python 写一个"策略"（决定什么时候买、什么时候卖），机器人负责连接交易所、下单、记账、发通知。

```
freqtrade/                  ← 项目根目录
├── freqtrade/              ← 主源码包（Python 包）
│   ├── strategy/           ← 策略接口定义（用户最常打交道的地方）
│   ├── templates/          ← 模板，含示例策略 sample_strategy.py ★入门必读
│   ├── freqtradebot.py     ← 交易主逻辑
│   ├── worker.py           ← 主循环（程序的心跳）
│   ├── main.py             ← 程序入口
│   ├── exchange/           ← 对接各大交易所
│   ├── persistence/        ← 数据库，保存成交记录
│   ├── optimize/           ← 回测(backtesting)和参数优化(hyperopt)
│   ├── enums/              ← 各种枚举类型
│   └── rpc/                ← Telegram / API 通知
├── config_examples/        ← 配置文件示例
├── user_data/strategies/   ← 你自己写的策略放这里
└── tests/                  ← 单元测试
```

**入门只需要精读三个文件**：`freqtrade/templates/sample_strategy.py`（策略怎么写）、`freqtrade/main.py`（入口）、`freqtrade/worker.py`（主循环）。

---

## 2. 读 Python 代码前必须知道的三件事

### ① 缩进就是语法

Python 不用 `{ }` 表示代码块，**用缩进（4 个空格）**。缩进错了程序直接报错：

```python
if state == State.STOPPED:          # 冒号结尾，下一行缩进
    self._notify("WATCHDOG=1")      # 属于 if 的代码块
    self._throttle(func=...)        # 还是 if 的代码块
# 这里缩进还原，说明 if 结束了
```

### ② 注释和文档字符串

```python
# 井号开头是单行注释，Python 会忽略它

def populate_indicators(self, dataframe, metadata):
    """
    三引号包起来的是"文档字符串"(docstring)，
    写在函数/类的第一行，用来说明这个函数是干什么的。
    """
```

### ③ 一个 `.py` 文件就是一个"模块"

`freqtrade/worker.py` 就是模块 `worker`，别的文件用 `import` 来使用它。

---

## 3. 变量与基本类型

Python 变量**不需要声明类型**，直接赋值即可（这叫"动态类型"）：

```python
# 摘自 templates/sample_strategy.py
INTERFACE_VERSION = 3          # int 整数
stoploss = -0.10               # float 浮点数（小数）
timeframe = "5m"               # str 字符串
trailing_stop = False          # bool 布尔值，只有 True / False 两种
can_short: bool = False        # 冒号写法是"类型注解"，只是给人看的提示，不强制
```

还有一个特殊的"空值"：

```python
self._sd_notify = None         # None 表示"什么都没有"
```

> 小贴士：Python 变量名约定用小写 + 下划线（`stop_loss`），类名用大驼峰（`SampleStrategy`），全大写表示常量（`DOCS_LINK`）。

---

## 4. 字符串与 f-string

f-string 是现代 Python 拼字符串的标准方式：字符串前加 `f`，花括号里直接放变量或表达式。

```python
# 摘自 worker.py
logger.info(f"Starting worker {__version__}")
logger.info(f"Error: {error}, retrying in {RETRY_TIMEOUT} seconds...")

# 花括号里可以是表达式，甚至可以再嵌套 f-string：
logger.info(
    f"Changing state{f' from {old_state.name}' if old_state else ''} to: {state.name}"
)

# :.2f 表示保留两位小数
logger.debug(f"sleep for {sleep_duration:.2f} s")
```

常用字符串方法（`worker.py:94`）：

```python
state.name.lower()      # .lower() 把字符串转小写，比如 "RUNNING" -> "running"
"state: " + state_str   # + 号可以拼接字符串
```

---

## 5. 容器：list / dict / tuple

### list 列表 —— 有序、可修改，用方括号

```python
# 摘自 constants.py
TIMEOUT_UNITS = ["minutes", "seconds"]
ORDERTYPE_POSSIBILITIES = ["limit", "market"]
```

### dict 字典 —— 键值对，用花括号（策略文件里到处都是）

```python
# 摘自 templates/sample_strategy.py
minimal_roi = {
    "60": 0.01,     # "键": 值 —— 60分钟后利润达到1%就卖出
    "30": 0.02,
    "0": 0.04,
}

order_types = {
    "entry": "limit",
    "exit": "limit",
    "stoploss": "market",
}
```

取值和"取不到就用默认值"：

```python
# 摘自 worker.py
self._throttle_secs = internals_config.get("process_throttle_secs", PROCESS_THROTTLE_SECS)
#          .get(键, 默认值) —— 键不存在时不报错，返回默认值
self._config["timeframe"]   # 方括号取值：键不存在会直接报错
```

### tuple 元组 —— 和 list 类似但**不可修改**，用圆括号

```python
# 摘自 sample_strategy.py：返回 (交易对, 周期) 的组合
return [("ETH/USDT", "5m"), ("BTC/USDT", "15m")]
```

### 嵌套取值

```python
# 摘自 sample_strategy.py：从订单簿里取最优买价
dataframe['best_bid'] = ob['bids'][0][0]
#                        字典['键']→列表第0个→再取该元组第0个
```

### 成员判断 `in`

```python
# 摘自 worker.py：state 是否是这两个状态之一
if state in (State.RUNNING, State.PAUSED):
    ...
```

---

## 6. 推导式

一行代码生成一个 list，Python 特色语法：

```python
# 摘自 constants.py
# 意思：遍历 _ORDERTIF_POSSIBILITIES 里每个元素 t，把 t.lower() 收集进新列表
ORDERTIF_POSSIBILITIES = _ORDERTIF_POSSIBILITIES + [t.lower() for t in _ORDERTIF_POSSIBILITIES]

STOPLOSS_PRICE_TYPES = [p for p in PriceType]
```

读法：`[表达式 for 变量 in 序列]` ≈ 逐个取出元素、算出表达式、装进新列表。等价的普通写法：

```python
result = []
for t in _ORDERTIF_POSSIBILITIES:
    result.append(t.lower())
```

---

## 7. 控制流

### if / elif / else

```python
# 摘自 worker.py
if state == State.STOPPED:
    self._throttle(func=self._process_stopped, ...)
elif state in (State.RUNNING, State.PAUSED):
    state_str = "RUNNING" if state == State.RUNNING else "PAUSED"
    ...
```

### while True 无限循环（机器人主循环就是它）

```python
# 摘自 worker.py:76 —— 死循环 + 每轮处理一次，直到程序被杀掉
def run(self) -> None:
    state = None
    while True:
        state = self._worker(old_state=state)
        if state == State.RELOAD_CONFIG:
            self._reconfigure()
```

### 三元表达式：一行写 if-else

```python
# 摘自 worker.py:127   值A if 条件 else 值B
timeframe=self._config["timeframe"] if self._config else None
```

### 逻辑运算 and / or / not，以及取最值

```python
# 摘自 worker.py
sleep_duration = max(sleep_duration, 0.0)   # 至少是 0
sleep_duration = min(sleep_duration, next_tf_with_offset)
```

---

## 8. 函数 def

```python
def _worker(self, old_state: State | None) -> State:
    """docstring 说明"""
    ...
    return state
#  │    │     │            └ 返回值类型注解
#  │    │     └ 参数名: 参数类型
#  │    └ self 代表"这个对象自己"，实例方法第一个参数固定是它
#  └ def 关键字
```

### 默认参数 & 关键字参数

```python
# 摘自 worker.py:145 —— 参数后跟 = 默认值，调用时可以不传
def _throttle(
    self,
    func: Callable[..., Any],
    throttle_secs: float,
    timeframe: str | None = None,        # 有默认值，可以不传
    timeframe_offset: float = 1.0,
    *args,                               # 收集多余的位置参数，装成元组
    **kwargs,                            # 收集多余的关键字参数，装成字典
) -> Any:
```

调用时就变成了灵活的"点菜式"传参（这正是 `worker.py:124` 的写法）：

```python
self._throttle(func=self._process_running, throttle_secs=self._throttle_secs,
               timeframe="5m", timeframe_offset=1)
```

---

## 9. 类与对象（重点）

类（class）是把**数据**和**操作数据的方法**打包在一起的模板，对象是按模板造出来的实例。freqtrade 大量使用类，这一节必须掌握。

### 最基本的类：`__init__` 和 self

```python
# 摘自 worker.py
class Worker:
    def __init__(self, args: dict[str, Any], config: Config | None = None) -> None:
        """构造函数：创建对象时自动执行，用来初始化"""
        self._args = args          # self.xxx = 挂在"这个对象"身上的属性
        self._config = config
        self._init(False)

    def run(self) -> None:         # 普通方法
        ...

# 使用：worker = Worker(args, config)   ← Python 自动调用 __init__
```

> `self` 就是"这个对象自己"。`worker.run()` 内部等价于 `Worker.run(worker)`，所以方法的第一个参数永远是 `self`。

### 继承：站在父类肩膀上

```python
# 摘自 sample_strategy.py —— SampleStrategy 继承了 IStrategy 的所有能力
class SampleStrategy(IStrategy):
    ...

# 摘自 exceptions.py —— 异常类的继承链，一层套一层
class FreqtradeException(Exception):        # 继承 Python 内置的 Exception
    """Freqtrade base exception."""

class OperationalException(FreqtradeException):   # 再继承 freqtrade 的基类
    ...

class ConfigurationError(OperationalException):  # 第三层
    ...
```

子类可以在方法里用 `super()` 调用父类的实现（`strategy/informative_decorator.py`）：

```python
def __init__(self, maxsize: int, timer: Callable[[], float] = monotonic) -> None:
    super().__init__(maxsize=maxsize, ttu=self._time_to_use, timer=timer)
```

### 类属性 vs 实例属性

```python
class SampleStrategy(IStrategy):
    # 这些直接写在类下面（没有 self.），叫"类属性"：
    # 所有实例共享，相当于这个策略的"出厂配置"
    INTERFACE_VERSION = 3
    timeframe = "5m"
    stoploss = -0.10
```

### 特殊方法（dunder methods，名字前后双下划线）

```python
# 摘自 enums/exittype.py —— __str__ 决定 str(对象) 时显示什么
class ExitType(Enum):
    ROI = "roi"
    STOP_LOSS = "stop_loss"
    ...
    def __str__(self):
        return self.value
```

常见的还有：`__init__`（构造）、`__repr__`（调试显示）、`__name__`（函数名/模块名）。

### @property：把方法伪装成属性

```python
# 摘自 strategy/parameters.py
class BaseParameter(ABC):
    @property
    def value(self) -> Any:          # 读 p.value 时实际执行这个方法
        self._warn_static_indicator_use()
        return self._value

    @value.setter
    def value(self, new_value):      # 写 p.value = 30 时执行这个方法
        self._value = new_value
```

好处：外部用起来像普通变量 `p.value`，内部却可以加校验、加逻辑。

### @staticmethod 静态方法

```python
# 摘自 worker.py:189 —— 不需要 self 的工具函数，挂在类里面归类管理
@staticmethod
def _sleep(sleep_duration: float) -> None:
    time.sleep(sleep_duration)
```

### 抽象类 ABC：规定"子类必须实现什么"

```python
# 摘自 strategy/parameters.py
from abc import ABC, abstractmethod

class BaseParameter(ABC):
    @abstractmethod
    def get_space(self, name: str):
        """子类必须实现这个方法，否则实例化时报错"""
```

`IStrategy` 就是这么规定所有策略必须实现 `populate_indicators` 等方法的。

---

## 10. 枚举 Enum

枚举 = 一组**固定的、有名字的常量**，避免代码里散落魔法字符串：

```python
# 摘自 enums/exittype.py
from enum import Enum

class ExitType(Enum):
    ROI = "roi"
    STOP_LOSS = "stop_loss"
    EXIT_SIGNAL = "exit_signal"
    NONE = ""
```

用法（`worker.py`）：

```python
state == State.RUNNING        # 比较用枚举成员
state.name                    # "RUNNING"（名字，字符串）
state.value                   # 成员的值
State(self.freqtrade.state)   # 由值反查枚举成员
```

同类文件还有 `enums/state.py`（机器人状态）、`enums/signaltype.py`（信号类型）等。

---

## 11. dataclass 数据类

只想"打包几个字段"时，用 `@dataclass` 可以**免手写 `__init__`**，声明字段即可：

```python
# 摘自 strategy/informative_decorator.py
from dataclasses import dataclass, field

@dataclass
class InformativeData:
    asset: str | None                      # 字段名: 类型
    timeframe: str
    fmt: str | Callable[[Any], str] | None
    ffill: bool
    candle_type: CandleType | None
    cache: bool = True                     # 字段也可以有默认值

# 用法：data = InformativeData(asset=None, timeframe="1h", fmt="", ffill=True,
#                              candle_type=None)   ← __init__ 自动生成
```

进阶修饰（同一个文件里出现）：

```python
@dataclass(frozen=True, slots=True)    # frozen=True 不可修改；slots=True 更省内存
class InformativeCacheKey:
    callback: PopulateIndicators = field(repr=False)   # field() 可微调单个字段行为
```

---

## 12. 类型注解

注解（`变量: 类型`）**不影响运行**，是写给人和 IDE/检查工具看的"说明书"。freqtrade 的注解非常全，认识它们才能读懂代码：

```python
def populate_indicators(self, dataframe: DataFrame, metadata: dict) -> DataFrame:
    #                          参数注解                          返回值注解（-> 后面）

# 基础类型：int, float, str, bool
can_short: bool = False

# "或者是 None" —— 两种等价写法（项目里两种都有）：
config: Config | None = None        # 新写法（Python 3.10+，本项目用 Python 3.11+）
old_style: Optional[str] = None     # 旧写法，来自 typing

# 容器注解：中括号里写元素类型
args: dict[str, Any]                # 键是 str、值是任意的字典
sysargv: list[str] | None           # 字符串列表
fingerprint: tuple[Any, ...]        # 元组，... 表示"任意个任意类型"

# 可调用对象（函数也能当参数传！）
func: Callable[..., Any]            # 一个函数：参数任意，返回任意
PopulateIndicators = Callable[[Any, DataFrame, dict], DataFrame]   # 给复杂类型起别名

# Literal：限定只能是几个字面量之一（见 constants.py 顶部 from typing import Literal）
```

---

## 13. 异常处理

程序出错时 Python 会抛出（raise）异常；`try/except` 用来接住它，避免程序直接崩溃。

```python
# 摘自 main.py —— 频率最高的标准范式
def main(sysargv: list[str] | None = None) -> None:
    return_code: int | None = None
    try:
        ...                                   # 可能出错的代码
    except KeyboardInterrupt:                 # 用户按 Ctrl+C
        logger.info("SIGINT received, aborting ...")
        return_code = 130
    except ConfigurationError as e:           # 只接住特定类型的异常，as e 拿到异常对象
        logger.error(f"Configuration error: {e}")
    except Exception:                         # 兜底：其他所有异常
        logger.exception("Fatal exception!")  # .exception() 会连调用栈一起打印
    finally:
        sys.exit(return_code)                 # finally：无论有没有异常都执行
```

主动抛出异常（`worker.py:203` 之外，`main.py` 里）：

```python
raise OperationalException("Usage of Freqtrade requires a subcommand...")
```

自定义异常就是**继承**（见第 9 节 `exceptions.py`），业务代码用 `except 某个子类` 就能精确分类处理——`worker.py:198` 就只处理"临时性错误"然后重试：

```python
try:
    self.freqtrade.process()
except TemporaryError as error:
    logger.warning(f"Error: {error}, retrying in {RETRY_TIMEOUT} seconds...")
    time.sleep(RETRY_TIMEOUT)
except OperationalException:
    ...
    self.freqtrade.state = State.STOPPED
```

---

## 14. import 与模块

```python
# 三种常见姿势（摘自各文件顶部）
import logging                          # 导入整个模块，用 logging.getLogger(...)
import talib.abstract as ta             # 起别名，之后用 ta.RSI(...)
from datetime import datetime, timedelta, timezone   # 只导入需要的东西
from freqtrade.strategy import IStrategy, Trade       # 从项目其他模块导入

# 用 _ 开头的私有变量也能被导入引用（constants.py）：
_ORDERTIF_POSSIBILITIES = ["GTC", "FOK", "IOC", "PO"]  # 约定：下划线开头 = 内部使用
```

**条件导入**——某个库可能没安装，缺了也不崩（`strategy/parameters.py`）：

```python
from contextlib import suppress

with suppress(ImportError):             # 如果下面 import 失败，就当无事发生
    from freqtrade.optimize.space import Categorical, Integer, Real
```

**程序入口**（`main.py` 最后一行）：

```python
if __name__ == "__main__":
    main()
# 意思：直接运行本文件（python main.py）时才执行 main()；
# 被别的文件 import 时不执行。几乎每个可执行脚本都有这行。
```

---

## 15. 装饰器 @

`@xxx` 写在函数/类上方 = "把这个东西交给 xxx 加工一下"。你已经见过好几个了：

| 装饰器 | 作用 | 出处 |
|---|---|---|
| `@staticmethod` | 不需要 self 的方法 | worker.py |
| `@property` | 方法伪装成属性 | strategy/parameters.py |
| `@abstractmethod` | 强制子类实现 | strategy/parameters.py |
| `@dataclass` | 自动生成数据类 | informative_decorator.py |
| `@informative(...)` | freqtrade 自定义，给策略附加大周期数据 | templates/sample_strategy.py |

装饰器的本质是"**函数接收函数、返回新函数**"。看一个真实自定义装饰器的签名（`informative_decorator.py:66`）：

```python
def informative(timeframe, asset="", *, candle_type=None, ...) -> Callable:
    """
    用法：
    @informative('1h')
    def populate_indicators_1h(self, dataframe, metadata):
        ...
    它把返回的 DataFrame 合并进主周期。
    """
```

> 面向入门的结论：**看到 `@` 不用慌**，记住常见几个的含义即可，原理以后再深挖。

---

## 16. 日志 logging

项目从不使用 `print()` 调试，统一用 logging 模块（`worker.py`）：

```python
import logging

logger = logging.getLogger(__name__)    # __name__ 是当前模块名，每个文件固定这么写一行

logger.debug("...")       # 调试信息（最详细，默认不显示）
logger.info("...")        # 正常运行信息
logger.warning("...")     # 警告
logger.error("...")       # 出错了
logger.exception("...")   # 在 except 块里用，会附带完整错误堆栈
```

---

## 17. 策略文件专属语法（pandas）

这是你**将来自己动手写**的部分，重点掌握。策略 = 继承 `IStrategy` 的类 + 三个必须实现的方法：

| 方法 | 干什么 |
|---|---|
| `populate_indicators` | 算指标：往表格里加 RSI、MACD 等新列 |
| `populate_entry_trend` | 定"什么时候买" |
| `populate_exit_trend` | 定"什么时候卖" |

### DataFrame 是一张表格

`dataframe` 就是 K 线数据表，每行一根蜡烛，列有 `date, open, high, low, close, volume`。加一列指标就像给字典赋值：

```python
# 摘自 sample_strategy.py
dataframe["rsi"] = ta.RSI(dataframe)           # 加一列 RSI 指标
dataframe["sar"] = ta.SAR(dataframe)
macd = ta.MACD(dataframe)                      # MACD 返回一张小表
dataframe["macd"] = macd["macd"]               # 把小表的列拷进主表
```

### 用布尔条件发信号（核心语法！）

```python
dataframe.loc[
    (
        (qtpylib.crossed_above(dataframe["rsi"], self.buy_rsi.value))    # RSI 上穿 30
        & (dataframe["tema"] <= dataframe["bb_middleband"])  # 且 tema 在布林中轨下方
        & (dataframe["tema"] > dataframe["tema"].shift(1))   # 且 tema 在上涨
        & (dataframe["volume"] > 0)                          # 且成交量不为 0
    ),
    "enter_long",        # 满足上面所有条件的那些行
] = 1                    # 在 enter_long 列写 1（= 发出做多信号）
```

三个语法点：

- **`&` 不是 and**：pandas 里对"整列的 True/False"做逐行逻辑运算用 `&`（与）、`|`（或）、`~`（非）。
- **每个条件必须用小括号包住**：因为 `&` 的优先级高于比较运算符，不括起来会报错。
- **`.shift(1)`**：整列往下挪一行，即"上一根蜡烛的值"，用来判断"比上一根涨了"。

### 常用类属性速查（都写在策略类里）

```python
timeframe = "5m"                # 用什么周期的K线
minimal_roi = {"60": 0.01, "0": 0.04}   # 达到目标利润就止盈
stoploss = -0.10                # 亏损10%止损（注意负号）
trailing_stop = False           # 是否用移动止损
startup_candle_count: int = 200 # 需要多少根历史蜡烛来预热指标
can_short: bool = False         # 能否做空
```

---

## 18. 程序是怎么跑起来的

把前面学过的串成一条线（谁调用谁）：

```
main.py  main()
 │  try/except 兜底所有异常（第13节）
 └─► Arguments 解析命令行参数
     └─► Worker(args, config)            ← __init__ 初始化（第9节）
         └─► worker.run()
             └─► while True:             ← 永不停歇的主循环（第7节）
                 └─► _worker(old_state)  判断当前状态 RUNNING / STOPPED（第10节枚举）
                     └─► _throttle(...)  控制节奏，每轮至少睡5秒（第8节函数）
                         └─► FreqtradeBot.process()
                             └─► 调用你的策略：populate_indicators → entry/exit 信号
                                 → 有信号就下单 → 写数据库 → 发 Telegram 通知
```

---

## 19. 学习路线建议

1. **第 1 周：Python 基础**。本文档第 3–8、13、14 节 + 任意一份 Python 入门教程。用 `python3` 交互式终端把每段示例敲一遍。
2. **第 2 周：面向对象**。第 9–12、15 节。对照 `freqtrade/exceptions.py`（只有几十行，全是继承）和 `enums/exittype.py`（20 行）这两个小文件精读。
3. **第 3 周：读懂策略**。精读 `freqtrade/templates/sample_strategy.py`（全文 429 行，一半是注释），配合本文第 17 节。建议用编辑器打开，边看边查每个方法的含义。
4. **第 4 周：动手改**。把 sample_strategy 复制到 `user_data/strategies/`，改改 `minimal_roi`、RSI 阈值，跑一次回测感受效果（本文不涉及部署，操作见官方文档）。
5. **之后**：读 `worker.py`（240 行）理解主循环，再按兴趣深入 `exchange/`、`optimize/`。

**官方文档**（有完整策略教程）：<https://www.freqtrade.io/en/stable/strategy-customization/>

---

*文档基于 freqtrade develop 分支源码整理，所有代码片段均可直接搜索定位到原文件。*
