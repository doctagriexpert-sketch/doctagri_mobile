"use client";

import React from "react";
import { TOGO_REGIONS, FieldLocation } from "@/data/togoData";

interface HeaderProps {
  currentRegion: string;
  onSelectRegion: (region: string) => void;
  viewMode: "farmer" | "expert";
  onToggleViewMode: (mode: "farmer" | "expert") => void;
  currentLocation?: FieldLocation;
}

function placeLine(lat: number, lon: number) {
  const latLabel = `${Math.abs(lat).toFixed(2)}° ${lat >= 0 ? "N" : "S"}`;
  const lonLabel = `${Math.abs(lon).toFixed(2)}° ${lon >= 0 ? "E" : "O"}`;
  return `${latLabel}, ${lonLabel}`;
}

export const Header: React.FC<HeaderProps> = ({
  currentRegion,
  onSelectRegion,
  viewMode,
  onToggleViewMode,
  currentLocation,
}) => {
  const regionName = currentLocation?.region || currentRegion;
  const regionData = TOGO_REGIONS[regionName] || TOGO_REGIONS["Savanes"];
  const displayTitle = currentLocation?.name || regionData.name;
  const displayWhere = currentLocation?.locality || regionData.chefLieu;
  const lat = currentLocation?.lat ?? regionData.lat;
  const lon = currentLocation?.lon ?? regionData.lon;

  return (
    <header className="mast">
      <div className="mast-inner">
        <div className="mast-top">
          <p className="mark">
            Terra-Orbit
            <span>Togo</span>
          </p>
          <div className="mode" role="group" aria-label="Mode d’affichage">
            <button
              type="button"
              aria-pressed={viewMode === "farmer"}
              onClick={() => onToggleViewMode("farmer")}
            >
              Agriculteur
            </button>
            <button
              type="button"
              aria-pressed={viewMode === "expert"}
              onClick={() => onToggleViewMode("expert")}
            >
              Expert
            </button>
          </div>
        </div>

        <div className="mast-place">
          <h1>{displayTitle}</h1>
          <p className="mast-where">
            {displayWhere}
            <span aria-hidden="true"> — </span>
            {placeLine(lat, lon)}
          </p>
          <p className="mast-climate">
            {regionData.climat}. {regionData.solDominant}.
          </p>
        </div>

        <nav className="places" aria-label="Régions du Togo">
          {Object.keys(TOGO_REGIONS).map((name) => (
            <button
              key={name}
              type="button"
              aria-pressed={name === regionName}
              onClick={() => onSelectRegion(name)}
            >
              {name}
            </button>
          ))}
        </nav>
      </div>
    </header>
  );
};
