from typing import List, Optional
from pydantic import BaseModel, Field
from datetime import datetime

class CollarTelemetryDTO(BaseModel):
    timestamp: str
    activity: float = Field(..., description="Activity index")
    skin_temperature: float = Field(..., description="Skin temperature in Celsius")
    ambient_temperature: float = Field(..., description="Ambient temperature in Celsius")
    humidity: float = Field(..., description="Relative humidity %")
    thi: float = Field(..., description="Temperature Humidity Index")

class MilkDataDTO(BaseModel):
    milk_temperature: float = Field(..., description="Milk temperature in Celsius (30.0 - 45.0)")
    ph: float = Field(..., description="Milk pH (6.0 - 7.5)")
    conductivity: float = Field(..., description="Electrical conductivity in mS/cm (3.5 - 12.0)")
    scc: int = Field(..., description="Somatic Cell Count in cells/mL")
    fat: float = Field(..., description="Fat percentage")
    snf: float = Field(..., description="Solids-not-fat percentage")

class AnalysisRequestDTO(BaseModel):
    cow_id: str = Field(..., description="Unique cow identifier, e.g., COW-104")
    collar_data: Optional[List[CollarTelemetryDTO]] = Field(default=[], description="Longitudinal collar telemetry")
    milk_data: MilkDataDTO = Field(..., description="Point-of-care milk sample measurement")

class AnalysisResponseDTO(BaseModel):
    cow_id: str
    prediction: int = Field(..., description="0 = Healthy/Low Risk, 1 = Mastitis Risk")
    probability: float = Field(..., description="Calibrated risk probability (0.0 to 1.0)")
    risk_level: str = Field(..., description="LOW, MODERATE, or HIGH")
    factors: List[str] = Field(default=[], description="Contributing feature drivers")
    recommended_action: str = Field(..., description="Clinical guideline for farmer or veterinarian")
    timestamp: str = Field(default_factory=lambda: datetime.now().isoformat())
