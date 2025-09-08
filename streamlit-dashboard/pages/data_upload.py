"""
Data Upload Page
Handles CSV/Excel file uploads with validation and preview
"""

import streamlit as st
import pandas as pd
import numpy as np
from io import BytesIO
import sys
from pathlib import Path

# Add project root to path for imports
project_root = Path(__file__).parent.parent
sys.path.append(str(project_root))

from utils.config import AppConfig
from utils.theme_manager import ThemeManager

def render_page():
    """Render the data upload page"""
    config = AppConfig()
    theme_manager = ThemeManager()
    
    st.title("📤 Data Upload")
    st.markdown("Upload your CSV or Excel files to analyze your own data")
    
    # File upload section
    render_file_upload_section(config, theme_manager)
    
    # Data preview section
    if st.session_state.uploaded_data is not None:
        st.markdown("---")
        render_data_preview_section()
        
        st.markdown("---")
        render_data_quality_section()
        
        st.markdown("---")
        render_data_transformation_section()

def render_file_upload_section(config: AppConfig, theme_manager: ThemeManager):
    """Render file upload interface"""
    st.subheader("📁 Upload Your Data")
    
    # Upload instructions
    with st.expander("📋 Upload Instructions", expanded=True):
        st.markdown(f"""
        **Supported Formats:** {', '.join(config.SUPPORTED_FORMATS)}
        
        **Maximum File Size:** {config.MAX_FILE_SIZE}MB
        
        **Data Requirements:**
        - CSV files should have headers in the first row
        - Excel files will use the first sheet by default
        - Date columns should be in a recognizable format
        - Numeric columns should contain only numbers (no currency symbols)
        
        **Tips for Best Results:**
        - Include a date/timestamp column for time-series analysis
        - Use clear column names (avoid spaces and special characters)
        - Ensure data consistency (same format within each column)
        """)
    
    # File uploader
    uploaded_file = st.file_uploader(
        "Choose a CSV or Excel file",
        type=['csv', 'xlsx', 'xls'],
        help="Select a file from your computer to upload and analyze"
    )
    
    if uploaded_file is not None:
        # Validate file
        is_valid, message = config.validate_file_upload(
            uploaded_file.name, 
            uploaded_file.size
        )
        
        if not is_valid:
            st.error(f"❌ Upload Error: {message}")
            return
        
        # Show file info
        st.success(f"✅ File uploaded successfully: {uploaded_file.name}")
        
        col1, col2, col3 = st.columns(3)
        with col1:
            st.info(f"**Size:** {uploaded_file.size / 1024:.1f} KB")
        with col2:
            st.info(f"**Type:** {uploaded_file.type}")
        with col3:
            file_ext = uploaded_file.name.split('.')[-1].lower()
            st.info(f"**Format:** {file_ext.upper()}")
        
        # Processing options
        with st.expander("⚙️ Processing Options"):
            col1, col2 = st.columns(2)
            
            with col1:
                if file_ext == 'xlsx' or file_ext == 'xls':
                    sheet_name = st.text_input(
                        "Sheet Name (Excel only)", 
                        value="0",
                        help="Enter sheet name or index (0 for first sheet)"
                    )
                else:
                    sheet_name = None
                
                encoding = st.selectbox(
                    "File Encoding",
                    ['utf-8', 'latin-1', 'cp1252'],
                    help="Choose encoding if you see strange characters"
                )
            
            with col2:
                skiprows = st.number_input(
                    "Skip Rows",
                    min_value=0,
                    max_value=50,
                    value=0,
                    help="Number of rows to skip from the top"
                )
                
                nrows = st.number_input(
                    "Max Rows to Load",
                    min_value=100,
                    max_value=100000,
                    value=10000,
                    help="Limit rows for large files (0 = load all)"
                )
        
        # Process file button
        if st.button("🔄 Process File", type="primary"):
            with st.spinner("Processing file..."):
                try:
                    df = load_file(uploaded_file, file_ext, encoding, skiprows, nrows, sheet_name)
                    
                    if df is not None and not df.empty:
                        st.session_state.uploaded_data = df
                        st.session_state.upload_filename = uploaded_file.name
                        st.success(f"✅ Successfully loaded {len(df)} rows and {len(df.columns)} columns!")
                        st.experimental_rerun()
                    else:
                        st.error("❌ Failed to load data. Please check your file format.")
                        
                except Exception as e:
                    st.error(f"❌ Error processing file: {str(e)}")
                    st.exception(e)

def load_file(uploaded_file, file_ext: str, encoding: str, skiprows: int, nrows: int, sheet_name: str = None) -> pd.DataFrame:
    """Load file based on format"""
    try:
        if file_ext == 'csv':
            # Handle nrows parameter
            nrows_param = nrows if nrows > 0 else None
            
            df = pd.read_csv(
                uploaded_file,
                encoding=encoding,
                skiprows=skiprows,
                nrows=nrows_param
            )
        else:  # Excel files
            # Handle sheet name
            sheet_param = sheet_name
            if sheet_name and sheet_name.isdigit():
                sheet_param = int(sheet_name)
            
            # Handle nrows parameter
            nrows_param = nrows if nrows > 0 else None
            
            df = pd.read_excel(
                uploaded_file,
                sheet_name=sheet_param,
                skiprows=skiprows,
                nrows=nrows_param
            )
        
        return df
    
    except Exception as e:
        st.error(f"Error loading file: {str(e)}")
        return None

def render_data_preview_section():
    """Render data preview and basic information"""
    st.subheader("👀 Data Preview")
    
    df = st.session_state.uploaded_data
    
    # Basic info
    col1, col2, col3, col4 = st.columns(4)
    
    with col1:
        st.metric("Total Rows", len(df))
    with col2:
        st.metric("Total Columns", len(df.columns))
    with col3:
        st.metric("Memory Usage", f"{df.memory_usage().sum() / 1024:.1f} KB")
    with col4:
        duplicates = df.duplicated().sum()
        st.metric("Duplicate Rows", duplicates)
    
    # Column information
    st.write("**Column Information:**")
    
    col_info = []
    for col in df.columns:
        info = {
            'Column': col,
            'Type': str(df[col].dtype),
            'Non-Null Count': df[col].count(),
            'Null Count': df[col].isnull().sum(),
            'Unique Values': df[col].nunique()
        }
        
        # Add sample values for non-numeric columns
        if df[col].dtype == 'object':
            unique_vals = df[col].unique()[:3]
            info['Sample Values'] = ', '.join([str(v) for v in unique_vals])
        else:
            info['Min'] = df[col].min()
            info['Max'] = df[col].max()
            info['Mean'] = df[col].mean() if pd.api.types.is_numeric_dtype(df[col]) else None
        
        col_info.append(info)
    
    col_df = pd.DataFrame(col_info)
    st.dataframe(col_df, use_container_width=True)
    
    # Data sample
    st.write("**Data Sample:**")
    
    col1, col2 = st.columns([3, 1])
    with col2:
        sample_size = st.slider("Rows to display", 5, min(50, len(df)), 10)
        show_head = st.radio("Show", ["Head", "Tail", "Random Sample"])
    
    with col1:
        if show_head == "Head":
            st.dataframe(df.head(sample_size), use_container_width=True)
        elif show_head == "Tail":
            st.dataframe(df.tail(sample_size), use_container_width=True)
        else:
            st.dataframe(df.sample(min(sample_size, len(df))), use_container_width=True)

def render_data_quality_section():
    """Render data quality analysis"""
    st.subheader("🔍 Data Quality Analysis")
    
    df = st.session_state.uploaded_data
    
    col1, col2 = st.columns(2)
    
    with col1:
        st.write("**Missing Values Analysis**")
        
        missing_data = df.isnull().sum()
        missing_pct = (missing_data / len(df)) * 100
        
        missing_df = pd.DataFrame({
            'Column': missing_data.index,
            'Missing Count': missing_data.values,
            'Missing %': missing_pct.values
        })
        missing_df = missing_df[missing_df['Missing Count'] > 0].sort_values('Missing %', ascending=False)
        
        if len(missing_df) > 0:
            st.dataframe(missing_df, use_container_width=True)
        else:
            st.success("✅ No missing values found!")
    
    with col2:
        st.write("**Data Type Issues**")
        
        issues = []
        for col in df.columns:
            col_data = df[col]
            
            # Check for mixed data types in object columns
            if col_data.dtype == 'object':
                # Try to identify potential numeric columns stored as strings
                non_null_data = col_data.dropna()
                if len(non_null_data) > 0:
                    # Check if it looks like numbers
                    numeric_count = 0
                    for val in non_null_data.head(100):
                        try:
                            float(str(val).replace(',', ''))
                            numeric_count += 1
                        except (ValueError, TypeError):
                            pass
                    
                    if numeric_count / min(len(non_null_data), 100) > 0.8:
                        issues.append(f"{col}: May be numeric data stored as text")
        
        if issues:
            for issue in issues:
                st.warning(f"⚠️ {issue}")
        else:
            st.success("✅ No obvious data type issues found!")
    
    # Quick statistics for numeric columns
    numeric_cols = df.select_dtypes(include=[np.number]).columns
    if len(numeric_cols) > 0:
        st.write("**Numeric Columns Statistics**")
        st.dataframe(df[numeric_cols].describe(), use_container_width=True)

def render_data_transformation_section():
    """Render data transformation options"""
    st.subheader("🔧 Data Transformations")
    
    df = st.session_state.uploaded_data.copy()
    
    col1, col2 = st.columns(2)
    
    with col1:
        st.write("**Column Operations**")
        
        # Column selection for operations
        selected_cols = st.multiselect(
            "Select columns to transform:",
            df.columns.tolist(),
            help="Choose columns for transformation operations"
        )
        
        if selected_cols:
            transformation_type = st.selectbox(
                "Transformation Type",
                [
                    "None",
                    "Convert to Numeric",
                    "Convert to DateTime", 
                    "Remove Duplicates",
                    "Fill Missing Values",
                    "Standardize Text"
                ]
            )
            
            if transformation_type != "None":
                if st.button("Apply Transformation"):
                    df_transformed = apply_transformation(df, selected_cols, transformation_type)
                    if df_transformed is not None:
                        st.session_state.uploaded_data = df_transformed
                        st.success("✅ Transformation applied successfully!")
                        st.experimental_rerun()
    
    with col2:
        st.write("**Export Options**")
        
        # Export processed data
        if st.button("📥 Download Processed Data"):
            csv = df.to_csv(index=False)
            st.download_button(
                label="Download CSV",
                data=csv,
                file_name=f"processed_{st.session_state.get('upload_filename', 'data')}.csv",
                mime="text/csv"
            )
        
        # Generate data summary report
        if st.button("📊 Generate Data Report"):
            report = generate_data_report(df)
            st.download_button(
                label="Download Report",
                data=report,
                file_name="data_quality_report.txt",
                mime="text/plain"
            )

def apply_transformation(df: pd.DataFrame, columns: list, transformation_type: str) -> pd.DataFrame:
    """Apply selected transformation to dataframe"""
    try:
        df_copy = df.copy()
        
        if transformation_type == "Convert to Numeric":
            for col in columns:
                df_copy[col] = pd.to_numeric(df_copy[col], errors='coerce')
        
        elif transformation_type == "Convert to DateTime":
            for col in columns:
                df_copy[col] = pd.to_datetime(df_copy[col], errors='coerce')
        
        elif transformation_type == "Remove Duplicates":
            df_copy = df_copy.drop_duplicates(subset=columns)
        
        elif transformation_type == "Fill Missing Values":
            for col in columns:
                if df_copy[col].dtype in ['object']:
                    df_copy[col] = df_copy[col].fillna('Unknown')
                else:
                    df_copy[col] = df_copy[col].fillna(df_copy[col].mean())
        
        elif transformation_type == "Standardize Text":
            for col in columns:
                if df_copy[col].dtype == 'object':
                    df_copy[col] = df_copy[col].astype(str).str.strip().str.title()
        
        return df_copy
    
    except Exception as e:
        st.error(f"Transformation failed: {str(e)}")
        return None

def generate_data_report(df: pd.DataFrame) -> str:
    """Generate a comprehensive data quality report"""
    report = []
    report.append("DATA QUALITY REPORT")
    report.append("=" * 50)
    report.append(f"Generated on: {pd.Timestamp.now().strftime('%Y-%m-%d %H:%M:%S')}")
    report.append("")
    
    # Basic info
    report.append("BASIC INFORMATION:")
    report.append(f"Total Rows: {len(df)}")
    report.append(f"Total Columns: {len(df.columns)}")
    report.append(f"Memory Usage: {df.memory_usage().sum() / 1024:.1f} KB")
    report.append("")
    
    # Column details
    report.append("COLUMN ANALYSIS:")
    for col in df.columns:
        report.append(f"\n{col}:")
        report.append(f"  Type: {df[col].dtype}")
        report.append(f"  Non-null count: {df[col].count()}")
        report.append(f"  Null count: {df[col].isnull().sum()}")
        report.append(f"  Unique values: {df[col].nunique()}")
        
        if pd.api.types.is_numeric_dtype(df[col]):
            report.append(f"  Min: {df[col].min()}")
            report.append(f"  Max: {df[col].max()}")
            report.append(f"  Mean: {df[col].mean():.2f}")
    
    return "\n".join(report)