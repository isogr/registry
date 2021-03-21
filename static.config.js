import path from 'path'

import { itemClassConfiguration } from '@riboseinc/paneron-extension-geodetic-registry/registryConfig';


const DATASET_ROOT = path.join(__dirname, 'gr-registry');


export default {
  entry: path.join(__dirname, 'src', 'index.jsx'),
  
  getRoutes: async () => {
    return [
    ]
  },
  plugins: [
    [
      '@riboseinc/react-static-plugin-paneron-registry',
      {
        datasetSourcePath: DATASET_ROOT,
        iconURL: 'http://www.electropedia.org/img/logo.jpg',
        urlPrefix: '',
        itemClassConfiguration,
        subregisters: {},
        itemClassPageTemplate: 'src/ItemClassPage',
        itemPageTemplate: 'src/ItemPage',
        subregisterPageTemplate: 'src/SubregisterPage',
        homePageTemplate: 'src/HomePage',
      },
    ],
    require.resolve('react-static-plugin-reach-router'),
    [
      'react-static-plugin-file-watch-reload',
      {
        paths: [`${DATASET_ROOT}/**/*`],
      },
    ],
  ],
};
