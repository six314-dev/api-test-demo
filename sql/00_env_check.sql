-- ============================================================
-- 00_env_check.sql —— Day 0 环境验证（只跑一次，之后不用再跑）
-- 作用：确认能连上本机 SQL Server，并新建练习专用库 DQTest
-- 注意：本脚本必须在 master 库执行！因为 DQTest 此刻还不存在
--   命令：python utils/run_sql.py -d master sql/00_env_check.sql
-- ============================================================

-- 1) 看清自己连的是哪台机器、哪个版本、用谁的身份登录
SELECT @@SERVERNAME  AS server_name,
       @@VERSION     AS version_info,
       SUSER_SNAME() AS login_name,
       GETDATE()     AS checked_at;
GO

-- 2) 新建练习库（已存在则跳过，可反复执行，不会覆盖你的表）
--    CREATE DATABASE 不能和普通语句放在同一个批处理里，所以用 EXEC 动态执行
IF DB_ID(N'DQTest') IS NULL
BEGIN
    EXEC(N'CREATE DATABASE DQTest');
    PRINT 'DQTest 已创建';
END
ELSE
BEGIN
    PRINT 'DQTest 已存在，跳过创建（不会删你已有的表）';
END
GO

-- 3) 确认库真的在，并看看当前库是空的（还没有任何用户表）
SELECT name, create_date FROM sys.databases WHERE name = N'DQTest';
GO
USE DQTest;
GO
SELECT name AS user_tables FROM sys.tables ORDER BY name;
GO

-- 看到「(0 行受影响)」是正常的：表还没建，W1 周二才由你自己建。
PRINT '环境验证完成：下一步打开 W1 手册，周二写 01_create_tables.sql';
GO
