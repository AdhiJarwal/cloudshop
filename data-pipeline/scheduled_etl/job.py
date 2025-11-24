#!/usr/bin/env python3
"""
Scheduled ETL job that runs daily to aggregate product data
Runs as an ECS scheduled task
"""

import os
import json
import boto3
import psycopg2
from datetime import datetime, timedelta

def get_db_connection():
    """Get database connection using environment variables"""
    return psycopg2.connect(
        host=os.getenv("DB_HOST"),
        database=os.getenv("DB_NAME"),
        user=os.getenv("DB_USER"),
        password=os.getenv("DB_PASSWORD"),
        port=os.getenv("DB_PORT", "5432")
    )

def get_s3_client():
    """Get S3 client"""
    return boto3.client('s3')

def extract_product_data():
    """Extract product data from database"""
    conn = get_db_connection()
    cur = conn.cursor()
    
    # Get products created in the last 24 hours
    yesterday = datetime.now() - timedelta(days=1)
    cur.execute("""
        SELECT id, name, price, description, created_at
        FROM products 
        WHERE created_at >= %s
        ORDER BY created_at DESC
    """, (yesterday,))
    
    products = []
    for row in cur.fetchall():
        products.append({
            'id': row[0],
            'name': row[1],
            'price': float(row[2]),
            'description': row[3],
            'created_at': row[4].isoformat()
        })
    
    cur.close()
    conn.close()
    
    return products

def transform_data(products):
    """Transform and aggregate product data"""
    if not products:
        return {
            'total_products': 0,
            'average_price': 0,
            'price_ranges': {},
            'products': []
        }
    
    total_products = len(products)
    total_price = sum(p['price'] for p in products)
    average_price = total_price / total_products if total_products > 0 else 0
    
    # Price range analysis
    price_ranges = {
        'under_50': len([p for p in products if p['price'] < 50]),
        '50_to_100': len([p for p in products if 50 <= p['price'] < 100]),
        '100_to_500': len([p for p in products if 100 <= p['price'] < 500]),
        'over_500': len([p for p in products if p['price'] >= 500])
    }
    
    return {
        'total_products': total_products,
        'average_price': round(average_price, 2),
        'price_ranges': price_ranges,
        'products': products,
        'generated_at': datetime.now().isoformat()
    }

def load_to_s3(data, bucket_name):
    """Load aggregated data to S3"""
    s3 = get_s3_client()
    
    # Generate filename with timestamp
    timestamp = datetime.now().strftime('%Y-%m-%d')
    key = f"etl-reports/daily-product-report-{timestamp}.json"
    
    s3.put_object(
        Bucket=bucket_name,
        Key=key,
        Body=json.dumps(data, indent=2),
        ContentType='application/json'
    )
    
    print(f"Report uploaded to s3://{bucket_name}/{key}")
    return key

def main():
    """Main ETL process"""
    print("Starting daily ETL job...")
    
    try:
        # Extract
        print("Extracting product data...")
        products = extract_product_data()
        print(f"Extracted {len(products)} products")
        
        # Transform
        print("Transforming data...")
        aggregated_data = transform_data(products)
        
        # Load
        bucket_name = os.getenv("DATA_BUCKET", "cloudshop-data-bucket")
        print(f"Loading data to S3 bucket: {bucket_name}")
        s3_key = load_to_s3(aggregated_data, bucket_name)
        
        print("ETL job completed successfully!")
        print(f"Report available at: s3://{bucket_name}/{s3_key}")
        
    except Exception as e:
        print(f"ETL job failed: {str(e)}")
        raise

if __name__ == "__main__":
    main()