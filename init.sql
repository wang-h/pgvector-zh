-- 创建必要的扩展
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS pg_jieba;

-- 创建基于pg_jieba的中文全文搜索配置
DO $BLOCK$
BEGIN
  -- 检查中文搜索配置是否已存在
  IF NOT EXISTS (
      SELECT 1 FROM pg_ts_config 
      WHERE cfgname = 'jieba_cfg'
  ) THEN
      -- 创建中文全文搜索配置
      EXECUTE 'CREATE TEXT SEARCH CONFIGURATION jieba_cfg (PARSER = jieba_parser)';
      EXECUTE 'ALTER TEXT SEARCH CONFIGURATION jieba_cfg ADD MAPPING FOR n,v,a,i,e,l WITH simple';
      RAISE NOTICE 'Text search configuration jieba_cfg created.';
  ELSE
      RAISE NOTICE 'Text search configuration jieba_cfg already exists.';
  END IF;
END;
$BLOCK$;

-- 为content_with_weight列创建或更新GIN索引
CREATE INDEX IF NOT EXISTS idx_chunk_content_fts_chinese
ON "Chunk" USING GIN (to_tsvector('jieba_cfg', content_with_weight)); 