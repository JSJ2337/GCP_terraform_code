import json, base64, gzip, os, re
import urllib3
from collections import defaultdict
from datetime import datetime

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
http = urllib3.PoolManager(timeout=urllib3.Timeout(connect=5.0, read=10.0))

ALLOY_ENDPOINT = os.environ.get('ALLOY_ENDPOINT', 'http://<ALLOY_HOST>:9080/loki/api/v1/push')
ACCOUNT_ALIAS  = os.environ.get('ACCOUNT_ALIAS', 'default-account')

LOG_GROUP_RX = re.compile(r"^/aws/rds/(?:cluster|instance)/([^/]+)/([^/]+)")

def _ns(ts_ms:int) -> str:
    return str(int(ts_ms) * 1_000_000)

def lambda_handler(event, context):
    cw = json.loads(gzip.decompress(base64.b64decode(event['awslogs']['data'])).decode('utf-8'))
    log_group  = cw.get('logGroup', 'unknown')
    log_stream = cw.get('logStream', 'unknown')

    # region: 환경변수 우선, 없으면 ARN에서
    region = os.environ.get('AWS_REGION') or context.invoked_function_arn.split(':')[3]

    m = LOG_GROUP_RX.match(log_group)
    db_name, log_type = (m.group(1), m.group(2)) if m else ("rds", "unknown")

    # 같은 라벨끼리 묶어서 전송
    buckets = defaultdict(list)
    for ev in cw.get('logEvents', []):
        line_obj = {
            "resources": {
                "cloudwatch.log.group.name":  log_group,
                "cloudwatch.log.stream.name": log_stream
            },
            "body": ev['message']
        }
        labels = (
            ("source", "lambda"),
            ("account", ACCOUNT_ALIAS),
            ("region",  region),
            ("service", "AWS-RDS"),            # ★ 대시보드 호환: service=로그그룹
            ("log_group", log_group),
            ("log_type", log_type),
            ("db_cluster", db_name),
        )
        buckets[tuple(labels)].append([_ns(ev['timestamp']), json.dumps(line_obj, ensure_ascii=False)])

    streams = [{"stream": dict(labels), "values": buckets[labels]} for labels in buckets]
    resp = http.request('POST', ALLOY_ENDPOINT,
                        body=json.dumps({"streams": streams}).encode('utf-8'),
                        headers={'Content-Type': 'application/json'})
    return {'statusCode': 200 if resp.status == 204 else resp.status,
            'body': resp.data.decode('utf-8') if resp.data else 'OK'}
