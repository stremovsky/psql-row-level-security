CREATE TABLE data_table (
    id SERIAL PRIMARY KEY,
    tenant_id INT,
    data TEXT
);

INSERT INTO data_table VALUES(DEFAULT, 1, 'secret value for tenant 1');
INSERT INTO data_table VALUES(DEFAULT, 2, 'secret value for tenant 2');
INSERT INTO data_table VALUES(DEFAULT, 3, 'secret value for tenant 3');

ALTER TABLE data_table ENABLE ROW LEVEL SECURITY;

CREATE POLICY tenant_policy ON data_table 
    USING (tenant_id = current_setting('app.current_tenant')::int);

CREATE ROLE rds_iam_user;
GRANT rds_iam TO rds_iam_user;
