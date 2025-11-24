import json
import boto3
import csv
from io import StringIO

s3 = boto3.client('s3')

def lambda_handler(event, context):
    """
    Lambda function to preprocess CSV files uploaded to S3
    Triggered by S3 events when CSV files are uploaded
    """
    
    for record in event['Records']:
        bucket = record['s3']['bucket']['name']
        key = record['s3']['object']['key']
        
        # Only process CSV files
        if not key.endswith('.csv'):
            continue
            
        try:
            # Download the CSV file
            response = s3.get_object(Bucket=bucket, Key=key)
            csv_content = response['Body'].read().decode('utf-8')
            
            # Process CSV data
            csv_reader = csv.DictReader(StringIO(csv_content))
            processed_data = []
            
            for row in csv_reader:
                # Example preprocessing: clean and validate data
                processed_row = {
                    'product_name': row.get('name', '').strip(),
                    'price': float(row.get('price', 0)),
                    'category': row.get('category', 'uncategorized').lower(),
                    'processed_at': context.aws_request_id
                }
                processed_data.append(processed_row)
            
            # Save processed data back to S3
            processed_key = key.replace('.csv', '_processed.json')
            s3.put_object(
                Bucket=bucket,
                Key=processed_key,
                Body=json.dumps(processed_data, indent=2),
                ContentType='application/json'
            )
            
            print(f"Processed {len(processed_data)} records from {key}")
            
        except Exception as e:
            print(f"Error processing {key}: {str(e)}")
            raise
    
    return {
        'statusCode': 200,
        'body': json.dumps('CSV preprocessing completed successfully')
    }