/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    './Resources/**/*.leaf',
    './Public/**/*.html',
  ],
  theme: {
    extend: {
      brightness: {
        5: '.05'
      },
      colors: {
        gray: {
          900: '#0d1117', // Dark background
          800: '#161b22', // Darker background for elements
          700: '#21262d', // Borders or secondary background
          300: '#c9d1d9', // Text color
        },
        blue: {
          600: '#238636', // GitHub-style blue
        },
      },
    },
  },
  plugins: [
    require('@tailwindcss/forms'),
    require('@tailwindcss/typography'),
  ]
}
