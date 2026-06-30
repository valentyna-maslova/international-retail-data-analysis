International Retail Data Analysis: Adaptive Expansion Strategy for a D2C Brand

Comprehensive analysis of a D2C brand's 53% revenue drop in 2024 using Python, PostgreSQL & Power BI. Includes EDA, 3NF database design, 25+ SQL queries, hypothesis testing, A/B tests, and an interactive dashboard. Delivers data-driven recommendations for adaptive international expansion strategy.

Project Goal

Identify the key causes behind a D2C brand's 2024 financial downturn and define priority directions for international expansion under global market uncertainty, through a comprehensive analysis of sales data, discount policy, and logistics processes.

Dataset

Global E-Commerce Sales Dataset 2021–2024 (Kaggle) — a synthetically generated dataset: 10,000 transactions, 26 columns, 2021–2024, 4 regions, 18 countries, 5 product categories.

Tech Stack


Python (Pandas, NumPy, Matplotlib, SciPy) — EDA, data cleaning, currency API enrichment, correlation & hypothesis testing
PostgreSQL — relational database design (Star Schema, 3NF), 25+ analytical queries, window functions, CTEs, views, A/B testing
Power BI (DAX, Power Query) — interactive 4-page dashboard with drill-down navigation
External API — Frankfurter API for historical currency exchange rates


Key Findings


Discount levels above 30% are negatively correlated with order volume (r = −0.30) and profit (r = −0.24) — excessive discounts do not drive demand, only reduce profitability
Markets with stable currencies show higher margins (24.23% vs 23.42%) and lower share of unprofitable orders (12.76% vs 13.62%) than markets with volatile currencies
Currency devaluation is negatively correlated with order volume (r = −0.22), confirmed by Egypt's case: a 180% devaluation of the Egyptian pound coincided with a 47% drop in orders in 2024
Eliminating discounts above 30% would have increased profit by an estimated $179,100 with no additional marketing or logistics investment


Project Structure

├── Project_Python.py                              # EDA, data cleaning, currency enrichment, hypothesis testing
├── Project_SQL.sql                                # Database schema, 25+ analytical queries, A/B tests
├── Project_PowerBI.pbix                           # Interactive 4-page dashboard
├── Пояснювальна_записка_до_фінального_проєкту.pdf  # Full project documentation (Ukrainian, 75 pages)
└── README.md

Methodology


Data preparation (Python) — EDA, data quality checks, chronology validation, enrichment with historical USD exchange rates via API
Database design (PostgreSQL) — Star Schema with 1 fact table and 4 dimension tables, normalized to 3NF, constraints, generated columns, 4 analytical views
Business analysis (SQL) — revenue trends, profitability by category/discount/country, logistics anomaly detection, customer retention analysis
Statistical testing (Python) — Pearson correlation for 3 hypotheses on discount, shipping cost, and currency volatility vs. order volume
A/B testing (PostgreSQL) — currency stability and shipping cost impact on profitability
Dashboard (Power BI) — 4 interconnected pages: overview, regional analysis, unprofitable orders breakdown, hypothesis testing results


Note on AI Usage

AI tools (Claude Sonnet 4.6, Anthropic) were used as a technical and analytical assistant for: accelerating SQL/Python code development, formulating analytical hypotheses, and structuring business conclusions from the computed results. All data interpretation and business decisions are the author's own.

Author

Valentyna Maslova — LinkedIn

Final project for "Data Analytics Pro with AI" course, Hillel IT School (2026).
