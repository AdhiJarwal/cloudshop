from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Optional
import psycopg2
from .db import get_db_connection, init_db
import os

app = FastAPI(title="CloudShop API", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class Product(BaseModel):
    id: Optional[int] = None
    name: str
    price: float
    description: Optional[str] = None

class ProductCreate(BaseModel):
    name: str
    price: float
    description: Optional[str] = None

@app.on_event("startup")
async def startup_event():
    init_db()

@app.get("/health")
async def health_check():
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute("SELECT 1")
        cur.close()
        conn.close()
        return {"status": "healthy", "database": "connected"}
    except Exception as e:
        raise HTTPException(status_code=503, detail=f"Database connection failed: {str(e)}")

@app.get("/products", response_model=List[Product])
async def get_products():
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute("SELECT id, name, price, description FROM products ORDER BY id")
        products = []
        for row in cur.fetchall():
            products.append(Product(
                id=row[0],
                name=row[1],
                price=float(row[2]),
                description=row[3]
            ))
        cur.close()
        conn.close()
        return products
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to fetch products: {str(e)}")

@app.post("/products", response_model=Product)
async def create_product(product: ProductCreate):
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute(
            "INSERT INTO products (name, price, description) VALUES (%s, %s, %s) RETURNING id",
            (product.name, product.price, product.description)
        )
        product_id = cur.fetchone()[0]
        conn.commit()
        cur.close()
        conn.close()
        return Product(
            id=product_id,
            name=product.name,
            price=product.price,
            description=product.description
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to create product: {str(e)}")

@app.delete("/products/{product_id}")
async def delete_product(product_id: int):
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute("DELETE FROM products WHERE id = %s", (product_id,))
        if cur.rowcount == 0:
            raise HTTPException(status_code=404, detail="Product not found")
        conn.commit()
        cur.close()
        conn.close()
        return {"message": "Product deleted successfully"}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to delete product: {str(e)}")

@app.options("/{full_path:path}")
async def options_handler(full_path: str):
    return {}

@app.get("/")
async def root():
    return {"message": "CloudShop API", "version": "1.0.0", "docs": "/docs"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)