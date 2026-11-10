
# ScrapWise – E-waste AI Integration Contract

## 1. Purpose

The E-waste module analyses discarded electronic devices using
image classification and device-condition information.

It helps users understand whether a device may be suitable for:
- Repair
- Resale
- Recycling
- Manual inspection

## 2. Shared Architecture

Flutter Frontend
       |
       v
FastAPI Shared Backend
       |
       v
E-waste AI Model
       |
       v
MongoDB Atlas

Database: scrapwise
Collection: e_waste_assessments

The AI model must integrate with the existing FastAPI backend.
It must not create a separate database or backend.

## 3. Team Responsibility

E-waste teammate:
- Collect and prepare device image datasets.
- Train and evaluate the classification model.
- Identify electronic device categories.
- Assess visible device condition.
- Estimate recoverable materials where supported.
- Integrate model inference with the shared backend.

Team Lead:
- Create API integration.
- Save assessment results in MongoDB.
- Maintain common database structure.
- Connect E-waste results with the Flutter application.

Flutter teammate:
- Build the E-waste user interface.
- Upload device images.
- Display AI assessment results.
- Connect to the shared FastAPI endpoint.

## 4. API Endpoint

POST /api/e-waste/assessments

Purpose:
Submit a device image and receive an AI assessment.

Request format:
multipart/form-data

Fields:
- household_id
- image (device photograph)
- device_brand (optional)
- device_model (optional)
- device_age_years (optional)
- user_reported_issues (optional)

The image is processed by the E-waste AI model through
the shared backend.

## 5. Expected AI Assessment Response

Example response:

{
  "assessment_id": "EW-001",
  "household_id": "H001",
  "predicted_device_type": "mobile_phone",
  "condition": "damaged",
  "confidence": 0.91,
  "recommended_action": "manual_inspection",
  "recoverable_materials": [
    {
      "material": "copper",
      "estimated_quantity": null,
      "unit": "unknown"
    }
  ],
  "assessment_status": "completed"
}

This is an illustrative response, not a claim that the
current model supports these exact classes or predictions.

## 6. Recommended Action Values

- repair
- resale
- recycle
- manual_inspection

The model owner must map its supported outputs to these
standardized values.

## 7. MongoDB Structure

Database: scrapwise

Collection: e_waste_assessments

Suggested fields:
- assessment_id
- household_id
- predicted_device_type
- condition
- confidence
- recommended_action
- recoverable_materials
- image_reference
- created_at
- assessment_status

Do not store image files directly inside ordinary
assessment documents. Image storage location and access
permissions must be agreed upon before implementation.

## 8. Important Integration Rules

1. Flutter communicates only with FastAPI.
2. FastAPI handles communication with the AI model.
3. Assessment metadata is stored in MongoDB Atlas.
4. The E-waste module uses the existing ScrapWise database.
5. Model confidence must not be presented as guaranteed accuracy.
6. Material recovery quantities must not be invented.
7. Unsupported device categories must return an appropriate
   manual inspection result.
8. Authentication and role-based access will be added
   before production deployment.
