
# ScrapWise – Data Dictionary
## Scrap Collection and Intelligence Module

Version: 1.0

Purpose:
This document defines the common data fields used by the household scrap collection workflow, kabadiwala assignment, physical weighing, transaction confirmation, DBSCAN clustering and scrap availability forecasting.

All frontend, backend and ML developers must follow these field names.

---

## 1. Standard Material Categories

The following material identifiers must be used consistently:

- newspaper
- old_books
- cardboard
- PET_plastic
- mixed_plastic
- iron
- steel
- aluminium
- copper
- glass
- clothes
- other

The UI may display translated material names, but the backend must store these standard identifiers.

---

## 2. Household Pickup Request

Collection: pickup_requests

Purpose:
Stores the materials a household wants to sell and its preferred collection details.

| Field | Data type | Required | Description |
|---|---|---|---|
| request_id | String | Yes | Unique request identifier |
| household_id | String | Yes | Household user identifier |
| locality_id | String | Yes | Selected locality |
| requested_materials | Array | Yes | List of material identifiers |
| preferred_date | Date | Yes | Preferred pickup date |
| preferred_time_slot | String | Yes | morning / afternoon / evening |
| address | String | Yes | Pickup address |
| latitude | Number | Yes | Location latitude |
| longitude | Number | Yes | Location longitude |
| selected_kabadiwala_id | String or null | No | Selected collector |
| status | String | Yes | Request status |
| notes | String | No | Additional information |
| created_at | DateTime | Yes | Request creation time |

Important:
- Household users are not required to enter scrap weight.
- A request may contain multiple material categories.
- Coordinates must be handled securely and only exposed to authorised users.
- The selected kabadiwala may be assigned later by a trader or the system.

Request statuses:
pending, assigned, accepted, completed, cancelled.

---

## 3. Kabadiwala Assignment

Collection: pickup_assignments

Purpose:
Records who assigned a pickup and which collector is responsible.

| Field | Data type | Description |
|---|---|---|
| assignment_id | String | Unique assignment ID |
| request_id | String | Associated household request |
| collector_id | String | Assigned kabadiwala |
| assigned_by_user_id | String | Trader, household or admin who assigned the work |
| assignment_mode | String | household_selected / trader_assisted / automatic |
| assigned_at | DateTime | Assignment timestamp |
| status | String | Assignment status |

Important:
A kabadiwala does not have to operate the application personally. A trader can manage assignments on their behalf.

The actual collector and the person entering the information must be recorded separately.

---

## 4. Actual Scrap Weighing and Transaction

Collection: collection_transactions

Purpose:
Stores the actual weight measured by the kabadiwala and the mutually agreed price.

| Field | Data type | Description |
|---|---|---|
| transaction_id | String | Unique transaction ID |
| request_id | String | Related pickup request |
| collector_id | String | Person who physically collected the scrap |
| recorded_by_user_id | String | Person who entered the details |
| entry_mode | String | collector_app / trader_assisted |
| items | Array | Material-wise weighing details |
| total_amount | Number | Total transaction value |
| confirmation_status | String | Household confirmation status |
| weighed_at | DateTime | Weighing timestamp |
| confirmed_at | DateTime or null | Household confirmation timestamp |

Each item in the items array:

| Field | Data type | Description |
|---|---|---|
| material_type | String | Standard material identifier |
| quality_grade | String | normal / mixed / damaged / unknown |
| actual_weight_kg | Number | Physically measured weight |
| agreed_rate_per_kg | Number | Agreed purchase rate |
| line_total | Number | Actual weight multiplied by agreed rate |

Formula:

line_total = actual_weight_kg * agreed_rate_per_kg

total_amount = Sum of all line_total values.

Only household-confirmed transactions should be treated as confirmed historical training records.

Confirmation statuses:
pending_household, confirmed, disputed.

---

## 5. Trader Price Observations

Collection: price_updates

Purpose:
Stores rates updated by verified traders.

| Field | Data type | Description |
|---|---|---|
| price_id | String | Unique price record |
| trader_id | String | Trader who submitted the rate |
| material_type | String | Standard material identifier |
| quality_grade | String | Material grade |
| rate_per_kg | Number | Observed price per kg |
| market_stage | String | Trader buying / Trader selling |
| locality_id | String | Market locality |
| updated_at | DateTime | Update date and time |

Important:
Price observations are indicative references. The final household transaction uses the mutually agreed rate entered at physical collection.

Old price observations must remain in the history.

---

## 6. Weekly Scrap Collection Aggregates

Collection: weekly_collection_aggregates

Purpose:
This is the primary historical dataset for scrap availability forecasting.

Each record represents one material in one locality during one week.

| Field | Data type | Description |
|---|---|---|
| locality_id | String | Collection locality |
| material_type | String | Material identifier |
| week_start_date | Date | Start of aggregation week |
| actual_collected_kg | Number | Total confirmed weight collected |
| participating_households_count | Integer | Distinct households contributing confirmed collections |
| confirmed_transaction_count | Integer | Number of confirmed transactions |

The actual_collected_kg value must be derived from household-confirmed weighing records.

Do not use household estimates as actual collected quantities.

---

## 7. ML Model 1 – Scrap Availability Forecasting

Purpose:
Predict expected confirmed scrap collection quantity for each locality and material over the next seven days.

Input features:

| Feature | Meaning |
|---|---|
| locality_id | Locality |
| material_type | Scrap material |
| week_of_year | Collection week |
| month | Month |
| qty_lag_1_week_kg | Previous week's actual quantity |
| qty_lag_2_week_kg | Quantity two weeks earlier |
| qty_lag_4_week_kg | Quantity four weeks earlier |
| avg_qty_last_4_weeks_kg | Four-week historical average |
| participating_households_last_4_weeks | Number of contributing households |
| days_since_last_collection | Days since previous confirmed collection |

Prediction target:

next_7_days_confirmed_collection_kg

Suggested algorithm:
- Moving Average baseline
- Random Forest Regressor
- Gradient Boosting Regressor

Evaluation:
- MAE
- RMSE
- R-squared

Important:
Features must only use information available at the prediction cutoff. No future data may enter model training features.

---

## 8. DBSCAN – Collaborative Pickup Clustering

Purpose:
Group geographically close pending household pickup requests.

Inputs:

| Field | Description |
|---|---|
| request_id | Request identifier |
| latitude | Household latitude |
| longitude | Household longitude |
| locality_id | Locality |
| preferred_date | Requested pickup date |
| preferred_time_slot | Requested pickup period |
| requested_materials | Materials available |

Algorithm:
DBSCAN with geographic distance using the Haversine metric.

The latitude and longitude must be converted to radians before applying Haversine distance.

Clustering should consider compatible pickup dates and time windows.

Output:

| Field | Description |
|---|---|
| cluster_id | Identified cluster |
| request_ids | Requests grouped together |
| locality_id | Locality |
| number_of_requests | Number of grouped requests |

Important:
- DBSCAN identifies nearby request groups.
- It does not predict scrap weight.
- It does not calculate an optimised driving route.
- Every household transaction remains independent.

---

## 9. ML Forecast Output

Collection: scrap_forecasts

| Field | Description |
|---|---|
| forecast_id | Unique forecast ID |
| locality_id | Forecast locality |
| material_type | Scrap material |
| forecast_start_date | Start date |
| forecast_end_date | End date |
| predicted_collection_kg | Model prediction |
| model_version | Model version |
| generated_at | Prediction timestamp |

The frontend displays this value on the locality heat map.

---

## 10. Shared Development Rules

1. All team members must use the exact field names in this dictionary.
2. Household users do not enter mandatory kilograms.
3. Actual weight must come from physical weighing.
4. Only confirmed collection transactions enter the confirmed historical forecasting dataset.
5. Forecast heat maps and DBSCAN pickup clusters are separate layers.
6. Trader-assisted operations must record who performed the physical collection and who entered the data.
7. Price updates must preserve source and timestamp.
8. Do not claim model accuracy without actual evaluation.
9. Do not use simulated quantities as real collection history.
10. Changes to common fields require agreement from all three developers.
