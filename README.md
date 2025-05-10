# PGVector-ZH: PostgreSQL向量搜索与中文分词

本项目提供了一个集成了向量搜索(pgvector)、中文分词(pg_jieba)和图数据库功能(Apache AGE)的PostgreSQL Docker镜像，方便处理中文向量搜索、全文搜索和图数据需求。

## 功能特点

- 基于 PostgreSQL 16 版本
- 集成 pgvector 扩展用于向量搜索
- 集成 pg_jieba 扩展用于中文分词，解决BM25分数为0的问题
- 集成 Apache AGE 扩展用于图数据库功能 （只支持pg12-16）
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

首次启动容器时，`init.sql`脚本会自动执行以下操作：
- 创建 vector 和 pg_jieba 扩展
- 配置 jieba_cfg 文本搜索配置（使用 jieba 解析器）

如果您的数据卷已经存在，初始化脚本不会自动执行。您可以通过以下方式手动执行：

```bash
# 删除现有数据卷并重启(会清除所有数据)
docker compose down -v
docker compose up -d

# 或者手动执行SQL命令
docker compose exec postgres psql -U postgres -c "CREATE EXTENSION IF NOT EXISTS vector; CREATE EXTENSION IF NOT EXISTS pg_jieba;"
docker compose exec postgres psql -U postgres -c "CREATE TEXT SEARCH CONFIGURATION jieba_cfg (PARSER = jieba); ALTER TEXT SEARCH CONFIGURATION jieba_cfg ADD MAPPING FOR n,v,a,i,e,l WITH simple;"
```

### 连接到数据库

```bash
# 连接到PostgreSQL
docker compose exec postgres psql -U postgres
```

### 验证安装是否成功

您可以通过以下命令检查扩展和文本搜索配置是否已成功安装：

```bash
# 检查已安装的扩展
docker compose exec postgres psql -U postgres -c "SELECT extname, extversion FROM pg_extension;"

# 检查是否有jieba解析器
docker compose exec postgres psql -U postgres -c "SELECT prsname FROM pg_ts_parser WHERE prsname LIKE 'jieba%';"

# 检查jieba_cfg是否已创建
docker compose exec postgres psql -U postgres -c "SELECT cfgname FROM pg_ts_config WHERE cfgname = 'jieba_cfg';"

# 检查AGE图是否已创建
docker compose exec postgres psql -U postgres -c "SELECT * FROM ag_catalog.ag_graph;"
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
      tsv_content @@ to_tsquery('jieba_cfg', '数据库');
```

预期结果应当包含 "PostgreSQL数据库简介" 这篇文章，因为它的标题中包含 "数据库" 这个词。

## 使用Apache AGE进行图数据操作

Apache AGE是PostgreSQL的图数据库扩展，支持图数据的存储和Cypher查询语法。在使用前，确保AGE扩展已加载：

```sql
-- 检查AGE扩展是否加载
SELECT * FROM pg_extension WHERE extname = 'age';

-- 加载AGE，设置搜索路径
LOAD 'age';
SET search_path = ag_catalog, "$user", public;

-- 创建一个新图
SELECT create_graph('my_graph');

-- 创建节点
SELECT * FROM cypher('my_graph', $$
    CREATE (p:Person {name: '张三', age: 30})
    RETURN p
$$) as (v agtype);

-- 创建多个节点
SELECT * FROM cypher('my_graph', $$
    CREATE (p1:Person {name: '李四', age: 25}),
           (p2:Person {name: '王五', age: 35})
    RETURN p1, p2
$$) as (v1 agtype, v2 agtype);

-- 创建边
SELECT * FROM cypher('my_graph', $$ 
    MATCH (p1:Person {name: '张三'}), (p2:Person {name: '李四'}) 
    CREATE (p1)-[r:FRIEND {since: '2023'}]->(p2)
    RETURN r
$$) AS (e agtype);

-- 查询所有人
SELECT * FROM cypher('my_graph', $$
    MATCH (p:Person)
    RETURN p.name AS name, p.age AS age
$$) as (name agtype, age agtype);

-- 查询好友关系
SELECT * FROM cypher('my_graph', $$
    MATCH (a:Person)-[r:FRIEND]->(b:Person)
    RETURN a.name AS person1, b.name AS person2, r.since AS since
$$) as (person1 agtype, person2 agtype, since agtype);

-- 路径查询
SELECT * FROM cypher('my_graph', $$
    MATCH p = (a:Person {name: '张三'})-[*1..3]->(b:Person)
    RETURN p
$$) as (path agtype);
```

### 组合使用向量搜索和图数据库

可以将pgvector向量搜索与Apache AGE图数据库结合使用，实现更复杂的知识检索应用：

```sql
-- 创建人物向量表
CREATE TABLE person_embeddings (
    id SERIAL PRIMARY KEY,
    name TEXT,
    embedding VECTOR(384)
);

-- 插入一些人物向量数据
INSERT INTO person_embeddings (name, embedding)
VALUES 
    ('张三', '[0.1, 0.2, 0.3, ... ]'),
    ('李四', '[0.2, 0.3, 0.4, ... ]'),
    ('王五', '[0.3, 0.4, 0.5, ... ]');

-- 在图中创建相应的人物节点
SELECT * FROM cypher('my_graph', $$
    CREATE (p:Person {name: '张三', person_id: 1})
    RETURN p
$$) as (v agtype);

-- 查询最相似的人物，并查询其在图中的关系
WITH similar_persons AS (
    SELECT name, id
    FROM person_embeddings
    ORDER BY embedding <-> '[0.15, 0.25, 0.35, ... ]'
    LIMIT 3
)
SELECT 
    sp.name,
    (SELECT * FROM cypher('my_graph', $$
        MATCH (p:Person {name: $1})-[r]->(other)
        RETURN collect(other.name) AS connected_to
    $$, sp.name) AS (connected_to agtype)) AS connections
FROM similar_persons sp;
```

## 故障排除

1. **找不到vector类型**：如果遇到`ERROR: type "vector" does not exist`错误，说明vector扩展未正确加载。使用`CREATE EXTENSION vector;`创建扩展。

2. **jieba_cfg配置未找到**：如果遇到文本搜索配置相关错误，可能是初始化脚本没有执行。连接到数据库后手动创建所需配置：
   ```sql
   CREATE TEXT SEARCH CONFIGURATION jieba_cfg (PARSER = jieba);
   ALTER TEXT SEARCH CONFIGURATION jieba_cfg ADD MAPPING FOR n,v,a,i,e,l WITH simple;
   ```

3. **找不到jieba解析器**：确保pg_jieba扩展已正确加载，并且在`shared_preload_libraries`中包含了`pg_jieba.so`。使用`SHOW shared_preload_libraries;`命令检查。

4. **重置数据库**：如需完全重置，可使用以下命令删除所有数据并重新初始化：
   ```bash
   docker compose down -v
   docker compose up -d
   ```

## 高级配置

pgvector支持多种维度的向量，默认示例使用的是3维向量，实际应用中通常会使用高维向量（如OpenAI模型生成的1536维嵌入向量）。

pg_jieba提供了四种不同的解析器模式：
- `jieba`：标准模式，默认使用
- `jiebaqry`：查询模式
- `jiebamp`：最大概率模式
- `jiebahmm`：隐马尔可夫模型模式

您可以根据需要选择不同的解析器模式创建文本搜索配置。

## 在Prisma应用中使用

如果您的应用使用Prisma ORM，确保在`schema.prisma`文件中开启PostgreSQL扩展支持：

```prisma
generator client {
  provider        = "prisma-client-js"
  previewFeatures = ["postgresqlExtensions"]
}

datasource db {
  provider   = "postgresql"
  url        = env("DATABASE_URL")
  extensions = [vector]
}
```

对于向量字段，可以使用`Unsupported`类型：

```prisma
model Chunk {
  // ... 其他字段
  embedding Unsupported("vector(1536)")? // 向量嵌入，支持 pgvector
}
```

## 参考资料

- [pg_jieba GitHub仓库](https://github.com/jaiminpan/pg_jieba)
- [pgvector GitHub仓库](https://github.com/pgvector/pgvector)
- [Apache AGE GitHub仓库](https://github.com/apache/age)
- [Apache AGE官方文档](https://age.apache.org/)
- [PostgreSQL 全文检索安装 pg_jieba 中文插件](https://www.zhangbj.com/p/1750.html)

## 图数据库AGE拓展，使用递归CTE查找路径

```sql
-- 创建节点和边表
CREATE TABLE nodes (
    id SERIAL PRIMARY KEY,
    properties JSONB
);

CREATE TABLE edges (
    id SERIAL PRIMARY KEY,
    source_id INTEGER REFERENCES nodes(id),
    target_id INTEGER REFERENCES nodes(id),
    type TEXT,
    properties JSONB
);

-- 使用递归CTE查找路径
WITH RECURSIVE path AS (
    SELECT source_id, target_id, ARRAY[source_id, target_id] AS path
    FROM edges
    WHERE source_id = 1
    
    UNION ALL
    
    SELECT e.source_id, e.target_id, p.path || e.target_id
    FROM edges e
    JOIN path p ON e.source_id = p.target_id
    WHERE NOT e.target_id = ANY(p.path)
)
SELECT * FROM path;
``` 