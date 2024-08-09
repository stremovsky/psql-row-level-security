import os
import boto3
import psycopg2
import psycopg2.extras
import json
import base64

def remove_port(host):
    parts = host.split(':')
    return parts[0]

def base64url_decode(input_str):
    # Base64URL decoding
    padding = '=' * (4 - len(input_str) % 4)
    return base64.urlsafe_b64decode(input_str + padding)

def parse_jwt(token):
    # Split the JWT into its components
    header_encoded, payload_encoded, signature_encoded = token.split('.')

    # Decode the header and payload
    header = base64url_decode(header_encoded).decode('utf-8')
    payload = base64url_decode(payload_encoded).decode('utf-8')

    # Convert to JSON
    header_json = json.loads(header)
    payload_json = json.loads(payload)

    # Return payload
    return payload_json

def lambda_handler(event, context):
    db_host = remove_port(os.getenv('DB_HOST'))
    tenant_id = 0
    if 'headers' in event and event['headers'] is not None and 'Authorization' in event['headers']:
        token = event['headers']['Authorization']
        decoded_token = parse_jwt(token)
        tenant_id = decoded_token['custom:tenant_id']

    if tenant_id == 0:
        return {
            'statusCode': 200,
            'body': '{"error":"no tenant_id"}'
        }
    client = boto3.client('rds')
    auth_token = client.generate_db_auth_token(
        DBHostname=db_host,
        Port=5432,
        DBUsername=os.getenv('DB_USER'),
        Region=os.getenv('REGION')
    )
    #if auth_token is not None:
    #    return {
    #        'statusCode': 200,
    #        'body': auth_token
    #   }

    conn = psycopg2.connect(
        dbname=os.getenv('DB_NAME'),
        user=os.getenv('DB_USER'),
        password=auth_token,
        host=db_host,
        sslmode='require'
    )
    cur = conn.cursor()
    cur.execute("SET app.current_tenant TO %s", (tenant_id,))
    cur.execute("SELECT * FROM data_table")
    records = cur.fetchall()
    
    return {
        'statusCode': 200,
        'body': json.dumps(records)
    }
