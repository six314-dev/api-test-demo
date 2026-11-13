-- ============================================================
-- 保底答案 01：建 4 张业务表
-- 【重要】这是「卡满 30 分钟才准打开」的参考答案，不是给你抄的。
--   先自己在 sql/01_create_tables.sql 里写一遍，写完再对这里。
-- 执行：python utils/run_sql.py sql/01_create_tables.sql
-- 可重复执行：会先删表再重建（按外键依赖倒序删）
-- ============================================================

USE DQTest;
GO

-- 删表顺序不能反：先删被别人引用的子表，最后删父表
DROP TABLE IF EXISTS refunds;
DROP TABLE IF EXISTS order_items;
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS users;
GO

-- ------------------------------------------------------------
-- 表 1：用户表 users
-- 约束练习点：主键 / NOT NULL / UNIQUE / CHECK（age 范围、status 枚举）/ DEFAULT
-- ------------------------------------------------------------
CREATE TABLE users (
    -- 【为什么不用 IDENTITY】测试库要能精确控制每一条记录的 ID
    -- 空表上 DBCC CHECKIDENT RESEED 0 后第一条可能从 0 开始，会让外键对不上
    user_id    INT               NOT NULL,
    user_name  NVARCHAR(32)      NOT NULL,
    phone      CHAR(11)          NOT NULL,
    age        INT               NOT NULL,
    reg_date   DATE              NOT NULL,
    status     VARCHAR(10)       NOT NULL,
    created_at DATETIME2(0)      NOT NULL DEFAULT GETDATE(),
    CONSTRAINT PK_users PRIMARY KEY (user_id),
    CONSTRAINT UQ_users_phone UNIQUE (phone),
    CONSTRAINT CK_users_age CHECK (age >= 18 AND age <= 60),
    CONSTRAINT CK_users_status CHECK (status IN ('ACTIVE', 'FROZEN'))
);
GO

-- ------------------------------------------------------------
-- 表 2：订单表 orders
-- 刻意留的口子（W3 埋雷要用，现在别补）：
--   * 不加 CHECK(paid_at >= created_at) —— 否则「时间穿越」的雷埋不进去
--   * 不加 CHECK(order_amount = 明细合计) —— 跨表约束 SQL 里本来也写不了
--   * UQ_orders_order_no 显式命名 —— W3 造「重复订单号」时一行 DROP 就能临时去掉
-- ------------------------------------------------------------
CREATE TABLE orders (
    order_id     INT               NOT NULL,
    order_no     VARCHAR(20)       NOT NULL,
    user_id      INT               NOT NULL,
    order_amount DECIMAL(12,2)     NOT NULL,
    status       VARCHAR(12)       NOT NULL,
    created_at   DATETIME2(0)      NOT NULL,
    paid_at      DATETIME2(0)      NULL,       -- 可空：未支付的订单没有支付时间，练 IS NULL
    is_deleted   BIT               NOT NULL DEFAULT 0,   -- 软删除标记，W3 要统计「被漏算」
    CONSTRAINT PK_orders PRIMARY KEY (order_id),
    CONSTRAINT UQ_orders_order_no UNIQUE (order_no),
    CONSTRAINT FK_orders_user FOREIGN KEY (user_id) REFERENCES users(user_id),
    CONSTRAINT CK_orders_amount CHECK (order_amount >= 0),
    CONSTRAINT CK_orders_status CHECK (status IN ('CREATED','PAID','SHIPPED','CLOSED','REFUNDED'))
);
GO

-- ------------------------------------------------------------
-- 表 3：订单明细表 order_items
-- line_amount 冗余存一行金额（= qty * unit_price）
-- 真实系统里这列常常算错，是「金额与明细不符」这个雷的落点
-- ------------------------------------------------------------
CREATE TABLE order_items (
    item_id      INT               NOT NULL,
    order_id     INT               NOT NULL,
    product_name NVARCHAR(50)      NOT NULL,
    qty          INT               NOT NULL,
    unit_price   DECIMAL(10,2)     NOT NULL,
    line_amount  DECIMAL(12,2)     NOT NULL,
    CONSTRAINT PK_order_items PRIMARY KEY (item_id),
    CONSTRAINT FK_items_order FOREIGN KEY (order_id) REFERENCES orders(order_id),
    CONSTRAINT CK_items_qty CHECK (qty > 0),
    CONSTRAINT CK_items_price CHECK (unit_price > 0)
);
GO

-- ------------------------------------------------------------
-- 表 4：退款表 refunds
-- ------------------------------------------------------------
CREATE TABLE refunds (
    refund_id     INT               NOT NULL,
    order_id      INT               NOT NULL,
    refund_amount DECIMAL(12,2)     NOT NULL,
    reason        NVARCHAR(100)     NULL,
    created_at    DATETIME2(0)      NOT NULL,
    CONSTRAINT PK_refunds PRIMARY KEY (refund_id),
    CONSTRAINT FK_refunds_order FOREIGN KEY (order_id) REFERENCES orders(order_id),
    CONSTRAINT CK_refunds_amount CHECK (refund_amount > 0)
);
GO

-- 验收：应该列出 4 张表名
SELECT name AS table_name FROM sys.tables ORDER BY name;
GO
