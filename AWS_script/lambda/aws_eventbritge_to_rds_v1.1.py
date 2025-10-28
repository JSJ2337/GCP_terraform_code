import os, boto3, json, time, random
from botocore.exceptions import ClientError

logs = boto3.client("logs")

PROCESSOR_ARN = os.environ["PROCESSOR_LAMBDA_ARN"]
FILTER_NAME   = "RdsLogSubscription"
PREFIXES      = ("/aws/rds/cluster/", "/aws/rds/instance/")

# 최대 10회, 200ms~1.5s 지터 백오프
def wait_until_log_group_exists(name, max_attempts=10):
    for attempt in range(1, max_attempts+1):
        try:
            resp = logs.describe_log_groups(logGroupNamePrefix=name, limit=1)
            if any(g["logGroupName"] == name for g in resp.get("logGroups", [])):
                return True
        except ClientError as e:
            # 가끔 Throttling 등은 그냥 재시도
            print(f"[WARN] describe_log_groups attempt{attempt}: {e}")
        # 지터 백오프
        sleep = min(1.5, 0.2 * (2 ** (attempt-1))) * (0.5 + random.random())
        time.sleep(sleep)
    return False

def lambda_handler(event, context):
    lg = event["detail"]["requestParameters"]["logGroupName"]
    print(f"[INFO] incoming logGroup={lg}")

    if not lg.startswith(PREFIXES):
        print("[INFO] skip non-RDS")
        return

    if not wait_until_log_group_exists(lg):
        print(f"[ERROR] log group still not visible: {lg}")
        return

    # 중복 방지
    try:
        existing = logs.describe_subscription_filters(logGroupName=lg).get("subscriptionFilters", [])
        if any(sf["filterName"] == FILTER_NAME for sf in existing):
            print("[INFO] already exists; skip")
            return
    except ClientError as e:
        print(f"[WARN] describe_subscription_filters: {e}")

    # put_subscription_filter 재시도(존재 지연/일시 오류 대비)
    for attempt in range(1, 6):
        try:
            logs.put_subscription_filter(
                logGroupName=lg,
                filterName=FILTER_NAME,
                filterPattern="",
                destinationArn=PROCESSOR_ARN
            )
            print("[INFO] put_subscription_filter OK")
            return
        except ClientError as e:
            code = e.response["Error"]["Code"]
            if code in ("ResourceNotFoundException", "ThrottlingException", "ServiceUnavailableException"):
                sleep = min(2.0, 0.2 * (2 ** (attempt-1))) * (0.5 + random.random())
                print(f"[WARN] put_subscription_filter attempt{attempt} {code}, retry in {sleep:.2f}s")
                time.sleep(sleep)
                continue
            if code == "ResourceAlreadyExistsException":
                print("[INFO] already exists (race); done")
                return
            if code == "LimitExceededException":
                print("[ERROR] subscription filter limit reached (2 per group)")
                return
            print(f"[ERROR] put_subscription_filter failed: {e}")
            return
