from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from .models.schemas import AnalysisRequestDTO, AnalysisResponseDTO
from .services.inference_service import inference_service

app = FastAPI(
    title="Gau-Prahari Mastitis Inference Backend",
    description="AI-Based Predictive Modelling API for Early Forecasting of Bovine Mastitis in Indian Dairy Farms (SIH26109)",
    version="1.0.0",
)

# CORS middleware for mobile/emulator/web access
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/")
def root():
    return {
        "project": "Gau-Prahari",
        "service": "Bovine Mastitis Early Forecasting API",
        "team": "HealX",
        "status": "online",
        "version": "1.0.0",
    }

@app.get("/health")
def health_check():
    return {"status": "healthy", "model_loaded": inference_service.predictor.model is not None}

@app.post("/api/v1/analysis/predict", response_model=AnalysisResponseDTO)
def predict_mastitis(request: AnalysisRequestDTO):
    try:
        response = inference_service.analyze(request)
        return response
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Inference error: {str(e)}")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("backend.app.main:app", host="0.0.0.0", port=8000, reload=True)
