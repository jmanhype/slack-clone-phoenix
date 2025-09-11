const {getDefaultConfig, mergeConfig} = require('@react-native/metro-config');

/**
 * Metro configuration
 * https://facebook.github.io/metro/docs/configuration
 */

const config = {
  transformer: {
    getTransformOptions: async () => ({
      transform: {
        experimentalImportSupport: false,
        inlineRequires: true,
      },
    }),
  },
  resolver: {
    alias: {
      '@': './src',
      '@components': './src/components',
      '@screens': './src/screens',
      '@services': './src/services',
      '@store': './src/store',
      '@hooks': './src/hooks',
      '@utils': './src/utils',
      '@types': './src/types',
      '@contexts': './src/contexts',
    },
  },
  watchFolders: [],
};

module.exports = mergeConfig(getDefaultConfig(__dirname), config);