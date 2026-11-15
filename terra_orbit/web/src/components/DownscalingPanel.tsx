"use client";

import React, { useEffect, useState } from "react";
import { MultiSensorDownscaler } from "@/lib/simulationEngine";
import type { SoilInputs } from "@/lib/environment";

interface EarthdataGranule {
  title: string;
  timeStart: string;
  timeEnd?: string;
  dataset: string;
  shortName: string;
  cmrLink?: string;
}

interface EarthdataState {
  loading: boolean;
  source: string;
  smap: EarthdataGranule | null;
  ecostress: EarthdataGranule | null;
  error?: string;
}

interface DownscalingPanelProps {
  slopeDeg: number;
  regionName: string;
  lat?: number;
  lon?: number;
  inputs: SoilInputs | null;
  manual: boolean;
  onChange: (inputs: SoilInputs) => void;
  onUseProvider: () => void;
}

const FIELDS: { key: keyof SoilInputs; label: string; min: number; max: number; step: number }[] = [
  { key: "moisture", label: "Humidité volumique de surface", min: 0, max: 1, step: 0.01 },
  { key: "temperature", label: "Température de surface", min: -90, max: 90, step: 0.5 },
  { key: "ndvi", label: "NDVI hypothétique", min: 0.1, max: 0.85, step: 0.01 },
];

export function DownscalingPanel({
  slopeDeg,
  regionName,
  lat,
  lon,
  inputs,
  manual,
  onChange,
  onUseProvider,
}: DownscalingPanelProps) {
  const [earthdata, setEarthdata] = useState<EarthdataState>({
    loading: false,
    source: "NASA EOSDIS CMR",
    smap: null,
    ecostress: null,
  });

  useEffect(() => {
    if (lat === undefined || lon === undefined) return;
    let cancelled = false;

    setEarthdata((prev) => ({ ...prev, loading: true, error: undefined }));

    fetch(`/api/nasa-earthdata?lat=${lat}&lon=${lon}`)
      .then((res) => {
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        return res.json();
      })
      .then((data) => {
        if (!cancelled) {
          setEarthdata({
            loading: false,
            source: data.source ?? "NASA EOSDIS CMR",
            smap: data.smapGranule ?? null,
            ecostress: data.ecostressGranule ?? null,
          });
        }
      })
      .catch((err) => {
        if (!cancelled) {
          setEarthdata((prev) => ({
            ...prev,
            loading: false,
            error: err instanceof Error ? err.message : "Erreur Earthdata",
          }));
        }
      });

    return () => {
      cancelled = true;
    };
  }, [lat, lon]);

  if (!inputs) {
    return (
      <section className="panel">
        <h2>Estimation de l’humidité du sol</h2>
        <p className="lede">
          Données sol indisponibles. Activez un scénario manuel dans le bandeau du haut.
        </p>
      </section>
    );
  }

  const result = MultiSensorDownscaler.downscaleSoilMoisture(
    inputs.moisture,
    inputs.temperature,
    inputs.ndvi,
    slopeDeg,
    regionName
  );

  return (
    <section className="panel">
      <div className="panel-head">
        <div>
          <h2>Estimation de l’humidité du sol & Super-Résolution</h2>
          <p className="lede">
            La température et l’humidité proviennent du modèle Open-Meteo de surface (0 à 1 cm).
            Le NDVI et la pente régionale sont des hypothèses de travail.
          </p>
        </div>
        <span className="tag">{manual ? "Scénario manuel" : "Modèle et NDVI hypothétique"}</span>
      </div>

      {/* Cartouche NASA Earthdata officiel */}
      <div
        style={{
          border: "1px solid #0284c7",
          backgroundColor: "#f0f9ff",
          borderRadius: "8px",
          padding: "1rem",
          margin: "1rem 0",
        }}
      >
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "0.5rem" }}>
          <strong style={{ color: "#0369a1", fontSize: "0.95rem" }}>
            🛰️ Traçabilité Satellitaire NASA Earthdata (EOSDIS CMR)
          </strong>
          <span style={{ fontSize: "0.8rem", color: "#0284c7" }}>
            {earthdata.loading ? "Interrogation en direct..." : "Catalogue NASA synchronisé"}
          </span>
        </div>

        {earthdata.loading ? (
          <p style={{ margin: 0, fontSize: "0.85rem", color: "#64748b" }}>
            Interrogation des derniers passages orbitaux au-dessus de {regionName}...
          </p>
        ) : (
          <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: "0.75rem", fontSize: "0.85rem" }}>
            <div style={{ background: "#ffffff", padding: "0.6rem", borderRadius: "6px", border: "1px solid #bae6fd" }}>
              <div style={{ fontWeight: 600, color: "#0c4a6e", marginBottom: "2px" }}>
                NASA SMAP L3 (`SPL3SMP_E`)
              </div>
              {earthdata.smap ? (
                <>
                  <div style={{ color: "#334155", wordBreak: "break-all", fontSize: "0.78rem" }}>
                    <strong>Granule :</strong> {earthdata.smap.title}
                  </div>
                  <div style={{ color: "#64748b", marginTop: "2px" }}>
                    Acquis : {new Date(earthdata.smap.timeStart).toLocaleString("fr-FR")}
                  </div>
                  {earthdata.smap.cmrLink && (
                    <a
                      href={earthdata.smap.cmrLink}
                      target="_blank"
                      rel="noreferrer"
                      style={{ color: "#0284c7", textDecoration: "underline", display: "inline-block", marginTop: "4px" }}
                    >
                      Vérifier sur NASA CMR ↗
                    </a>
                  )}
                </>
              ) : (
                <div style={{ color: "#94a3b8" }}>Aucun granule récent sur ces coordonnées</div>
              )}
            </div>

            <div style={{ background: "#ffffff", padding: "0.6rem", borderRadius: "6px", border: "1px solid #bae6fd" }}>
              <div style={{ fontWeight: 600, color: "#0c4a6e", marginBottom: "2px" }}>
                NASA ECOSTRESS L2T (`ECO_L2T_LSTE`)
              </div>
              {earthdata.ecostress ? (
                <>
                  <div style={{ color: "#334155", wordBreak: "break-all", fontSize: "0.78rem" }}>
                    <strong>Scène :</strong> {earthdata.ecostress.title}
                  </div>
                  <div style={{ color: "#64748b", marginTop: "2px" }}>
                    Acquis : {new Date(earthdata.ecostress.timeStart).toLocaleString("fr-FR")}
                  </div>
                  {earthdata.ecostress.cmrLink && (
                    <a
                      href={earthdata.ecostress.cmrLink}
                      target="_blank"
                      rel="noreferrer"
                      style={{ color: "#0284c7", textDecoration: "underline", display: "inline-block", marginTop: "4px" }}
                    >
                      Vérifier sur NASA CMR ↗
                    </a>
                  )}
                </>
              ) : (
                <div style={{ color: "#94a3b8" }}>Aucun granule récent sur ces coordonnées</div>
              )}
            </div>
          </div>
        )}
      </div>

      {manual && (
        <p style={{ marginTop: 0 }}>
          <button type="button" className="linkish" onClick={onUseProvider}>
            Revenir aux données fournisseur
          </button>
        </p>
      )}

      <div className="sliders">
        {FIELDS.map((field) => (
          <label key={field.key}>
            <span className="slider-top">
              <span>{field.label}</span>
              <strong className="num">
                {field.key === "temperature" ? `${inputs[field.key]} °C` : inputs[field.key]}
                {field.key === "moisture" ? " m³/m³" : ""}
              </strong>
            </span>
            <input
              type="range"
              min={field.min}
              max={field.max}
              step={field.step}
              value={inputs[field.key]}
              onChange={(event) =>
                onChange({ ...inputs, [field.key]: Number(event.target.value) })
              }
            />
          </label>
        ))}
      </div>

      <div className="figures">
        <article>
          <h3>Humidité estimée</h3>
          <p>{result.smPercentage}%</p>
        </article>
        <article>
          <h3>Eau disponible</h3>
          <p>{result.pawPercent}%</p>
        </article>
        <article>
          <h3>TVDI</h3>
          <p>{result.tvdi}</p>
        </article>
      </div>
      <p className={result.seedSafe ? "tone-good" : "tone-bad"} style={{ margin: 0 }}>
        {result.seedSafe
          ? "Seuil hydrique du scénario atteint. Le semis reste à confirmer sur le terrain."
          : "Seuil hydrique du scénario insuffisant. À vérifier sur le terrain."}
      </p>
    </section>
  );
}
