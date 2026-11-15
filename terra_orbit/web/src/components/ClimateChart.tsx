"use client";

import React, { useState } from "react";
import type { ClimateData, RemoteData } from "@/lib/environment";

interface ClimateChartProps {
  regionName: string;
  weather: RemoteData<ClimateData>;
  onRetry: () => void;
}

export function ClimateChart({ regionName, weather, onRetry }: ClimateChartProps) {
  const [activeDate, setActiveDate] = useState<string | null>(null);
  const data = weather.status === "ready" ? weather.data : null;
  const series = data?.series ?? [];
  const validTemps = series.flatMap((point) => (point.tempMean === null ? [] : [point.tempMean]));
  const maxRain = Math.max(10, ...series.map((point) => point.rainMm ?? 0));
  const minTemp = Math.min(20, ...validTemps);
  const maxTemp = Math.max(40, ...validTemps);
  const points = series.map((point, index) => ({
    ...point,
    x: 36 + (index / Math.max(1, series.length - 1)) * 580,
    y:
      point.tempMean === null
        ? null
        : 122 - ((point.tempMean - minTemp) / Math.max(1, maxTemp - minTemp)) * 100,
  }));
  let continuous = false;
  const path = points
    .map((point) => {
      if (point.y === null) {
        continuous = false;
        return "";
      }
      const command = `${continuous ? "L" : "M"} ${point.x},${point.y}`;
      continuous = true;
      return command;
    })
    .join(" ");
  const selected = series.find((point) => point.dateIso === activeDate);
  const display = (value: number | null) => (value === null ? "indisponible" : String(value));

  return (
    <section className="panel">
      <div className="panel-head">
        <div>
          <h2>Historique météo, {regionName}</h2>
          <p className="lede">Source NASA POWER. Les jours sans mesure restent vides.</p>
        </div>
      </div>

      {weather.status === "loading" && <p role="status">Chargement de la météo de cette région.</p>}
      {weather.status === "error" && (
        <div role="alert">
          <p>{weather.error}</p>
          <button type="button" className="linkish" onClick={onRetry}>
            Réessayer les sources
          </button>
        </div>
      )}

      {data && (
        <div className="chart-meta">
          <p className={data.missingDaysCount ? "tone-warn" : "tone-good"}>
            {data.validDaysCount}/{data.periodDays} jours complets. {data.summary.validRainDaysCount}/
            {data.periodDays} jours de pluie renseignés.
            {data.missingDaysCount > 0 && " Données partielles : les valeurs absentes restent inconnues."}
          </p>
          <p>
            Du {series[0]?.dateIso} au {series[series.length - 1]?.dateIso}. Cumul sur les jours
            renseignés : {display(data.summary.totalRainMm)} mm. Plus longue période sèche confirmée :{" "}
            {display(data.summary.maxDrySpellDays)} jours.
          </p>
          <p className="legend">
            <span>
              <i className="swatch swatch-rain" aria-hidden="true" />
              Pluie
            </span>
            <span>
              <i className="swatch swatch-temp" aria-hidden="true" />
              Température moyenne
            </span>
          </p>
          <svg
            viewBox="0 0 640 150"
            className="chart-svg"
            role="img"
            aria-label="Pluie en barres et température en courbe. Interruptions lorsque la donnée manque."
          >
            {points.map((point) => (
              <g
                key={point.dateIso}
                onMouseEnter={() => setActiveDate(point.dateIso)}
                onMouseLeave={() => setActiveDate(null)}
              >
                {point.rainMm !== null && (
                  <rect
                    x={point.x - 4}
                    y={122 - (point.rainMm / maxRain) * 100}
                    width={8}
                    height={(point.rainMm / maxRain) * 100}
                    fill="#1a5c68"
                  />
                )}
                {point.y !== null && (
                  <circle
                    cx={point.x}
                    cy={point.y}
                    r={2.4}
                    fill="#9c341f"
                    data-kind="temperature"
                  />
                )}
              </g>
            ))}
            <path data-kind="temperature-line" d={path} fill="none" stroke="#9c341f" strokeWidth={1.6} />
            {points
              .filter((_, index) => index % 5 === 0 || index === points.length - 1)
              .map((point) => (
                <text
                  key={point.dateIso}
                  x={point.x}
                  y={142}
                  textAnchor="middle"
                  fontSize={10}
                  fill="#5c6660"
                >
                  {point.dateIso.slice(5)}
                </text>
              ))}
          </svg>
          {selected && (
            <p>
              {selected.dateIso} : pluie {display(selected.rainMm)} mm, température{" "}
              {display(selected.tempMean)} °C, minimum {display(selected.tempMin)} °C, maximum{" "}
              {display(selected.tempMax)} °C.
            </p>
          )}
          <p className="footnote">
            Le cumul décrit le passé. Les pluies des cycles à venir restent des hypothèses régionales.
          </p>
        </div>
      )}
    </section>
  );
};
