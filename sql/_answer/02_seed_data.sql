-- ============================================================
-- 保底答案 02：灌 500 条有分布的模拟数据
-- 【重要】卡满 30 分钟才准打开。先自己在 sql/02_seed_data.sql 写一遍。
-- 执行：python utils/run_sql.py sql/02_seed_data.sql
-- 可重复执行：先清空再灌，跑几次结果都一样（这是「环境可重置」）
-- ============================================================

USE DQTest;
GO

-- ------------------------------------------------------------
-- 0) 重置：有外键的表不能用 TRUNCATE，只能 DELETE，顺序同样是先子后父
--    主键不用 IDENTITY，所以不需要 DBCC CHECKIDENT，ID 由造数语句自己给
-- ------------------------------------------------------------
DELETE FROM refunds;
DELETE FROM order_items;
DELETE FROM orders;
DELETE FROM users;
GO

-- ------------------------------------------------------------
-- 1) 用户 100 条 —— 练清单第 2 条 INSERT ... SELECT
--    数据分布：年龄 18—60、注册日期跨 180 天、约 1/13 是冻结账号
-- ------------------------------------------------------------
;WITH N AS (
    SELECT TOP (500) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
    FROM sys.all_objects a CROSS JOIN sys.all_objects b
)
INSERT INTO users (user_id, user_name, phone, age, reg_date, status)
SELECT
    n,                                                                 -- 1 ... 100
    'user' + RIGHT('000' + CAST(n AS VARCHAR(3)), 3),                 -- user001 ...
    '138'  + RIGHT('00000000' + CAST(n AS VARCHAR(8)), 8),           -- 11 位且不重复
    18 + (n * 7 % 43),                                                -- 18 ... 60
    DATEADD(DAY, n % 180, CAST('2026-01-01' AS DATE)),                -- 跨半年
    CASE WHEN n % 13 = 0 THEN 'FROZEN' ELSE 'ACTIVE' END
FROM N
WHERE n <= 100;
GO

-- ------------------------------------------------------------
-- 2) 订单 500 条 —— 清单第 4 条 INSERT ... SELECT 批量造数
--    order_amount 先全部置 0，第 4 步用明细汇总回填（顺便练 UPDATE 纪律）
-- ------------------------------------------------------------
;WITH N AS (
    SELECT TOP (500) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
    FROM sys.all_objects a CROSS JOIN sys.all_objects b
)
INSERT INTO orders (order_id, order_no, user_id, order_amount, status, created_at, paid_at, is_deleted)
SELECT
    n,                                                                 -- 1 ... 500
    'ORD' + RIGHT('00000' + CAST(n AS VARCHAR(5)), 5),                -- ORD00001 ... ORD00500
    (n % 100) + 1,                                                    -- 均匀落在这 100 个用户上
    CAST(0 AS DECIMAL(12,2)),                                         -- 占位，稍后回填
    CASE n % 5
        WHEN 0 THEN 'CREATED'
        WHEN 1 THEN 'PAID'
        WHEN 2 THEN 'SHIPPED'
        WHEN 3 THEN 'CLOSED'
        ELSE 'REFUNDED'
    END,
    v.created_at,
    CASE WHEN n % 5 = 0 THEN NULL                                     -- 未支付 → paid_at 为空
         ELSE DATEADD(HOUR, 2, v.created_at) END,
    CASE WHEN n % 37 = 0 THEN 1 ELSE 0 END                            -- 约 13 条软删除
FROM N
CROSS APPLY (
    SELECT DATEADD(DAY, N.n % 180,
           DATEADD(HOUR, N.n % 24,
           CAST('2026-01-01T08:00:00' AS DATETIME2(0)))) AS created_at
) v;
GO

-- ------------------------------------------------------------
-- 3) 明细约 1000 条 —— 清单第 5 条「造有规律的数据」
--    每单 1—3 行；line_amount = qty * unit_price（此刻全部对得上，W3 才埋雷）
-- ------------------------------------------------------------
;WITH N AS (
    SELECT TOP (500) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
    FROM sys.all_objects a CROSS JOIN sys.all_objects b
), K AS (
    SELECT 1 AS k UNION ALL SELECT 2 UNION ALL SELECT 3
)
INSERT INTO order_items (item_id, order_id, product_name, qty, unit_price, line_amount)
SELECT
    ROW_NUMBER() OVER (ORDER BY N.n, K.k),                             -- 连续主键
    N.n,
    'ITEM-' + CAST(K.k AS VARCHAR(2)),
    q.qty,
    q.price,
    CAST(q.qty * q.price AS DECIMAL(12,2))
FROM N CROSS JOIN K
CROSS APPLY (
    SELECT (N.n + K.k) % 4 + 1 AS qty,                                -- 1 ... 4
           CAST(10 + (N.n * 3 + K.k * 7) % 190 AS DECIMAL(10,2)) AS price  -- 10 ... 199
) q
WHERE (N.n + K.k) % 3 <> 0;                                           -- 每单留 1—3 行
GO

-- ------------------------------------------------------------
-- 4) 回填订单金额 —— 清单第 3 条 UPDATE 带条件的「纪律」
--    纪律：先 SELECT 确认影响范围，再 UPDATE。这条上班后能救你一次。
-- ------------------------------------------------------------
SELECT COUNT(*) AS will_update_rows
FROM orders o
JOIN (SELECT order_id, SUM(line_amount) AS total FROM order_items GROUP BY order_id) x
  ON o.order_id = x.order_id;
GO

UPDATE o
SET order_amount = x.total
FROM orders o
JOIN (SELECT order_id, SUM(line_amount) AS total FROM order_items GROUP BY order_id) x
  ON o.order_id = x.order_id;
GO

-- ------------------------------------------------------------
-- 5) 退款记录 —— 只给部分已退款订单，退款额 = 订单额的一半
-- ------------------------------------------------------------
INSERT INTO refunds (refund_id, order_id, refund_amount, reason, created_at)
SELECT ROW_NUMBER() OVER (ORDER BY order_id),
       order_id,
       CAST(order_amount * 0.5 AS DECIMAL(12,2)),
       'CUSTOMER_REQUEST',
       DATEADD(DAY, 1, created_at)
FROM orders
WHERE status = 'REFUNDED' AND order_id % 3 = 0;
GO

-- ------------------------------------------------------------
-- 6) 验收：下面这几个数就是 W1 的「做完了」标准
-- ------------------------------------------------------------
SELECT 'users'       AS tbl, COUNT(*) AS rows_cnt FROM users
UNION ALL SELECT 'orders',       COUNT(*) FROM orders
UNION ALL SELECT 'order_items',  COUNT(*) FROM order_items
UNION ALL SELECT 'refunds',      COUNT(*) FROM refunds;
GO

-- 双向核对：两个合计必须相等，diff 必须是 0.00
SELECT (SELECT SUM(order_amount) FROM orders)       AS orders_sum,
       (SELECT SUM(line_amount)  FROM order_items)  AS items_sum,
       (SELECT SUM(order_amount) FROM orders)
     - (SELECT SUM(line_amount)  FROM order_items)  AS diff;
GO

-- 按状态分组统计（W1 验收题：「PAID 状态的订单总金额是多少」）
SELECT status, COUNT(*) AS order_cnt, SUM(order_amount) AS total_amount
FROM orders
GROUP BY status
ORDER BY status;
GO

-- 不用一句乐观的 PRINT 糊弄过去，真的去校验一次
IF (SELECT COUNT(*) FROM orders) = 500
   AND (SELECT SUM(order_amount) FROM orders) = (SELECT SUM(line_amount) FROM order_items)
    PRINT '校验通过：500 单，订单金额与明细合计一致';
ELSE
    PRINT '校验未通过：往上翻，看是哪一步 INSERT 报了错';
GO
