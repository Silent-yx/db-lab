USE sql2024;

DROP table IF EXISTS account;	
CREATE TABLE account(
	account_number CHAR(10),	#--账号
	balance INT CHECK (balance >= 0),#	--账户余额
    Create_time DATETIME NOT NULL,
	PRIMARY KEY (account_number)
);

INSERT INTO account VALUES ('yx','1000',SYSDATE());
INSERT INTO account VALUES ('ys','500',SYSDATE());
INSERT INTO account VALUES ('lrb','900',SYSDATE());
INSERT INTO account VALUES ('ln','700',SYSDATE());
INSERT INTO account VALUES ('zzy','750',SYSDATE());
INSERT INTO account VALUES ('cyy','700',SYSDATE());
INSERT INTO account VALUES ('llz','250',SYSDATE());
INSERT INTO account VALUES ('zh','0',SYSDATE());

-- 1：创建还款表payment表及插入数据
DROP TABLE IF EXISTS payment;
CREATE TABLE payment(
    account_number CHAR(10),    -- 账号：贷款账户的唯一标识
    payment_number CHAR(10),    -- 还款号：确定是要插入新的还款记录还是更新已有记录的还款金额
    payment_amount INT,         -- 还款额度
    payment_datetime DATETIME NOT NULL, -- 时间
    PRIMARY KEY (account_number, payment_number)
);

-- 2：创建贷款表loan表及插入数据
DROP TABLE IF EXISTS loan;
CREATE TABLE loan(
    account_number CHAR(10),    -- 账号：标识
    branch_number CHAR(10),     -- 支行号
    amount INT,                 -- 贷款数额
    PayOverDate DATETIME,       -- 添加一列PayOverDate用于记录还款完成日期
    PRIMARY KEY (account_number)
);

/****************************
一、创建 转账存储过程
*****************************/
#-说明: account表中的 balance属性必须有>=0约束。否则，转账仍可完成，但结果balance会出现负数。

DROP PROCEDURE IF EXISTS PTransfer;   
DELIMITER //
CREATE PROCEDURE PTransfer(IN account_no_x CHAR(10),account_no_y CHAR(10),amount_k INT,OUT ErrorVar INT)
label:BEGIN
    DECLARE insufficient_balance CONDITION FOR SQLSTATE '45000';
    DECLARE no_account CONDITION FOR SQLSTATE '45000';

    IF  (SELECT balance 
         FROM account 
         WHERE account_number = account_no_x) IS NULL 
        OR
        (SELECT balance 
        FROM account 
        WHERE account_number = account_no_y) IS NULL THEN
        SIGNAL no_account SET MESSAGE_TEXT = 'An account number does not exist.';
    END IF;
    
    IF (SELECT balance 
        FROM account 
        WHERE account_number = account_no_x) < amount_k THEN
        SET ErrorVar=-2;
        SIGNAL insufficient_balance SET MESSAGE_TEXT = 'Insufficient balance in account';
    END IF;
    UPDATE account   
    SET balance = balance + amount_k
    WHERE account_number = account_no_y;
    #-（1）**********X账号减去k元***********
    UPDATE account
    SET balance = balance - amount_k
    WHERE account_number = account_no_x;
    
    SET ErrorVar=0; 
    COMMIT;
    
END label;
//
DELIMITER ;

#调用：
SET SQL_SAFE_UPDATES = 0;	#设置批量更新数据
CALL PTransfer('yx','ys',100,@A);
# CALL PTransfer('yx','hhhh',100,@A);
# CALL PTransfer('yx','ys',1000,@A);
SELECT @A;
SELECT * FROM account;

-- 创建存储过程
DROP PROCEDURE IF EXISTS LoanProcedure;
DELIMITER //
CREATE PROCEDURE LoanProcedure(IN account_no CHAR(10), loan_amount INT)  # 贷款
BEGIN
    DECLARE no_account CONDITION FOR SQLSTATE '45000';

    IF (SELECT balance FROM account WHERE account_number = account_no) IS NULL THEN
        SIGNAL no_account SET MESSAGE_TEXT = 'The account number does not exist.';
    ELSE
        UPDATE account SET balance = balance + loan_amount WHERE account_number = account_no;
        INSERT INTO loan (account_number, amount, PayOverDate) VALUES (account_no, loan_amount, NULL);
    END IF;
END;
//
DELIMITER ;

DROP PROCEDURE IF EXISTS RepaymentProcedure;
DELIMITER //
CREATE PROCEDURE RepaymentProcedure(IN account_no CHAR(10), payment_no CHAR(10), repayment_amount INT)
BEGIN
    DECLARE insufficient_balance CONDITION FOR SQLSTATE '45000';
    DECLARE no_account CONDITION FOR SQLSTATE '45000';

    IF (SELECT balance FROM account WHERE account_number = account_no) IS NULL THEN
        SIGNAL no_account SET MESSAGE_TEXT = 'The account number does not exist.';
    ELSEIF (SELECT balance FROM account WHERE account_number = account_no) < repayment_amount THEN
        SIGNAL insufficient_balance SET MESSAGE_TEXT = 'Insufficient balance in account for repayment.';
    ELSE
        UPDATE account SET balance = balance - repayment_amount WHERE account_number = account_no;
        INSERT INTO payment (account_number, payment_number, payment_amount, payment_datetime) VALUES (account_no, payment_no, repayment_amount, NOW());
        UPDATE loan SET amount = amount - repayment_amount WHERE account_number = account_no;
        IF (SELECT amount FROM loan WHERE account_number = account_no) <= 0 THEN
            UPDATE loan SET PayOverDate = NOW() WHERE account_number = account_no;
        END IF;
    END IF;
END;
//
DELIMITER ;

-- 调用存储过程
SET SQL_SAFE_UPDATES = 0; -- 设置批量更新数据
CALL LoanProcedure('yx', 555);
CALL LoanProcedure('ys', 1000);
SELECT * FROM account;

-- 还款
CALL RepaymentProcedure('yx', 'y-001', 500);
CALL RepaymentProcedure('yx', 'y-002', 50);
CALL RepaymentProcedure('yx', 'y-003', 5);
CALL RepaymentProcedure('ln', 'l-001', 100);

-- 查看表内容
SELECT * FROM loan;
SELECT * FROM payment;
SELECT * FROM account;
