from ..models.schemas import AnalysisRequestDTO, AnalysisResponseDTO
from ..ml.model import MastitisPredictor
from datetime import datetime

class InferenceService:
    def __init__(self):
        self.predictor = MastitisPredictor()

    def analyze(self, request: AnalysisRequestDTO) -> AnalysisResponseDTO:
        milk_dict = request.milk_data.model_dump()
        result = self.predictor.predict(milk_dict)

        return AnalysisResponseDTO(
            cow_id=request.cow_id,
            prediction=result["prediction"],
            probability=result["probability"],
            risk_level=result["risk_level"],
            factors=result["factors"],
            recommended_action=result["recommended_action"],
            timestamp=datetime.now().isoformat(),
        )

inference_service = InferenceService()
