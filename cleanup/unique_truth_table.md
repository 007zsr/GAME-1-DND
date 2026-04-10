# 唯一真值表

更新时间：2026-04-08

## 参数唯一来源

### 1. A 类属性

- 唯一来源：`玩家基础属性数据 + 装备 A 加成`
- 主文件：
  - `game/scripts/player.gd`
  - `game/scripts/item_system.gd`

### 2. B 类属性

- 唯一来源：`game/scripts/character_stats.gd`
- 禁止行为：
  - 技能脚本自行重新推导
  - UI 脚本自行重新写一套公式
  - 装备脚本直接覆盖最终 B 值

### 3. 玩家移动速度

- 唯一来源：`B 类属性中的 move_speed`
- 当前固定值：`2.00`
- 主文件：
  - `game/scripts/character_stats.gd`
  - `game/scripts/player.gd`

### 4. 斩击冷却时间

- 唯一来源：`技能模块读取 B 类 attack_speed`
- 固定公式：`1 / 攻击速度`
- 主文件：
  - `game/scripts/player.gd`

### 5. 斩击伤害

- 唯一来源：`基础伤害 + B 类 damage_power × 0.5`
- 主文件：
  - `game/scripts/player.gd`

### 6. 背包容量

- 唯一来源：`game/scripts/player.gd`
- 当前公式：`12 + 感知 + 坚韧 + 等级 × 2`
- UI 只能读取，不允许各自保存另一份容量值。

### 7. 装备数据

- 唯一来源：`game/scripts/item_system.gd`
- 当前状态：
  - 仍是脚本常量字典，不是 Resource 文件
  - 后续可迁移到 `data/items/` / `data/equipment/`

### 8. 当前 UI 显示值

- 唯一来源：读取玩家运行时最终数据
- 主读取端：
  - `game/scripts/player_menu_ui_v2.gd`
  - `game/scripts/chest_menu_ui_v2.gd`
  - `game/scripts/newbie_village.gd`

## 统一刷新链

1. 基础 A 属性
2. 装备 A 加成
3. 重算推导型 B 属性
4. 叠加装备直接给的 B 属性
5. 刷新运行时参数
6. 刷新 UI

## 禁止重复控制的点

- 不允许在 UI 中保存独立背包列表
- 不允许在 UI 中保存独立装备列表
- 不允许在 Tooltip 中重新计算技能伤害
- 不允许在旧版菜单脚本中继续监听 `I` / `E`
