#!/bin/bash


USER_POOL_ID=$(terraform output -raw user_pool_id)

if [[ -z "$USER_POOL_ID" ]]; then
    echo "Failed to get USER_POOL_ID from terraform output"
    exit
fi

USER_POOL_CLIENT_ID=$(terraform output -raw user_pool_client_id)
URL=$(terraform output -raw invoke_url)

USERNAME="user1"
PASSWORD="1qaz@WSX"

# Authenticate the user and get tokens
RESPONSE=$(aws cognito-idp initiate-auth \
    --auth-flow USER_PASSWORD_AUTH \
    --client-id $USER_POOL_CLIENT_ID \
    --auth-parameters USERNAME=$USERNAME,PASSWORD=$PASSWORD \
    --query 'AuthenticationResult.[IdToken,AccessToken,RefreshToken]' \
    --output text)

# Split the response into tokens
ID_TOKEN=$(echo $RESPONSE | awk '{print $1}')
ACCESS_TOKEN=$(echo $RESPONSE | awk '{print $2}')
REFRESH_TOKEN=$(echo $RESPONSE | awk '{print $3}')

# Output the tokens
#echo "ID Token: $ID_TOKEN"
#echo "Access Token: $ACCESS_TOKEN"
#echo "Refresh Token: $REFRESH_TOKEN"

echo "Passing auth token to $URL"
curl $URL -H "Authorization: $ID_TOKEN"
