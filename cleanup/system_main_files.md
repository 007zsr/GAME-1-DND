# 系统主文件清单

更新时间：2026-04-08

## 玩家系统

- 主体脚本：`game/scripts/player.gd`
- 属性重算：`game/scripts/character_stats.gd`
- 运行时状态单例：`game/scripts/game_state.gd`
- 层级常量：`game/scripts/game_layers.gd`

## 技能与战斗系统

- 主场景逻辑：`game/scripts/newbie_village.gd`
- 敌人基类：`game/scripts/enemy_actor.gd`
- 敌方投射物：`game/scripts/enemy_projectile.gd`
- 飘字、结算、战斗处理：`game/scripts/newbie_village.gd`

## 背包与装备系统

- 物品数据：`game/scripts/item_system.gd`
- 物品槽通用控件：`game/scripts/item_slot.gd`
- 统合菜单主 UI：`game/scripts/player_menu_ui_v2.gd`

## 宝箱系统

- 宝箱交互对象：`game/scripts/chest_interactable_v2.gd`
- 宝箱场景：`game/scenes/chest_interactable_v2.tscn`
- 宝箱 UI：`game/scripts/chest_menu_ui_v2.gd`

## UI 系统

- 主菜单：`main_menu/scripts/main_menu.gd`
- 角色创建：`character_creation/scripts/character_creation_flow.gd`
- 小型物品提示框：`game/scripts/simple_item_tooltip.gd`
- 死亡结算：`game/scripts/newbie_village.gd`
- Boss 结算：`game/scripts/newbie_village.gd`

## 场景主文件

- 主菜单场景：`main_menu/scenes/main_menu.tscn`
- 角色创建场景：`character_creation/scenes/character_creation_flow.tscn`
- 游戏主场景：`game/scenes/newbie_village.tscn`
- 敌人场景：`game/scenes/enemy_actor.tscn`
- 投射物场景：`game/scenes/enemy_projectile.tscn`

## 当前现役引用确认

- `newbie_village.gd` 当前引用：
  - `player_menu_ui_v2.gd`
  - `chest_menu_ui_v2.gd`
  - `chest_interactable_v2.tscn`

凡是不在本清单中的旧版本文件，默认列为“待废弃候选”，不能继续作为新功能入口。
## 2026-04-08 Active Entry Reconfirmation

After first cleanup migration in `project_cleanup_working`, the active runtime entry files remain:

- `game/scripts/player_menu_ui_v2.gd`
- `game/scripts/chest_menu_ui_v2.gd`
- `game/scripts/chest_interactable_v2.gd`
- `game/scenes/chest_interactable_v2.tscn`
- `game/scripts/newbie_village.gd`
- `game/scripts/character_stats.gd`
- `game/scripts/item_system.gd`

Verification notes:
- `newbie_village.gd` still preloads `player_menu_ui_v2.gd`
- `newbie_village.gd` still preloads `chest_menu_ui_v2.gd`
- `newbie_village.gd` still instantiates `game/scenes/chest_interactable_v2.tscn`
- The first deprecated migration batch did not change current main entry ownership
