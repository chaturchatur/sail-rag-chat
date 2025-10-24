# backend/lambdas/ingest/main.py
def handler(event, context):
    return {
        'statusCode': 200,
        'body': '{"message": "ingest endpoint working"}'
    }