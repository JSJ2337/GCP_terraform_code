import os, boto3, json, time, random, hashlib
from botocore.exceptions import ClientError

logs   = boto3.client("logs")
lmb    = boto3.client("lambda")
region = os.environ.get("AWS_REGION") or os.environ.get("AWS_DEFAULT_REGION")

PROCESSOR_ARN = os.environ["PROCESSOR_LAMBDA_ARN"]   # 구독 필터 목적지(정확한 ARN, 별칭 쓰면 별칭까지)
FILTER_NAME   = "RdsLogSubscription"
PREFIXES      = ("/aws/rds/cluster/", "/aws/rds/instance/")

def _account_id_from_arn(arn: str) -> str:
    # arn:aws:lambda:region:ACCOUNT_ID:function:...
    return arn.split(":")[4]

def _ensure_logs_invoke_permission(func_arn: str, log_group: str):
    """
    CloudWatch Logs가 func_arn을 호출할 수 있도록 리소스 정책을 보장.
    동일 항목이면 Conflict 무시(idempotent).
    """
    account_id = _account_id_from_arn(func_arn)
    source_arn = f"arn:aws:logs:{region}:{account_id}:log-group:{log_group}:*"
    sid = "AllowCWLogs_" + hashlib.md5(f"{func_arn}|{source_arn}".encode()).hexdigest()[:10]

    try:
        lmb.add_permission(
            FunctionName=func_arn,
            StatementId=sid,
            Action="lambda:InvokeFunction",
            Principal=f"logs.{region}.amazonaws.com",
            SourceArn=source_arn,
            SourceAccount=account_id,
        )
        print(f"[INFO] add_permission OK sid={sid}")
    except ClientError as e:
        code = e.response["Error"]["Code"]
        if code == "ResourceConflictException":
            # 이미 같은 SID 존재 → OK
            print(f"[INFO] permission already exists sid={sid}")
        else:
            print(f"[WARN] add_permission: {e}")
            # 권한 추가 실패 시에도 계속 시도하게 두고, put에서 InvalidParameterException이면 종료.

def wait_until_log_group_exists(name, max_attempts=10):
    for attempt in range(1, max_attempts+1):
        try:
            resp = logs.describe_log_groups(logGroupNamePrefix=name, limit=1)
            if any(g["logGroupName"] == name for g in resp.get("logGroups", [])):
                return True
        except ClientError as e:
            print(f"[WARN] describe_log_groups attempt{attempt}: {e}")
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

    # 목적지 Lambda에 Logs Invoke 권한 보장
    _ensure_logs_invoke_permission(PROCESSOR_ARN, lg)

    # put_subscription_filter 재시도
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
            msg  = e.response["Error"].get("Message","")
            if code in ("ResourceNotFoundException", "ThrottlingException", "ServiceUnavailableException"):
                sleep = min(2.0, 0.2 * (2 ** (attempt-1))) * (0.5 + random.random())
                print(f"[WARN] attempt{attempt} {code}, retry in {sleep:.2f}s")
                time.sleep(sleep); continue
            if code == "ResourceAlreadyExistsException":
                print("[INFO] already exists (race); done"); return
            if code == "LimitExceededException":
                print("[ERROR] subscription filter limit reached (2 per group)"); return
            if code == "InvalidParameterException" and "Could not execute the lambda function" in msg:
                print("[ERROR] destination Lambda lacks CloudWatch Logs invoke permission"); return
            print(f"[ERROR] put_subscription_filter failed: {e}"); return
