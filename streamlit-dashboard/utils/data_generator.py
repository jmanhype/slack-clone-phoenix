"""
Sample data generation for demonstration purposes
Creates realistic datasets for testing and demos
"""

import pandas as pd
import numpy as np
from datetime import datetime, timedelta
import random
from typing import Dict, List, Any

class DataGenerator:
    """Generate sample datasets for demonstration"""
    
    def __init__(self):
        """Initialize data generator with random seed for reproducibility"""
        np.random.seed(42)
        random.seed(42)
        
        # Sample data configurations
        self.product_categories = ['Electronics', 'Clothing', 'Books', 'Home & Garden', 'Sports']
        self.customer_segments = ['Premium', 'Standard', 'Basic']
        self.regions = ['North America', 'Europe', 'Asia Pacific', 'Latin America', 'Africa']
        self.sales_channels = ['Online', 'Retail', 'Mobile', 'Partner']
    
    def generate_sample_data(self, rows: int = 1000) -> Dict[str, pd.DataFrame]:
        """Generate comprehensive sample dataset"""
        return {
            'sales_data': self.generate_sales_data(rows),
            'customer_data': self.generate_customer_data(rows // 2),
            'product_data': self.generate_product_data(100),
            'time_series': self.generate_time_series_data(365)
        }
    
    def generate_sales_data(self, rows: int = 1000) -> pd.DataFrame:
        """Generate realistic sales transaction data"""
        end_date = datetime.now()
        start_date = end_date - timedelta(days=365)
        
        data = []
        for i in range(rows):
            # Generate random date within the last year
            random_date = start_date + timedelta(
                days=random.randint(0, (end_date - start_date).days)
            )
            
            # Generate transaction
            transaction = {
                'transaction_id': f'TXN-{str(i+1).zfill(6)}',
                'date': random_date,
                'customer_id': f'CUST-{random.randint(1, 500):04d}',
                'product_category': random.choice(self.product_categories),
                'product_name': self._generate_product_name(),
                'quantity': random.randint(1, 10),
                'unit_price': round(random.uniform(10, 500), 2),
                'discount': round(random.uniform(0, 0.3), 2),
                'region': random.choice(self.regions),
                'sales_channel': random.choice(self.sales_channels),
                'customer_segment': random.choice(self.customer_segments)
            }
            
            # Calculate derived fields
            subtotal = transaction['quantity'] * transaction['unit_price']
            transaction['total_amount'] = round(subtotal * (1 - transaction['discount']), 2)
            transaction['profit_margin'] = round(random.uniform(0.1, 0.4), 2)
            transaction['profit'] = round(transaction['total_amount'] * transaction['profit_margin'], 2)
            
            data.append(transaction)
        
        df = pd.DataFrame(data)
        df['date'] = pd.to_datetime(df['date'])
        return df.sort_values('date').reset_index(drop=True)
    
    def generate_customer_data(self, rows: int = 500) -> pd.DataFrame:
        """Generate customer demographic and behavior data"""
        data = []
        for i in range(rows):
            join_date = datetime.now() - timedelta(days=random.randint(30, 1095))  # 1 month to 3 years ago
            
            customer = {
                'customer_id': f'CUST-{str(i+1).zfill(4)}',
                'first_name': random.choice(['John', 'Jane', 'Michael', 'Sarah', 'David', 'Lisa', 'Robert', 'Emily']),
                'last_name': random.choice(['Smith', 'Johnson', 'Williams', 'Brown', 'Jones', 'Garcia', 'Miller', 'Davis']),
                'email': f'customer{i+1}@email.com',
                'age': random.randint(18, 80),
                'gender': random.choice(['Male', 'Female', 'Other']),
                'region': random.choice(self.regions),
                'customer_segment': random.choice(self.customer_segments),
                'join_date': join_date,
                'total_orders': random.randint(1, 50),
                'total_spent': round(random.uniform(100, 10000), 2),
                'avg_order_value': round(random.uniform(50, 500), 2),
                'last_purchase_date': join_date + timedelta(days=random.randint(0, 365)),
                'preferred_channel': random.choice(self.sales_channels)
            }
            
            # Calculate customer lifetime value
            days_active = (datetime.now() - join_date).days
            customer['customer_lifetime_value'] = round(
                customer['total_spent'] * (days_active / 365) * random.uniform(1.2, 2.5), 2
            )
            
            data.append(customer)
        
        df = pd.DataFrame(data)
        df['join_date'] = pd.to_datetime(df['join_date'])
        df['last_purchase_date'] = pd.to_datetime(df['last_purchase_date'])
        return df
    
    def generate_product_data(self, rows: int = 100) -> pd.DataFrame:
        """Generate product catalog data"""
        data = []
        for i in range(rows):
            category = random.choice(self.product_categories)
            
            product = {
                'product_id': f'PROD-{str(i+1).zfill(4)}',
                'product_name': self._generate_product_name(category),
                'category': category,
                'subcategory': self._get_subcategory(category),
                'brand': self._generate_brand_name(),
                'cost_price': round(random.uniform(5, 200), 2),
                'selling_price': round(random.uniform(10, 500), 2),
                'stock_quantity': random.randint(0, 1000),
                'reorder_level': random.randint(10, 100),
                'supplier': f'Supplier-{random.randint(1, 20)}',
                'rating': round(random.uniform(1, 5), 1),
                'reviews_count': random.randint(0, 1000),
                'is_active': random.choices([True, False], weights=[0.9, 0.1])[0],
                'launch_date': datetime.now() - timedelta(days=random.randint(30, 1095))
            }
            
            # Calculate profit margin
            product['profit_margin'] = round(
                (product['selling_price'] - product['cost_price']) / product['selling_price'], 2
            )
            
            data.append(product)
        
        df = pd.DataFrame(data)
        df['launch_date'] = pd.to_datetime(df['launch_date'])
        return df
    
    def generate_time_series_data(self, days: int = 365) -> pd.DataFrame:
        """Generate time series data for trend analysis"""
        end_date = datetime.now()
        start_date = end_date - timedelta(days=days)
        
        dates = pd.date_range(start=start_date, end=end_date, freq='D')
        
        # Generate base trends with seasonality
        base_sales = 1000
        trend = np.linspace(0, 200, len(dates))  # Growth trend
        seasonal = 100 * np.sin(2 * np.pi * np.arange(len(dates)) / 365.25)  # Yearly seasonality
        weekly = 50 * np.sin(2 * np.pi * np.arange(len(dates)) / 7)  # Weekly seasonality
        noise = np.random.normal(0, 30, len(dates))  # Random noise
        
        sales = base_sales + trend + seasonal + weekly + noise
        sales = np.maximum(sales, 100)  # Ensure positive values
        
        # Generate related metrics
        data = {
            'date': dates,
            'sales': sales.round(2),
            'visitors': (sales * random.uniform(0.1, 0.3) + np.random.normal(0, 50, len(dates))).astype(int),
            'conversion_rate': np.random.normal(0.05, 0.01, len(dates)).clip(0.01, 0.15),
            'avg_order_value': (sales / np.maximum(sales * 0.1, 1) + np.random.normal(0, 10, len(dates))).round(2),
            'cost': (sales * random.uniform(0.6, 0.8) + np.random.normal(0, 20, len(dates))).round(2)
        }
        
        df = pd.DataFrame(data)
        df['profit'] = df['sales'] - df['cost']
        df['profit_margin'] = (df['profit'] / df['sales']).round(3)
        
        return df
    
    def _generate_product_name(self, category: str = None) -> str:
        """Generate realistic product names based on category"""
        if not category:
            category = random.choice(self.product_categories)
        
        product_templates = {
            'Electronics': ['Smartphone', 'Laptop', 'Tablet', 'Headphones', 'Camera', 'Speaker'],
            'Clothing': ['T-Shirt', 'Jeans', 'Dress', 'Jacket', 'Shoes', 'Sweater'],
            'Books': ['Novel', 'Textbook', 'Biography', 'Cookbook', 'Manual', 'Guide'],
            'Home & Garden': ['Chair', 'Lamp', 'Plant', 'Tool Set', 'Pillow', 'Vase'],
            'Sports': ['Basketball', 'Running Shoes', 'Yoga Mat', 'Dumbbells', 'Bicycle', 'Helmet']
        }
        
        base_name = random.choice(product_templates.get(category, ['Product']))
        adjectives = ['Premium', 'Professional', 'Ultra', 'Deluxe', 'Classic', 'Modern', 'Smart']
        colors = ['Black', 'White', 'Blue', 'Red', 'Silver', 'Gold', 'Green']
        
        name_parts = [random.choice(adjectives), base_name]
        if random.random() > 0.5:
            name_parts.append(random.choice(colors))
        
        return ' '.join(name_parts)
    
    def _get_subcategory(self, category: str) -> str:
        """Get subcategory based on main category"""
        subcategories = {
            'Electronics': ['Smartphones', 'Computers', 'Audio', 'Cameras', 'Accessories'],
            'Clothing': ['Men\'s Wear', 'Women\'s Wear', 'Footwear', 'Accessories'],
            'Books': ['Fiction', 'Non-Fiction', 'Educational', 'Reference'],
            'Home & Garden': ['Furniture', 'Decor', 'Tools', 'Plants'],
            'Sports': ['Fitness', 'Outdoor', 'Team Sports', 'Water Sports']
        }
        
        return random.choice(subcategories.get(category, ['General']))
    
    def _generate_brand_name(self) -> str:
        """Generate realistic brand names"""
        prefixes = ['Tech', 'Pro', 'Ultra', 'Premium', 'Elite', 'Smart', 'Neo', 'Alpha']
        suffixes = ['Corp', 'Tech', 'Solutions', 'Systems', 'Works', 'Labs', 'Industries']
        
        return f"{random.choice(prefixes)}{random.choice(suffixes)}"