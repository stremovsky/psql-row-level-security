import os
import boto3
import psycopg2
import psycopg2.extras
import json
import jwt


def lambda_handler(event, context):
    token = event['headers']['Authorization']
    decoded_token = jwt.decode(token, options={"verify_signature": False})
    tenant_id = decoded_token['custom:tenant_id']

    client = boto3.client('rds')
    auth_token = client.generate_db_auth_token(
        DBHostname=os.getenv('DB_HOST'),
        Port=5432,
        DBUsername=os.getenv('DB_USER'),
        Region=os.getenv('REGION')
    )

    conn = psycopg2.connect(
        dbname=os.getenv('DB_NAME'),
        user=os.getenv('DB_USER'),
        password=auth_token,
        host=os.getenv('DB_HOST'),
        sslmode='require'
    )
    
    cursor = conn.cursor(cursor_factory=psycopg2.extras.DictCursor)
    cursor.execute(f"SELECT * FROM data_table WHERE tenant_id = %s", (tenant_id,))
    records = cursor.fetchall()
    
    return {
        'statusCode': 200,
        'body': json.dumps([dict(record) for record in records])
    }
