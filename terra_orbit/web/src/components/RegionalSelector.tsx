"use client";

import React from "react";
import { TOGO_REGIONS, TogoRegion } from "@/data/togoData";
import { MapPin, CloudRain, Mountain, Layers, AlertTriangle } from "lucide-react";

interface RegionalSelectorProps {
  selectedRegion: string;
  onSelectRegion: (regionName: string) => void;
}

export const RegionalSelector: React.FC<RegionalSelectorProps> = ({
  selectedRegion,
  onSelectRegion,
}) => {
  const current = TOGO_REGIONS[selectedRegion] || TOGO_REGIONS["Savanes"];

  return (
    <div className="bg-white/80 dark:bg-slate-900/80 backdrop-blur-xl border border-slate-200/80 dark:border-slate-800 rounded-2xl p-5 shadow-lg shadow-slate-200/50 dark:shadow-none transition-all">
      <div className="flex items-center justify-between mb-4 pb-3 border-b border-slate-100 dark:border-slate-800">
        <div className="flex items-center gap-2">
          <div className="p-2 rounded-lg bg-emerald-500/10 text-emerald-600 dark:text-emerald-400">
            <MapPin className="w-5 h-5" />
          </div>
          <div>
            <h2 className="text-lg font-bold text-slate-900 dark:text-white">
              Territoire & Agro-Écologie (Togo)
            </h2>
            <p className="text-xs text-slate-500 dark:text-slate-400">
              5 zones économiques et pédo-climatiques calibrées
            </p>
          </div>
        </div>
        <span className="text-xs px-2.5 py-1 rounded-full font-bold bg-slate-100 dark:bg-slate-800 text-slate-600 dark:text-slate-300">
          Chef-lieu : <span className="text-emerald-600 dark:text-emerald-400">{current.chefLieu}</span>
        </span>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-12 gap-5 items-center">
        {/* Interactive Region Pills / Grid */}
        <div className="lg:col-span-8 flex flex-col gap-3">
          <div className="grid grid-cols-2 sm:grid-cols-5 gap-2">
            {Object.keys(TOGO_REGIONS).map((regName) => {
              const reg = TOGO_REGIONS[regName];
              const isSelected = regName === selectedRegion;
              return (
                <button
                  key={reg.id}
                  onClick={() => onSelectRegion(regName)}
                  className={`flex flex-col p-3 rounded-xl border text-left transition-all relative overflow-hidden group ${
                    isSelected
                      ? "bg-gradient-to-br from-emerald-600 to-teal-700 text-white border-transparent shadow-md shadow-emerald-600/30 ring-2 ring-emerald-500/50 scale-[1.02]"
                      : "bg-slate-50 dark:bg-slate-800/60 text-slate-700 dark:text-slate-300 border-slate-200 dark:border-slate-700/60 hover:bg-slate-100 dark:hover:bg-slate-800"
                  }`}
                >
                  <div className="flex items-center justify-between w-full mb-1">
                    <span className="text-xs uppercase tracking-wider font-semibold opacity-75">
                      Région
                    </span>
                    {isSelected && (
                      <span className="w-2 h-2 rounded-full bg-yellow-300 animate-pulse" />
                    )}
                  </div>
                  <span className="font-bold text-sm tracking-tight">{reg.name}</span>
                  <span className={`text-[11px] mt-1 font-mono ${isSelected ? "text-emerald-100" : "text-slate-500 dark:text-slate-400"}`}>
                    {reg.pluviometrieAnnuelleMoy} mm/an
                  </span>
                </button>
              );
            })}
          </div>

          {/* Region metadata card */}
          <div className="grid grid-cols-1 sm:grid-cols-3 gap-3 p-3.5 rounded-xl bg-slate-50/90 dark:bg-slate-800/40 border border-slate-200/70 dark:border-slate-800 text-xs">
            <div className="flex items-start gap-2">
              <CloudRain className="w-4 h-4 text-sky-500 shrink-0 mt-0.5" />
              <div>
                <p className="font-semibold text-slate-800 dark:text-slate-200">Climat & Pluviométrie</p>
                <p className="text-slate-600 dark:text-slate-400 leading-snug">{current.climat}</p>
                <p className="text-[11px] text-sky-600 dark:text-sky-400 font-mono mt-0.5">{current.regimePluviometrique}</p>
              </div>
            </div>

            <div className="flex items-start gap-2">
              <Layers className="w-4 h-4 text-amber-500 shrink-0 mt-0.5" />
              <div>
                <p className="font-semibold text-slate-800 dark:text-slate-200">Sol & Réserve Utile</p>
                <p className="text-slate-600 dark:text-slate-400 leading-snug">{current.solDominant}</p>
                <p className="text-[11px] text-amber-600 dark:text-amber-400 font-mono mt-0.5">RU sol : {current.reserveUtileSolMm} mm</p>
              </div>
            </div>

            <div className="flex items-start gap-2">
              <Mountain className="w-4 h-4 text-purple-500 shrink-0 mt-0.5" />
              <div>
                <p className="font-semibold text-slate-800 dark:text-slate-200">Relief SRTM 30m</p>
                <p className="text-slate-600 dark:text-slate-400 leading-snug">Altitude : {current.altitudeMoySrtm} m</p>
                <p className="text-[11px] text-purple-600 dark:text-purple-400 font-mono mt-0.5">Pente moyenne : {current.penteMoyenneDeg}°</p>
              </div>
            </div>
          </div>

          {/* Major risk banner */}
          <div className="flex items-center gap-2 px-3 py-2 rounded-lg bg-amber-500/10 border border-amber-500/20 text-xs text-amber-800 dark:text-amber-300">
            <AlertTriangle className="w-4 h-4 shrink-0 text-amber-600 dark:text-amber-400" />
            <span className="font-medium">
              <b>Risque identifié :</b> {current.risqueMajeur}
            </span>
          </div>
        </div>

        {/* SVG Togo Map showing the 5 regions North to South */}
        <div className="lg:col-span-4 flex flex-col items-center justify-center p-3 rounded-xl bg-gradient-to-b from-slate-900 to-slate-950 border border-slate-800 text-white relative">
          <div className="flex items-center justify-between w-full mb-2 px-1">
            <span className="text-[11px] font-bold text-slate-400 uppercase tracking-widest flex items-center gap-1">
              Carte Vectorielle Togo
            </span>
            <span className="text-[10px] px-2 py-0.5 rounded bg-emerald-500/20 text-emerald-400 font-mono">
              6°N - 11°N
            </span>
          </div>

          <div className="relative w-48 h-64 flex items-center justify-center">
            <svg
              viewBox="0 0 220 380"
              className="w-full h-full filter drop-shadow-[0_0_12px_rgba(16,185,129,0.2)]"
            >
              {/* Regional polygons */}
              {Object.keys(TOGO_REGIONS).map((regName) => {
                const reg = TOGO_REGIONS[regName];
                const isSelected = regName === selectedRegion;
                return (
                  <path
                    key={reg.id}
                    d={reg.pathD}
                    onClick={() => onSelectRegion(regName)}
                    className="cursor-pointer transition-all duration-300"
                    fill={isSelected ? "#10b981" : "#334155"}
                    stroke={isSelected ? "#34d399" : "#64748b"}
                    strokeWidth={isSelected ? "2.5" : "1.2"}
                    opacity={isSelected ? 1 : 0.65}
                  >
                    <title>{`${reg.name} (${reg.chefLieu})`}</title>
                  </path>
                );
              })}

              {/* Labels for regions */}
              <text x="75" y="44" fill="#fff" fontSize="10" fontWeight="bold">Savanes</text>
              <text x="85" y="98" fill="#fff" fontSize="10" fontWeight="bold">Kara</text>
              <text x="92" y="162" fill="#fff" fontSize="10" fontWeight="bold">Centrale</text>
              <text x="100" y="240" fill="#fff" fontSize="10" fontWeight="bold">Plateaux</text>
              <text x="105" y="325" fill="#fff" fontSize="10" fontWeight="bold">Maritime</text>

              {/* Ocean indicator */}
              <text x="110" y="372" fill="#38bdf8" fontSize="8" fontStyle="italic">Océan Atlantique</text>
            </svg>
          </div>

          <p className="text-[10px] text-slate-400 text-center mt-1">
            Cliquez sur une région pour re-calculer les bilans pédo-climatiques
          </p>
        </div>
      </div>
    </div>
  );
};
