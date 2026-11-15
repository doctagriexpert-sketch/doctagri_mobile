import type { Config } from "tailwindcss";

const config: Config = {
  content: [
    "./src/pages/**/*.{js,ts,jsx,tsx,mdx}",
    "./src/components/**/*.{js,ts,jsx,tsx,mdx}",
    "./src/app/**/*.{js,ts,jsx,tsx,mdx}",
  ],
  theme: {
    extend: {
      colors: {
        nasa: {
          blue: "#0b3d91",
          red: "#fc3d21",
          dark: "#051630",
        },
        togo: {
          green: "#006a4e",
          yellow: "#ffce00",
          red: "#d21034",
        },
      },
    },
  },
  plugins: [],
};

export default config;
