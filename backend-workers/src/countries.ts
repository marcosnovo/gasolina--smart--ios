// Static metadata about supported countries.
// Mirrors COUNTRY_INFO in the Bun backend's src/index.ts.

export interface CountryInfo {
  displayName: string;
  currency: string;
  currencySymbol: string;
  supportedFuels: string[];
  dataFreshness: string;
  attribution: { text: string; url: string; license: string };
}

export const COUNTRY_INFO: Record<string, CountryInfo> = {
  ES: {
    displayName: "España",
    currency: "EUR",
    currencySymbol: "€",
    supportedFuels: ["gasolina95", "gasolina98", "dieselA", "dieselPremium", "glp"],
    dataFreshness: "within1hour",
    attribution: {
      text: "Ministerio para la Transición Ecológica y el Reto Demográfico",
      url: "https://geoportalgasolineras.es",
      license: "Reutilización libre",
    },
  },
  GB: {
    displayName: "United Kingdom",
    currency: "GBP",
    currencySymbol: "£",
    supportedFuels: ["e10", "e5", "gasolina98", "dieselA", "dieselPremium"],
    dataFreshness: "within30min",
    attribution: {
      text: "Crown copyright. Source: Fuel Finder, operated by VE3 Global Ltd under the Motor Fuel Price (Open Data) Regulations 2025",
      url: "https://developer.fuel-finder.service.gov.uk",
      license: "Open Government Licence v3.0",
    },
  },
  FR: {
    displayName: "France",
    currency: "EUR",
    currencySymbol: "€",
    supportedFuels: ["e10", "e5", "gasolina98", "dieselA", "e85", "glp"],
    dataFreshness: "within1hour",
    attribution: {
      text: "Licence Ouverte / Open Licence. Source: data.economie.gouv.fr",
      url: "https://data.economie.gouv.fr",
      license: "Licence Ouverte v2.0",
    },
  },
  DE: {
    displayName: "Deutschland",
    currency: "EUR",
    currencySymbol: "€",
    supportedFuels: ["e5", "e10", "dieselA"],
    dataFreshness: "realtime",
    attribution: {
      text: "Spritpreis-Daten von Tankerkönig, lizenziert unter CC BY 4.0",
      url: "https://creativecommons.tankerkoenig.de",
      license: "CC BY 4.0",
    },
  },
  IT: {
    displayName: "Italia",
    currency: "EUR",
    currencySymbol: "€",
    supportedFuels: ["e5", "gasolina98", "dieselA", "dieselPremium", "glp", "gnc"],
    dataFreshness: "daily",
    attribution: {
      text: "Ministero delle Imprese e del Made in Italy (MIMIT)",
      url: "https://www.mimit.gov.it/it/open-data/elenco-dataset/carburanti-prezzi-praticati-e-anagrafica-degli-impianti",
      license: "IODL 2.0",
    },
  },
};

export const SUPPORTED_COUNTRIES = Object.keys(COUNTRY_INFO);
