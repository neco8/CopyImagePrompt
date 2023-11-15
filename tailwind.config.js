/** @type {import('tailwindcss').Config} */
module.exports = {
  content: ["./src/**/*.{elm,ts}", "./styles/**/*.{scss,css}", "./index.html"],
  theme: {
    extend: {
      fontFamily: {
        poppins: "'Poppins', sans-serif",
      },
    },
  },
  daisyui: {
    themes: [
      {
        mytheme: {
          primary: "#52e5cd",
          secondary: "#6caa1b",
          accent: "#9fd836",
          neutral: "#1f242e",
          "base-100": "#ffffff",
          info: "#8cbade",
          success: "#57ead2",
          warning: "#f4c82a",
          error: "#f75f67",
        },
      },
    ],
  },
  plugins: [require("daisyui")],
};
