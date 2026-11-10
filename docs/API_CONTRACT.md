# ScrapWise API Contract

## Architecture

Flutter Frontend → FastAPI Backend → MongoDB Atlas

Database: scrapwise

## 1. Pickup Request APIs

### Create pickup request
POST /api/pickups

Request:
{
  "household_id": "H001",
  "locality_id": "BALLARI-1",
  "latitude": 15.1394,
  "longitude": 76.9214,
  "preferred_date": "2026-11-09",
  "preferred_time_slot": "morning",
  "materials": ["paper", "plastic"],
  "notes": "Pickup from main gate"
}

Rules:
- Household does not enter estimated weight.
- Request status starts as pending.
- GPS coordinates are required for DBSCAN clustering.

### View pending requests
GET /api/pickups/pending

### Generate pickup clusters
POST /api/pickups/cluster

Request:
{
  "eps_metres": 500,
  "min_samples": 2
}

Rules:
- Only pending requests are considered.
- Requests must match locality, date, time slot
  and exact material combination.
- Haversine DBSCAN is used.
- Cluster radius is configurable.

## 2. Collection Transaction APIs

### Record actual collection
POST /api/transactions

Request:
{
  "request_id": "REQUEST_ID",
  "household_id": "H001",
  "locality_id": "BALLARI-1",
  "collector_id": "C001",
  "recorded_by_user_id": "C001",
  "entry_mode": "collector_self",
  "materials": [
    {
      "material_type": "paper",
      "actual_weight_kg": 5.5,
      "agreed_rate_per_kg": 12
    }
  ],
  "weighed_at": "2026-11-09T10:30:00+05:30"
}

Rules:
- Collector physically weighs the materials.
- Backend calculates the total amount.
- Initial status is awaiting_household_confirmation.

### Household confirms
POST /api/transactions/{transaction_id}/confirm

Request:
{
  "household_id": "H001"
}

### Household disputes
POST /api/transactions/{transaction_id}/dispute

Request:
{
  "household_id": "H001"
}

### Weekly confirmed collection data
GET /api/transactions/confirmed-weekly

Only household-confirmed real transactions
are used for forecasting history.

## 3. Database Collections

Database: scrapwise

- users
- pickup_requests
- collection_transactions
- pickup_clusters
- e_waste_assessments
- localities
- scrap_prices
- forecast_results

## 4. Team Responsibilities

Team Lead:
- Scrap forecasting
- DBSCAN clustering
- Pickup and collection backend
- Database integration

E-waste teammate:
- Device classification
- E-waste condition assessment
- Material recovery intelligence

Flutter teammate:
- Flutter frontend
- Role-based dashboards
- API integration

## 5. User Roles

- Household
- Collector / Kabadiwala
- Trader
- Admin

## 6. Integration Rules

- One FastAPI backend.
- One MongoDB Atlas database.
- Flutter communicates through FastAPI.
- Flutter must not connect directly to MongoDB.
- E-waste module integrates through the shared backend.
- Database credentials remain private in .env.

Important:
Current endpoints are development prototypes.
Authentication and role-based authorization must
be implemented before production deployment.