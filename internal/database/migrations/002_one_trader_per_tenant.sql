SET @musky_trader_ddl = (
 SELECT IF(COUNT(*) = 0,
 'ALTER TABLE users ADD COLUMN trader_tenant_slot BIGINT UNSIGNED GENERATED ALWAYS AS (CASE WHEN role = ''trader'' THEN tenant_id ELSE NULL END) STORED, ADD UNIQUE KEY uq_trader_tenant (trader_tenant_slot)',
 'SELECT 1')
 FROM information_schema.columns
 WHERE table_schema = DATABASE() AND table_name = 'users' AND column_name = 'trader_tenant_slot'
);
PREPARE musky_trader_migration FROM @musky_trader_ddl;
EXECUTE musky_trader_migration;
DEALLOCATE PREPARE musky_trader_migration;
