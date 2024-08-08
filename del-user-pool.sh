#!/bin/bash

USER_POOL_ID=$(terraform output -raw user_pool_id)

aws cognito-idp delete-user-pool \
    --user-pool-id $USER_POOL_ID
