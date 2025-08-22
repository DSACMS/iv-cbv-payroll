import os
import json
import boto3
import traceback
from aws_lambda_powertools import Logger, Tracer, Metrics

logger = Logger(service="PrivateSFTP")
tracer = Tracer(service="PrivateSFTP")
metrics = Metrics(namespace="PrivateSFTP", service="PrivateSFTP")

secrets_region = os.environ["SecretsManagerRegion"]
secrets_client = boto3.session.Session().client(service_name="secretsmanager", region_name=secrets_region)

@tracer.capture_lambda_handler
@logger.inject_lambda_context(log_event=True)
@metrics.log_metrics(capture_cold_start_metric=True)
def handler(event, context):
    try:
        server_id = event["serverId"]
        user_name = event["username"]
        protocol  = event["protocol"]
        source_ip = event["sourceIp"] 
        password  = event.get("password", "")

        logger.info(f"server ID: {server_id}, username: {user_name}, protocol: {protocol}, source IP: {source_ip}")

        secret_id = f"aws/transfer/{server_id}/{user_name}"
        expected_password_secret = secrets_client.get_secret_value(SecretId=secret_id).get("SecretString", None)

        if expected_password_secret is not None:
            expected_password_secret_dict = json.loads(expected_password_secret)
            
            expected_password = expected_password_secret_dict.get("password", None)
            if password == expected_password:
                logger.info(f"Password for user: {user_name} matches expected password")
                response = {
                    "Role": expected_password_secret_dict.get("role", None),
                    "HomeDirectory": expected_password_secret_dict.get("home_dir", None)
                }
                logger.info(f"Response: {response}")
                return response
            else:
                logger.error(f"Password for user: {user_name} does not match expected password")
                return {}
        else:
            logger.error(f"No secret found for user: {user_name}")
            return {}
        
    except Exception as e:
        traceback.print_exc()
        logger.info(f"traceback={traceback.format_exc()}")   
        return {}