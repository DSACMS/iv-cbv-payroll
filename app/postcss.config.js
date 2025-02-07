import autoprefixer from 'autoprefixer';
import postcssMinify from 'postcss-minify';
import postcssImport from 'postcss-import';
import postcssSass from '@csstools/postcss-sass'

export const config = {
  syntax: 'postcss-scss',
  plugins: [
    postcssImport,
    postcssSass({
      includePaths: ['./node_modules/@uswds/uswds/packages'],
      // Silence Sass 3.0.0 deprecation warnings in @uswds/uswds module. (Hopefully
      // uswds will upgrade to the new functions by 3.0.0's release.)
      quietDeps: true,
      // Silence deprecation warning for postcss-sass.
      // See: https://github.com/csstools/postcss-sass/issues/45
      silenceDeprecations: ['legacy-js-api'],
    }),
    autoprefixer,
    process.env.NODE_ENV === 'production' ? postcssMinify : null,
  ],
}

export default config;