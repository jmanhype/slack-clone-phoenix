"""
Main Dashboard Page
Displays key metrics, charts, and KPIs
"""

import streamlit as st
import plotly.express as px
import plotly.graph_objects as go
from plotly.subplots import make_subplots
import pandas as pd
import numpy as np
from datetime import datetime, timedelta
import sys
from pathlib import Path

# Add project root to path for imports
project_root = Path(__file__).parent.parent
sys.path.append(str(project_root))

from utils.theme_manager import ThemeManager

def render_page(sample_data: dict, uploaded_data: pd.DataFrame = None):
    """Render the main dashboard page"""
    theme_manager = ThemeManager()
    
    st.title("📊 Analytics Dashboard")
    st.markdown("Welcome to your comprehensive analytics overview")
    
    # Use uploaded data if available, otherwise use sample data
    data_source = uploaded_data if uploaded_data is not None else sample_data['sales_data']
    time_series = sample_data['time_series']
    
    # Key metrics section
    render_key_metrics(data_source, theme_manager)
    
    st.markdown("---")
    
    # Charts section
    col1, col2 = st.columns(2)
    
    with col1:
        render_sales_trend_chart(time_series)
        render_category_distribution(data_source)
    
    with col2:
        render_revenue_metrics(data_source)
        render_regional_performance(data_source)
    
    # Full-width charts
    st.markdown("---")
    render_detailed_analytics(data_source, time_series)

def render_key_metrics(data: pd.DataFrame, theme_manager: ThemeManager):
    """Render key performance indicators"""
    st.subheader("📈 Key Performance Indicators")
    
    # Calculate metrics
    total_revenue = data['total_amount'].sum()
    total_orders = len(data)
    avg_order_value = data['total_amount'].mean()
    total_profit = data['profit'].sum() if 'profit' in data.columns else total_revenue * 0.2
    
    # Previous period comparison (mock data for demo)
    prev_revenue = total_revenue * 0.85
    prev_orders = total_orders * 0.92
    prev_aov = avg_order_value * 0.88
    prev_profit = total_profit * 0.83
    
    # Create metric columns
    col1, col2, col3, col4 = st.columns(4)
    
    with col1:
        revenue_delta = ((total_revenue - prev_revenue) / prev_revenue * 100)
        revenue_card = theme_manager.create_metric_card(
            "Total Revenue",
            f"${total_revenue:,.2f}",
            f"↗️ {revenue_delta:.1f}% vs last period",
            "positive" if revenue_delta > 0 else "negative"
        )
        st.markdown(revenue_card, unsafe_allow_html=True)
    
    with col2:
        orders_delta = ((total_orders - prev_orders) / prev_orders * 100)
        orders_card = theme_manager.create_metric_card(
            "Total Orders",
            f"{total_orders:,}",
            f"↗️ {orders_delta:.1f}% vs last period",
            "positive" if orders_delta > 0 else "negative"
        )
        st.markdown(orders_card, unsafe_allow_html=True)
    
    with col3:
        aov_delta = ((avg_order_value - prev_aov) / prev_aov * 100)
        aov_card = theme_manager.create_metric_card(
            "Avg Order Value",
            f"${avg_order_value:.2f}",
            f"↗️ {aov_delta:.1f}% vs last period",
            "positive" if aov_delta > 0 else "negative"
        )
        st.markdown(aov_card, unsafe_allow_html=True)
    
    with col4:
        profit_delta = ((total_profit - prev_profit) / prev_profit * 100)
        profit_card = theme_manager.create_metric_card(
            "Total Profit",
            f"${total_profit:,.2f}",
            f"↗️ {profit_delta:.1f}% vs last period",
            "positive" if profit_delta > 0 else "negative"
        )
        st.markdown(profit_card, unsafe_allow_html=True)

def render_sales_trend_chart(time_series: pd.DataFrame):
    """Render sales trend over time"""
    st.subheader("📊 Sales Trend")
    
    # Create time series chart
    fig = go.Figure()
    
    fig.add_trace(go.Scatter(
        x=time_series['date'],
        y=time_series['sales'],
        mode='lines',
        name='Sales',
        line=dict(color='#FF6B6B', width=3),
        fill='tonexty',
        fillcolor='rgba(255, 107, 107, 0.1)'
    ))
    
    # Add moving average
    time_series['ma_7'] = time_series['sales'].rolling(window=7).mean()
    fig.add_trace(go.Scatter(
        x=time_series['date'],
        y=time_series['ma_7'],
        mode='lines',
        name='7-Day MA',
        line=dict(color='#4ECDC4', width=2, dash='dash')
    ))
    
    fig.update_layout(
        title="Daily Sales Trend with Moving Average",
        xaxis_title="Date",
        yaxis_title="Sales ($)",
        hovermode='x unified',
        showlegend=True,
        height=400
    )
    
    st.plotly_chart(fig, use_container_width=True)

def render_category_distribution(data: pd.DataFrame):
    """Render product category distribution"""
    st.subheader("🏷️ Category Performance")
    
    if 'product_category' in data.columns:
        category_revenue = data.groupby('product_category')['total_amount'].sum().reset_index()
        category_revenue = category_revenue.sort_values('total_amount', ascending=False)
        
        fig = px.pie(
            category_revenue,
            values='total_amount',
            names='product_category',
            title="Revenue by Product Category",
            color_discrete_sequence=px.colors.qualitative.Set3
        )
        
        fig.update_traces(textposition='inside', textinfo='percent+label')
        fig.update_layout(height=400)
        
        st.plotly_chart(fig, use_container_width=True)
    else:
        st.info("Category data not available in uploaded dataset")

def render_revenue_metrics(data: pd.DataFrame):
    """Render revenue and profit metrics"""
    st.subheader("💰 Revenue & Profit")
    
    # Monthly aggregation
    if 'date' in data.columns:
        data['month'] = pd.to_datetime(data['date']).dt.to_period('M')
        monthly_data = data.groupby('month').agg({
            'total_amount': 'sum',
            'profit': 'sum' if 'profit' in data.columns else lambda x: data['total_amount'].sum() * 0.2
        }).reset_index()
        
        monthly_data['month_str'] = monthly_data['month'].astype(str)
        
        fig = make_subplots(specs=[[{"secondary_y": True}]])
        
        # Revenue bars
        fig.add_trace(
            go.Bar(
                x=monthly_data['month_str'],
                y=monthly_data['total_amount'],
                name='Revenue',
                marker_color='#FF6B6B'
            ),
            secondary_y=False,
        )
        
        # Profit line
        if 'profit' in monthly_data.columns:
            fig.add_trace(
                go.Scatter(
                    x=monthly_data['month_str'],
                    y=monthly_data['profit'],
                    mode='lines+markers',
                    name='Profit',
                    line=dict(color='#4ECDC4', width=3)
                ),
                secondary_y=True,
            )
        
        fig.update_yaxes(title_text="Revenue ($)", secondary_y=False)
        fig.update_yaxes(title_text="Profit ($)", secondary_y=True)
        fig.update_xaxes(title_text="Month")
        fig.update_layout(title="Monthly Revenue & Profit", height=400)
        
        st.plotly_chart(fig, use_container_width=True)
    else:
        # Fallback for data without date column
        total_revenue = data['total_amount'].sum()
        total_profit = data['profit'].sum() if 'profit' in data.columns else total_revenue * 0.2
        
        fig = go.Figure(data=[
            go.Bar(
                x=['Revenue', 'Profit'],
                y=[total_revenue, total_profit],
                marker_color=['#FF6B6B', '#4ECDC4']
            )
        ])
        
        fig.update_layout(
            title="Total Revenue vs Profit",
            yaxis_title="Amount ($)",
            height=400
        )
        
        st.plotly_chart(fig, use_container_width=True)

def render_regional_performance(data: pd.DataFrame):
    """Render regional performance metrics"""
    st.subheader("🌍 Regional Performance")
    
    if 'region' in data.columns:
        regional_data = data.groupby('region').agg({
            'total_amount': 'sum',
            'transaction_id': 'count'
        }).reset_index()
        
        regional_data.columns = ['region', 'revenue', 'orders']
        regional_data = regional_data.sort_values('revenue', ascending=True)
        
        fig = px.bar(
            regional_data,
            x='revenue',
            y='region',
            orientation='h',
            title="Revenue by Region",
            color='revenue',
            color_continuous_scale='Viridis'
        )
        
        fig.update_layout(height=400)
        st.plotly_chart(fig, use_container_width=True)
    else:
        st.info("Regional data not available in uploaded dataset")

def render_detailed_analytics(data: pd.DataFrame, time_series: pd.DataFrame):
    """Render detailed analytics section"""
    st.subheader("📊 Detailed Analytics")
    
    tab1, tab2, tab3 = st.tabs(["Sales Analysis", "Customer Insights", "Performance Metrics"])
    
    with tab1:
        render_sales_analysis(data, time_series)
    
    with tab2:
        render_customer_insights(data)
    
    with tab3:
        render_performance_metrics(data, time_series)

def render_sales_analysis(data: pd.DataFrame, time_series: pd.DataFrame):
    """Detailed sales analysis"""
    col1, col2 = st.columns(2)
    
    with col1:
        st.write("**Daily Sales Distribution**")
        fig = px.histogram(
            time_series,
            x='sales',
            nbins=30,
            title="Distribution of Daily Sales",
            color_discrete_sequence=['#FF6B6B']
        )
        st.plotly_chart(fig, use_container_width=True)
    
    with col2:
        if 'sales_channel' in data.columns:
            st.write("**Sales by Channel**")
            channel_data = data.groupby('sales_channel')['total_amount'].sum().reset_index()
            fig = px.bar(
                channel_data,
                x='sales_channel',
                y='total_amount',
                title="Revenue by Sales Channel",
                color='total_amount',
                color_continuous_scale='Blues'
            )
            st.plotly_chart(fig, use_container_width=True)

def render_customer_insights(data: pd.DataFrame):
    """Customer insights analysis"""
    col1, col2 = st.columns(2)
    
    with col1:
        if 'customer_segment' in data.columns:
            st.write("**Customer Segment Analysis**")
            segment_data = data.groupby('customer_segment').agg({
                'total_amount': 'sum',
                'customer_id': 'nunique'
            }).reset_index()
            
            fig = px.scatter(
                segment_data,
                x='customer_id',
                y='total_amount',
                color='customer_segment',
                size='total_amount',
                title="Customer Segments: Count vs Revenue"
            )
            st.plotly_chart(fig, use_container_width=True)
    
    with col2:
        if 'quantity' in data.columns:
            st.write("**Order Size Distribution**")
            fig = px.box(
                data,
                y='quantity',
                title="Order Quantity Distribution",
                color_discrete_sequence=['#4ECDC4']
            )
            st.plotly_chart(fig, use_container_width=True)

def render_performance_metrics(data: pd.DataFrame, time_series: pd.DataFrame):
    """Performance metrics visualization"""
    col1, col2 = st.columns(2)
    
    with col1:
        st.write("**Profit Margin Analysis**")
        if 'profit_margin' in time_series.columns:
            fig = go.Figure()
            fig.add_trace(go.Scatter(
                x=time_series['date'],
                y=time_series['profit_margin'] * 100,
                mode='lines',
                name='Profit Margin %',
                line=dict(color='#95A5A6', width=2)
            ))
            
            fig.update_layout(
                title="Daily Profit Margin Trend",
                yaxis_title="Profit Margin (%)",
                xaxis_title="Date"
            )
            st.plotly_chart(fig, use_container_width=True)
    
    with col2:
        st.write("**Growth Rate Analysis**")
        if len(time_series) > 1:
            time_series['growth_rate'] = time_series['sales'].pct_change() * 100
            
            fig = px.bar(
                time_series.tail(30),  # Last 30 days
                x='date',
                y='growth_rate',
                title="Daily Growth Rate (Last 30 Days)",
                color='growth_rate',
                color_continuous_scale='RdYlBu'
            )
            st.plotly_chart(fig, use_container_width=True)