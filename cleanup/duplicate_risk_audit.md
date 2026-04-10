# 重复源风险审计

更新时间：2026-04-08

## 一、全局单例 / Autoload

- 当前只发现一个 Autoload：
  - `GameState -> game/scripts/game_state.gd`
- 结论：
  - 未发现第二个属性管理器 / 背包管理器 / 结算管理器单例
  - Autoload 重复风险低

## 二、高风险重复脚本

### 玩家菜单 / 背包 UI 旧版本

- `game/scripts/player_menu.gd`
- `game/scripts/player_menu_v2.gd`
- `game/scripts/player_menu_v3.gd`
- `game/scripts/player_menu_ui.gd`
- 现役文件：
  - `game/scripts/player_menu_ui_v2.gd`
- 风险：
  - 多个脚本都监听 `KEY_I`
  - 多个脚本都包含装备 / 背包 / 属性显示逻辑
  - 如果场景或代码误引用旧版，会出现菜单错乱、Tooltip 复用、布局退化

### 宝箱 UI 旧版本

- `game/scripts/chest_menu.gd`
- `game/scripts/chest_menu_v2.gd`
- `game/scripts/chest_menu_ui.gd`
- 现役文件：
  - `game/scripts/chest_menu_ui_v2.gd`
- 风险：
  - 多个脚本都监听 `KEY_E`
  - 多个脚本都处理宝箱与背包拖拽

### 宝箱交互对象旧版本

- `game/scripts/chest_interactable.gd`
- `game/scenes/chest_interactable.tscn`
- 现役文件：
  - `game/scripts/chest_interactable_v2.gd`
  - `game/scenes/chest_interactable_v2.tscn`
- 风险：
  - 旧版提示文案编码损坏
  - 若场景回指旧版，交互提示和打开逻辑可能不稳定

## 三、属性重算重复源

- 现役唯一公式：
  - `game/scripts/character_stats.gd`
- 仍存在的包装调用：
  - `character_creation/scripts/character_creation_flow.gd::_calculate_b_stats()`
- UI 仍有读取并格式化 B 属性的行为：
  - `player_menu_ui_v2.gd`
  - `newbie_village.gd`
- 结论：
  - 公式源头已经统一
  - 但旧版 UI 文件里仍残留对 `CharacterStats.calculate_b_stats()` 的调用，需避免再次引用

## 四、技能逻辑重复源

- 现役逻辑：
  - `player.gd`
  - 触发方式：范围内有敌人且冷却结束立即触发
- 高风险旧版本：
  - 旧版菜单脚本中曾保留旧 Tooltip / 旧冷却显示结构
- 结论：
  - 代码层没发现第二套现役斩击逻辑入口
  - 但旧菜单文件的说明文案与显示逻辑仍会制造“看起来像第二套逻辑”的风险

## 五、装备结算重复源

- 现役结算链：
  - `player.gd::_recalculate_character_state()`
- 风险点：
  - 若旧菜单脚本再次被引用，会在 UI 层重复计算增量显示
- 结论：
  - 真正的最终数值入口当前只有一套
  - 但旧 UI 文件是高风险误引用源

## 六、背包数据重复源

- 现役数据源：
  - `player.gd::inventory_slots`
- 现役读取端：
  - `player_menu_ui_v2.gd`
  - `chest_menu_ui_v2.gd`
- 风险点：
  - 旧版 `player_menu*` 与 `chest_menu*` 也维护自己的视图数组
- 结论：
  - 数据源统一
  - 视图实现文件重复很多，优先级很高

## 七、输入监听重复源

- 输入映射文件：
  - `project.godot`
  - 仅发现 `move_left / move_right / move_up / move_down`
- 非映射直连输入：
  - `KEY_I`
  - `KEY_E`
  - `KEY_SHIFT`
  - 鼠标滚轮
- 风险：
  - 多个旧菜单脚本都监听 `I`
  - 多个旧宝箱脚本 / 菜单脚本都监听 `E`
- 结论：
  - Input Map 重复风险低
  - 输入监听重复风险高

## 八、信号连接重复源

- 现役明显连接：
  - `player.death_requested -> newbie_village.request_player_death`
  - `enemy.enemy_died -> newbie_village._on_enemy_died`
- 风险：
  - 若旧场景或旧脚本重新接入，会造成双触发
- 当前证据：
  - 未发现第二个现役结算入口
  - 但旧文件仍在项目中，应先隔离

## 九、首批待废弃对象

建议先移动到 `res://_deprecated/`，不要立刻删除：

- `game/scripts/player_menu.gd`
- `game/scripts/player_menu_v2.gd`
- `game/scripts/player_menu_v3.gd`
- `game/scripts/player_menu_ui.gd`
- `game/scripts/chest_menu.gd`
- `game/scripts/chest_menu_v2.gd`
- `game/scripts/chest_menu_ui.gd`
- `game/scripts/chest_interactable.gd`
- `game/scenes/chest_interactable.tscn`

第二批候选，需再确认是否还需要保留测试用途：

- `game/scripts/enemy_dummy.gd`
- `game/scenes/enemy_dummy.tscn`
- `tools/check_newbie_village.gd`

## 十、清理顺序建议

1. 先在 `project_cleanup_working` 中查引用
2. 确认新入口仍指向：
   - `player_menu_ui_v2.gd`
   - `chest_menu_ui_v2.gd`
   - `chest_interactable_v2.tscn`
3. 把首批待废弃对象移动到 `res://_deprecated/`
4. 跑一次固定回归测试
5. 没问题后再处理第二批候选
## 2026-04-08 First Migration Batch Status

Working copy used:
- `e:\working_VSCODE\project_cleanup_working`

Batch A completed: old menu files moved to `_deprecated/menus`
- `game/scripts/player_menu.gd` -> `_deprecated/menus/deprecated_player_menu.gd`
- `game/scripts/player_menu_v2.gd` -> `_deprecated/menus/deprecated_player_menu_v2.gd`
- `game/scripts/player_menu_v3.gd` -> `_deprecated/menus/deprecated_player_menu_v3.gd`
- `game/scripts/player_menu_ui.gd` -> `_deprecated/menus/deprecated_player_menu_ui.gd`

Batch B completed: old chest files moved to `_deprecated/chest`
- `game/scripts/chest_menu.gd` -> `_deprecated/chest/deprecated_chest_menu.gd`
- `game/scripts/chest_menu_v2.gd` -> `_deprecated/chest/deprecated_chest_menu_v2.gd`
- `game/scripts/chest_menu_ui.gd` -> `_deprecated/chest/deprecated_chest_menu_ui.gd`
- `game/scripts/chest_interactable.gd` -> `_deprecated/chest/deprecated_chest_interactable.gd`
- `game/scenes/chest_interactable.tscn` -> `_deprecated/chest/deprecated_chest_interactable.tscn`

Reference note:
- The moved deprecated chest scene was updated to reference `res://_deprecated/chest/deprecated_chest_interactable.gd`
- No active `game/` path in the working copy still references the migrated old menu/chest files

Automated validation:
- Menu batch headless check: `check_newbie_village_ok`
- Chest batch headless check: `check_newbie_village_ok`

Current status:
- First migration batch passed automated scene-load validation
- Manual regression checklist is still required for `I` menu flow, chest flow, iron sword equip flow, combat, death result, and boss clear result
