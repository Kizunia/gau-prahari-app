import unittest
from fastapi.testclient import TestClient
from app.main import app
from app.ml.model import MastitisPredictor

class TestMastitisMLAndAPI(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.client = TestClient(app)
        cls.predictor = MastitisPredictor()

    def test_health_check(self):
        response = self.client.get("/health")
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertEqual(data["status"], "healthy")
        self.assertTrue(data["model_loaded"])

    def test_ml_healthy_prediction(self):
        sample = {
            "milk_temperature": 35.5,
            "ph": 6.65,
            "conductivity": 4.65,
            "scc": 148000,
            "fat": 4.2,
            "snf": 8.8,
        }
        result = self.predictor.predict(sample)
        self.assertEqual(result["prediction"], 0)
        self.assertEqual(result["risk_level"], "LOW")
        self.assertLess(result["probability"], 0.30)
        self.assertTrue(len(result["factors"]) > 0)

    def test_ml_mastitis_prediction(self):
        sample = {
            "milk_temperature": 38.2,
            "ph": 7.15,
            "conductivity": 6.85,
            "scc": 650000,
            "fat": 3.1,
            "snf": 7.6,
        }
        result = self.predictor.predict(sample)
        self.assertEqual(result["prediction"], 1)
        self.assertEqual(result["risk_level"], "HIGH")
        self.assertGreaterEqual(result["probability"], 0.60)
        self.assertTrue(len(result["factors"]) > 0)

    def test_scc_scale_resilience(self):
        # Test with SCC in raw cells/mL
        res1 = self.predictor.predict({
            "milk_temperature": 35.5,
            "ph": 6.65,
            "conductivity": 4.65,
            "scc": 148000,
        })
        # Test with SCC already scaled in thousands
        res2 = self.predictor.predict({
            "milk_temperature": 35.5,
            "ph": 6.65,
            "conductivity": 4.65,
            "scc": 148,
        })
        self.assertEqual(res1["prediction"], res2["prediction"])
        self.assertAlmostEqual(res1["probability"], res2["probability"], places=3)

    def test_api_predict_endpoint_healthy(self):
        payload = {
            "cow_id": "COW-101",
            "collar_data": [],
            "milk_data": {
                "milk_temperature": 35.4,
                "ph": 6.62,
                "conductivity": 4.68,
                "scc": 140000,
                "fat": 4.1,
                "snf": 8.7,
            },
        }
        response = self.client.post("/api/v1/analysis/predict", json=payload)
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertEqual(data["cow_id"], "COW-101")
        self.assertEqual(data["prediction"], 0)
        self.assertEqual(data["risk_level"], "LOW")
        self.assertIn("recommended_action", data)

    def test_api_predict_endpoint_mastitis(self):
        payload = {
            "cow_id": "COW-808",
            "collar_data": [],
            "milk_data": {
                "milk_temperature": 38.4,
                "ph": 7.20,
                "conductivity": 6.95,
                "scc": 720000,
                "fat": 3.0,
                "snf": 7.5,
            },
        }
        response = self.client.post("/api/v1/analysis/predict", json=payload)
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertEqual(data["cow_id"], "COW-808")
        self.assertEqual(data["prediction"], 1)
        self.assertEqual(data["risk_level"], "HIGH")
        self.assertGreaterEqual(len(data["factors"]), 2)

if __name__ == "__main__":
    unittest.main()
