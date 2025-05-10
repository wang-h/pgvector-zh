-- 创建必要的扩展
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS pg_jieba;
CREATE EXTENSION IF NOT EXISTS age;

-- 创建基于pg_jieba的中文全文搜索配置
DO $BLOCK$
BEGIN
  -- 检查中文搜索配置是否已存在
  IF NOT EXISTS (
      SELECT 1 FROM pg_ts_config 
      WHERE cfgname = 'jieba_cfg'
  ) THEN
      -- 创建中文全文搜索配置
      EXECUTE 'CREATE TEXT SEARCH CONFIGURATION jieba_cfg (PARSER = jieba)';
      EXECUTE 'ALTER TEXT SEARCH CONFIGURATION jieba_cfg ADD MAPPING FOR n,v,a,i,e,l WITH simple';
      RAISE NOTICE 'Text search configuration jieba_cfg created.';
  ELSE
      RAISE NOTICE 'Text search configuration jieba_cfg already exists.';
  END IF;
END;
$BLOCK$;

-- 加载AGE扩展并设置搜索路径
LOAD 'age';
SET search_path = ag_catalog, "$user", public;

-- 创建一个示例图
SELECT create_graph('sample_graph');