# Free Reader Tools

## 抓取赞美诗歌1218并生成 hymn.db

安装依赖：

```powershell
cd tools
npm install
```

生成数据库：

```powershell
npm run scrape:hymn1218
```

也可以自定义输出路径：

```powershell
node scrape_hymn_1218.mjs --out ../resources/hymn/hymn.db
```

如果脚本找不到 `sqlite3.exe`，传入路径：

```powershell
node scrape_hymn_1218.mjs --out ../hymn.db --sqlite3 D:\_devTools\_supports\free-reader-env\android-sdk\platform-tools\sqlite3.exe
```

输出表：

- `metadata`
- `catalog`
- `hymn`

`hymn` 表字段：

- `id`
- `title`
- `lyrics`
- `content`
- `audio_url`
- `notation_url`
- `source_id`
- `range_label`
- `source_url`
- `scraped_at`

注意：当前目标站点公开的 JSON 数据包含标题、音频 URL、简谱图片 URL，但没有文本歌词字段。因此脚本会创建 `lyrics/content` 字段，但在源站不提供歌词文本时保持为空。要获得真正歌词文本，需要另接 OCR 或使用包含歌词文本的数据源。
