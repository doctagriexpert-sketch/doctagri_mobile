"use client";

import React, { useState } from "react";
import { useRegionalEnvironment } from "@/lib/useRegionalEnvironment";
import type { SoilInputs } from "@/lib/environment";
import { TOGO_REGIONS, TOGO_LOCALITIES, FieldLocation } from "@/data/togoData";
import {
  CropRotationEngine,
  MultiSensorDownscaler,
  DownscalingResult,
  RotationSimulationResult,
  SimulationContext,
  simulateWithContext,
} from "@/lib/simulationEngine";

import { Header } from "@/components/Header";
import { FieldLocationSelector } from "@/components/FieldLocationSelector";
import { VisualMetrics } from "@/components/VisualMetrics";
import { RotationSimulator } from "@/components/RotationSimulator";
import { DownscalingPanel } from "@/components/DownscalingPanel";
import { InstitutionalTab } from "@/components/InstitutionalTab";
import { RuralInclusionTab } from "@/components/RuralInclusionTab";
import { ClimateChart } from "@/components/ClimateChart";

const MODULES = [
  {
    id: "agri" as const,
    farmer: "Plan de Culture",
    expert: "Rotation",
  },
  {
    id: "downscale" as const,
    farmer: "Estimation du sol",
    expert: "Modèle de sol",
  },
  {
    id: "fintech" as const,
    farmer: "Prêt et assurance",
    expert: "Crédit et assurance",
  },
  {
    id: "rural" as const,
    farmer: "Messages",
    expert: "SMS et USSD",
  },
];

export default function HomePage() {
  const [selectedRegion, setSelectedRegion] = useState<string>("Savanes");
  const [currentLocation, setCurrentLocation] = useState<FieldLocation>(() => {
    return (
      TOGO_LOCALITIES.find(
        (l) => l.region === "Savanes" && l.canton?.toLowerCase().includes("dapaong")
      ) ||
      TOGO_LOCALITIES.find((l) => l.region === "Savanes") ||
      TOGO_LOCALITIES[0]
    );
  });
  const [viewMode, setViewMode] = useState<"farmer" | "expert">("farmer");
  const [cropSequence, setCropSequence] = useState<string[]>([
    "Maïs",
    "Soja Biologique",
    "Sorgho",
  ]);
  const [customPrices, setCustomPrices] = useState<Record<string, number>>({});

  const [activeTab, setActiveTab] = useState<
    "agri" | "downscale" | "fintech" | "rural"
  >("agri");

  const currentRegionData = TOGO_REGIONS[selectedRegion] || TOGO_REGIONS["Savanes"];
  const [rainScenario, setRainScenario] = useState<{ region: string; value: number } | null>(null);
  const rainfallMmPerDay = rainScenario?.region === selectedRegion ? rainScenario.value :
    Number((currentRegionData.pluviometrieAnnuelleMoy / 365).toFixed(2));

  const environment = useRegionalEnvironment(currentLocation.lat, currentLocation.lon);
  const [manualSoil, setManualSoil] = useState<{ region: string; inputs: SoilInputs } | null>(null);
  const manual = manualSoil?.region === selectedRegion;

  // Only used after explicit user activation; never a provider fallback.
  const defaultSoilInputs: SoilInputs = {
    moisture: selectedRegion === "Savanes" ? 0.16 : selectedRegion === "Kara" ? 0.20 : 0.23,
    temperature: 29.0,
    ndvi: 0.52,
  };

  const soilInputs: SoilInputs | null = manual
    ? manualSoil.inputs
    : environment.soil.status === "ready"
    ? {
        moisture: environment.soil.data.soilMoistureM3M3,
        temperature: environment.soil.data.surfaceTempC,
        ndvi: 0.52,
      }
    : null;

  const downscaleState: DownscalingResult | null = soilInputs ? MultiSensorDownscaler.downscaleSoilMoisture(
    soilInputs.moisture,
    soilInputs.temperature,
    soilInputs.ndvi,
    currentLocation.penteDeg,
    selectedRegion
  ) : null;

  const handleSelectRegion = (regionName: string) => {
    setManualSoil(null);
    setSelectedRegion(regionName);
    const loc = TOGO_LOCALITIES.find((l) => l.region === regionName) || {
      id: regionName.toLowerCase(),
      name: `Région ${regionName}`,
      locality: TOGO_REGIONS[regionName]?.chefLieu || regionName,
      region: regionName,
      lat: TOGO_REGIONS[regionName]?.lat || 10.86,
      lon: TOGO_REGIONS[regionName]?.lon || 0.20,
      penteDeg: TOGO_REGIONS[regionName]?.penteMoyenneDeg || 2.5,
    };
    setCurrentLocation(loc);
  };

  const handleSelectLocation = (loc: FieldLocation) => {
    setManualSoil(null);
    setCurrentLocation(loc);
    setSelectedRegion(loc.region);
  };

  const handleChangeCrop = (index: number, newCrop: string) => {
    const updated = [...cropSequence];
    updated[index] = newCrop;
    setCropSequence(updated);
  };

  const handleApplyPreset = (presetSequence: string[]) => {
    setCropSequence(presetSequence);
  };

  const handleUpdatePrice = (cropName: string, price: number) => {
    if (Number.isFinite(price) && price > 0 && price <= 5000)
      setCustomPrices((prev) => ({ ...prev, [cropName]: price }));
  };

  const handleResetPrice = (cropName: string) => {
    setCustomPrices((prev) => {
      const next = { ...prev };
      delete next[cropName];
      return next;
    });
  };

  const handleResetAllPrices = () => {
    setCustomPrices({});
  };

  const summary = environment.weather.status === "ready" ? environment.weather.data.summary : undefined;
  const completeRain = !!summary && summary.validRainDaysCount === summary.periodDays;
  const context: SimulationContext | null = downscaleState ? {
    regionName: selectedRegion, pawPercent: downscaleState.pawPercent,
    weatherObservation: completeRain ? summary : undefined, customPrices,
    rainfallMmPerDay, slopeDeg: currentLocation.penteDeg,
  } : null;
  const simResult: RotationSimulationResult | null = context ? simulateWithContext(cropSequence, context) : null;

  return (
    <div className="app">
      <Header
        currentRegion={selectedRegion}
        currentLocation={currentLocation}
        onSelectRegion={handleSelectRegion}
        viewMode={viewMode}
        onToggleViewMode={setViewMode}
      />

      <main className="workspace">
        <nav className="index" aria-label="Modules">
          {MODULES.map((item) => (
            <button
              key={item.id}
              type="button"
              aria-current={activeTab === item.id ? "page" : undefined}
              onClick={() => setActiveTab(item.id)}
            >
              {viewMode === "farmer" ? item.farmer : item.expert}
            </button>
          ))}
        </nav>

        <div className="stage">
          {/* Sélecteur de canton / coopérative / GPS */}
          <FieldLocationSelector
            currentLocation={currentLocation}
            onSelectLocation={handleSelectLocation}
          />

          <section className="panel" aria-label="Sources et hypothèses">
            <h2>Comparaison exploratoire — résultats non validés sur le terrain</h2>
            <p>Aucun crédit, paiement ou SMS réel. Les résultats financiers sont des perspectives de démonstration.</p>
            <p><strong>Sol :</strong> {manual ? "Saisie manuelle : toutes les valeurs sont hypothétiques." :
              environment.soil.status === "ready" ? `${environment.soil.data.provider}, surface ${environment.soil.data.depthCm} cm, ${environment.soil.data.asOf}.` :
              environment.soil.status === "loading" ? "Chargement ; estimations suspendues." : "Source indisponible ; estimations suspendues."}</p>
            <p>NDVI hypothétique : {soilInputs?.ndvi ?? "non utilisé"}. Pente de référence : {currentLocation.penteDeg}°. Aucune mesure racinaire ou résolution de 30 m démontrée.</p>
            <p><strong>NASA POWER :</strong> {summary ? `${summary.validRainDaysCount}/${summary.periodDays} jours de pluie renseignés.` : "Observations indisponibles ou en chargement."}
              {completeRain ? " La séquence sèche historique module le premier cycle dans tous les scénarios." : " Aucun malus de sécheresse observée n’est appliqué."}</p>
            <label>Pluie hypothétique uniforme pour les cycles futurs (mm/jour)
              <input className="control" type="number" min="0" max="30" step="0.1" value={rainfallMmPerDay}
                onChange={event => { const value = Number(event.target.value); if (Number.isFinite(value) && value >= 0 && value <= 30) setRainScenario({ region: selectedRegion, value }); }} />
            </label>
            <p className="fine">Valeur initiale : référence annuelle régionale / 365, non calibrée. Modifiable ; ni prévision NASA ni calendrier des pluies. Trois cycles successifs sans temps de jachère ; la durée dépend des cultures.</p>
            {!manual && <button type="button" className="choice" onClick={() => setManualSoil({ region: selectedRegion, inputs: defaultSoilInputs })}>Activer un scénario manuel</button>}
            {environment.soil.status === "error" && <button type="button" className="choice" onClick={environment.retry}>Réessayer les sources</button>}
          </section>
          {downscaleState && simResult && <VisualMetrics
            downscaleResult={downscaleState}
            simResult={simResult}
            viewMode={viewMode}
          />}

          {activeTab === "agri" && simResult && context && (
            <RotationSimulator
              cropSequence={cropSequence}
              onChangeCrop={handleChangeCrop}
              onApplyPreset={handleApplyPreset}
              simResult={simResult}
              viewMode={viewMode}
              customPrices={customPrices}
              onUpdatePrice={handleUpdatePrice}
              onResetPrice={handleResetPrice}
              onResetAllPrices={handleResetAllPrices}
              regionName={selectedRegion}
              context={context}
            />
          )}

          {activeTab === "downscale" && (
            <DownscalingPanel
              slopeDeg={currentLocation.penteDeg}
              regionName={selectedRegion}
              lat={currentLocation.lat}
              lon={currentLocation.lon}
              inputs={soilInputs}
              manual={manual}
              onChange={(inputs) => setManualSoil({ region: selectedRegion, inputs })}
              onUseProvider={() => setManualSoil(null)}
            />
          )}

          {activeTab === "fintech" && simResult && downscaleState && (
            <InstitutionalTab
              resilienceScore={simResult.resilienceScore}
              pawPercent={downscaleState.pawPercent}
              regionName={selectedRegion}
            />
          )}

          {activeTab === "rural" && downscaleState && (
            <RuralInclusionTab
              regionName={selectedRegion}
              soilMoisturePct={downscaleState.smPercentage}
              seedSafe={downscaleState.seedSafe}
              crop1={cropSequence[0]}
              crop2={cropSequence[1]}
            />
          )}

          <ClimateChart
            regionName={currentLocation.locality || selectedRegion}
            weather={environment.weather}
            onRetry={environment.retry}
          />
        </div>
      </main>
    </div>
  );
}
