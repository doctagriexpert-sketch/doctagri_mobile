"use client";

import React from "react";
import { DownscalingResult, RotationSimulationResult } from "@/lib/simulationEngine";

interface VisualMetricsProps {
  downscaleResult: DownscalingResult;
  simResult: RotationSimulationResult;
  viewMode: "farmer" | "expert";
}

function toneOf(score: number): "good" | "warn" | "bad" {
  if (score >= 70) return "good";
  if (score >= 50) return "warn";
  return "bad";
}

export const VisualMetrics: React.FC<VisualMetricsProps> = ({
  downscaleResult,
  simResult,
  viewMode,
}) => {
  const score = simResult.resilienceScore;
  const tone = toneOf(score);
  const farmer = viewMode === "farmer";

  const status =
    tone === "good"
      ? farmer
        ? "Scénario favorable, à vérifier sur la parcelle"
        : "Scénario favorable"
      : tone === "warn"
      ? farmer
        ? "Risque moyen : la succession peut encore être ajustée"
        : "Résilience modérée"
      : farmer
      ? "Risque élevé : la terre s’épuise dans ce scénario"
      : "Scénario critique";

  const heatHigh = downscaleResult.tvdi > 0.6;

  return (
    <div className="stack">
      <section className="scoreband" aria-label="Résilience du scénario">
        <div>
          <p className="score-label">Résilience du scénario</p>
          <p className="score">
            {score.toLocaleString("fr-FR", { maximumFractionDigits: 1 })}
            <span>/ 100</span>
          </p>
          <p className={`score-note tone-${tone}`}>{status}</p>
          <div className={`meter tone-${tone}`} aria-hidden="true">
            <span style={{ width: `${Math.max(0, Math.min(100, score))}%` }} />
          </div>
          <p className="score-note">
            {farmer
              ? "Indice exploratoire. Il ne remplace pas une mesure sur votre champ."
              : "Score agro-climatique sur trois saisons, sans calibration parcellaire."}
          </p>
        </div>
        <dl className="totals">
          <div>
            <dt>{farmer ? "Revenu estimé" : "Revenu estimé"}</dt>
            <dd>{simResult.revenuCumuleEstimeFcfa.toLocaleString("fr-FR")} FCFA</dd>
          </div>
          <div>
            <dt>{farmer ? "Gain par millimètre d’eau" : "Efficacité de l’eau"}</dt>
            <dd>{simResult.wueFcfaParMmEau.toLocaleString("fr-FR")} F/mm</dd>
          </div>
        </dl>
      </section>

      <section className="readings" aria-label="Lectures du scénario">
        <article>
          <h3>{farmer ? "Humidité du sol" : "Humidité estimée"}</h3>
          <p className="reading">{downscaleResult.smPercentage}%</p>
          <p className={`reading-note ${downscaleResult.seedSafe ? "tone-good" : "tone-bad"}`}>
            {farmer
              ? downscaleResult.seedSafe
                ? "Seuil hydrique atteint dans le scénario"
                : "Seuil hydrique insuffisant dans le scénario"
              : `${downscaleResult.smFine30mM3M3} m³/m³`}
          </p>
        </article>

        <article>
          <h3>{farmer ? "Chaleur des plants" : "Indice TVDI"}</h3>
          <p className="reading">{farmer ? (heatHigh ? "Élevée" : "Modérée") : downscaleResult.tvdi}</p>
          <p className={`reading-note ${heatHigh ? "tone-warn" : "tone-good"}`}>
            {farmer
              ? heatHigh
                ? "Pailler le sol pour limiter l’évaporation"
                : "Feuillage dans une plage acceptable"
              : heatHigh
              ? "Stress hydrique"
              : "Évapotranspiration régulée"}
          </p>
        </article>

        <article>
          <h3>{farmer ? "Eau utile aux racines" : "Eau utile (PAW)"}</h3>
          <p className="reading">{downscaleResult.pawPercent}%</p>
          <p className={`reading-note ${downscaleResult.seedSafe ? "tone-good" : "tone-bad"}`}>
            {downscaleResult.seedSafe ? "Seuil hydrique atteint" : "Seuil hydrique insuffisant"}
          </p>
        </article>

        <article>
          <h3>{farmer ? "Nourriture du sol" : "Bilan azote"}</h3>
          <p className={`reading ${simResult.bilanAzoteTotalKgHa > 0 ? "tone-good" : "tone-bad"}`}>
            {simResult.bilanAzoteTotalKgHa > 0 ? "+" : ""}
            {simResult.bilanAzoteTotalKgHa}
            <span style={{ fontSize: "0.85rem", fontWeight: 500, color: "var(--muted)" }}> kg/ha</span>
          </p>
          <p className="reading-note">
            {farmer
              ? simResult.bilanAzoteTotalKgHa > 0
                ? "Le sol gagne de l’azote sans engrais minéral"
                : "Le sol perd de l’azote : une légumineuse le compense"
              : simResult.bilanAzoteTotalKgHa > 0
              ? "Régénération nette"
              : "Déficit minéral"}
          </p>
        </article>

        <article>
          <h3>{farmer ? "Tenue du sol à la pluie" : "Protection anti-érosion"}</h3>
          <p className="reading">
            {simResult.scoreProtectionErosion.toLocaleString("fr-FR", { maximumFractionDigits: 1 })}%
          </p>
          <p className="reading-note">
            {farmer ? "Part du sol retenue face au ruissellement" : "Couverture de pente"}
          </p>
        </article>
      </section>
    </div>
  );
};
