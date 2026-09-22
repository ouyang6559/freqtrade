# 第 7 章 语法分层：Python 初级 / 中级 / 高级 + Rust 入门对照

> 本章解决两个问题：
> ① 读 freqtrade 源码时，**哪些 Python 语法是初级、哪些是中级、哪些是高级**——按层级逐个击破，不再一看到陌生写法就慌；
> ② **Rust 是什么、长什么样**——freqtrade 是纯 Python 项目（仓库内没有任何 `.rs` 文件），但你的 `rust-pro/` 工作区里有正在学的 Rust 项目（`rushwind`、`trade-alert`），本章用它们的真实代码和 freqtrade 对照讲解。

---

## 目录

- [7.1 Python 初级语法（能跑起来就够）](#71-python-初级语法能跑起来就够)
- [7.2 Python 中级语法（读懂 freqtrade 80% 的代码）](#72-python-中级语法读懂-freqtrade-80-的代码)
- [7.3 Python 高级语法（剩下的 20% 硬骨头）](#73-python-高级语法剩下的-20-硬骨头)
- [7.4 三级自测：你到哪一级了](#74-三级自测你到哪一级了)
- [7.5 为什么会有 Rust：和 Python 的根本差异](#75-为什么会有-rust-和-python-的根本差异)
- [7.6 Rust 初级语法](#76-rust-初级语法)
- [7.7 Rust 中级语法](#77-rust-中级语法)
- [7.8 同一件事，两种写法：RSI 指标 Python vs Rust 对照](#78-同一件事两种写法rsi-指标-python-vs-rust-对照)
- [7.9 Python ↔ Rust 语法速查表](#79-python--rust-语法速查表)
- [7.10 学习路线建议](#710-学习路线建议)

---

## 7.1 Python 初级语法（能跑起来就够）

这些是"任何 Python 教程第一周"的内容，freqtrade 到处都是，此处只列清单并标注在本项目中的出处（详细讲解见 [Python语法入门总结.md](../../Python语法入门总结.md) 第 3~8 节）：

| # | 语法 | 一句话 | freqtrade 出处 |
|---|---|---|---|
| 1 | 变量与类型 `int/float/str/bool/None` | 直接赋值，不用声明 | `stoploss = -0.10`（`templates/sample_strategy.py:76`） |
| 2 | f-string | `f"...{变量}..."` 拼字符串 | `f"Starting worker {__version__}"`（`worker.py:35`） |
| 3 | list / dict / tuple | 三种容器：有序列表、键值对、不可变组合 | `minimal_roi = {"60": 0.01}`（`sample_strategy.py:67`） |
| 4 | if / elif / else | 分支 | `worker.py:112-129` 状态机分支 |
| 5 | `while True` / `for ... in` | 循环 | `worker.py:78` 主循环 |
| 6 | `def` 函数、默认参数、`*args/**kwargs` | 封装一段逻辑 | `_throttle(func, throttle_secs, timeframe=None, ...)`（`worker.py:145`） |
| 7 | `class` + `__init__` + `self` | 对象 = 数据 + 方法 | `class Worker`（`worker.py:26`） |
| 8 | `try / except / finally` | 错误处理 | `main.py:38-79` |
| 9 | `import` / `from ... import` | 引入模块 | 每个文件头部 |
| 10 | 缩进、注释、`None`、`in`、逻辑运算 `and/or/not` | 基本功 | 无处不在 |

**分层标准**：这一级的语法占 freqtrade 约 60% 的行数。**判断标准：看到它你能立刻翻译成中文伪代码。**

## 7.2 Python 中级语法（读懂 freqtrade 80% 的代码）

这一级是"读过一点教程但没在真实项目见过"的写法，也是**从教程到真实项目的分水岭**。共 8 个主题，全部给真实例子。

### ① 继承、多态与 `super()`

```python
# 子类继承父类，拿到父类全部能力
class SampleStrategy(IStrategy):            # templates/sample_strategy.py:40
    ...

# 子类扩展父类：先调父类的实现
class InformativeCache(TLRUCache[...]):
    def __init__(self, maxsize, timer=monotonic):
        super().__init__(maxsize=maxsize, ttu=self._time_to_use, timer=timer)
        #       ↑ 调父类的 __init__（strategy/informative_decorator.py:47-48）
```

**多态**：同一个方法名，不同类有不同实现。`exchange/binance.py` 和 `exchange/okx.py` 都实现了 `ft_additional_exchange_init()`，上层代码只管调，不用关心是哪家交易所。

### ② 装饰器 `@`（中级核心）

"函数接收函数、返回新函数"的语法糖。freqtrade 有三类：

```python
# (a) 标准库装饰器
@staticmethod            # 不需要 self（worker.py:189）
@property                # 方法伪装成属性（strategy/parameters.py）
@dataclass(slots=True)   # 自动生成 __init__/__repr__（informative_decorator.py:38）
@cached(FtTTLCache(maxsize=1, ttl=1800))   # 结果缓存1800秒（pairlistmanager.py:133）
@wraps(f)                # 保留被包装函数的名字和文档（exchange/common.py:176）

# (b) 项目自定义装饰器
@informative('1h')       # 给策略附加大周期数据（templates/sample_strategy.py 文档区）
def populate_indicators_1h(self, dataframe, metadata): ...

# (c) 带参数的装饰器（中级里的高级，先会用即可）
@retrier(retries=3)      # 失败自动重试（exchange/common.py:174）
def fetch_something(): ...
```

**读法口诀：看到 `@xxx` 就想成"这个函数先交给 xxx 加工一下再定义"。**

### ③ 生成器：`yield` / `yield from`

`yield` = "函数可以中途产出一个值、暂停、下次继续"。好处：处理百万行数据也不占内存。

```python
# 例1：逐个产出下一个K线时间（optimize/backtesting.py:1608-1612）
def _time_generator(self, start_date, end_date):
    current_time = start_date + self.timeframe_td
    while current_time <= end_date:
        yield current_time                    # ★ 产出一个值，暂停
        current_time += self.timeframe_td

# 例2：找到第一个有效交易对就产出（exchange/exchange.py:805-818）
def get_valid_pair_combination(self, curr_1, curr_2) -> Generator[str, None, None]:
    for pair in (...):
        if pair in self.markets and self.markets[pair].get("active"):
            yield pair                        # ★

# 例3：yield from = 把另一个生成器的所有值接过来（configuration/config_validation.py:38）
yield from validate_properties(validator, properties, instance, schema)
```

调用方通常出现在 `for x in generator` 里——**你每次 `for` 遍历一个 `*_generator` 函数，就是在用生成器**。

### ④ lambda 匿名函数与 sorted(key=)

一行写完的小函数，常作为参数传给别人：

```python
distances.sort(key=lambda x: x.remaining)          # freqtradebot.py:467
#                                        ↑ 按 remaining 字段排序，lambda 定义"怎么比"

logger.info(f"...took {duration:.2f}s")            # 配合 MeasureTime 的回调：
with MeasureTime(lambda duration, _: logger.info(...), 0):   # freqtradebot.py:157-158
    self._refresh_active_whitelist()
```

### ⑤ 上下文管理器：`with` 和 `__enter__/__exit__`

`with X:` 保证"无论是否报错，离开时一定执行清理"。自己实现只需两个方法：

```python
# freqtrade/util/measure_time.py:32
class MeasureTime:
    def __enter__(self):        # 进入 with 时执行：记录开始时间
        self.start = time.time()
    def __exit__(self, *args):  # 离开 with 时执行：算耗时并打日志（即使中间报错）
        logger.info(f"...{time.time() - self.start}...")

# 用法（freqtradebot.py:331）：块内代码的执行时间被自动测量
with self._measure_execution:
    self.strategy.analyze(self.active_pair_whitelist)
```

你已经认识的 `with self._exit_lock:`（`freqtradebot.py:334`）同理：离开时自动释放锁。还有 `with suppress(ImportError):`（导入失败也不崩）。

### ⑥ 枚举 `Enum` 与 dataclass 进阶

```python
class State(Enum):              # enums/state.py —— 有限取值集合
    RUNNING = 3
    RELOAD_CONFIG = 4

@dataclass(frozen=True, slots=True)          # frozen=不可变(像元组)、slots=省内存
class InformativeCacheKey:                    # strategy/informative_decorator.py:24
    asset: str
    informative_timeframe: str
    candle_type: CandleType | None            # 字段直接写类型，自动生成 __init__
```

### ⑦ 类型注解进阶：`X | None`、容器注解、`Callable`

```python
def _worker(self, old_state: State | None) -> State: ...     # worker.py:83
config: dict[str, Any]                                       # 键值类型都标注
pairs: list[tuple[str, str]] | None                          # 嵌套容器
func: Callable[..., Any]                                     # "这是一个函数"
```

**注解不参与运行**，是给 IDE 和人看的说明书——这是 Python（动态类型）与 Rust（编译器强制）的重大区别，也是第 7.5 节的伏笔。

### ⑧ 闭包与工厂函数

```python
# exchange/common.py:175-178：retrier 内部定义 wrapper，"记住"了 f
def retrier(_func=None, *, retries=API_RETRY_COUNT):
    def decorator(f):                 # ← 内层函数记住了外层的 retries
        @wraps(f)
        def wrapper(*args, **kwargs): # ← 又一层嵌套，真正干活的函数
            ...
        return wrapper
    return decorator
```

**中级语法出现频率**：装饰器和 `with` 每个文件几乎都有；生成器集中在 `optimize/` 和 `exchange/`；闭包集中在装饰器和回调里。

## 7.3 Python 高级语法（剩下的 20% 硬骨头）

这一级的特点：**出现频率低、但一旦跳过就读不懂关键代码**。共 7 个主题，每个都"会认、知道去哪查"即可，不要求会写。

### ① 异步 `async / await`（并发 IO）

普通代码一行行等待；`async` 函数在"等待网络响应"时**让出控制权去做别的事**——交易所 API 全靠它。

```python
# exchange/exchange.py:2721 —— 同时发多个请求，谁都不用等谁
results = await asyncio.gather(*input_coro, return_exceptions=True)

# exchange/common.py:124-129 —— 异步版重试装饰器
def retrier_async(f):
    async def wrapper(*args, **kwargs):
        try:
            return await f(*args, **kwargs)     # await = "等这个异步操作完成"
        except TemporaryError as ex:
            ...
```

要点：`async def` 定义、`await` 使用、必须由事件循环（`asyncio`）驱动。freqtrade 用独立线程跑这个循环（`exchange/exchange.py:355 _init_async_loop`），主循环仍是同步的——**异步只在 exchange 层内部消化掉**。

### ② 泛型 `TypeVar` / `Generic`（"类型也当参数"）

```python
T = TypeVar("T")                       # exchange/exchange.py:118
# 意思：T 是一个"占位类型"，调用时 T 是 int 就返回 int，是 str 就返回 str
def first_of(items: list[T]) -> T: ...

F = TypeVar("F", bound=Callable[..., Any])   # exchange/common.py:161
# bound = T 必须是函数类型 —— 装饰器返回"和入参同类型的函数"，靠它保持类型信息
```

类比：像 `stake_amount: "unlimited"` 里的策略——"我先不说死是什么类型，调用者说了算"。

### ③ `@overload`：一个函数多种调用签名的"说明书"

```python
# exchange/common.py:165-174 —— 同一个 retrier 有 3 种合法调用方式：
@overload
def retrier(_func: F) -> F: ...                    # @retrier 直接当装饰器
@overload
def retrier(_func: F, *, retries=3) -> F: ...      # @retrier(retries=3)
@overload
def retrier(*, retries=3) -> Callable[[F], F]: ... # 不传函数、只传参数
def retrier(_func=None, *, retries=API_RETRY_COUNT):   # ← 真正的实现只有这一行
    ...
```

`...`（Ellipsis）表示"这里没有实现，只是类型声明"。**只影响类型检查，不影响运行**。

### ④ `Protocol`：结构化类型——"只要有这个方法就行"

```python
# optimize/space/optunaspaces.py:7 —— 不继承任何类，只要求"长这样"
class DimensionProtocol(Protocol):
    name: str            # 任何拥有 name 属性的类都自动兼容

# 类比：USB 接口协议——不关心你是什么牌子，有 USB 口就能插
```

freqtrade 用它解耦 hyperopt 的搜索空间（`optimize/space/__init__.py:3`）。

### ⑤ `TypeGuard`：给动态类型世界里的"if 判断"加类型保证

```python
# exchange/exchange.py:1862
def is_cancel_order_result_suitable(self, corder) -> TypeGuard[CcxtOrder]:
    """
    返回 True 时，类型检查器会相信：调用方手里那个"什么都能装"的 corder
    此刻确定是 CcxtOrder。后续代码就能直接用 CcxtOrder 的方法而不报警。
    """
```

### ⑥ 结构化模式匹配 `match / case`（Python 3.10+，最"新"的语法）

像 Rust 的 `match`（这不是巧合，两边互相借鉴）：

```python
# rpc/webhook.py:88-95 —— 按类型分派
match obj:
    case dict():      # 如果是字典
        ...
    case list():      # 如果是列表
        ...
    case str():       # 如果是字符串
        ...
    case _:           # _ 是通配符，以上都不是
        ...
```

freqtrade 全项目**只有这一处**用 `match`，其余都是传统 if/elif——看到认识即可。

### ⑦ 海象运算符 `:=`（边判断边赋值）

```python
# freqtradebot.py:355 —— 求值一次，判断和使用共用结果
if self.state == State.RUNNING and ((free_trade_slots := self.get_free_open_trades()) > 0):
    self.enter_positions(free_trade_slots)   # ↑ 刚赋的值直接用，避免算两遍
```

**为什么叫海象**：`:=` 两颗"獠牙"朝左，像海象的脸。

### 高级语法出现频率

| 语法 | freqtrade 中出现次数（约） | 位置 |
|---|---|---|
| `async/await` | 数百处 | `exchange/`、`rpc/api_server/` |
| `TypeVar/overload/Protocol/TypeGuard` | 十几处 | 类型标注密集区 |
| `match/case` | 1 处 | `rpc/webhook.py` |
| `:=` | 几处 | `freqtradebot.py` 等 |
| 生成器 yield | 十几处 | `optimize/`、`exchange/` |

> **给小白的定心丸**：高级语法大多只出现在框架的"管道"里，**你自己写的策略文件用不到它们**——策略只需要初级 + 少量中级（类属性、dataclass 认识即可）。

---

## 7.4 三级自测：你到哪一级了

打开这几个文件，30 秒内不查资料说出"每行在干嘛"，即达到对应级：

| 级别 | 检验文件 | 通过标准 |
|---|---|---|
| 初级 | `freqtrade/enums/exittype.py`（约 20 行） | 看懂类、枚举、`__str__` |
| 中级 | `freqtrade/util/measure_time.py`（约 50 行） | 看懂 class、`__enter__/__exit__`、装饰器用法 |
| 中级 | `freqtrade/templates/sample_strategy.py` | 看懂三方法 + `.loc` 信号 |
| 高级 | `freqtrade/exchange/common.py` 120~200 行 | 认出 async 重试、`TypeVar`、`@overload`、闭包 |
| 高级 | `freqtrade/worker.py` 全文 | 认出状态机、节流、海象以外的所有写法 |

---

## 7.5 为什么会有 Rust：和 Python 的根本差异

先说清楚事实：**freqtrade 是 100% Python 项目，仓库里没有任何 Rust 代码**（可用 `find . -name "*.rs"` 验证）。
但你的工作区 `rust-pro/` 下有正在学的 Rust 项目，其中和量化最相关的是：

```
../trade-alert/          ← 用 Rust 手写的技术指标库 + 告警（含 RSI/EMA/MACD/BB/CCI/随机指标）
    crates/indicators/src/   rsi.rs  ema.rs  macd.rs  bands.rs ...
    crates/core/src/         config.rs（配置系统）
../rushwind/             ← 大型 Rust 微服务框架（tokio/axum 生态）
../nautilus_trader_source/ ← 知名 Rust 量化交易内核的源码
```

**为什么要用 Rust 重写交易系统？两者哲学对比：**

| 维度 | Python（freqtrade） | Rust（trade-alert 等） |
|---|---|---|
| 执行方式 | 解释执行，慢（约 C 的 1/50~1/100） | 编译成机器码，接近 C/C++ |
| 类型检查 | 运行时才发现类型错误 | **编译期**强制，写错编译不过 |
| 内存管理 | 垃圾回收（GC），有停顿 | **所有权系统**，无 GC、无悬垂指针 |
| 并发安全 | GIL 限制多核，线程 bug 运行时爆 | 编译器保证"数据竞争不可能发生" |
| 开发速度 | **极快**，改完就跑 | 较慢，编译几十秒到几分钟 |
| 生态 | pandas/talib/机器学习全家桶 | 性能敏感组件（行情网关、撮合、指标计算） |
| 典型分工 | 策略、回测、研究 | 低延迟执行层、高频数据管道 |

一句话：**Python 赢在"写得快"，Rust 赢在"跑得快且不出错"**。业界常见做法正是混合：Rust 做执行内核，Python 做策略层（`nautilus_trader` 就是这个思路）。

## 7.6 Rust 初级语法

用 `trade-alert` 的真实代码教学（下面每段都能在 `../trade-alert/` 里找到原型）。

### ① 变量：默认不可变，`mut` 才可变（和 Python 完全相反）

```rust
let period = 14;            // 不可变，period = 15 会编译报错！
let mut sum = 0.0;          // mut = mutable，可以重新赋值
sum += 1.0;
let alpha = 2.0 / (period as f64 + 1.0);   // as = 类型转换（Python 的 float()）
```

> Python 里 `stoploss = -0.10` 随时能改；Rust 里同样写 `let stoploss = -0.10;`，改它就编译失败——**逼你思考：这个值到底该不该变**。

### ② 类型标注在变量后面，函数用 `fn`

```rust
// trade-alert/crates/indicators/src/ema.rs —— 函数签名
pub fn ema_series(src: &[f64], period: usize) -> Vec<f64> { ... }
//    ↑pub=公开   ↑入参:切片(借用的数组)  ↑返回:浮点数向量(可增长数组)
```

| Rust | Python 对应 |
|---|---|
| `f64` | `float` |
| `usize` / `i64` | `int` |
| `bool` | `bool` |
| `&str` / `String` | `str` |
| `&[f64]`（切片，只读借用） | `list[float]` |
| `Vec<f64>`（可增长数组） | `list[float]` |
| `Option<T>`（可能没有） | `None` / 值 |
| `Result<T, E>`（可能出错） | `try/except` 抛异常 |

### ③ 结构体 `struct` + 方法写在 `impl` 块里

```rust
// trade-alert/crates/core/src/config.rs
#[derive(Debug, Clone, Serialize, Deserialize)]   // ← derive 宏：自动生成样板代码
#[serde(default, deny_unknown_fields)]            // ← serde 宏：自动生成 YAML/JSON 读写
pub struct RsiConfig {
    pub period: usize,        // 字段:类型，pub = 对外可见
    pub overbought: f64,
    pub oversold: f64,
}

impl Default for RsiConfig {                       // 实现"默认值"这个 trait
    fn default() -> Self {                          // Self = RsiConfig 自己
        Self { period: 14, overbought: 70.0, oversold: 30.0 }
    }
}
```

**对照 Python**：`@dataclass` + 默认值 ≈ `#[derive(...)]` + `impl Default`——两边都在消灭重复样板，思路一致。
`#[derive(Debug, Clone, Serialize, Deserialize)]` 一行顶 Python 十行：可打印、可克隆、**自动序列化**（Python 得手写或用第三方库）。

### ④ `enum` + `match`：Rust 的杀手锏

```rust
enum ExitType { ROI, StopLoss, ExitSignal, Liquidation }   // 穷举所有可能

match exit {
    ExitType::ROI          => println!("止盈"),
    ExitType::StopLoss     => println!("止损"),
    ExitType::ExitSignal   => println!("信号"),
    ExitType::Liquidation  => println!("强平!"),
    // 少写一个分支 → 编译错误。Python 的 match 借鉴了这个设计
}
```

对照 freqtrade：`enums/exittype.py` 用 Python `Enum` 写，但**漏了分支只能靠 `if/elif` 一路 else 兜底**，编译器不提醒；Rust 在编译期就把你拦下。

### ⑤ `Option` / `Result`：没有 null，没有异常

```rust
let maybe: Option<f64> = Some(100.5);      // 有值
let none:  Option<f64> = None;             // 没值 —— 必须显式处理
let v = match maybe { Some(x) => x, None => 0.0 };   // 必须自己处理"没有"的情况

fn get_rate() -> Result<f64, String> {     // 成功给 f64，失败给错误信息
    Ok(99.5)
    // Err("网络超时".into())
}
let rate = get_rate().unwrap_or(0.0);      // 出错就用默认值，绝不 panic
```

对照 Python：`dataframe.get(SignalType.ENTER_LONG, 0)` 的"取不到用默认值"思想相同，但 Rust 是**类型层面强制你面对**——`Option<f64>` 不调用 `.unwrap()/match` 就别想拿到 `f64`。这就是为什么 Rust 程序"编译过了基本就能跑"。

### ⑥ 循环与迭代器

```rust
// trade-alert ema.rs 真实代码片段
for i in 1..n {                              // 1..n = [1, n) 半开区间
    out[i] = alpha * src[i] + (1.0 - alpha) * out[i - 1];
}

for (i, v) in src.iter().enumerate() { ... } // 带下标的遍历 ≈ Python: for i, v in enumerate(src)

let mut out = vec![f64::NAN; n];             // 创建 n 个 NaN 的数组 ≈ [float("nan")] * n
```

## 7.7 Rust 中级语法

### ① 所有权与借用（Rust 最核心的概念，10 分钟版）

三条规则背下来：
1. 每个值有且只有一个**所有者**；
2. 所有权可以 **move（转移）**，转移后旧变量不能再用；
3. 想"用但不拿走"就 **借用**：`&T` 只读借用、`&mut T` 可变借用，且**可变借用同一时刻只能有一个**。

```rust
fn ema_series(src: &[f64], period: usize) -> Vec<f64> { ... }
//                       ↑ & = "我只读你的数据，不拿走"
// 调用方：let result = ema_series(&closes, 9);   // &closes 借出去
// 调用后 closes 还完好属于我 —— Python 传 list 从来不用担心这个？
// 错！Python 里别人 mutate 了你的 list 你根本不知道 —— Rust 把这隐患编译掉
```

**为什么量化代码在乎这个**：一根 K 线数组被策略读、被指标算、被回测引擎用——Rust 保证"只有一个地方能改它"，回测结果不可能被某个角落偷偷篡改。

### ② trait：比 Python 的继承更常用的"能力声明"

```rust
trait Indicator {
    fn calculate(&self, src: &[f64]) -> Vec<f64>;     // 只声明，不实现
}

struct Rsi { period: usize }
impl Indicator for Rsi {                              // 给 Rsi 实现这个能力
    fn calculate(&self, src: &[f64]) -> Vec<f64> { ... }
}
```

**对照**：
- `Protocol`（7.3④）≈ 只声明不实现的 `trait`（都叫"结构化类型"）；
- `ABC + @abstractmethod`（`strategy/interface.py:235`）≈ 必须实现的 `trait` 方法；
- `IStrategy` 这种"接口 + 部分默认实现"≈ 带默认方法的 trait。
- 区别：Python 的继承树可以很深，Rust 鼓励**组合而非继承**（`impl X for Y` 想实现几个实现几个，没有单继承限制）。

### ③ 泛型与 trait bound（"类型参数 + 约束"）

```rust
fn max_of<T: PartialOrd>(a: T, b: T) -> T { if a > b { a } else { b } }
//      ↑ T 是占位类型    ↑ 但 T 必须支持 > < 比较（bound 约束）
```

对照 Python 的 `TypeVar("T")` + `bound=Callable`（7.3②）——**概念一样，但 Rust 是编译器强制，Python 只是注释**。

### ④ 生命周期 `'a`（初学者最怕，其实先会认就行）

```rust
fn longest<'a>(a: &'a str, b: &'a str) -> &'a str { if a.len() > b.len() { a } else { b } }
```

**只需要知道**：编译器要保证"返回的引用不会比数据活得久"（防悬垂指针），当借用关系说不清时它会要求你标注 `'a`。**90% 的业务代码不需要手写生命周期**，被报错时查即可。

### ⑤ `async/await` + tokio（Rust 版异步）

```rust
use tokio;                                  // rushwind/Cargo.toml 里声明依赖
async fn fetch_ohlcv(pair: &str) -> Result<Vec<Kline>, Error> { ... }
let (a, b) = tokio::join!(fetch(pair1), fetch(pair2));   // 并发 ≈ asyncio.gather
```

对照 freqtrade 的 `await asyncio.gather(*coro)`（`exchange/exchange.py:2721`）——**写法几乎一样**，区别是 Rust 的 async 编译成状态机、无运行时开销，Python 的靠事件循环解释执行。

### ⑥ Cargo 与 workspace（工程管理 ≈ Python 的 pip + requirements）

```toml
# ../rushwind/Cargo.toml —— 大型项目拆成多个 crate
[workspace]
members = ["crates/*", "examples/*"]

[dependencies]
tokio = "1"          # ← 等价于 requirements.txt 里的一行，但带版本锁定
serde = { version = "1", features = ["derive"] }
```

| Python 世界 | Rust 世界 |
|---|---|
| `pip install requests` | `cargo add requests` → 写进 `Cargo.toml` |
| `requirements.txt` | `Cargo.lock`（精确锁定版本） |
| 一个仓库一个包 | workspace 多 crate（如 rushwind 有 50+ crates） |
| `python xxx.py` | `cargo run` |
| `pytest` | `cargo test`（测试就写在源码里 `#[cfg(test)]`） |
| `ruff` / `black` 格式化 | `cargo fmt` + `cargo clippy`（一个命令全配齐） |

## 7.8 同一件事，两种写法：RSI 指标 Python vs Rust 对照

最有价值的对读材料——同一个 RSI，freqtrade 一行调用，trade-alert 手写实现：

### Python（freqtrade 的做法：站在巨人肩膀上）

```python
# templates/sample_strategy.py:201 —— 一行完事
dataframe["rsi"] = ta.RSI(dataframe)        # talib 是 C 写的，Python 只是薄薄一层皮
```

```python
# 如果手写（pandas 向量化风格，也是策略里常见的 pandas 写法）：
delta = dataframe["close"].diff()                    # 相邻两根收盘价之差
gain = delta.clip(lower=0)                           # 负数归零 = 只留涨幅
loss = -delta.clip(upper=0)                          # 只留跌幅
rs = gain.rolling(14).mean() / loss.rolling(14).mean()   # 14 周期平均涨跌比
dataframe["rsi"] = 100 - 100 / (1 + rs)              # RSI 公式
```

### Rust（trade-alert 的做法：自己动手，极致性能）

```rust
// ../trade-alert/crates/indicators/src/rsi.rs（真实代码节选）
pub fn rsi_from_closes(c: &[f64], period: usize) -> Vec<f64> {
    let n = c.len();
    let mut out = vec![f64::NAN; n];          // 输出数组，前 period 个是 NaN
    if period == 0 || n <= period { return out; }

    let mut avg_gain = 0.0;                   // mut：这些值每轮都要更新
    let mut avg_loss = 0.0;
    for i in 1..=period {                     // 1..=period：闭区间，含 period
        let ch = c[i] - c[i - 1];             // 每根K线的变化量
        if ch >= 0.0 { avg_gain += ch; } else { avg_loss -= ch; }
    }
    avg_gain /= period as f64;                // 种子：前 period 个的算术平均
    avg_loss /= period as f64;
    out[period] = rsi_value(avg_gain, avg_loss);

    for i in (period + 1)..n {                // Wilder 平滑：新值 = 旧值*(n-1)/n + 当期/n
        let ch = c[i] - c[i - 1];
        let gain = if ch > 0.0 { ch } else { 0.0 };   // if 表达式有返回值（Python 没有！）
        let loss = if ch < 0.0 { -ch } else { 0.0 };
        avg_gain = (avg_gain * (period as f64 - 1.0) + gain) / period as f64;
        avg_loss = (avg_loss * (period as f64 - 1.0) + loss) / period as f64;
        out[i] = rsi_value(avg_gain, avg_loss);
    }
    out
}

#[inline]                                       // 内联提示：给编译器的性能建议
fn rsi_value(avg_gain: f64, avg_loss: f64) -> f64 {
    if avg_loss == 0.0 { return 100.0; }        // 全是涨 → RSI=100
    100.0 - 100.0 / (1.0 + avg_gain / avg_loss)
}
```

### 逐点对照（这张表值得背）

| 概念 | Python 写法 | Rust 写法 |
|---|---|---|
| 可变变量 | `avg_gain = 0.0` 直接改 | `let mut avg_gain = 0.0` |
| 类型转换 | `float(period)` / 隐式 | `period as f64`（显式、编译期） |
| 循环 | `for i in range(1, period+1):` | `for i in 1..=period`（`..=`含右端） |
| 带下标循环 | `enumerate(c)` | `src.iter().enumerate()` |
| 新建数组 | `[float("nan")] * n` / `np.full` | `vec![f64::NAN; n]` |
| if 是表达式 | `x = a if cond else b`（三元） | `let x = if cond { a } else { b };` |
| 函数返回 | `return x` 或最后一行 | 必须写 `x` / `return x`，签名声明类型 |
| 空值 | `None`，调用方爱忘处理 | `Option<T>`，编译器逼你处理 |
| 出错 | `raise / try-except` | `Result<T,E>`，编译器逼你处理 |
| 注释 | `#` | `//`，`///` 是文档注释（自动生成手册） |
| 单元测试 | 单独 `tests/` 目录 | 源码底部 `#[cfg(test)] mod tests` |

## 7.9 Python ↔ Rust 语法速查表

```
               Python                          Rust
定义函数     def f(a: int) -> int:          fn f(a: i32) -> i32
默认值       def f(a=10)                    fn f(a: i32)  // 调用方 f(10)
可变         x = 1（天生可变）               let mut x = 1;（默认不可变）
空值         None                           Option<T>（Some/None）
错误         raise E / try-except           Result<T, E>（Ok/Err）
类           class A(B): ...                struct A; impl B for A
继承         class B(A)（深树）              trait（组合优先，无单继承）
接口/鸭子类型 Protocol / ABC                trait
数据类       @dataclass                     #[derive(Debug, Clone)]
枚举         from enum import Enum          enum + match（穷举检查）
泛型         TypeVar("T")（注解）            <T: Bound>（编译强制）
异步         async/await + asyncio          async/await + tokio
字符串格式   f"{x:.2f}"                     format!("{:.2f}", x)
注释        #                               // 和 ///
包管理      pip + requirements.txt          cargo + Cargo.toml/Cargo.lock
运行        python main.py                  cargo run
测试        pytest tests/                   cargo test（写在同文件）
包           pypi.org                       crates.io
```

## 7.10 学习路线建议

**Python 语法（服务 freqtrade 阅读）**：
1. 初级 → 过一遍 [Python语法入门总结.md](../../Python语法入门总结.md) 第 3~8 节；
2. 中级 → 本章 7.2 的 8 个主题，每个都在 freqtrade 里找到实例（文件:行号都给了）；
3. 高级 → 只需**会认**：`async/await` 看懂调用方向即可，`TypeVar/overload/Protocol` 当注释读，`match/case` 认识就行；
4. 分层检验 → 做 7.4 的自测。

**Rust（服务 rust-pro 工作区）**：
1. 先用本章 7.6 把 `trade-alert/crates/indicators/` 里 10 个 `.rs` 文件读懂——它们是你自己工作区的代码，短小、纯算法、无框架噪音，**比任何教程都合适**；
2. 再读 `crates/core/src/config.rs`（struct/derive/serde/Default 全齐）；
3. 所有权、trait、`Option/Result` 是 Rust 的"三座大山"，配合《The Rust Programming Language》（官方书，免费）第 4、5、10 章；
4. 生命周期先会认、不强求会写；`tokio/async` 等接触 rushwind 时再学；
5. 终极练习：**把 7.8 的 `rsi_from_closes` 从头默写一遍，再给它写 `#[cfg(test)]` 单元测试**（对照 Python 的 RSI 结果验证数值一致——这是"Python 做参考实现、Rust 做性能实现"的标准工程手法）。

---

## 动手练习

1. **分层标注**：打开 `freqtrade/util/measure_time.py`，把里面每个语法点标上"初级/中级/高级"。
2. **生成器**：写一个 `yield` 版本的斐波那契数列，`for` 循环打印前 10 个；对比 `backtesting.py:1608` 的 `_time_generator`。
3. **装饰器**：不查资料说出 `@cached(FtTTLCache(maxsize=1, ttl=1800))`（`pairlistmanager.py:133`）缓存的是什么、ttl 到期后下次调用会发生什么。
4. **Rust 对读**：打开 `../trade-alert/crates/indicators/src/ema.rs`，逐行回答：`out[0] = src[0]` 是种子值，如果 `period == 0` 函数为什么提前 `return`？（防御性编程——对照 freqtrade 哪里也有类似检查？）
5. **Rust 动手**：`cd ../trade-alert && cargo test`，跑通测试；然后给 `rsi_from_closes` 加一条边界测试：`period` 大于数据长度时应返回全 NaN。
6. **思考题**：为什么 Python 的 `let` 对应物必须写 `let mut` 才能改？这对"回测结果可信度"有什么隐性好处？（提示：7.7① 第三条规则）

---

→ 返回目录：[《Freqtrade 小白入门书系》](README.md) ｜ 上一章：[第 6 章 学习路线与练习](第6章-学习路线与练习.md)
