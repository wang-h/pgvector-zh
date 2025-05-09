# PGVector-ZH: PostgreSQL向量搜索与中文分词

本项目提供了一个集成了向量搜索(pgvector)和中文分词(pg_jieba)的PostgreSQL Docker镜像，方便处理中文向量搜索和全文搜索需求。

## 功能特点

- 基于 PostgreSQL 17 最新版本
- 集成 pgvector 扩展用于向量搜索
- 集成 pg_jieba 扩展用于中文分词，解决BM25分数为0的问题
- 预配置优化的中文全文搜索配置
- 使用中国镜像源加速构建

## 使用前准备

项目根目录需要有一个完整的`pg_jieba`目录，包含所有必要的子目录和依赖项：

```
pg_jieba/                      # pg_jieba主目录
├── libjieba/                  # libjieba子模块目录
│   ├── deps/                  # 存放依赖的目录
│   │   └── limonp/           # limonp依赖(必须)
│   │       └── include/      # limonp的头文件目录
│   │           └── limonp/   # 包含Logging.hpp等头文件
│   └── include/              # cppjieba的头文件目录
│       └── cppjieba/         # 包含Jieba.hpp等头文件
├── CMakeLists.txt            # 编译配置文件
├── jieba.cpp                 # 源代码文件
└── pg_jieba.c                # 源代码文件
```

您可以通过以下方式获取完整的pg_jieba：

```bash
# 克隆pg_jieba仓库并初始化所有子模块
git clone https://github.com/jaiminpan/pg_jieba.git
cd pg_jieba
git submodule update --init --recursive
```

## 使用方法

### 启动服务

```bash
# 构建并启动容器(首次启动)
docker compose up -d

# 查看日志
docker compose logs -f
```

### 初始化说明

首次启动容器时，`init-database.sh`脚本会自动执行以下操作：
- 创建pg_jieba和vector扩展
- 配置jieba_cfg文本搜索配置

如果您的数据卷已经存在，初始化脚本不会自动执行。您可以通过以下方式手动执行：

```bash
# 删除现有数据卷并重启(会清除所有数据)
docker compose down -v
docker compose up -d

# 或者手动执行SQL命令
docker compose exec postgres psql -U postgres -c "CREATE EXTENSION IF NOT EXISTS vector; CREATE EXTENSION IF NOT EXISTS pg_jieba;"
```

### 连接到数据库

```bash
# 连接到PostgreSQL
docker compose exec postgres psql -U postgres
```

### 使用pgvector创建向量数据

在使用pgvector相关功能前，确保扩展已加载：

```sql
-- 检查扩展是否已加载
SELECT * FROM pg_extension;

-- 如果没有vector扩展，手动创建
CREATE EXTENSION IF NOT EXISTS vector;

-- 创建测试表
CREATE TABLE items (
  id SERIAL PRIMARY KEY,
  embedding VECTOR(3),
  name TEXT,
  description TEXT
);

-- 插入一些测试数据
INSERT INTO items (embedding, name, description)
VALUES ('[1,2,3]', '笔记本电脑', '这是一台高性能的笔记本电脑'),
       ('[4,5,6]', '智能手机', '这是一款功能强大的智能手机'),
       ('[7,8,9]', '平板电脑', '这是一台轻薄的平板电脑');

-- 使用向量搜索查询最相似的项目
SELECT name, description, embedding <-> '[3,3,3]' as distance
FROM items
ORDER BY distance
LIMIT 5;
```

### 使用pg_jieba进行中文分词搜索

在使用pg_jieba相关功能前，确保扩展已加载：

```sql
-- 检查扩展是否已加载
SELECT * FROM pg_extension;

-- 如果没有pg_jieba扩展，手动创建
CREATE EXTENSION IF NOT EXISTS pg_jieba;

-- 创建全文搜索测试表
CREATE TABLE articles (
  id SERIAL PRIMARY KEY,
  title TEXT,
  content TEXT
);

-- 添加全文搜索索引
ALTER TABLE articles ADD COLUMN tsv_title TSVECTOR GENERATED ALWAYS AS (to_tsvector('jieba_cfg', title)) STORED;
ALTER TABLE articles ADD COLUMN tsv_content TSVECTOR GENERATED ALWAYS AS (to_tsvector('jieba_cfg', content)) STORED;

-- 创建GIN索引加速搜索
CREATE INDEX articles_tsv_title_idx ON articles USING GIN(tsv_title);
CREATE INDEX articles_tsv_content_idx ON articles USING GIN(tsv_content);

-- 插入测试数据
INSERT INTO articles (title, content)
VALUES ('PostgreSQL数据库简介', 'PostgreSQL是一个功能强大的开源关系型数据库系统'),
       ('中文全文搜索技术', '全文搜索是信息检索领域的重要技术，能够快速从大量文本中找到相关信息'),
       ('人工智能与大数据', '人工智能技术结合大数据分析可以提供更智能的决策支持');

-- 使用全文搜索查询
SELECT title, content, 
       ts_rank(tsv_title, to_tsquery('jieba_cfg', '数据库')) AS title_rank,
       ts_rank(tsv_content, to_tsquery('jieba_cfg', '数据库')) AS content_rank
FROM articles
WHERE tsv_title @@ to_tsquery('jieba_cfg', '数据库') OR 
      tsv_content @@ to_tsquery('jieba_cfg', '数据库')
ORDER BY title_rank + content_rank DESC;
```

## 故障排除

1. **找不到vector类型**：如果遇到`ERROR: type "vector" does not exist`错误，说明vector扩展未正确加载。使用`CREATE EXTENSION vector;`创建扩展。

2. **jieba_cfg配置未找到**：如果遇到文本搜索配置相关错误，可能是初始化脚本没有执行。连接到数据库后手动创建所需配置：
   ```sql
   CREATE TEXT SEARCH CONFIGURATION jieba_cfg (PARSER = jieba_parser);
   ALTER TEXT SEARCH CONFIGURATION jieba_cfg ADD MAPPING FOR n,v,a,i,e,l WITH simple;
   ```

3. **重置数据库**：如需完全重置，可使用以下命令删除所有数据并重新初始化：
   ```bash
   docker compose down -v
   docker compose up -d
   ```

## 高级配置

初始化脚本已自动配置了基础的中文分词设置。如需进一步自定义，可以修改 `init-database.sh` 文件。

## 参考资料

- [pg_jieba GitHub仓库](https://github.com/jaiminpan/pg_jieba)
- [pgvector GitHub仓库](https://github.com/pgvector/pgvector)
- [PostgreSQL 全文检索安装 pg_jieba 中文插件](https://www.zhangbj.com/p/1750.html) 