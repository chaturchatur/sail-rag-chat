# backend/lambdas/query/main.py
def handler(event, context):
    return {
        'statusCode': 200,
        'body': '{"message": "query endpoint working"}'
    }