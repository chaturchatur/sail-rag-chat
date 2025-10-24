# backend/lambdas/get_upload_url/main.py
def handler(event, context):
    return {
        'statusCode': 200,
        'body': '{"message": "upload-url endpoint working"}'
    }