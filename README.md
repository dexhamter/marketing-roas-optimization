# Project: Improving Marketing ROAS

## 🎯 Problem

Marketing team needs to improve blended ROAS by **15% next quarter** without reducing revenue. Spend is spread across channels like Search, Social, Email, Display, Affiliate.

---

## 📌 Business Questions

1. **Which channels drive the highest ROAS?**

&nbsp; → Descriptive analysis: measure performance by channel.

2. **Which campaigns are wasting spend (low ROAS, high spend)?**

&nbsp; → Diagnostic analysis: find inefficiencies.

3. **Should we shift the budget to different platforms?**

&nbsp; → Prescriptive analysis: make recommendations to reallocate spend.

---

## 📂 Data Sources

- `orders` (order_id, customer_id, order_date, revenue)
- `web_sessions` (session_id, customer_id, campaign_id, date)
- `ad_spend_daily` (date, campaign_id, spend)
- `orders` (order_id, customer_id, order_date, revenue)
- `order_items` (order_item_id, order_id, product_id, quantity, price)
- `customers` (customer_id, first_order_date, region)

---

## 🛠️ Tools Used

- **SQL (SQLite/DB Browser)** → for data joins, attribution, ROAS calculation, data validation
- Excel → pivot tables, charts, static dashboards
- Power BI → interactive dashboard

---

## 🔍 Analysis Process

### 1. SQL

- Linked `orders` with `web_sessions` to attribute revenue to campaigns.

- Aggregated revenue and spend by **campaign** and **channel**.

- Performed validations:

&nbsp; - **Total order revenue** = `$778,147.91`

&nbsp; - **Attributed revenue + Unattributed revenue** = `$778,147.91` ✅

### 2. Excel

- Built pivot tables for channel & campaign ROAS.

- Created charts:

&nbsp; - **ROAS by Channel** (clustered column)

&nbsp; - **Revenue Contribution by Channel** (pie)

&nbsp; - **Spend vs Revenue** (bubble)

### 3. Power BI

- KPI Cards: **Attributed Revenue**, **Total Spend**, **Blended ROAS**

- Channel-level visuals: ROAS comparison, spend vs revenue

- Campaign-level drilldown table

- Filters/slicers for channels

---

## 📊 Key Findings

- **Affiliate** → Highest ROAS (3.1) but lowest spend → opportunity to scale.

- **Display** → High spend, lowest ROAS (1.52) → candidate to cut/reduce.

- **Email & Search** → Stable revenue drivers (ROAS ~1.7–1.9).

- **Social Media** → Mid ROAS (1.93) with moderate spend, could scale selectively.

- **Unattributed Revenue** = `$153K` (≈20% of total revenue) → requires deeper investigation.

---

## 💡 Recommendations

- **Scale** Affiliate and Social Media campaigns with higher ROAS.

- **Reduce** investment in Display campaigns.

- **Maintain** spend on Email and Search to preserve stable revenue.

- **Investigate** unattributed revenue to identify potential missed attributions.

---

## 📂 Deliverables

- **SQL Scripts:**

&nbsp; - [`channel_roas.sql`](sql/channel_roas.sql)

&nbsp; - [`campaign_roas.sql`](sql/campaign_roas.sql)

&nbsp; - [`validations.sql`](sql/validations.sql)

&nbsp; - [`unattributed_revenue`](sql/unattributed_revenue.sql)

- **Excel Dashboard:** [`marketing_dashboard.xlsx`](excel/marketing_dashboard.xlsx)

- **Power BI Dashboard:** [`marketing_dashboard.pbix`](powerbi/marketing_attribution.pbix)

- **Dashboard Screenshots:**

&nbsp; - ![Excel Dashboard](/images/marketing_attribution.png)

&nbsp; - ![Power BI Dashboard](images/powerbi_dashboard.pdf)

---

## 👤 Author

Mohd Hammad Yousuf

- This project was created as part of a **portfolio case study** to demonstrate SQL, Excel, and Power BI skills for marketing analytics.
