# Free Reader

个人使用的 Android 本地圣经阅读 App。第一阶段目标是搭好离线阅读基础架构、数据库边界和基础页面，不实现完整阅读器。

## 项目目录结构

```text
lib/
  app/
    free_reader_app.dart
    main_shell.dart
  core/
    theme/
  database/
    connections/
    tables/
    bible_database.dart
    user_database.dart
    database_providers.dart
  features/
    home/
      presentation/
      providers/
    library/
      presentation/
      providers/
    setting/
      data/
      presentation/
      providers/
    reader/
      data/
      domain/
      providers/
assets/
  db/
    bible.db
android/
```

## 数据库设计

### bible.db

用途：圣经正文，只读。

来源：`F:/_softwares/Edge/Downloads/bible_简体中文和合本.db` 已复制到 `assets/db/bible.db`，App 首次运行会复制到应用支持目录后以只读方式打开。

已映射表：

- `BibleID`
  - `SN`
  - `KindSN`
  - `ChapterNumber`
  - `NewOrOld`
  - `PinYin`
  - `ShortName`
  - `FullName`
- `Bible`
  - `ID`
  - `VolumeSN`
  - `ChapterSN`
  - `VerseSN`
  - `Lection`
  - `SoundBegin`
  - `SoundEnd`

### user.db

用途：用户数据，可写，由 Drift 创建和迁移。

第一阶段表：

- `reading_progress`
  - `id`
  - `volume_sn`
  - `chapter_sn`
  - `verse_sn`
  - `scroll_offset`
  - `last_read_time`
- `app_setting`
  - `id`
  - `theme`
  - `font_size`
  - `line_height`
  - `background_type`

## 已完成内容

- Flutter + Dart + Material 3 项目基础结构
- Riverpod Provider 入口
- 底部导航：首页、书架、我的
- 首页：最近阅读卡片、继续阅读入口占位
- 书架：圣经入口，读取 `BibleID` 统计卷数
- 我的：深色模式开关、字号设置基础结构
- Drift 数据库定义
- `bible.db` 只读连接能力
- `user.db` 创建与 Migration 基础结构
- Repository 层隔离数据库访问

暂未实现：阅读页面、搜索、笔记、书签、云同步、登录、后端、多版本圣经。

## 如何运行

当前机器命令行未安装 `flutter`/`dart`，因此本次未执行编译验证。安装 Flutter SDK 后，在项目根目录运行：

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```

如果 Android Gradle wrapper 缺失或本地 Android 工程需要由 Flutter 重新补齐，可先执行：

```bash
flutter create . --platforms=android
```

再重新执行上面的依赖安装、Drift 代码生成和运行命令。

## 下一阶段建议

1. 实现阅读页面：按 `volume_sn/chapter_sn/verse_sn` 加载章节正文。
2. 接入阅读进度：监听滚动位置，保存 `reading_progress`。
3. 增加书卷/章节选择：先做 Bible App 风格的书卷结构，不做复杂工具。
4. 扩展阅读设置：背景色、行高、段间距、屏幕常亮。
5. 增加基础测试：Repository 查询、设置默认值、迁移验证。
