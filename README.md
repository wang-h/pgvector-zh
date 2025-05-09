# PGVector-ZH: PostgreSQL向量搜索与中文分词

本项目提供了一个集成了向量搜索(pgvector)和中文分词(pg_jieba)的PostgreSQL Docker镜像，方便处理中文向量搜索和全文搜索需求。

## 功能特点

- 基于 PostgreSQL 17 最新版本
- 集成 pgvector 扩展用于向量搜索
- 集成 pg_jieba 扩展用于中文分词，解决BM25分数为0的问题
- 预配置优化的中文全文搜索配置
- 使用中国镜像源加速构建

## 使用前准备

您需要下载以下文件并放在相应目录：

1. `pg_jieba-master.zip` - pg_jieba源码，放在项目根目录
   ```bash
   curl -L https://github.com/jaiminpan/pg_jieba/archive/refs/heads/master.zip -o pg_jieba-master.zip
   ```

2. pg_jieba的依赖项，需要放在项目根目录下的相应文件夹：
   ```bash
   # 下载并解压jieba依赖
   mkdir -p jieba
   curl -L https://github.com/yanyiwu/jieba/archive/refs/heads/master.zip -o jieba.zip
   unzip -q jieba.zip
   cp -r jieba-master/* jieba/
   rm -rf jieba-master jieba.zip

   # 下载并解压cppjieba依赖
   mkdir -p cppjieba
   curl -L https://github.com/yanyiwu/cppjieba/archive/refs/heads/master.zip -o cppjieba.zip
   unzip -q cppjieba.zip
   cp -r cppjieba-master/* cppjieba/
   rm -rf cppjieba-master cppjieba.zip
   ```

## 使用方法

### 启动服务

```bash
# 构建并启动容器
docker compose up -d

# 查看日志
docker compose logs -f
```

### 连接到数据库

```bash
# 连接到PostgreSQL
docker compose exec postgres psql -U postgres
```

### 使用pgvector创建向量数据

```sql
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

```sql
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

## 高级配置

初始化脚本已自动配置了基础的中文分词设置。如需进一步自定义，可以修改 `init-database.sh` 文件。

## 参考资料

- [pg_jieba GitHub仓库](https://github.com/jaiminpan/pg_jieba)
- [pgvector GitHub仓库](https://github.com/pgvector/pgvector)
- [PostgreSQL 全文检索安装 pg_jieba 中文插件](https://www.zhangbj.com/p/1750.html) 