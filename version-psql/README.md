
## Prerequisites
1. Download and install [Terraform](https://developer.hashicorp.com/terraform/install)
2. Ensure you have AWS CLI installed and configured with appropriate access keys
3. Install Session Manager plugin for AWS cli: https://docs.aws.amazon.com/systems-manager/latest/userguide/install-plugin-macos-overview.html
3. Make sure to install postgresql client library: psql

I use the following commands to install on MACOS

```
brew install libpq
sudo ln -s `find /opt/homebrew/Cellar/libpq/ -name psql` /usr/local/bin/psql
sudo ln -s `find /opt/homebrew/Cellar/libpq/ -name pg_config` /usr/local/bin/pg_config
```

## Setup postgresql
```
export AWS_DEFAULT_PROFILE='dev'
export AWS_DEFAULT_REGION='us-east-1'
./setup-db.sh
```
