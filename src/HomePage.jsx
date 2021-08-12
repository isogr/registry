import React from 'react';
import DefaultHomePage from '@riboseinc/react-static-plugin-paneron-registry/DefaultHomePage';
import { itemClassConfiguration } from '@riboseinc/paneron-extension-geodetic-registry/registryConfig';


export default () => (
  <DefaultHomePage itemClassConfiguration={itemClassConfiguration} />
)
