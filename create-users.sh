#!/bin/bash

USER_POOL_ID=$(terraform output -raw user_pool_id)

if [[ -z "$USER_POOL_ID" ]]; then
    echo "Failed to get USER_POOL_ID from terraform output"
    exit
fi

aws cognito-idp admin-create-user \
    --user-pool-id $USER_POOL_ID \
    --username user1 \
    --user-attributes Name=email,Value=user1@example.com Name=custom:tenant_id,Value=1
aws cognito-idp admin-set-user-password \
    --user-pool-id $USER_POOL_ID \
    --username user1 \
    --password "1qaz@WSX" \
    --permanent

aws cognito-idp admin-create-user \
    --user-pool-id $USER_POOL_ID \
    --username user2 \
    --temporary-password "1qaz@WSX" \
    --user-attributes Name=email,Value=user2@example.com Name=custom:tenant_id,Value=2
aws cognito-idp admin-set-user-password \
    --user-pool-id $USER_POOL_ID \
    --username user2 \
    --password "1qaz@WSX" \
    --permanent