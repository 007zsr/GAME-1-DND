# _deprecated

杩欎釜鐩綍鐢ㄤ簬涓存椂涓嬬嚎鏃ф枃浠讹紝涓嶇敤浜庡紑鍙戠幇褰瑰姛鑳姐€?
瑙勫垯锛?
- 鍙厑璁稿瓨鏀惧緟搴熷純鏂囦欢
- 鏂扮郴缁熺姝㈠紩鐢ㄨ繖閲岀殑鍐呭
- 鏂囦欢澶勭悊椤哄簭蹇呴』鏄細
  - 鏌ュ紩鐢?  - 鏇挎崲寮曠敤
  - 绉诲叆 `_deprecated`
  - 鍥炲綊娴嬭瘯
  - 鏈€缁堝垹闄?
褰撳墠杩樻病鏈夋寮忚縼鍏ユ枃浠躲€?寤鸿鍏堝湪 `project_cleanup_working` 鍓湰閲屾墽琛岃縼绉伙紝鍐嶅喅瀹氭槸鍚﹀悓姝ュ埌涓婚」鐩€?## First Migration Batch - 2026-04-08

This directory now contains the first formally retired UI / chest files, but only inside the cleanup working-copy migration flow.

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
- High risk of hidden preload / signal / scene reference conflicts
- Not part of the current active runtime path

Important rule:
- These files must not be reintroduced into active scene/script references
- If any future scene or script still points here, treat it as a regression

Validation state:
- First migration batch passed automated `newbie_village` headless load checks
- Manual gameplay regression verification is still pending
