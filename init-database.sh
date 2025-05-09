#!/bin/bash
set -e

# 此脚本在PostgreSQL初始化后运行
# 等待PostgreSQL完全启动
until pg_isready -h localhost -p 5432; do
  echo "等待PostgreSQL启动..."
  sleep 1
done

# 创建pg_jieba和vector扩展
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
  -- 创建扩展
  CREATE EXTENSION IF NOT EXISTS pg_jieba;
  CREATE EXTENSION IF NOT EXISTS vector;
  
  -- 创建中文全文搜索配置
  -- 如果配置不存在，则创建
  DO \$\$
  BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_ts_config WHERE cfgname = 'jieba_cfg') THEN
      CREATE TEXT SEARCH CONFIGURATION jieba_cfg (PARSER = jieba_parser);
      ALTER TEXT SEARCH CONFIGURATION jieba_cfg ADD MAPPING FOR n,v,a,i,e,l WITH simple;
    END IF;
  END
  \$\$;
  
  -- 显示中文分词示例
  SELECT ts_parse('jieba_parser', '这是一个中文分词测试');
  
  -- 显示安装的扩展
  SELECT * FROM pg_extension;
EOSQL

echo "数据库初始化完成：pg_jieba和pgvector扩展已创建" 