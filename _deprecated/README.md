# _deprecated

这个目录用于临时下线旧文件，不用于当前现役功能开发。

规则：
- 这里只存放已废弃或待彻底清理的旧文件。
- 新系统和现役主链路禁止继续引用这里的内容。
- 推荐处理顺序是：
  - 先检查旧文件是否仍被引用
  - 把引用替换到现役入口
  - 再移入 `_deprecated/`
  - 跑回归测试
  - 最后再决定是否彻底删除

当前状态：
- 当前主项目副本里的 `_deprecated/` 还没有正式迁入废弃文件，本目录目前主要保留说明文档。
- 如果要执行首批迁移，建议先在 `project_cleanup_working` 这类清理工作副本中完成验证，再决定是否同步到主项目。

## First Migration Batch - 2026-04-08

The first formal migration batch was defined for the cleanup working-copy flow, covering old menu and chest entry files.

Deprecated menu files:
- `menus/deprecated_player_menu.gd`
- `menus/deprecated_player_menu_v2.gd`
- `menus/deprecated_player_menu_v3.gd`
- `menus/deprecated_player_menu_ui.gd`

Deprecated chest files:
- `chest/deprecated_chest_menu.gd`
- `chest/deprecated_chest_menu_v2.gd`
- `chest/deprecated_chest_menu_ui.gd`
- `chest/deprecated_chest_interactable.gd`
- `chest/deprecated_chest_interactable.tscn`

Reason for retirement:
- Duplicate old menu and chest entry points
- High risk of hidden preload, signal, or scene reference conflicts
- Not part of the current active runtime path

Important rule:
- These files must not be reintroduced into active scene or script references
- If any future scene or script still points here, treat it as a regression

Validation state:
- The first migration batch passed automated `newbie_village` headless load checks
- Manual gameplay regression verification is still pending