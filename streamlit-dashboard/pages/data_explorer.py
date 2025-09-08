"""
Interactive Data Explorer Page
Advanced data analysis with filtering, sorting, and custom visualizations
"""

import streamlit as st
import plotly.express as px
import plotly.graph_objects as go
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
    """Render the data explorer page"""
    theme_manager = ThemeManager()
    
    st.title("🔍 Interactive Data Explorer")
    st.markdown("Dive deep into your data with advanced filtering and visualization tools")
    
    # Data source selection
    data_source = select_data_source(sample_data, uploaded_data)
    
    if data_source is not None and not data_source.empty:
        # Data filtering section
        filtered_data = render_data_filtering_section(data_source)
        
        st.markdown("---")
        
        # Visualization section
        render_visualization_section(filtered_data, theme_manager)
        
        st.markdown("---")
        
        # Advanced analysis section
        render_advanced_analysis_section(filtered_data)
        
        st.markdown("---")
        
        # Data table section
        render_data_table_section(filtered_data)
    else:
        st.info("No data available. Please upload data or check the sample data.")

def select_data_source(sample_data: dict, uploaded_data: pd.DataFrame = None):
    """Allow user to select which dataset to explore"""
    st.subheader("📊 Data Source Selection")
    
    available_sources = ["Sample Sales Data"]
    if uploaded_data is not None:
        available_sources.append("Uploaded Data")
    
    # Add other sample datasets
    available_sources.extend([
        "Sample Customer Data", 
        "Sample Product Data", 
        "Sample Time Series"
    ])
    
    selected_source = st.selectbox(
        "Choose dataset to explore:",
        available_sources,
        help="Select which dataset you want to analyze"
    )
    
    # Return appropriate dataset
    if selected_source == "Uploaded Data" and uploaded_data is not None:
        st.info(f"Exploring uploaded data: {len(uploaded_data)} rows, {len(uploaded_data.columns)} columns")
        return uploaded_data
    elif selected_source == "Sample Sales Data":
        return sample_data['sales_data']
    elif selected_source == "Sample Customer Data":
        return sample_data['customer_data']
    elif selected_source == "Sample Product Data":
        return sample_data['product_data']
    elif selected_source == "Sample Time Series":
        return sample_data['time_series']
    else:
        return sample_data['sales_data']

def render_data_filtering_section(data: pd.DataFrame) -> pd.DataFrame:
    """Render interactive filtering controls"""
    st.subheader("🔧 Data Filters")
    
    # Create filter columns
    col1, col2, col3 = st.columns(3)
    
    filtered_data = data.copy()
    
    with col1:
        st.write("**Column Filters**")
        
        # Numeric column filters
        numeric_cols = data.select_dtypes(include=[np.number]).columns.tolist()
        if numeric_cols:
            selected_numeric_col = st.selectbox("Numeric Column", numeric_cols)
            if selected_numeric_col:
                min_val = float(data[selected_numeric_col].min())
                max_val = float(data[selected_numeric_col].max())
                
                # Range slider for numeric filtering
                range_values = st.slider(
                    f"Filter {selected_numeric_col}",
                    min_val, max_val,
                    (min_val, max_val),
                    key=f"numeric_filter_{selected_numeric_col}"
                )
                
                filtered_data = filtered_data[
                    (filtered_data[selected_numeric_col] >= range_values[0]) &
                    (filtered_data[selected_numeric_col] <= range_values[1])
                ]
    
    with col2:
        st.write("**Categorical Filters**")
        
        # Categorical column filters
        categorical_cols = data.select_dtypes(include=['object']).columns.tolist()
        if categorical_cols:
            selected_cat_col = st.selectbox("Categorical Column", categorical_cols)
            if selected_cat_col:
                unique_values = data[selected_cat_col].unique().tolist()
                
                # Multi-select for categorical filtering
                selected_values = st.multiselect(
                    f"Select {selected_cat_col} values",
                    unique_values,
                    default=unique_values,
                    key=f"cat_filter_{selected_cat_col}"
                )
                
                if selected_values:
                    filtered_data = filtered_data[filtered_data[selected_cat_col].isin(selected_values)]
    
    with col3:
        st.write("**Date Filters**")
        
        # Date column filters
        date_cols = data.select_dtypes(include=['datetime64', 'datetime']).columns.tolist()
        if date_cols:
            selected_date_col = st.selectbox("Date Column", date_cols)
            if selected_date_col:
                min_date = data[selected_date_col].min().date()
                max_date = data[selected_date_col].max().date()
                
                # Date range picker
                date_range = st.date_input(
                    f"Filter {selected_date_col}",
                    value=(min_date, max_date),
                    min_value=min_date,
                    max_value=max_date,
                    key=f"date_filter_{selected_date_col}"
                )
                
                if len(date_range) == 2:
                    start_date, end_date = date_range
                    filtered_data = filtered_data[
                        (filtered_data[selected_date_col].dt.date >= start_date) &
                        (filtered_data[selected_date_col].dt.date <= end_date)
                    ]
    
    # Filter summary
    st.info(f"Filtered data: {len(filtered_data)} rows (from {len(data)} total)")
    
    # Reset filters button
    if st.button("🔄 Reset All Filters"):
        st.experimental_rerun()
    
    return filtered_data

def render_visualization_section(data: pd.DataFrame, theme_manager: ThemeManager):
    """Render custom visualization builder"""
    st.subheader("📈 Custom Visualizations")
    
    # Visualization builder
    col1, col2 = st.columns([1, 3])
    
    with col1:
        st.write("**Chart Builder**")
        
        # Chart type selection
        chart_type = st.selectbox(
            "Chart Type",
            [
                "Scatter Plot",
                "Line Chart", 
                "Bar Chart",
                "Histogram",
                "Box Plot",
                "Correlation Heatmap",
                "Distribution Plot"
            ]
        )
        
        # Column selections based on chart type
        numeric_cols = data.select_dtypes(include=[np.number]).columns.tolist()
        categorical_cols = data.select_dtypes(include=['object']).columns.tolist()
        all_cols = data.columns.tolist()
        
        if chart_type in ["Scatter Plot", "Line Chart"]:
            x_col = st.selectbox("X-axis", all_cols)
            y_col = st.selectbox("Y-axis", numeric_cols)
            color_col = st.selectbox("Color by (optional)", [None] + categorical_cols)
            size_col = st.selectbox("Size by (optional)", [None] + numeric_cols)
        
        elif chart_type in ["Bar Chart"]:
            x_col = st.selectbox("X-axis", categorical_cols + numeric_cols)
            y_col = st.selectbox("Y-axis", numeric_cols)
            color_col = st.selectbox("Color by (optional)", [None] + categorical_cols)
        
        elif chart_type in ["Histogram", "Distribution Plot"]:
            x_col = st.selectbox("Column", numeric_cols)
            color_col = st.selectbox("Group by (optional)", [None] + categorical_cols)
            y_col = None
            size_col = None
        
        elif chart_type == "Box Plot":
            x_col = st.selectbox("Category", categorical_cols)
            y_col = st.selectbox("Values", numeric_cols)
            color_col = None
            size_col = None
        
        elif chart_type == "Correlation Heatmap":
            x_col = None
            y_col = None
            color_col = None
            size_col = None
        
        # Chart customization
        st.write("**Customization**")
        chart_title = st.text_input("Chart Title", f"{chart_type} - {y_col if y_col else x_col}")
        chart_height = st.slider("Chart Height", 300, 800, 500)
    
    with col2:
        # Generate and display chart
        fig = create_custom_chart(
            data, chart_type, x_col, y_col, color_col, size_col, 
            chart_title, chart_height
        )
        
        if fig:
            st.plotly_chart(fig, use_container_width=True)

def create_custom_chart(data: pd.DataFrame, chart_type: str, x_col: str, y_col: str, 
                       color_col: str, size_col: str, title: str, height: int):
    """Create custom plotly chart based on parameters"""
    
    try:
        if chart_type == "Scatter Plot":
            fig = px.scatter(
                data, x=x_col, y=y_col, 
                color=color_col, size=size_col,
                title=title, height=height
            )
        
        elif chart_type == "Line Chart":
            fig = px.line(
                data, x=x_col, y=y_col,
                color=color_col, title=title, height=height
            )
        
        elif chart_type == "Bar Chart":
            if pd.api.types.is_numeric_dtype(data[x_col]):
                # For numeric x-axis, create bins
                data_grouped = data.groupby(x_col)[y_col].sum().reset_index()
                fig = px.bar(
                    data_grouped, x=x_col, y=y_col,
                    title=title, height=height
                )
            else:
                # For categorical x-axis
                data_grouped = data.groupby(x_col)[y_col].sum().reset_index()
                fig = px.bar(
                    data_grouped, x=x_col, y=y_col,
                    color=color_col, title=title, height=height
                )
        
        elif chart_type == "Histogram":
            fig = px.histogram(
                data, x=x_col, color=color_col,
                title=title, height=height
            )
        
        elif chart_type == "Box Plot":
            fig = px.box(
                data, x=x_col, y=y_col,
                title=title, height=height
            )
        
        elif chart_type == "Distribution Plot":
            fig = go.Figure()
            if color_col:
                for category in data[color_col].unique():
                    subset = data[data[color_col] == category]
                    fig.add_trace(go.Histogram(
                        x=subset[x_col],
                        name=str(category),
                        opacity=0.7
                    ))
            else:
                fig.add_trace(go.Histogram(x=data[x_col]))
            
            fig.update_layout(
                title=title,
                height=height,
                barmode='overlay'
            )
        
        elif chart_type == "Correlation Heatmap":
            numeric_data = data.select_dtypes(include=[np.number])
            if len(numeric_data.columns) > 1:
                corr_matrix = numeric_data.corr()
                fig = px.imshow(
                    corr_matrix,
                    title=title,
                    height=height,
                    color_continuous_scale='RdBu'
                )
            else:
                st.warning("Need at least 2 numeric columns for correlation heatmap")
                return None
        
        return fig
    
    except Exception as e:
        st.error(f"Error creating chart: {str(e)}")
        return None

def render_advanced_analysis_section(data: pd.DataFrame):
    """Render advanced statistical analysis"""
    st.subheader("🧮 Advanced Analysis")
    
    tab1, tab2, tab3 = st.tabs(["Statistical Summary", "Correlation Analysis", "Outlier Detection"])
    
    with tab1:
        render_statistical_summary(data)
    
    with tab2:
        render_correlation_analysis(data)
    
    with tab3:
        render_outlier_detection(data)

def render_statistical_summary(data: pd.DataFrame):
    """Render comprehensive statistical summary"""
    st.write("**Descriptive Statistics**")
    
    # Numeric columns analysis
    numeric_cols = data.select_dtypes(include=[np.number]).columns.tolist()
    if numeric_cols:
        st.write("Numeric Columns:")
        stats_df = data[numeric_cols].describe()
        st.dataframe(stats_df, use_container_width=True)
        
        # Additional statistics
        additional_stats = pd.DataFrame({
            'Skewness': data[numeric_cols].skew(),
            'Kurtosis': data[numeric_cols].kurtosis(),
            'Variance': data[numeric_cols].var()
        })
        
        st.write("Additional Statistics:")
        st.dataframe(additional_stats, use_container_width=True)
    
    # Categorical columns analysis
    categorical_cols = data.select_dtypes(include=['object']).columns.tolist()
    if categorical_cols:
        st.write("**Categorical Columns Analysis**")
        
        selected_cat = st.selectbox("Select categorical column", categorical_cols)
        if selected_cat:
            value_counts = data[selected_cat].value_counts()
            
            col1, col2 = st.columns(2)
            with col1:
                st.write("Value Counts:")
                st.dataframe(value_counts.reset_index(), use_container_width=True)
            
            with col2:
                fig = px.pie(
                    values=value_counts.values,
                    names=value_counts.index,
                    title=f"Distribution of {selected_cat}"
                )
                st.plotly_chart(fig, use_container_width=True)

def render_correlation_analysis(data: pd.DataFrame):
    """Render correlation analysis"""
    numeric_cols = data.select_dtypes(include=[np.number]).columns.tolist()
    
    if len(numeric_cols) < 2:
        st.warning("Need at least 2 numeric columns for correlation analysis")
        return
    
    # Correlation matrix
    corr_matrix = data[numeric_cols].corr()
    
    col1, col2 = st.columns(2)
    
    with col1:
        st.write("**Correlation Matrix**")
        st.dataframe(corr_matrix, use_container_width=True)
        
        # Strong correlations
        st.write("**Strong Correlations (|r| > 0.7)**")
        strong_corrs = []
        for i in range(len(corr_matrix.columns)):
            for j in range(i+1, len(corr_matrix.columns)):
                corr_val = corr_matrix.iloc[i, j]
                if abs(corr_val) > 0.7:
                    strong_corrs.append({
                        'Variable 1': corr_matrix.columns[i],
                        'Variable 2': corr_matrix.columns[j],
                        'Correlation': corr_val
                    })
        
        if strong_corrs:
            st.dataframe(pd.DataFrame(strong_corrs), use_container_width=True)
        else:
            st.info("No strong correlations found")
    
    with col2:
        st.write("**Correlation Heatmap**")
        fig = px.imshow(
            corr_matrix,
            title="Correlation Heatmap",
            color_continuous_scale='RdBu',
            aspect="auto"
        )
        st.plotly_chart(fig, use_container_width=True)

def render_outlier_detection(data: pd.DataFrame):
    """Render outlier detection analysis"""
    numeric_cols = data.select_dtypes(include=[np.number]).columns.tolist()
    
    if not numeric_cols:
        st.warning("No numeric columns available for outlier detection")
        return
    
    selected_col = st.selectbox("Select column for outlier detection", numeric_cols)
    
    if selected_col:
        col_data = data[selected_col].dropna()
        
        # Calculate outlier thresholds using IQR method
        Q1 = col_data.quantile(0.25)
        Q3 = col_data.quantile(0.75)
        IQR = Q3 - Q1
        lower_bound = Q1 - 1.5 * IQR
        upper_bound = Q3 + 1.5 * IQR
        
        # Identify outliers
        outliers = col_data[(col_data < lower_bound) | (col_data > upper_bound)]
        
        col1, col2 = st.columns(2)
        
        with col1:
            st.write("**Outlier Statistics**")
            st.metric("Total Outliers", len(outliers))
            st.metric("Outlier Percentage", f"{len(outliers)/len(col_data)*100:.2f}%")
            st.metric("Lower Bound", f"{lower_bound:.2f}")
            st.metric("Upper Bound", f"{upper_bound:.2f}")
            
            if len(outliers) > 0:
                st.write("**Outlier Values**")
                st.dataframe(
                    outliers.reset_index().rename(columns={'index': 'Row Index'}),
                    use_container_width=True
                )
        
        with col2:
            st.write("**Outlier Visualization**")
            
            # Box plot
            fig = go.Figure()
            fig.add_trace(go.Box(
                y=col_data,
                name=selected_col,
                boxpoints='outliers'
            ))
            
            fig.update_layout(
                title=f"Box Plot - {selected_col}",
                yaxis_title=selected_col
            )
            
            st.plotly_chart(fig, use_container_width=True)

def render_data_table_section(data: pd.DataFrame):
    """Render interactive data table with search and sort"""
    st.subheader("📋 Data Table")
    
    # Table controls
    col1, col2, col3, col4 = st.columns(4)
    
    with col1:
        # Search functionality
        search_term = st.text_input("🔍 Search in data", "")
    
    with col2:
        # Column selection
        selected_columns = st.multiselect(
            "Select columns to display",
            data.columns.tolist(),
            default=data.columns.tolist()[:10]  # Show first 10 columns by default
        )
    
    with col3:
        # Sort options
        sort_column = st.selectbox("Sort by", data.columns.tolist())
        sort_ascending = st.checkbox("Ascending", value=True)
    
    with col4:
        # Pagination
        rows_per_page = st.selectbox("Rows per page", [10, 25, 50, 100], index=1)
    
    # Apply filters and sorting
    display_data = data.copy()
    
    # Apply search filter
    if search_term:
        # Search in all string columns
        mask = pd.Series([False] * len(display_data))
        for col in display_data.select_dtypes(include=['object']).columns:
            mask |= display_data[col].astype(str).str.contains(search_term, case=False, na=False)
        display_data = display_data[mask]
    
    # Apply column selection
    if selected_columns:
        display_data = display_data[selected_columns]
    
    # Apply sorting
    if sort_column in display_data.columns:
        display_data = display_data.sort_values(sort_column, ascending=sort_ascending)
    
    # Pagination
    total_rows = len(display_data)
    total_pages = (total_rows - 1) // rows_per_page + 1
    
    if total_pages > 1:
        page_number = st.number_input(
            f"Page (1-{total_pages})",
            min_value=1,
            max_value=total_pages,
            value=1
        )
        
        start_idx = (page_number - 1) * rows_per_page
        end_idx = start_idx + rows_per_page
        display_data = display_data.iloc[start_idx:end_idx]
    
    # Display table
    st.dataframe(display_data, use_container_width=True)
    
    # Table summary
    st.info(f"Showing {len(display_data)} of {total_rows} rows")
    
    # Export filtered data
    if st.button("📥 Export Filtered Data"):
        csv = display_data.to_csv(index=False)
        st.download_button(
            label="Download CSV",
            data=csv,
            file_name="filtered_data.csv",
            mime="text/csv"
        )