export interface ClimatePoint {
  dateIso: string;
  rainMm: number | null;
  tempMean: number | null;
  tempMin: number | null;
  tempMax: number | null;
  solarRadiation: number | null;
  hasMissingData: boolean;
}
export interface ClimateData {
  provider: string;
  periodDays: number;
  validDaysCount: number;
  missingDaysCount: number;
  summary: {
    totalRainMm: number | null;
    maxDrySpellDays: number | null;
    validRainDaysCount: number;
    periodDays: number;
  };
  series: ClimatePoint[];
}
export interface SoilData {
  provider: string;
  asOf: string;
  soilMoistureM3M3: number;
  surfaceTempC: number;
  depthCm: string;
}
export interface SoilInputs { moisture: number; temperature: number; ndvi: number; }
export type RemoteData<T> =
  | { status: "loading"; data?: never; error?: never }
  | { status: "ready"; data: T; error?: never }
  | { status: "error"; data?: never; error: string };
