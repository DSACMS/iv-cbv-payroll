module.exports = {
  syntax: 'postcss-scss',
  plugins: [
    require('postcss-import'),
    require('@csstools/postcss-sass')({
      includePaths: ['./node_modules/@uswds/uswds/packages'],
      // Silence Sass 3.0.0 deprecation warnings in @uswds/uswds module. (Hopefully
      // uswds will upgrade to the new functions by 3.0.0's release.)
      quietDeps: true,
      // Silence deprecation warning for postcss-sass.
      // See: https://github.com/csstools/postcss-sass/issues/45
      silenceDeprecations: ['legacy-js-api'],
    }),
    require('autoprefixer'),
    process.env.NODE_ENV === 'production' ? require('postcss-minify') : null,
  ],
}
