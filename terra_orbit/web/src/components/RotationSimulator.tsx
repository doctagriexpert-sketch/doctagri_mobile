"use client";

import React, { useState } from "react";
import {
  CROP_DATABASE,
  ROTATION_PRESETS,
  RECOMMENDED_ROTATIONS,
  CropData,
  RecommendedRotation,
} from "@/data/togoData";
import { RotationSimulationResult, CropRotationEngine } from "@/lib/simulationEngine";

interface RotationSimulatorProps {
  cropSequence: string[];
  onChangeCrop: (index: number, cropName: string) => void;
  onApplyPreset: (presetSequence: string[]) => void;
  simResult: RotationSimulationResult;
  viewMode: "farmer" | "expert";
  customPrices?: Record<string, number>;
  onUpdatePrice?: (cropName: string, price: number) => void;
  onResetPrice?: (cropName: string) => void;
  onResetAllPrices?: () => void;
  regionName?: string;
  pawPercent?: number;
  context?: any;
}

const AUDIO_COPY: Record<"fr" | "ewe" | "kabye", string> = {
  fr: "Conseil en français : votre terre a besoin de soja pour se reposer. N’enchaînez pas le maïs sans rotation.",
  ewe: "Conseil en éwé : Miawoe zɔ. Anyigba la le ku dzi. Mina miado ayi (soja) be anyigba la naɖu nu nyuie.",
  kabye: "Conseil en kabyè : Tɛtʊ nɛ tɩkɩndaa. Yele nɛ ɩsɔɔ sɔya se tɛtʊ ɛwaa maɣmaɣ nɛ pɩwɛɛ ɖeu.",
};

export const RotationSimulator: React.FC<RotationSimulatorProps> = ({
  cropSequence,
  onChangeCrop,
  onApplyPreset,
  simResult,
  viewMode,
  customPrices,
  onUpdatePrice,
  onResetPrice,
  onResetAllPrices,
  regionName,
  pawPercent,
  context,
}) => {
  const cropList = Object.keys(CROP_DATABASE);
  const [playing, setPlaying] = useState<"fr" | "ewe" | "kabye" | null>(null);
  const farmer = viewMode === "farmer";

  const handlePlayVoice = (lang: "fr" | "ewe" | "kabye") => {
    setPlaying(lang);
    window.setTimeout(() => setPlaying(null), 4500);
  };

  const seasonTitle = (index: number) => {
    if (farmer) {
      return index === 0
        ? "Saison 1, grande pluie"
        : index === 1
        ? "Saison 2, petite pluie"
        : "Saison 3, repos ou sécheresse";
    }
    return index === 0
      ? "Saison 1, principale"
      : index === 1
      ? "Saison 2, dérobée"
      : "Saison 3, stabilisation";
  };

  const presetLabel = (name: string) => {
    if (!farmer) return name.split(" (")[0];
    if (name.includes("Soja")) return "Maïs puis soja";
    if (name.includes("Monoculture")) return "Maïs seul";
    return "Bouclier sécheresse";
  };

  const region = regionName || simResult.region || "Savanes";
  const paw = pawPercent ?? 55;

  const evaluatedRecommendations = RECOMMENDED_ROTATIONS.map((rec) => {
    const isCurrent =
      cropSequence[0] === rec.sequence[0] &&
      cropSequence[1] === rec.sequence[1] &&
      cropSequence[2] === rec.sequence[2];
    const recSim = CropRotationEngine.simulateRotation(
      rec.sequence,
      region,
      paw,
      context?.weatherObservation,
      customPrices,
      context
    );
    const diffScore = recSim.resilienceScore - simResult.resilienceScore;
    const diffRevenue = recSim.revenuCumuleEstimeFcfa - simResult.revenuCumuleEstimeFcfa;
    const diffNitrogen = recSim.bilanAzoteTotalKgHa - simResult.bilanAzoteTotalKgHa;
    return {
      rec,
      isCurrent,
      sim: recSim,
      diffScore,
      diffRevenue,
      diffNitrogen,
    };
  });

  return (
    <section className="panel">
      <div className="panel-head">
        <div>
          <h2>{farmer ? "Plan de culture sur trois saisons" : "Succession culturale"}</h2>
          <p className="lede">
            {farmer
              ? "Choisissez les cultures pour voir si le sol s’enrichit et quel revenu le scénario indique."
              : "Simulation agro-climatique sur trois saisons consécutives."}
          </p>
        </div>
        <div className="choice-row" role="group" aria-label="Exemples de succession">
          <span>{farmer ? "Exemples" : "Préréglages"}</span>
          {ROTATION_PRESETS.map((preset) => {
            const isMatch =
              preset.sequence[0] === cropSequence[0] &&
              preset.sequence[1] === cropSequence[1] &&
              preset.sequence[2] === cropSequence[2];
            return (
              <button
                key={preset.name}
                type="button"
                className="choice"
                aria-pressed={isMatch}
                onClick={() => onApplyPreset(preset.sequence)}
              >
                {presetLabel(preset.name)}
              </button>
            );
          })}
        </div>
      </div>

      <div className="seasons">
        {[0, 1, 2].map((cycleIdx) => {
          const selectedCrop = cropSequence[cycleIdx];
          const cropData: CropData = CROP_DATABASE[selectedCrop] || CROP_DATABASE["Maïs"];
          return (
            <div className="season" key={cycleIdx}>
              <div className="season-top">
                <strong>{seasonTitle(cycleIdx)}</strong>
                <span className="days">{cropData.cycleJours} jours</span>
              </div>
              <select
                  className="control"
                  value={selectedCrop}
                  aria-label={`Culture de la saison ${cycleIdx + 1}`}
                  onChange={(event) => onChangeCrop(cycleIdx, event.target.value)}
                >
                  {cropList.map((cropName) => (
                    <option key={cropName} value={cropName}>
                      {cropName}
                    </option>
                  ))}
              </select>

              <div className="price-box">
                <div className="price-header">
                  <span className="price-label">{farmer ? "Prix marché local" : "Prix au kg"}</span>
                  {customPrices && customPrices[selectedCrop] !== undefined && onResetPrice && (
                    <button
                      type="button"
                      className="linkish-mini"
                      onClick={() => onResetPrice(selectedCrop)}
                      title="Rétablir la mercuriale officielle ANSAT"
                    >
                      ↺ Réf. ANSAT ({cropData.valeurCommercialeKgFcfa} F)
                    </button>
                  )}
                </div>
                <div className="price-input-row">
                  <input
                    type="number"
                    className="price-input"
                    min={50}
                    max={5000}
                    step={10}
                    value={customPrices?.[selectedCrop] ?? cropData.valeurCommercialeKgFcfa}
                    onChange={(event) => {
                      const val = Number(event.target.value);
                      if (val > 0 && onUpdatePrice) onUpdatePrice(selectedCrop, val);
                    }}
                    aria-label={`Prix de vente au kg pour ${selectedCrop}`}
                  />
                  <span className="price-unit">FCFA / kg</span>
                </div>
                <div className="price-footer">
                  {customPrices && customPrices[selectedCrop] !== undefined ? (
                    <span className="custom-tag">✓ Prix réseau / marché local</span>
                  ) : (
                    <span className="default-tag">Réf. ANSAT (modifiable)</span>
                  )}
                </div>
              </div>

              {farmer ? (
                <dl className="facts">
                  <div>
                    <dt>Besoin en eau</dt>
                    <dd>{cropData.besoinEauCycleMm > 500 ? "Élevé" : "Modéré"}</dd>
                  </div>
                  <div>
                    <dt>Effet sur le sol</dt>
                    <dd className={cropData.bilanAzoteKgHa > 0 ? "tone-good" : "tone-warn"}>
                      {cropData.bilanAzoteKgHa > 0 ? "Apporte de l’azote" : "Épuise le sol"}
                    </dd>
                  </div>
                  <div>
                    <dt>Face au sec</dt>
                    <dd>
                      {cropData.sensibiliteStressKy > 1 ? "Sensible au manque d’eau" : "Plus résistant"}
                    </dd>
                  </div>
                </dl>
              ) : (
                <dl className="expert-facts">
                  <div>
                    <dt>Eau</dt>
                    <dd>{cropData.besoinEauCycleMm} mm</dd>
                  </div>
                  <div>
                    <dt>Bilan N</dt>
                    <dd className={cropData.bilanAzoteKgHa > 0 ? "tone-good" : "tone-bad"}>
                      {cropData.bilanAzoteKgHa > 0 ? `+${cropData.bilanAzoteKgHa}` : cropData.bilanAzoteKgHa}
                    </dd>
                  </div>
                  <div>
                    <dt>Ky FAO</dt>
                    <dd>{cropData.sensibiliteStressKy}</dd>
                  </div>
                </dl>
              )}
            </div>
          );
        })}
      </div>

      {customPrices && Object.keys(customPrices).length > 0 && onResetAllPrices && (
        <div className="custom-prices-notice">
          <span>ℹ Des prix personnalisés du marché local sont appliqués au calcul du revenu.</span>
          <button type="button" className="linkish-mini" onClick={onResetAllPrices}>
            Rétablir toutes les mercuriales officielles ANSAT
          </button>
        </div>
      )}

      <div className="table-wrap">
        <table className="sheet">
          <thead>
            <tr>
              <th>Saison</th>
              <th>Culture</th>
              <th>{farmer ? "Eau requise" : "Besoin en eau"}</th>
              <th>{farmer ? "Fertilité" : "Azote"}</th>
              <th>{farmer ? "Risque de sécheresse" : "Risque de stress"}</th>
              <th>{farmer ? "Prix marché" : "Prix / kg"}</th>
              <th>{farmer ? "Vente estimée" : "Revenu brut / ha"}</th>
            </tr>
          </thead>
          <tbody>
            {simResult.detailsCycles.map((cycle, i) => (
              <tr key={i}>
                <td>{cycle.saison}</td>
                <td>{cycle.culture}</td>
                <td className="num">{cycle.besoinEauMm} mm</td>
                <td className={`num ${cycle.bilanAzoteKg > 0 ? "tone-good" : "tone-bad"}`}>
                  {cycle.bilanAzoteKg > 0 ? `+${cycle.bilanAzoteKg}` : cycle.bilanAzoteKg} kg
                </td>
                <td className={`num ${cycle.risqueStressPct > 30 ? "tone-bad" : "tone-good"}`}>
                  {cycle.risqueStressPct}%
                </td>
                <td className="num">
                  {cycle.prixKgFcfa.toLocaleString("fr-FR")} F
                  {cycle.isCustomPrice && (
                    <span className="custom-tag-mini" title="Prix ajusté manuellement d’après le marché local">
                      édité
                    </span>
                  )}
                </td>
                <td className="num">{cycle.revenuEstimeFcfa.toLocaleString("fr-FR")} FCFA</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      <div className="advice">
        <div className="advice-bar">
          <div>
            <h3>{farmer ? "Conseil & Stratégies pour le champ" : "Diagnostic & Alternatives Agronomiques"}</h3>
            <p className="advice-subtitle">
              {farmer
                ? "Diagnostic agronomique de votre sélection actuelle et meilleures rotations recommandées pour votre parcelle."
                : "Évaluation multicritère et alternatives de rotation optimisées."}
            </p>
          </div>
          <div className="choice-row" role="group" aria-label="Écouter le conseil">
            <span>Écouter</span>
            {(
              [
                ["fr", "Français"],
                ["ewe", "Éwé"],
                ["kabye", "Kabyè"],
              ] as const
            ).map(([id, label]) => (
              <button
                key={id}
                type="button"
                className="choice"
                aria-pressed={playing === id}
                onClick={() => handlePlayVoice(id)}
              >
                {label}
              </button>
            ))}
          </div>
        </div>
        {playing ? (
          <p className="audio-live" role="status">
            {AUDIO_COPY[playing]}
          </p>
        ) : (
          <div
            className={`diagnostic-box tone-${
              simResult.resilienceScore >= 70
                ? "good"
                : simResult.resilienceScore >= 50
                ? "warn"
                : "bad"
            }`}
          >
            <strong>Diagnostic actuel :</strong> {simResult.recommandationAgronomique}
          </div>
        )}

        <div className="recommendations-box">
          <div className="recommendations-head">
            <h4>
              {farmer
                ? "💡 Meilleures rotations recommandées pour votre parcelle"
                : "Alternatives culturales optimisées"}
            </h4>
            <p className="lede">
              {farmer
                ? "Chaque plan ci-dessous résout un défi précis (régénération du sol, résistance à la sécheresse ou revenu). Cliquez sur un plan pour l'appliquer instantanément au simulateur."
                : "Simulations comparatives multicritères sous contraintes agro-climatiques régionales."}
            </p>
          </div>

          <div className="recommendations-grid">
            {evaluatedRecommendations.map(
              ({ rec, isCurrent, sim, diffScore, diffRevenue, diffNitrogen }) => (
                <article
                  key={rec.id}
                  className={`rec-card ${isCurrent ? "is-active" : ""}`}
                >
                  <div className="rec-card-header">
                    <span className="rec-badge">{rec.badge}</span>
                    {isCurrent && (
                      <span className="rec-current-pill">✓ Plan actif</span>
                    )}
                  </div>

                  <h5 className="rec-title">{rec.name}</h5>
                  <div className="rec-sequence">
                    {rec.sequence.map((crop, idx) => (
                      <React.Fragment key={crop}>
                        <span className="crop-tag">{crop}</span>
                        {idx < rec.sequence.length - 1 && (
                          <span className="arrow">➔</span>
                        )}
                      </React.Fragment>
                    ))}
                  </div>

                  <p className="rec-role">{rec.role}</p>

                  <div className="rec-metrics">
                    <div className="rec-metric">
                      <span className="rec-metric-label">Résilience</span>
                      <strong className="rec-metric-val">
                        {sim.resilienceScore.toLocaleString("fr-FR", {
                          maximumFractionDigits: 1,
                        })}
                        <small>/100</small>
                      </strong>
                      {!isCurrent && diffScore !== 0 && (
                        <span
                          className={`diff-pill ${
                            diffScore > 0 ? "diff-up" : "diff-down"
                          }`}
                        >
                          {diffScore > 0
                            ? `+${diffScore.toFixed(1)} pts`
                            : `${diffScore.toFixed(1)} pts`}
                        </span>
                      )}
                    </div>

                    <div className="rec-metric">
                      <span className="rec-metric-label">Revenu 3 saisons</span>
                      <strong className="rec-metric-val">
                        {sim.revenuCumuleEstimeFcfa.toLocaleString("fr-FR")} F
                      </strong>
                      {!isCurrent && diffRevenue !== 0 && (
                        <span
                          className={`diff-pill ${
                            diffRevenue > 0 ? "diff-up" : "diff-down"
                          }`}
                        >
                          {diffRevenue > 0
                            ? `+${diffRevenue.toLocaleString("fr-FR")} F`
                            : `${diffRevenue.toLocaleString("fr-FR")} F`}
                        </span>
                      )}
                    </div>

                    <div className="rec-metric">
                      <span className="rec-metric-label">Bilan azote</span>
                      <strong
                        className={`rec-metric-val ${
                          sim.bilanAzoteTotalKgHa > 0
                            ? "tone-good"
                            : "tone-bad"
                        }`}
                      >
                        {sim.bilanAzoteTotalKgHa > 0
                          ? `+${sim.bilanAzoteTotalKgHa}`
                          : sim.bilanAzoteTotalKgHa}{" "}
                        kg/ha
                      </strong>
                      {!isCurrent && diffNitrogen !== 0 && (
                        <span
                          className={`diff-pill ${
                            diffNitrogen > 0 ? "diff-up" : "diff-down"
                          }`}
                        >
                          {diffNitrogen > 0
                            ? `+${diffNitrogen} kg`
                            : `${diffNitrogen} kg`}
                        </span>
                      )}
                    </div>
                  </div>

                  <div className="rec-details">
                    <p className="rec-why">{rec.agronomicWhy}</p>
                    <ul className="rec-points">
                      <li>
                        <strong>🌱 Sol :</strong> {rec.points.sol}
                      </li>
                      <li>
                        <strong>💧 Eau :</strong> {rec.points.eau}
                      </li>
                      <li>
                        <strong>💰 Économie :</strong> {rec.points.economie}
                      </li>
                    </ul>
                  </div>

                  <div className="rec-action">
                    {isCurrent ? (
                      <button
                        type="button"
                        className="rec-btn is-current"
                        disabled
                      >
                        ✓ Ce plan est actuellement appliqué
                      </button>
                    ) : (
                      <button
                        type="button"
                        className="rec-btn apply"
                        onClick={() => onApplyPreset(rec.sequence)}
                      >
                        ➔ Appliquer ce plan de culture
                      </button>
                    )}
                  </div>
                </article>
              )
            )}
          </div>
        </div>
      </div>
    </section>
  );
};
