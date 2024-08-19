from diagrams import Diagram, Cluster
from diagrams.aws.network import VPC
from diagrams.aws.security import ACM  # We'll use this instead of SecurityGroup
from diagrams.aws.database import Aurora, DatabaseMigrationService
from diagrams.aws.security import SecretsManager, Cognito
from diagrams.aws.compute import Lambda
from diagrams.aws.network import APIGateway
from diagrams.aws.security import IAM
from diagrams.aws.general import User, Client, GenericSamlToken

#with Diagram("AWS Architecture", show=False, direction="TB"):
with Diagram("AWS Architecture"):
    token = GenericSamlToken("Token")
    with Cluster("Clients"):
        user = User("User")
        testapp = Client("TestApp")

    with Cluster("AWS Cloud"):
        secrets = SecretsManager("Secrets Manager")
        
        cognito_pool = Cognito("User Pool")
        #cognito_client = Cognito("User Pool Client")

        api = APIGateway("API Gateway")

        with Cluster("VPC"):
            sg_postgres = ACM("postgres-sg")  # Using ACM as a visual representation of SecurityGroup
            sg_lambda = ACM("lambda-sg")  # Using ACM as a visual representation of SecurityGroup

            with Cluster("Database Subnet Group"):
                db = Aurora("PostgreSQL Cluster")

            lambda_func = Lambda("fetchRecords")

        iam_role = IAM("lambda-exec-role")

        with Cluster("Setup DB"):
            null_resource1 = DatabaseMigrationService("wait_for_rds")
            null_resource2 = DatabaseMigrationService("db_setup")

    # Connections
    #user >> cognito_client
    #user >> cognito_pool
    #cognito_pool >> user
    user >> cognito_pool
    cognito_pool >> token
    token >> user
    #token >> api
    testapp >> api

    secrets >> db
    #cognito_client >> cognito_pool
    api >> sg_lambda
    lambda_func >> sg_postgres
    lambda_func >> iam_role
    iam_role >> db
    sg_postgres >> db
    sg_lambda >> lambda_func
    null_resource1 >> db
    null_resource2 >> db
    null_resource1 >> null_resource2
    null_resource2 >> secrets
