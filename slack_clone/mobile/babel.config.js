module.exports = {
  presets: ['module:metro-react-native-babel-preset'],
  plugins: [
    'react-native-reanimated/plugin', // Must be last
    [
      'module-resolver',
      {
        root: ['./src'],
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
    ],
  ],
};