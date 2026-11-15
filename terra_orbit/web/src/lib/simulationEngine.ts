import { TOGO_REGIONS, CROP_DATABASE, CropData } from "@/data/togoData";

export interface RegionPedology {
  soilType: string;
  pwp: number;
  fc: number;
  sat: number;
  tvdiRef: number;
  twiRef: number;
  lstMin: number;
  lstMax: number;
  drySlope: number;
  wetSlope: number;
}

export const REGION_PEDOLOGY: Record<string, RegionPedology> = {
  Savanes: {
    soilType: "Sols ferrugineux tropicaux lessivés (faible rétention)",
    pwp: 0.07,
    fc: 0.23,
    sat: 0.38,
    tvdiRef: 0.52,
    twiRef: 7.8,
    lstMin: 24.0,
    lstMax: 48.0,
    drySlope: 17.0,
    wetSlope: 1.5,
  },
  Kara: {
    soilType: "Vertisols et lithosols sur roches cristallines",
    pwp: 0.13,
    fc: 0.33,
    sat: 0.44,
    tvdiRef: 0.48,
    twiRef: 7.2,
    lstMin: 22.0,
    lstMax: 46.0,
    drySlope: 16.0,
    wetSlope: 1.5,
  },
  Centrale: {
    soilType: "Sols ferrugineux tropicaux profonds",
    pwp: 0.09,
    fc: 0.27,
    sat: 0.40,
    tvdiRef: 0.46,
    twiRef: 8.2,
    lstMin: 22.0,
    lstMax: 44.0,
    drySlope: 15.5,
    wetSlope: 1.5,
  },
  Plateaux: {
    soilType: "Sols ferrallitiques rouges et bruns profonds",
    pwp: 0.12,
    fc: 0.34,
    sat: 0.46,
    tvdiRef: 0.42,
    twiRef: 8.8,
    lstMin: 20.0,
    lstMax: 42.0,
    drySlope: 15.0,
    wetSlope: 1.8,
  },
  Maritime: {
    soilType: "Terres de barre (sols ferrallitiques sablo-argileux)",
    pwp: 0.08,
    fc: 0.26,
    sat: 0.40,
    tvdiRef: 0.50,
    twiRef: 8.6,
    lstMin: 23.0,
    lstMax: 44.0,
    drySlope: 16.0,
    wetSlope: 1.5,
  },
};

export interface DownscalingResult {
  smapCoarseM3M3: number;
  smFine30mM3M3: number;
  smPercentage: number;
  tvdi: number;
  twi: number;
  pawPercent: number;
  stressLevel: string;
  seedSafe: boolean;
  correctionFactor: number;
  soilType: string;
  pwp: number;
  fc: number;
}

export class MultiSensorDownscaler {
  static computeTVDI(
    lstEcostress: number,
    ndvi: number,
    lstMin: number = 24.0,
    lstMax: number = 46.0,
    drySlope: number = 16.5,
    wetSlope: number = 1.5
  ): number {
    const dryEdge = lstMax - drySlope * ndvi;
    const wetEdge = lstMin + wetSlope * ndvi;
    const safeDryEdge = dryEdge <= wetEdge + 1.5 ? wetEdge + 1.5 : dryEdge;

    const tvdi = (lstEcostress - wetEdge) / (safeDryEdge - wetEdge);
    return Math.max(0.0, Math.min(1.0, tvdi));
  }

  static computeTWI(
    slopeDeg: number,
    catchmentAreaM2: number = 2500.0,
    contourWidthM: number = 30.0,
    minSlopeDeg: number = 0.1
  ): number {
    const w = Math.max(1.0, contourWidthM);
    const aSpecific = Math.max(w, catchmentAreaM2) / w;
    const slopeEffDeg = Math.max(minSlopeDeg, slopeDeg);
    const slopeRad = (slopeEffDeg * Math.PI) / 180;
    const tanSlope = Math.max(1e-4, Math.tan(slopeRad));

    const twi = Math.log(aSpecific / tanSlope);
    return Math.max(3.0, Math.min(16.0, twi));
  }

  static downscaleSoilMoisture(
    smapSmCoarse: number,
    ecostressLst: number,
    ndvi: number,
    slopeDeg: number,
    regionName: string = "Savanes",
    alpha: number = 0.35,
    beta: number = 0.12
  ): DownscalingResult {
    const pedo = REGION_PEDOLOGY[regionName] || REGION_PEDOLOGY["Savanes"];

    const tvdi = this.computeTVDI(
      ecostressLst,
      ndvi,
      pedo.lstMin,
      pedo.lstMax,
      pedo.drySlope,
      pedo.wetSlope
    );
    const twi = this.computeTWI(slopeDeg);

    const correctionFactor =
      1.0 -
      alpha * (tvdi - pedo.tvdiRef) +
      beta * ((twi - pedo.twiRef) / pedo.twiRef);

    let smFine = smapSmCoarse * correctionFactor;
    smFine = Math.max(0.04, Math.min(pedo.sat, smFine));

    const pawPercent = Math.max(
      0.0,
      Math.min(100.0, ((smFine - pedo.pwp) / (pedo.fc - pedo.pwp)) * 100.0)
    );

    let stressLevel = "OPTIMAL (Sol hydraté en profondeur)";
    let seedSafe = true;

    if (pawPercent < 25.0) {
      stressLevel = "SÉVÈRE (Risque élevé de brûlure des jeunes pousses)";
      seedSafe = false;
    } else if (pawPercent < 45.0) {
      stressLevel = "MODÉRÉ (Surveillance requise - semis sous réserve)";
      seedSafe = pawPercent >= 40.0;
    }

    return {
      smapCoarseM3M3: Number(smapSmCoarse.toFixed(3)),
      smFine30mM3M3: Number(smFine.toFixed(3)),
      smPercentage: Number((smFine * 100).toFixed(1)),
      tvdi: Number(tvdi.toFixed(3)),
      twi: Number(twi.toFixed(2)),
      pawPercent: Number(pawPercent.toFixed(1)),
      stressLevel,
      seedSafe,
      correctionFactor: Number(correctionFactor.toFixed(3)),
      soilType: pedo.soilType,
      pwp: pedo.pwp,
      fc: pedo.fc,
    };
  }
}

export interface CycleDetail {
  saison: string;
  culture: string;
  cycleJours: number;
  besoinEauMm: number;
  bilanAzoteKg: number;
  prixKgFcfa: number;
  isCustomPrice: boolean;
  revenuEstimeFcfa: number;
  risqueStressPct: number;
  initialWaterMm: number;
  rainMm: number;
  consumedWaterMm: number;
  residualWaterMm: number;
  drainageMm: number;
  startDay: number;
  endDay: number;
  hydricYieldFactor: number;
}

export interface RotationSimulationResult {
  region: string;
  sequence: string;
  resilienceScore: number;
  bilanAzoteTotalKgHa: number;
  besoinEauTotalMm: number;
  risqueStressMoyenPct: number;
  scoreProtectionErosion: number;
  wueFcfaParMmEau: number;
  revenuCumuleEstimeFcfa: number;
  detailsCycles: CycleDetail[];
  recommandationAgronomique: string;
  totalDays: number;
  scoreComponents: { water: number; nitrogen: number; erosion: number; diversity: number };
}

export interface WeatherObservationInput {
  maxDrySpellDays: number | null;
  validRainDaysCount: number;
  periodDays: number;
}

/** All alternatives must receive this same context. Rain is a scenario, not a forecast. */
export interface SimulationContext {
  regionName: string;
  pawPercent: number;
  weatherObservation?: WeatherObservationInput;
  customPrices?: Record<string, number>;
  rainfallMmPerDay: number;
  slopeDeg: number;
}

export const MODEL_VERSION = "exploratory-2";
// Uncalibrated scenario assumptions. See docs/MODEL_ASSUMPTIONS.md.
export const MODEL_ASSUMPTIONS = {
  legumeCreditKg: 35, legumeYieldBonus: 1.15,
  repeatedCropNitrogenPenaltyKg: 20, repeatedCropYieldMultiplier: 0.75,
  repeatedCropStressPoints: 18, droughtThresholdDays: 7, droughtPointsPerDay: 3,
  runoffBase: 0.08, runoffPerSlopeDegree: 0.02, maxRunoff: 0.30,
} as const;

export interface RotationConstraints {
  allowedCrops: string[];
  maxDays: number;
  maxWaterMm: number;
  objective: "revenue" | "nitrogen" | "stress";
}

export function simulateWithContext(sequence: string[], context: SimulationContext) {
  return CropRotationEngine.simulateRotation(sequence, context.regionName, context.pawPercent,
    context.weatherObservation, context.customPrices, context);
}

/** Exhaustive search of at most 7³ combinations; filters are planning assumptions, not certification. */
export function selectRotationAlternatives(context: SimulationContext, constraints: RotationConstraints) {
  const crops = [...new Set(constraints.allowedCrops)].filter(c => CROP_DATABASE[c]);
  if (!Number.isFinite(constraints.maxDays) || constraints.maxDays <= 0 ||
      !Number.isFinite(constraints.maxWaterMm) || constraints.maxWaterMm < 0) {
    throw new Error("Contraintes de comparaison invalides.");
  }
  const candidates: { sequence: string[]; result: RotationSimulationResult }[] = [];
  for (const first of crops) for (const second of crops) for (const third of crops) {
    const sequence = [first, second, third];
    // Planning constraint: no immediately repeated crop in suggested alternatives.
    if (first === second || second === third) continue;
    if (sequence.reduce((sum, name) => sum + CROP_DATABASE[name].cycleJours, 0) > constraints.maxDays ||
        sequence.reduce((sum, name) => sum + CROP_DATABASE[name].besoinEauCycleMm, 0) > constraints.maxWaterMm) continue;
    candidates.push({ sequence, result: simulateWithContext(sequence, context) });
  }
  const rank = (objective: RotationConstraints["objective"]) => [...candidates].sort((a, b) => {
    const difference = objective === "revenue" ? b.result.revenuCumuleEstimeFcfa - a.result.revenuCumuleEstimeFcfa :
      objective === "nitrogen" ? b.result.bilanAzoteTotalKgHa - a.result.bilanAzoteTotalKgHa :
      a.result.risqueStressMoyenPct - b.result.risqueStressMoyenPct;
    return difference || b.result.resilienceScore - a.result.resilienceScore ||
      a.sequence.join().localeCompare(b.sequence.join(), "fr");
  });
  const selected: { sequence: string[]; result: RotationSimulationResult; objective: RotationConstraints["objective"] }[] = [];
  const objectives = [...new Set([constraints.objective, "revenue", "nitrogen", "stress"])] as RotationConstraints["objective"][];
  for (const objective of objectives) {
    const candidate = rank(objective).find(c => !selected.some(s => s.result.sequence === c.result.sequence));
    if (candidate) selected.push({ ...candidate, objective });
  }
  return { candidateCount: candidates.length, alternatives: selected };
}

export class CropRotationEngine {
  static simulateRotation(
    cropSequence: string[],
    regionName: string,
    soilInitialWaterPct: number = 55.0,
    weatherObservation?: WeatherObservationInput,
    customPrices?: Record<string, number>,
    scenario?: Pick<SimulationContext, "rainfallMmPerDay"> & Partial<Pick<SimulationContext, "slopeDeg">>
  ): RotationSimulationResult {
    if (!cropSequence.length || cropSequence.length > 3 || cropSequence.some(c => !CROP_DATABASE[c])) {
      throw new Error("Choisir une à trois cultures connues.");
    }
    if (!TOGO_REGIONS[regionName] || !Number.isFinite(soilInitialWaterPct) || soilInitialWaterPct < 0 || soilInitialWaterPct > 100) {
      throw new Error("Région ou réserve initiale invalide.");
    }
    const region = TOGO_REGIONS[regionName] || TOGO_REGIONS["Savanes"];
    const slopeDeg = scenario?.slopeDeg ?? region.penteMoyenneDeg;
    const dailyRain = scenario?.rainfallMmPerDay ?? region.pluviometrieAnnuelleMoy / 365;
    if (!Number.isFinite(dailyRain) || dailyRain < 0 || dailyRain > 30 ||
        !Number.isFinite(slopeDeg) || slopeDeg < 0 || slopeDeg > 90 ||
        Object.values(customPrices ?? {}).some(p => !Number.isFinite(p) || p <= 0 || p > 5000)) {
      throw new Error("Hypothèse de pluie, pente ou prix invalide.");
    }
    const ruSolRefMm = region.reserveUtileSolMm || 90;

    let cumulativeNitrogen = 0;
    let totalWaterNeededMm = 0;
    let totalCropDuration = 0;
    let totalStressRisk = 0;
    let economicGrossRevenueFcfa = 0;

    const cropDetails: CycleDetail[] = [];

    // One shared reference reservoir: carry millimetres, never create water when roots change.
    let storedWaterMm = soilInitialWaterPct / 100 * ruSolRefMm;

    cropSequence.forEach((cropName, step) => {
      const crop: CropData = CROP_DATABASE[cropName] || CROP_DATABASE["Maïs"];
      const needMm = crop.besoinEauCycleMm;
      totalWaterNeededMm += needMm;
      const startDay = totalCropDuration + 1;
      totalCropDuration += crop.cycleJours;

      const isLegume = cropName.includes("Soja") || cropName.includes("Niébé") || cropName.includes("Arachide");
      const prevCropName = step > 0 ? cropSequence[step - 1] : null;
      const prevIsLegume = prevCropName
        ? prevCropName.includes("Soja") || prevCropName.includes("Niébé") || prevCropName.includes("Arachide")
        : false;
      const isMonoculture = prevCropName === cropName;

      // 1. Bilan d'azote dynamique et effet précédent cultural
      let cropNBalance = crop.bilanAzoteKgHa;
      let yieldMultiplier = 1.0;
      let monocultureStressBonus = 0;

      if (prevIsLegume && !isLegume) {
        // La céréale qui succède à une légumineuse bénéficie du reliquat azoté (+35 kg N) et d'un gain de vigueur (+15%)
        cropNBalance = Math.min(0, cropNBalance + MODEL_ASSUMPTIONS.legumeCreditKg);
        yieldMultiplier *= MODEL_ASSUMPTIONS.legumeYieldBonus;
      } else if (isMonoculture) {
        // Répétition de la même culture consécutive (monoculture) : fatigue des sols et pression parasitaire accrue
        cropNBalance -= MODEL_ASSUMPTIONS.repeatedCropNitrogenPenaltyKg;
        yieldMultiplier *= MODEL_ASSUMPTIONS.repeatedCropYieldMultiplier;
        monocultureStressBonus = MODEL_ASSUMPTIONS.repeatedCropStressPoints;
      }

      cumulativeNitrogen += cropNBalance;

      // Aggregate reservoir approximation, not the daily FAO-56 model.
      const initialWaterInZone = storedWaterMm;
      const seasonalRain = dailyRain * crop.cycleJours;
      const runoffFraction = Math.min(MODEL_ASSUMPTIONS.maxRunoff,
        MODEL_ASSUMPTIONS.runoffBase + slopeDeg * MODEL_ASSUMPTIONS.runoffPerSlopeDegree);
      const effectiveRain = seasonalRain * (1.0 - runoffFraction);

      const waterAvailableMm = initialWaterInZone + effectiveRain;
      const actualEtMm = Math.min(needMm, waterAvailableMm);

      // Impact d'une poche de sécheresse observée par NASA POWER (jours consécutifs sans pluie)
      let droughtObservedPenalty = 0;
      if (step === 0 && weatherObservation && weatherObservation.periodDays > 0 &&
          weatherObservation.validRainDaysCount === weatherObservation.periodDays &&
          weatherObservation.maxDrySpellDays !== null && weatherObservation.maxDrySpellDays >= 8) {
        droughtObservedPenalty = (weatherObservation.maxDrySpellDays - MODEL_ASSUMPTIONS.droughtThresholdDays) *
          MODEL_ASSUMPTIONS.droughtPointsPerDay * crop.sensibiliteStressKy;
      }

      // Déficit hydrique et impact sur rendement (FAO-33 Stewart)
      const waterDeficitRatio = Math.max(0.0, (needMm - actualEtMm) / needMm);
      const cropStressRisk = Math.min(
        100.0,
        (waterDeficitRatio * crop.sensibiliteStressKy * 100.0) + monocultureStressBonus + droughtObservedPenalty
      );
      totalStressRisk += cropStressRisk;

      // Exact aggregate bookkeeping: excess becomes drainage, zero stays zero.
      const residualWater = Math.max(0.0, waterAvailableMm - actualEtMm);
      storedWaterMm = Math.min(ruSolRefMm, residualWater);
      const drainageMm = residualWater - storedWaterMm;

      // FAO-33 relative hydric response, followed by separate, uncalibrated scenario factors.
      const hydricYieldFactor = Math.max(0, 1 - crop.sensibiliteStressKy * waterDeficitRatio);
      const droughtFactor = Math.max(0, 1 - droughtObservedPenalty / 100);
      const actualYieldTHa = crop.rendementMoyenTHa * hydricYieldFactor * droughtFactor * yieldMultiplier;
      const customPrice = customPrices?.[cropName];
      const isCustomPrice = typeof customPrice === "number" && customPrice > 0;
      const unitPrice = isCustomPrice ? customPrice : crop.valeurCommercialeKgFcfa;
      const revenue = actualYieldTHa * 1000 * unitPrice;
      economicGrossRevenueFcfa += revenue;

      cropDetails.push({
        saison: `Cycle ${step + 1}`,
        culture: cropName,
        cycleJours: crop.cycleJours,
        besoinEauMm: needMm,
        bilanAzoteKg: cropNBalance,
        prixKgFcfa: unitPrice,
        isCustomPrice,
        revenuEstimeFcfa: Math.round(revenue),
        risqueStressPct: Number(cropStressRisk.toFixed(1)),
        initialWaterMm: initialWaterInZone, rainMm: effectiveRain, consumedWaterMm: actualEtMm,
        residualWaterMm: storedWaterMm, drainageMm, startDay, endDay: totalCropDuration,
        hydricYieldFactor,
      });
    });

    const avgStressRisk = Number(
      (totalStressRisk / Math.max(1, cropSequence.length)).toFixed(1)
    );

    const legumeCount = cropSequence.filter(
      (c) => c.includes("Soja") || c.includes("Niébé") || c.includes("Arachide")
    ).length;
    const erosionProtectionScore = Math.max(0, Math.min(100.0,
      45.0 + legumeCount * 25.0 - slopeDeg * 2.5));

    const wueIndex = Number(
      (economicGrossRevenueFcfa / Math.max(1, totalWaterNeededMm)).toFixed(1)
    );

    const uniqueCrops = new Set(cropSequence).size;
    const diversityBonus = Math.min(100, (uniqueCrops - 1) * 50);

    const rawNScore = 50.0 + cumulativeNitrogen * 0.4;
    const nitrogenScore = Math.max(10.0, Math.min(100.0, rawNScore));

    let resilienceScore =
      (100.0 - avgStressRisk) * 0.4 +
      nitrogenScore * 0.25 +
      erosionProtectionScore * 0.15 +
      diversityBonus * 0.2;

    resilienceScore = Number(
      Math.max(0.0, Math.min(100.0, resilienceScore)).toFixed(1)
    );

    return {
      region: regionName,
      sequence: cropSequence.join(" ➔ "),
      resilienceScore,
      bilanAzoteTotalKgHa: cumulativeNitrogen,
      besoinEauTotalMm: totalWaterNeededMm,
      risqueStressMoyenPct: avgStressRisk,
      scoreProtectionErosion: Number(erosionProtectionScore.toFixed(1)),
      wueFcfaParMmEau: wueIndex,
      revenuCumuleEstimeFcfa: Math.round(economicGrossRevenueFcfa),
      detailsCycles: cropDetails,
      totalDays: totalCropDuration,
      scoreComponents: { water: 100 - avgStressRisk, nitrogen: nitrogenScore,
        erosion: erosionProtectionScore, diversity: diversityBonus },
      recommandationAgronomique: this.getRecommendationText(
        resilienceScore,
        cumulativeNitrogen,
        avgStressRisk
      ),
    };
  }

  static getRecommendationText(
    score: number,
    nBalance: number,
    stressRisk: number
  ): string {
    if (score >= 75.0) {
      return (
        "EXCELLENTE ROTATION : Haute synergie agro-écologique. " +
        "Régénération d'azote par légumineuses symbiotiques (Soja/Niébé/Arachide), risque hydrique sous contrôle et protection renforcée des sols en pente."
      );
    } else if (score >= 55.0) {
      return (
        "ROTATION ACCEPTABLE : Équilibre moyen. " +
        "Nous recommandons l'introduction d'une légumineuse supplémentaire pour compenser les pertes azotées et réduire le risque de flétrissement."
      );
    } else {
      return (
        "ROTATION DÉGRADANTE (À RISQUE ÉLEVÉ) : Épuisement hydrique et azoté critique des sols. " +
        "Risque de perte de récolte totale en cas de sécheresse de mi-saison. Résultat exploratoire à confronter aux observations terrain."
      );
    }
  }
}

export interface CreditEvaluationResult {
  statutCredit: string;
  decisionCode: "GREEN_LIGHT" | "ORANGE_LIGHT" | "RED_LIGHT";
  tauxDefautHistoriquePct: number;
  tauxDefautProjetePct: number;
  reductionRisquePct: number;
  tauxInteretRecommandePct: number;
  montantDemandeFcfa: number;
  montantAccordeFcfa: number;
  perteFinanciereEviteeFcfa: number;
  avisAnalysteMifa: string;
}

export class ClimateCreditScorer {
  static BASE_UNINSURED_DEFAULT_RATE = 22.5;

  static evaluateLoanApplication(
    agronomicResilienceScore: number,
    pawPercent: number,
    requestedAmountFcfa: number = 250000
  ): CreditEvaluationResult {
    const riskReductionFactor =
      (agronomicResilienceScore / 100.0) *
      (Math.min(100.0, pawPercent) / 100.0);
    const projectedDefaultRate = Math.max(
      3.5,
      this.BASE_UNINSURED_DEFAULT_RATE * (1.0 - 0.85 * riskReductionFactor)
    );

    let status = "";
    let interestRatePct = 16.5;
    let decisionCode: "GREEN_LIGHT" | "ORANGE_LIGHT" | "RED_LIGHT" = "RED_LIGHT";
    let recommendationBanque = "";
    let maxLoanApproved = 0;

    if (agronomicResilienceScore >= 70.0 && pawPercent >= 40.0) {
      status = "SIMULATION — SCÉNARIO FAVORABLE";
      interestRatePct = 9.5;
      decisionCode = "GREEN_LIGHT";
      recommendationBanque =
        "Hypothèse favorable du modèle. Aucune éligibilité bancaire ou garantie MIFA n’est vérifiée.";
      maxLoanApproved = requestedAmountFcfa;
    } else if (agronomicResilienceScore >= 50.0 && pawPercent >= 25.0) {
      status = "SIMULATION — SCÉNARIO CONDITIONNEL";
      interestRatePct = 12.0;
      decisionCode = "ORANGE_LIGHT";
      recommendationBanque =
        "Scénario intermédiaire : comparer les cultures avec un conseiller. Aucune décision de crédit.";
      maxLoanApproved = Math.round(requestedAmountFcfa * 0.8);
    } else {
      status = "SIMULATION — SCÉNARIO DÉFAVORABLE";
      interestRatePct = 16.5;
      decisionCode = "RED_LIGHT";
      recommendationBanque =
        "Scénario défavorable selon les hypothèses du modèle. Le taux calculé n’est pas une probabilité de défaut validée.";
      maxLoanApproved = 0;
    }

    const lossPreventedFcfa = Math.round(
      requestedAmountFcfa *
        ((this.BASE_UNINSURED_DEFAULT_RATE - projectedDefaultRate) / 100.0)
    );

    return {
      statutCredit: status,
      decisionCode,
      tauxDefautHistoriquePct: this.BASE_UNINSURED_DEFAULT_RATE,
      tauxDefautProjetePct: Number(projectedDefaultRate.toFixed(1)),
      reductionRisquePct: Number(
        (
          ((this.BASE_UNINSURED_DEFAULT_RATE - projectedDefaultRate) /
            this.BASE_UNINSURED_DEFAULT_RATE) *
          100.0
        ).toFixed(1)
      ),
      tauxInteretRecommandePct: interestRatePct,
      montantDemandeFcfa: requestedAmountFcfa,
      montantAccordeFcfa: maxLoanApproved,
      perteFinanciereEviteeFcfa: lossPreventedFcfa,
      avisAnalysteMifa: recommendationBanque,
    };
  }
}

export interface InsuranceClaimResult {
  sinistreDeclenche: boolean;
  statutIndemnisation: string;
  anomalieSmapPct: number;
  anomalieThermiqueEcostressDeg: number;
  joursConsecutifsStress: number;
  capitalAssureFcfa: number;
  montantIndemniseFcfa: number;
  canalVersement: string;
  beneficiaire: string;
  smsTransaction: string;
  dateAudit: string;
  auditFingerprint: string;
}

export class ParametricInsuranceEngine {
  static evaluateClaimTrigger(
    soilMoistureAnomalyPct: number,
    ecostressLstAnomalyDeg: number,
    consecutiveDroughtDays: number,
    insuredCapitalFcfa: number = 200000,
    farmerPhone: string = "+228 90 12 34 56",
    operator: string = "T-Money (Togocom)"
  ): InsuranceClaimResult {
    const isSmCritical = soilMoistureAnomalyPct <= -25.0;
    const isThermalCritical = ecostressLstAnomalyDeg >= 2.5;
    const isDurationCritical = consecutiveDroughtDays >= 14;

    const triggered = isSmCritical && isThermalCritical && isDurationCritical;
    let payoutAmountFcfa = 0;
    let status = "";
    let messageBeneficiaire = "";

    if (triggered) {
      const severityFactor = Math.min(
        1.0,
        (Math.abs(soilMoistureAnomalyPct) / 50.0) *
          (consecutiveDroughtDays / 20.0)
      );
      payoutAmountFcfa = Math.round(insuredCapitalFcfa * severityFactor);
      status = "SIMULATION — SEUIL ATTEINT, AUCUN PAIEMENT";
      messageBeneficiaire = `[SIMULATION ASSURANCE PARAMÉTRIQUE TOGO] Seuil atteint avec les anomalies saisies (SMAP: ${soilMoistureAnomalyPct}%, ECOSTRESS: +${ecostressLstAnomalyDeg}°C). Indemnité estimée : ${payoutAmountFcfa.toLocaleString()} FCFA sur compte ${operator}.`;
    } else {
      status = "SIMULATION — SEUIL NON ATTEINT";
      messageBeneficiaire =
        "Seuil non atteint dans ce scénario. Aucune couverture ou transaction réelle.";
    }

    const todayStr = new Date().toLocaleDateString("fr-FR");
    
    // Identifiant déterministe de scénario (deux accumulateurs FNV dérivés), non cryptographique.
    const payloadStr = `${farmerPhone}|${operator}|Capital:${insuredCapitalFcfa}|Payout:${payoutAmountFcfa}|SMAP:${soilMoistureAnomalyPct}%|LST:+${ecostressLstAnomalyDeg}C|Drought:${consecutiveDroughtDays}d|Date:${todayStr}`;
    let h1 = 0x811c9dc5;
    let h2 = 0x811c9dc5 ^ 0x55555555;
    for (let i = 0; i < payloadStr.length; i++) {
      const code = payloadStr.charCodeAt(i);
      h1 = Math.imul(h1 ^ code, 0x01000193);
      h2 = Math.imul(h2 ^ (code + i), 0x01000193);
    }
    const auditDigest = `0x${(h1 >>> 0).toString(16).padStart(8, "0")}${(h2 >>> 0).toString(16).padStart(8, "0")}`;

    return {
      sinistreDeclenche: triggered,
      statutIndemnisation: status,
      anomalieSmapPct: soilMoistureAnomalyPct,
      anomalieThermiqueEcostressDeg: ecostressLstAnomalyDeg,
      joursConsecutifsStress: consecutiveDroughtDays,
      capitalAssureFcfa: insuredCapitalFcfa,
      montantIndemniseFcfa: payoutAmountFcfa,
      canalVersement: operator,
      beneficiaire: farmerPhone,
      smsTransaction: messageBeneficiaire,
      dateAudit: todayStr,
      auditFingerprint: auditDigest,
    };
  }
}

export function generateSmsAdvisory(
  language: "fr" | "ewe" | "kabye",
  regionName: string,
  soilMoisturePct: number,
  seedSafe: boolean,
  crop1: string,
  crop2: string
): string {
  const translationNote = language === "fr" ? "" : "Traduction locale non validée : aperçu en français.\n";
  return `${translationNote}[SIMULATION TERRA-ORBIT — NON ENVOYÉ]
Zone : ${regionName}
Humidité estimée : ${soilMoisturePct}%
Semis : ${seedSafe ? "seuil hydrique du scénario atteint ; à confirmer sur le terrain" : "seuil hydrique insuffisant ; vérification terrain nécessaire"}.
Rotation explorée : ${crop2} après ${crop1}.`;
}
