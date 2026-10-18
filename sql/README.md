# Inventory Segmentation & Service-Level Optimization

## Project Overview

This project develops a data-driven inventory management framework using the M5 retail sales dataset. It combines ABC-XYZ inventory segmentation, weekly demand forecasting, forecast accuracy evaluation, and inventory policy optimization to evaluate the trade-off between inventory investment, service levels, and modeled costs.

The goal is to identify inventory strategies that balance product availability with the cost of holding inventory.

## Business Problem

Retailers need to maintain enough inventory to meet customer demand without tying up excessive capital in stock. Applying the same service-level target to every product may not be the most cost-effective approach.

This project evaluates alternative inventory policies and compares their modeled inventory investment, lost sales, fill rates, and total costs.

## Tools & Technologies

- **SQL / DuckDB:** Data preparation, weekly aggregation, segmentation, forecasting evaluation, and inventory calculations
- **Power BI:** Interactive dashboard and visual reporting
- **Excel / CSV:** Data inspection and intermediate exports

## Methodology

### 1. Data Preparation
- Processed the M5 retail sales, calendar, and selling-price datasets.
- Transformed daily sales into weekly demand.
- Prepared product-store level data for analysis.

### 2. ABC-XYZ Segmentation
- Classified products into ABC groups based on revenue contribution.
- Classified demand patterns into XYZ groups based on variability.
- Combined the classifications into nine segments, such as AX, BY, and CZ.

### 3. Forecast Evaluation
- Compared last-week demand, four-week average, eight-week average, and same-week-last-year forecasting methods.
- Evaluated forecast accuracy using Weighted Absolute Percentage Error (WAPE).
- Selected forecasting methods by segment and assessed their performance on a separate test period.

### 4. Inventory Policy Optimization
Compared four policies:
- Uniform 90% service level
- Uniform 95% service level
- Uniform 98% service level
- Differentiated service levels: A = 98%, B = 95%, C = 90%

The model estimated safety stock, average inventory, lost sales, holding costs, and total modeled cost.

### 5. Sensitivity Analysis
Tested an alternative cost scenario by changing the assumed cost of goods sold from 70% to 50% of selling price and the annual holding-rate assumption from 25% to 15%.

## Key Findings

Under the baseline assumptions:

- **Uniform 98%** produced the lowest modeled total cost, approximately **$26,093**.
- Its modeled dollar fill rate was approximately **98.99%**.
- Its estimated average inventory value was approximately **$268,306**.
- Uniform 95% produced a modeled total cost of approximately $30,462 and an average inventory value of $234,513.
- The differentiated A98/B95/C90 policy produced a modeled total cost of approximately $28,472 and an average inventory value of $255,983.
- The sensitivity analysis showed that Uniform 98% remained the lowest-cost policy under the alternative cost assumptions.

ABC-XYZ segmentation also highlighted that the AX and AY segments accounted for a substantial share of estimated inventory investment and lost sales under the Uniform 95% policy.

## Deliverables

- SQL scripts for data preparation, segmentation, forecasting, and inventory policy calculations
- CSV exports for Power BI
- Power BI inventory policy dashboard
- One-page PDF dashboard export

## Limitations

The results depend on the model's assumptions about demand, forecast error, replenishment lead time, cost of goods sold, and inventory holding costs. The inventory and cost estimates are analytical simulations rather than observed operational outcomes. Actual business results may differ.

## Conclusion

This project demonstrates how SQL-based analytics and business intelligence tools can support inventory planning decisions. By combining demand segmentation, forecasting evaluation, and service-level policy comparisons, the analysis provides a structured way to assess the trade-off between product availability and inventory cost.
