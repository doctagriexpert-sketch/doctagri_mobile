"use client";

import React, { useState } from "react";
import { generateSmsAdvisory } from "@/lib/simulationEngine";

interface RuralInclusionTabProps {
  regionName: string;
  soilMoisturePct: number;
  seedSafe: boolean;
  crop1: string;
  crop2: string;
}

const LANGUAGES = [
  { id: "fr" as const, label: "Français", sub: "Langue officielle" },
  { id: "ewe" as const, label: "Éwé", sub: "Sud, dont le mina" },
  { id: "kabye" as const, label: "Kabyè", sub: "Nord" },
];

export const RuralInclusionTab: React.FC<RuralInclusionTabProps> = ({
  regionName,
  soilMoisturePct,
  seedSafe,
  crop1,
  crop2,
}) => {
  const [language, setLanguage] = useState<"fr" | "ewe" | "kabye">("fr");
  const [phoneMode, setPhoneMode] = useState<"sms" | "ussd">("sms");
  const [ussdStep, setUssdStep] = useState<number>(0);
  const [isPlayingAudio, setIsPlayingAudio] = useState<boolean>(false);

  const currentSms = generateSmsAdvisory(language, regionName, soilMoisturePct, seedSafe, crop1, crop2);

  const handleKeypadPress = (key: string) => {
    if (phoneMode !== "ussd") return;
    if (ussdStep === 0 && key === "#") setUssdStep(1);
    else if (ussdStep === 1) {
      if (key === "1") setUssdStep(2);
      else if (key === "2") setUssdStep(3);
      else if (key === "3") setUssdStep(4);
      else if (key === "4") setUssdStep(5);
    }
  };

  const toggleVoiceAdvisory = () => {
    if (!("speechSynthesis" in window)) return;
    if (isPlayingAudio) {
      window.speechSynthesis.cancel();
      setIsPlayingAudio(false);
      return;
    }
    const utterance = new SpeechSynthesisUtterance(currentSms);
    utterance.lang = "fr-FR";
    utterance.rate = 0.95;
    utterance.onend = () => setIsPlayingAudio(false);
    utterance.onerror = () => setIsPlayingAudio(false);
    setIsPlayingAudio(true);
    window.speechSynthesis.speak(utterance);
  };

  return (
    <section className="panel">
      <div className="panel-head">
        <div>
          <h2>Aperçu des messages</h2>
          <p className="lede">
            Démonstration locale, sans raccordement à un opérateur. Les traductions restent à faire
            valider.
          </p>
        </div>
        <span className="tag">Simulation locale</span>
      </div>

      <div className="rural">
        <div>
          <div className="group">
            <span className="block-label" id="lang-label">
              Langue du message
            </span>
            <div className="option-grid" role="group" aria-labelledby="lang-label">
              {LANGUAGES.map((lang) => (
                <button
                  key={lang.id}
                  type="button"
                  className="option"
                  aria-pressed={language === lang.id}
                  onClick={() => setLanguage(lang.id)}
                >
                  {lang.label}
                  <small>{lang.sub}</small>
                </button>
              ))}
            </div>
          </div>

          <div className="group">
            <span className="block-label" id="mode-label">
              Canal
            </span>
            <div className="option-grid two" role="group" aria-labelledby="mode-label">
              <button
                type="button"
                className="option"
                aria-pressed={phoneMode === "sms"}
                onClick={() => setPhoneMode("sms")}
              >
                SMS
                <small>Message préparé, non envoyé</small>
              </button>
              <button
                type="button"
                className="option"
                aria-pressed={phoneMode === "ussd"}
                onClick={() => {
                  setPhoneMode("ussd");
                  setUssdStep(0);
                }}
              >
                USSD
                <small>Composer *880#</small>
              </button>
            </div>
          </div>

          <button type="button" className="choice" onClick={toggleVoiceAdvisory}>
            {isPlayingAudio ? "Arrêter la lecture" : "Lire l’aperçu dans le navigateur"}
          </button>
        </div>

        <div className="handset" aria-label="Téléphone de démonstration">
          <div className="earpiece" />
          <span className="handset-name">Terra-Orbit</span>
          <div className="lcd">
            <div className="lcd-bar">
              <span>Démonstration</span>
              <span>Réseau</span>
            </div>
            <div className="lcd-body">
              {phoneMode === "sms" ? (
                <>
                  <p>
                    <strong>Aperçu non envoyé</strong>
                  </p>
                  <p style={{ whiteSpace: "pre-line" }}>{currentSms}</p>
                </>
              ) : (
                <>
                  {ussdStep === 0 && (
                    <>
                      <p>
                        <strong>*880# Terra-Orbit</strong>
                      </p>
                      <p>Appuyez sur # pour ouvrir le menu.</p>
                    </>
                  )}
                  {ussdStep === 1 && (
                    <>
                      <p>1. Humidité du sol</p>
                      <p>2. Alerte semis</p>
                      <p>3. Conseil de rotation</p>
                      <p>4. Statut d’assurance</p>
                    </>
                  )}
                  {ussdStep === 2 && (
                    <>
                      <p>
                        <strong>Humidité : {soilMoisturePct}%</strong>
                      </p>
                      <p>Zone : {regionName}</p>
                    </>
                  )}
                  {ussdStep === 3 && (
                    <p>
                      {seedSafe
                        ? "Seuil hydrique du scénario atteint."
                        : "Vérification sur le terrain nécessaire."}
                    </p>
                  )}
                  {ussdStep === 4 && (
                    <p>
                      Rotation : {crop2} après {crop1}.
                    </p>
                  )}
                  {ussdStep === 5 && <p>Aucune assurance souscrite.</p>}
                </>
              )}
            </div>
            <div className="lcd-foot">
              {phoneMode === "ussd" && ussdStep > 1 ? (
                <button type="button" onClick={() => setUssdStep(0)}>
                  Retour
                </button>
              ) : (
                <span>Menu</span>
              )}
              <span>Quitter</span>
            </div>
          </div>
          <div className="keypad">
            {["1", "2", "3", "4", "5", "6", "7", "8", "9", "*", "0", "#"].map((key) => (
              <button
                key={key}
                type="button"
                aria-label={`Touche ${key}`}
                onClick={() => handleKeypadPress(key)}
              >
                {key}
              </button>
            ))}
          </div>
        </div>
      </div>
    </section>
  );
};
